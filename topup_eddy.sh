#!/bin/bash
set -euo pipefail
#set -x

###############################################################################
# DWI distortion + motion/eddy correction using TOPUP + EDDY
#
# Key features:
#  1) TOPUP is estimated from opposite phase-encoded b0 images and is applied to
#     the full DWI series through EDDY using --topup=...
#  2) If epi1/epi2 are provided as separate AP/PA EPI field-map images, they are
#     used for TOPUP instead of extracting b0 volumes from diff/rdif.
#  3) If rdif is used, b0 volumes are extracted from diff and rdif. The rdif mean
#     b0 is resampled to the diff b0 grid only when needed, without rigid
#     registration, before merging the b0 images for TOPUP.
#  4) Diffusion metadata, including PhaseEncodingDirection and TotalReadoutTime,
#     is read from embedded metadata in config.json under ._inputs[].meta.
#  5) Legacy encode/param values are used as fallback when embedded metadata are
#     incomplete.
#  6) Optional sstrip creates a mask for TOPUP inputs without modifying the
#     original epi1/epi2 images.
#
# Requirements:
#  - FSL: topup, eddy_openmp/eddy_cuda/eddy_cpu, bet, fslmaths, fslmerge,
#         fslinfo, select_dwi_vols, flirt
#  - jq, python3
#
# Notes:
#  - Required inputs: diff, bvec, bval.
#  - TOPUP requires either:
#      (a) reverse phase-encoded DWI inputs: rdif, rbvc, rbvl, or
#      (b) EPI field-map inputs: epi1, epi2, epi1_json, epi2_json.
#  - If mergefull=true, rdif/rbvc/rbvl are also merged into the EDDY input.
#  - Final outputs are written to dwi/ and mask/. Intermediate TOPUP/EDDY files
#    are archived in raw/.
###############################################################################


hash -r

# Internal debug toggle (not from config.json)
DEBUG=1
DEBUG="${DEBUG:-0}"

for cmd in fslinfo topup fslmaths fslmerge bet select_dwi_vols flirt; do
  command -v "$cmd" >/dev/null || { echo "ERROR: missing $cmd"; exit 1; }
done
echo "topup=$(command -v topup)"

harmonize_bvals_file() {
  local bvals_file="$1"
  local targets_csv="$2"
  local tol="$3"

  [[ -f "$bvals_file" ]] || { echo "ERROR: missing bvals file $bvals_file"; exit 1; }
  [[ -n "$targets_csv" ]] || { echo "ERROR: harmonize_shells=true but shell_targets is empty"; exit 1; }

  if ! awk -v x="$tol" 'BEGIN{exit(x+0==x?0:1)}'; then
    echo "ERROR: shell_tolerance must be numeric (got: $tol)"
    exit 1
  fi

  cp "$bvals_file" "${bvals_file}.before_harmonize"

python3 - "$bvals_file" "$targets_csv" "$tol" <<'PY'
import sys, math

bvals_file = sys.argv[1]
targets_raw = sys.argv[2].strip().strip('"').strip("'")
targets = [float(x.strip()) for x in targets_raw.split(",") if x.strip() != ""]
tol = float(sys.argv[3])

with open(bvals_file, "r") as f:
    vals = [float(x) for x in f.read().split()]

mapped = []
changes = []

for v in vals:
    nearest = min(targets, key=lambda t: abs(v - t))
    dist = abs(v - nearest)
    if dist > tol:
        sys.stderr.write(
            f"ERROR: b-value {v:g} is farther than tolerance {tol:g} from all shell_targets {targets}\n"
        )
        sys.exit(2)
    mapped.append(nearest)
    if nearest != v:
        changes.append((v, nearest))

def fmt(x):
    if abs(x - round(x)) < 1e-6:
        return str(int(round(x)))
    return f"{x:.6g}"

with open(bvals_file, "w") as f:
    f.write(" ".join(fmt(x) for x in mapped) + "\n")

orig_unique = sorted(set(vals))
new_unique = sorted(set(mapped))

print("Shell harmonization enabled")
print("Original unique bvals:", " ".join(fmt(x) for x in orig_unique))
print("Snapped   unique bvals:", " ".join(fmt(x) for x in new_unique))

if changes:
    summary = {}
    for a, b in changes:
        summary.setdefault((a, b), 0)
        summary[(a, b)] += 1
    print("Mappings:")
    for (a, b), n in sorted(summary.items(), key=lambda kv: (kv[0][1], kv[0][0])):
        print(f"  {fmt(a)} -> {fmt(b)}   (n={n})")
else:
    print("No bvals needed harmonization")
PY
}

norm_bool () {
  local x="${1:-}"
  x="${x,,}"   # lowercase

  case "$x" in
    true|1)  echo "true" ;;
    false|0|"") echo "false" ;;
    *) echo "$x" ;;   # pass-through (avoid silent corruption)
  esac
}

dump_cfg_vars() {
  [[ "$DEBUG" == "1" ]] || return 0
  echo "===== DEBUG: parsed config vars ====="
  echo "PWD=$(pwd)"
  echo "CFG=$CFG"
  echo "PATH=$PATH"
  echo "JQ_BIN=${JQ_BIN:-<shim>}"
  echo

  # Show key values
  printf "diff=%q\nbvec=%q\nbval=%q\n" "$diff" "$bvec" "$bval"
  printf "rdif=%q\nrbvc=%q\nrbvl=%q\n" "$rdif" "$rbvc" "$rbvl"
  printf "epi1=%q\nepi2=%q\nepi1_json=%q\nepi2_json=%q\n" "$epi1" "$epi2" "$epi1_json" "$epi2_json"
  printf "encode=%q\nparam=%q\n" "$encode" "$param"
  printf "merge_full=%q\nreslice=%q\nsstrip=%q\neddy_cuda=%q\ncuda_version=%q\n" \
    "$merge_full" "$reslice" "$sstrip" "$eddy_cuda" "$cuda_version"
  printf "refvol=%q\n" "$refvol"
  echo

  # Existence checks (this is the money)
  echo "===== DEBUG: file existence ====="
  for f in "$CFG" "$diff" "$bvec" "$bval" "$rdif" "$rbvc" "$rbvl" "$epi1" "$epi2" "$epi1_json" "$epi2_json"; do
    [[ -z "$f" ]] && continue
    if [[ -e "$f" ]]; then
      echo "OK:  $f"
    else
      echo "MISS:$f"
    fi
  done
  echo "===================================="
}

# -----------------------
# JSON reader fallback (jq shim with defaults + --arg)
# -----------------------
JQ_BIN="$(type -P jq || true)"

json_get() {
  # Usage:
  #   json_get '<expr>' [--arg NAME VALUE ...]
  local expr="$1"; shift || true

  # Collect --arg pairs (we only really need ID, but make it generic)
  local args=()
  while [[ "${1:-}" == "--arg" ]]; do
    shift
    local k="${1:-}"; shift
    local v="${1:-}"; shift
    args+=("$k=$v")
  done

  if [[ -n "${JQ_BIN:-}" ]]; then
    # If real jq exists, just use it
    "$JQ_BIN" -r "$expr" "$CFG"
    return
  fi

  # Python fallback: supports:
  #   .key
  #   .key // empty
  #   .key // "false"  (or any string)
  #   .key // 0        (or any number)
  #   ._inputs[] | select(.id==$ID) | .meta.FIELD // empty
  python3 - "$CFG" "$expr" "${args[@]}" <<'PY'
import json,sys,re

cfg=sys.argv[1]
expr=sys.argv[2].strip()
kv = {}
for a in sys.argv[3:]:
    if "=" in a:
        k,v = a.split("=",1)
        kv[k]=v

with open(cfg) as f:
    d=json.load(f)

def print_val(v):
    if v is None:
        print("")
    elif isinstance(v, bool):
        print("true" if v else "false")
    elif isinstance(v,(dict,list)):
        print(json.dumps(v))
    else:
        print(v)

# Handle: ._inputs[] | select(.id==$ID) | .meta.FIELD // empty
m = re.match(r'^\._inputs\[\]\s*\|\s*select\(\.id==\$(\w+)\)\s*\|\s*\.meta\.([A-Za-z0-9_]+)\s*(//\s*empty)?\s*$', expr)
if m:
    varname = m.group(1)
    field = m.group(2)
    want = kv.get(varname,"")
    for it in d.get("_inputs",[]) or []:
        if str(it.get("id","")) == want:
            meta = it.get("meta",{}) or {}
            print_val(meta.get(field,""))
            sys.exit(0)
    print("")
    sys.exit(0)

# Handle: .key [// default]
m = re.match(r'^\.(\w+)\s*(//\s*(empty|"[^"]*"|[-+]?\d+(?:\.\d+)?))?\s*$', expr)
if not m:
    # unsupported expression
    print("")
    sys.exit(0)

key = m.group(1)
default_raw = m.group(3)

v = d.get(key, None)

if v is None or v == "":
    if default_raw is None or default_raw == "empty":
        print("")
    elif default_raw.startswith('"') and default_raw.endswith('"'):
        print(default_raw[1:-1])
    else:
        print(default_raw)
else:
    print_val(v)
PY
}

# jq compatibility shim ONLY if no real jq binary exists
if [[ -z "${JQ_BIN:-}" ]]; then
  jq() {
    # supports: jq -r [--arg K V ...] '<expr>' "$CFG"
    [[ "${1:-}" == "-r" ]] && shift

    local args=()
    while [[ "${1:-}" == "--arg" ]]; do
      args+=("$1" "$2" "$3")
      shift 3
    done

    local expr="${1:-}"; shift || true
    # ignore filename arg; always reads $CFG
    json_get "$expr" "${args[@]}"
  }
fi

pick_eddy_cuda() {
  local bindir="${FSLDIR:-/usr/local/fsl}/bin"

  # if user pins a version, prefer that
  if [[ -n "${cuda_version:-}" ]]; then
    local want="${bindir}/eddy_cuda${cuda_version}"
    [[ -x "$want" ]] && { echo "$want"; return 0; }
    echo "ERROR: requested cuda_version=${cuda_version} not available in ${bindir}" >&2
    ls -1 "${bindir}"/eddy_cuda* 2>/dev/null >&2 || true
    return 3
  fi

  # prefer versioned binaries if present, else fall back to plain eddy_cuda
  mapfile -t cuda_bins < <(ls -1 "${bindir}"/eddy_cuda* 2>/dev/null | grep -E 'eddy_cuda[0-9]+' || true)
  if [[ ${#cuda_bins[@]} -gt 0 ]]; then
    local latest
    latest=$(printf "%s\n" "${cuda_bins[@]##*/}" | sed 's/^eddy_cuda//' | sort -V | tail -n 1)
    echo "${bindir}/eddy_cuda${latest}"
    return 0
  fi

  if [[ -x "${bindir}/eddy_cuda" ]]; then
    echo "${bindir}/eddy_cuda"
    return 0
  fi

  echo "ERROR: eddy_cuda requested but no eddy_cuda binaries found in ${bindir}" >&2
  return 2
}

CFG="config.json"
if [[ ! -f "$CFG" ]]; then
  echo "ERROR: config.json not found in current directory."
  exit 1
fi

# -----------------------
# Config: required paths
# -----------------------
diff=$(jq -r '.diff' "$CFG")
bvec=$(jq -r '.bvec' "$CFG")
bval=$(jq -r '.bval' "$CFG")

# Optional opposite-PE DWI (only needed if mergefull=true and you want to use it)
rdif=$(jq -r '.rdif // empty' "$CFG")
rbvc=$(jq -r '.rbvc // empty' "$CFG")
rbvl=$(jq -r '.rbvl // empty' "$CFG")

# Optional EPI b0 pair for topup
epi1=$(jq -r '.epi1 // empty' "$CFG")
epi2=$(jq -r '.epi2 // empty' "$CFG")
epi1_json=$(jq -r '.epi1_json // empty' "$CFG")
epi2_json=$(jq -r '.epi2_json // empty' "$CFG")

# Legacy (Brainlife) metadata fallback
encode=$(jq -r '.encode // empty' "$CFG")   # expected "AP" or "PA"
param=$(jq -r '.param // empty' "$CFG")     # TotalReadoutTime (seconds)

# Topup options (kept from your original style)
warpres=$(jq -r '.warpres // empty' "$CFG")
subsamp=$(jq -r '.subsamp // empty' "$CFG")
fwhm=$(jq -r '.fwhm // empty' "$CFG")
miter=$(jq -r '.miter // empty' "$CFG")
lambda=$(jq -r '.lambda // empty' "$CFG")
ssqlambda=$(jq -r '.ssqlambda // empty' "$CFG")
regmod=$(jq -r '.regmod // empty' "$CFG")
estmov=$(jq -r '.estmov // empty' "$CFG")
minmet=$(jq -r '.minmet // empty' "$CFG")
splineorder=$(jq -r '.splineorder // empty' "$CFG")
numprec=$(jq -r '.numprec // empty' "$CFG")
interp=$(jq -r '.interp // empty' "$CFG")
scale=$(jq -r '.scale // "false"' "$CFG")
regrid=$(jq -r '.regrid // "false"' "$CFG")

# Eddy options
refvol=$(jq -r '.refvol // 0' "$CFG")
slspec=$(jq -r '.slspec // empty' "$CFG")
mporder=$(jq -r '.mporder // 0' "$CFG")
repol=$(jq -r '.repol // "false"' "$CFG")
repol="$(norm_bool "$repol")"
# Behavior flags
reslice=$(jq -r '.reslice // "false"' "$CFG")
merge_full=$(jq -r '.mergefull // "false"' "$CFG")
sstrip=$(jq -r '.sstrip // "false"' "$CFG")
eddy_cuda=$(jq -r '.eddy_cuda // "false"' "$CFG")
cuda_version=$(jq -r '.cuda_version // empty' "$CFG")
data_is_shelled=$(jq -r '.data_is_shelled // "false"' "$CFG")
#harmonize_shells
harmonize_shells=$(jq -r '.harmonize_shells // "false"' "$CFG")
harmonize_shells="$(norm_bool "$harmonize_shells")"
shell_targets=$(jq -r '.shell_targets // empty' "$CFG")
shell_tolerance=$(jq -r '.shell_tolerance // 120' "$CFG")

dump_cfg_vars

# normalize boolean-ish strings to "true"/"false"

reslice="$(norm_bool "$reslice")"
merge_full="$(norm_bool "$merge_full")"
sstrip="$(norm_bool "$sstrip")"
eddy_cuda="$(norm_bool "$eddy_cuda")"
scale="$(norm_bool "$scale")"
regrid="$(norm_bool "$regrid")"


EDDY_BIN=""

if [[ "$eddy_cuda" == "true" ]]; then
  EDDY_BIN="$(pick_eddy_cuda)" || exit $?
  echo "Using GPU eddy: $(basename "$EDDY_BIN")"
else
  if command -v eddy_openmp >/dev/null; then
    EDDY_BIN="eddy_openmp"
  elif command -v eddy_cpu >/dev/null; then
    EDDY_BIN="eddy_cpu"
  elif command -v eddy >/dev/null; then
    EDDY_BIN="eddy"
  else
    echo "ERROR: no CPU eddy binary found (expected eddy_openmp or eddy_cpu)"
    exit 1
  fi
  echo "Using CPU eddy: $(basename "$EDDY_BIN")"
fi

# -----------------------
# Helpers
# -----------------------

# Legacy fallback: replicate original Brainlife encode/param -> acq_params.txt mapping
# diff is always row 1, rdif is always row 2 (same order as b0_images merge)
get_legacy_ped_trt() {
  local which="$1"  # "diff" or "rdif"

  [[ -n "${encode:-}" && -n "${param:-}" ]] || return 1

  # validate param numeric-ish
  if ! awk -v x="$param" 'BEGIN{exit(x+0==x?0:1)}'; then
    echo "ERROR: param must be numeric TotalReadoutTime in seconds (got: '$param')" >&2
    return 3
  fi

  local diff_ped="" rdif_ped=""

  case "$encode" in
    PA)
      diff_ped="j"
      rdif_ped="j-"
      ;;
    AP)
      diff_ped="j-"
      rdif_ped="j"
      ;;
    LR)
      diff_ped="i-"
      rdif_ped="i"
      ;;
    *)
      # legacy "else" branch (effectively RL)
      diff_ped="i"
      rdif_ped="i-"
      ;;
  esac

  if [[ "$which" == "diff" ]]; then
    echo "$diff_ped $param"
  else
    echo "$rdif_ped $param"
  fi
}

log() { echo "[$(date +'%F %T')] $*"; }

debug_dump() {
  [[ "${DEBUG:-0}" -eq 1 ]] || return 0

  log "=== EDDY INPUT DEBUG ==="
  log "data dim4: $(fslinfo data.nii.gz | awk '/^dim4/ {print $2}')"

  log "bvals (last 120 chars):"
  tail -c 120 bvals | cat -A; echo

  log "bvecs (first 2 lines):"
  head -n 2 bvecs || true

  python - <<'PY'
import numpy as np
b = np.loadtxt("bvals").reshape(-1)
print("bvals_tokens=", b.size, "unique_shells=", len(set(b.tolist())), "min=", b.min(), "max=", b.max())
v = np.loadtxt("bvecs")
print("bvecs_shape=", v.shape)
PY
}



sanitize_and_validate_eddy_inputs() {
  # DO NOT overwrite bvecs here — it might be merged already
  # bvals: force single line + newline at end
  tr -s '[:space:]' ' ' < bvals | tr '\n' ' ' | sed 's/^ *//; s/ *$//' > bvals.tmp
  printf "%s\n" "$(cat bvals.tmp)" > bvals
  rm -f bvals.tmp

  # bvecs: clean whitespace but preserve 3-row structure
  sed 's/,/ /g; s/[[:space:]]\+/ /g; s/^ *//; s/ *$//' bvecs > bvecs.tmp
  mv bvecs.tmp bvecs

  local nvol
  nvol=$(fslinfo data.nii.gz | awk '/^dim4/ {print $2}')

  python - <<PY
import numpy as np, sys
nvol = int("$nvol")
b = np.loadtxt("bvals").reshape(-1)
if b.size != nvol:
    sys.stdout.write("ERROR: bvals tokens (%d) != data dim4 (%d)\\n" % (b.size, nvol))
    sys.exit(2)

v = np.loadtxt("bvecs")
if v.shape == (3, nvol):
    sys.exit(0)
if v.shape == (nvol, 3):
    np.savetxt("bvecs", v.T, fmt="%.10g")
    sys.exit(0)

sys.stdout.write("ERROR: bvecs has unexpected shape %s; expected (3,%d) or (%d,3)\\n" % (str(v.shape), nvol, nvol))
sys.exit(3)
PY
}




pe_to_vec() {
  case "$1" in
    i)  echo "1 0 0" ;;
    i-) echo "-1 0 0" ;;
    j)  echo "0 1 0" ;;
    j-) echo "0 -1 0" ;;
    k)  echo "0 0 1" ;;
    k-) echo "0 0 -1" ;;
    *)  echo "" ;;
  esac
}

get_meta_ped() {
  local id="$1"
  local ped=""

  ped=$(jq -r --arg ID "$id" '._inputs[] | select(.id==$ID) | .meta.PhaseEncodingDirection // empty' "$CFG")
  [[ -n "$ped" ]] && { echo "$ped"; return 0; }

 # ped=$(jq -r --arg ID "$id" '._inputs[] | select(.id==$ID) | .meta.PhaseEncodingAxis // empty' "$CFG")
 # [[ -n "$ped" ]] && { echo "$ped"; return 0; }

  if [[ -n "${encode:-}" ]]; then
    case "$encode" in
      PA) [[ "$id" == "diff" ]] && echo "j"  || echo "j-" ;;
      AP) [[ "$id" == "diff" ]] && echo "j-" || echo "j"  ;;
      LR) [[ "$id" == "diff" ]] && echo "i-" || echo "i"  ;;
      RL) [[ "$id" == "diff" ]] && echo "i"  || echo "i-" ;;
      *)  echo "" ;;
    esac
  else
    echo ""
  fi
}

get_meta_trt() {
  local id="$1"
  local trt="" ees="" recon_pe="" pe_steps="" wfs="" imgfreq="" etl=""

  trt=$(jq -r --arg ID "$id" '._inputs[] | select(.id==$ID) | .meta.TotalReadoutTime // empty' "$CFG")
  [[ -n "$trt" ]] && { echo "$trt"; return 0; }

  trt=$(jq -r --arg ID "$id" '._inputs[] | select(.id==$ID) | .meta.EstimatedTotalReadoutTime // empty' "$CFG")
  [[ -n "$trt" ]] && { echo "$trt"; return 0; }

  ees=$(jq -r --arg ID "$id" '._inputs[] | select(.id==$ID) | .meta.EstimatedEffectiveEchoSpacing // empty' "$CFG")
  recon_pe=$(jq -r --arg ID "$id" '._inputs[] | select(.id==$ID) | .meta.ReconMatrixPE // empty' "$CFG")
  pe_steps=$(jq -r --arg ID "$id" '._inputs[] | select(.id==$ID) | .meta.PhaseEncodingStepsNoPartialFourier // empty' "$CFG")

  if [[ -n "$ees" && -n "$recon_pe" ]]; then
    awk -v ees="$ees" -v n="$recon_pe" 'BEGIN{printf "%.10g\n", (n-1)*ees}'
    return 0
  fi
  if [[ -n "$ees" && -n "$pe_steps" ]]; then
    awk -v ees="$ees" -v n="$pe_steps" 'BEGIN{printf "%.10g\n", (n-1)*ees}'
    return 0
  fi

  wfs=$(jq -r --arg ID "$id" '._inputs[] | select(.id==$ID) | .meta.WaterFatShift // empty' "$CFG")
  imgfreq=$(jq -r --arg ID "$id" '._inputs[] | select(.id==$ID) | .meta.ImagingFrequency // empty' "$CFG")
  etl=$(jq -r --arg ID "$id" '._inputs[] | select(.id==$ID) | .meta.EchoTrainLength // empty' "$CFG")
  recon_pe=$(jq -r --arg ID "$id" '._inputs[] | select(.id==$ID) | .meta.ReconMatrixPE // empty' "$CFG")

  if [[ -n "$wfs" && -n "$imgfreq" && -n "$etl" && -n "$recon_pe" ]]; then
    awk -v wfs="$wfs" -v f="$imgfreq" -v etl="$etl" -v n="$recon_pe" \
      'BEGIN{
        ees = wfs / (f * (etl + 1) * 3.4);
        trt = ees * (n - 1);
        printf "%.10g\n", trt
      }'
    return 0
  fi

  echo ""
}

get_pe_dir_file() { jq -r '.PhaseEncodingDirection // empty' "$1"; }
get_trt_file()    { jq -r '.TotalReadoutTime // empty' "$1"; }

bool_to_01() {
  if [[ "$1" == "true" ]]; then echo 1; else echo 0; fi
}

write_topup_config() {
  local cnf="$1"
  : > "$cnf"

  [[ -n "$warpres" ]]    && echo "--warpres=${warpres}" >> "$cnf"
  [[ -n "$subsamp" ]]    && echo "--subsamp=${subsamp}" >> "$cnf"
  [[ -n "$fwhm" ]]       && echo "--fwhm=${fwhm}" >> "$cnf"
  [[ -n "$miter" ]]      && echo "--miter=${miter}" >> "$cnf"
  [[ -n "$lambda" ]]     && echo "--lambda=${lambda}" >> "$cnf"
  [[ -n "$ssqlambda" ]]  && echo "--ssqlambda=${ssqlambda}" >> "$cnf"
  [[ -n "$regmod" ]]     && echo "--regmod=${regmod}" >> "$cnf"
  [[ -n "$estmov" ]]     && echo "--estmov=${estmov}" >> "$cnf"
  [[ -n "$minmet" ]]     && echo "--minmet=${minmet}" >> "$cnf"
  [[ -n "$splineorder" ]]&& echo "--splineorder=${splineorder}" >> "$cnf"
  [[ -n "$numprec" ]]    && echo "--numprec=${numprec}" >> "$cnf"
  [[ -n "$interp" ]]     && echo "--interp=${interp}" >> "$cnf"

  echo "--scale=${scale01}"  >> "$cnf"
  echo "--regrid=${regrid01}" >> "$cnf"
}


run_topup_cli() {
  # Try "new-style" topup CLI (some older builds will reject and print usage).
  topup --imain=b0_images.nii.gz \
        --datain=acq_params.txt \
        --out=my_topup_results \
        --fout=my_field \
        --iout=my_unwarped_images \
        $topup_mask_opt \
        --warpres="${warpres}" \
        --subsamp="${subsamp}" \
        --fwhm="${fwhm}" \
        --miter="${miter}" \
        --lambda="${lambda}" \
        --ssqlambda="${ssqlambda}" \
        --regmod="${regmod}" \
        --estmov="${estmov}" \
        --minmet="${minmet}" \
        --splineorder="${splineorder}" \
        --numprec="${numprec}" \
        --interp="${interp}" \
        --scale="${scale01}" \
        --regrid="${regrid01}" --verbose
}

run_topup_config() {
  local cnf="$(pwd)/topup_config.cnf"
  write_topup_config "$cnf"

  echo "=== topup_config.cnf ==="
  ls -lh "$cnf"
  head -n 50 "$cnf" || true

  topup --imain=b0_images.nii.gz \
        --datain=acq_params.txt \
        --config="$cnf" \
        --out=my_topup_results \
        --fout=my_field \
        --iout=my_unwarped_images \
        $topup_mask_opt
}



# -----------------------
# Sanity checks
# -----------------------
for f in "$diff" "$bvec" "$bval"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: required file missing: $f"
    exit 1
  fi
done

use_epi_topup=false
if [[ -n "$epi1" && -n "$epi2" ]]; then
  if [[ ! -f "$epi1" || ! -f "$epi2" ]]; then
    echo "ERROR: epi1/epi2 specified but files not found."
    exit 1
  fi
  if [[ -z "$epi1_json" || -z "$epi2_json" || ! -f "$epi1_json" || ! -f "$epi2_json" ]]; then
    echo "ERROR: epi1/epi2 specified but epi1_json/epi2_json missing or not found."
    exit 1
  fi
  use_epi_topup=true
fi

if [[ "$merge_full" == "true" ]]; then
  if [[ -z "$rdif" || -z "$rbvc" || -z "$rbvl" ]]; then
    echo "ERROR: mergefull=true but rdif/rbvc/rbvl are not provided in config.json."
    exit 1
  fi
  for f in "$rdif" "$rbvc" "$rbvl"; do
    if [[ ! -f "$f" ]]; then
      echo "ERROR: required mergefull file missing: $f"
      exit 1
    fi
  done
fi

scale01=$(bool_to_01 "$scale")
regrid01=$(bool_to_01 "$regrid")

# -----------------------
# Folder structures
# -----------------------
need_rdif=false
if [[ "$use_epi_topup" == "false" && -n "$rdif" ]]; then
  need_rdif=true
fi

mkdir -p dwi mask raw diff
if [[ "$need_rdif" == "true" ]]; then
  mkdir -p rdif
fi

if [[ "$need_rdif" == "true" ]]; then
  if [[ -z "$rdif" || -z "$rbvc" || -z "$rbvl" ]]; then
    echo "ERROR: rdif present but rbvc/rbvl missing (needed to extract b0)."
    exit 1
  fi
  for f in "$rdif" "$rbvc" "$rbvl"; do
    [[ -f "$f" ]] || { echo "ERROR: missing $f"; exit 1; }
  done
fi


# -----------------------
# Copy inputs into working structure (unless reslice is true)
# -----------------------
if [[ "$reslice" == "false" ]]; then
  if [[ -f ./diff/dwi.nii.gz ]]; then
    echo "diff/dwi.nii.gz exists. skipping copying"
  else
    cp -v "$diff" ./diff/dwi.nii.gz
    cp -v "$bvec" ./diff/dwi.bvecs
    cp -v "$bval" ./diff/dwi.bvals
  fi

  if [[ "$need_rdif" == "true" ]]; then
    if [[ -f ./rdif/dwi.nii.gz ]]; then
      echo "rdif/dwi.nii.gz exists. skipping copying"
    else
      cp -v "$rdif" ./rdif/dwi.nii.gz
      cp -v "$rbvc" ./rdif/dwi.bvecs
      cp -v "$rbvl" ./rdif/dwi.bvals
    fi
  fi

fi

# -----------------------
# Determine number of volumes
# -----------------------
diff_num=$(fslinfo ./diff/dwi.nii.gz | sed -n 5p | awk '{print $2}')
rdif_num=0
if [[ "$merge_full" == "true" ]]; then
  rdif_num=$(fslinfo ./rdif/dwi.nii.gz | sed -n 5p | awk '{print $2}')
fi

# -----------------------
# Build TOPUP b0 stack (b0_images.nii.gz) + acq_params.txt
# -----------------------
if [[ -f b0_images.nii.gz && -f acq_params.txt ]]; then
  echo "b0_images.nii.gz and acq_params.txt exist. skipping creation"
else
  if [[ "$use_epi_topup" == "true" ]]; then
    echo "Using epi1/epi2 for topup"

  diff_ped=$(get_meta_ped "diff")
  diff_trt=$(get_meta_trt "diff")

  if [[ -z "$diff_ped" || -z "$diff_trt" ]]; then
    if [[ -n "${encode:-}" && -n "${param:-}" ]]; then
      read -r diff_ped diff_trt < <(get_legacy_ped_trt diff)
      echo "WARNING: diff embedded meta missing; using legacy encode/param for ordering (encode=$encode, param=$param)"
    else
      echo "ERROR: diffusion PhaseEncodingDirection/TotalReadoutTime not found for diff."
      echo "Provide _inputs meta for diff or legacy encode/param."
      exit 1
    fi
  fi

    epi1_ped=$(get_pe_dir_file "$epi1_json")
    epi2_ped=$(get_pe_dir_file "$epi2_json")
    epi1_trt=$(get_trt_file "$epi1_json")
    epi2_trt=$(get_trt_file "$epi2_json")

    if [[ -z "$epi1_ped" || -z "$epi2_ped" || -z "$epi1_trt" || -z "$epi2_trt" ]]; then
      echo "ERROR: epi1_json/epi2_json missing PhaseEncodingDirection or TotalReadoutTime."
      exit 1
    fi

    if [[ "$epi1_ped" == "$diff_ped" ]]; then
      b0_a="$epi1"; json_a="$epi1_json"
      b0_b="$epi2"; json_b="$epi2_json"
    elif [[ "$epi2_ped" == "$diff_ped" ]]; then
      b0_a="$epi2"; json_a="$epi2_json"
      b0_b="$epi1"; json_b="$epi1_json"
    else
      echo "WARNING: Neither epi1 nor epi2 matches diffusion PhaseEncodingDirection ($diff_ped). Using epi1,epi2 order."
      b0_a="$epi1"; json_a="$epi1_json"
      b0_b="$epi2"; json_b="$epi2_json"
    fi

	#########################################################################
	####### Rigid Alignment of EPIs data to DWI
	#########################################################################

	ref="diff/dwi.nii.gz"
	
	aligned_b0_a="./b0_a_aligned.nii.gz"
	aligned_b0_b="./b0_b_aligned.nii.gz"
	
	mat_b0_a="./b0_a_to_dwi.mat"
	mat_b0_b="./b0_b_to_dwi.mat"

	flirt -in "$b0_a" -ref "$ref" -out "$aligned_b0_a" -omat "$mat_b0_a" -dof 6
	flirt -in "$b0_b" -ref "$ref" -out "$aligned_b0_b" -omat "$mat_b0_b" -dof 6

	b0_a="${aligned_b0_a}"
	b0_b="${aligned_b0_b}"


    [[ -f b0_images.nii.gz ]] || fslmerge -t b0_images.nii.gz "$b0_a" "$b0_b"

    vec_a=$(pe_to_vec "$(get_pe_dir_file "$json_a")")
    vec_b=$(pe_to_vec "$(get_pe_dir_file "$json_b")")
    trt_a=$(get_trt_file "$json_a")
    trt_b=$(get_trt_file "$json_b")

    if [[ -z "$vec_a" || -z "$vec_b" ]]; then
      echo "ERROR: Unsupported PhaseEncodingDirection in epi jsons."
      exit 1
    fi
    [[ -f acq_params.txt ]] || printf "%s %s\n%s %s\n" "$vec_a" "$trt_a" "$vec_b" "$trt_b" > acq_params.txt

  else
    echo "epi1/epi2 not provided; building topup inputs by extracting b0 from DWI(s)"

	if [[ -z "$rdif" || ! -f "$rdif" ]]; then
	echo "ERROR: No epi1/epi2 and no rdif available (no opposite-PE pair for topup)."
	echo "Provide epi1/epi2 or provide rdif."
	exit 1
	fi


    for PHASE in diff rdif; do
      if [[ ! -f ./${PHASE}/${PHASE}_nodif.nii.gz ]]; then
        select_dwi_vols ./${PHASE}/dwi.nii.gz ./${PHASE}/dwi.bvals ./${PHASE}/${PHASE}_nodif.nii.gz 0
      fi
      if [[ ! -f ./${PHASE}/${PHASE}_nodif_mean.nii.gz ]]; then
        fslmaths ./${PHASE}/${PHASE}_nodif -Tmean ./${PHASE}/${PHASE}_nodif_mean.nii.gz
      fi
    done

	# Ensure rdif is on same grid as diff (NO registration, just resampling)
	if [[ ! -f ./rdif/rdif_nodif_mean_resampled.nii.gz ]]; then
	  echo "Checking grid consistency between diff and rdif"
	
	 same_grid=$(
		  {
		    fslinfo ./diff/diff_nodif_mean.nii.gz | grep -E '^(dim[123]|pixdim[123])'
		    fslinfo ./rdif/rdif_nodif_mean.nii.gz | grep -E '^(dim[123]|pixdim[123])'
		  } | awk '
		    NR<=6 { a[NR]=$0; next }
		    {
		      if ($0 != a[NR-6]) {
		        print "0"
		        exit
		      }
		    }
		    END {
		      if (NR == 12) print "1"
		    }'
		)
	
	  if [[ "$same_grid" == "1" ]]; then
	    echo "Grids match — no resampling needed"
	    cp -n ./rdif/rdif_nodif_mean.nii.gz ./rdif/rdif_nodif_mean_resampled.nii.gz
	  else
	    echo "Grids differ — resampling rdif b0 to diff grid"
	    flirt \
	      -in ./rdif/rdif_nodif_mean.nii.gz \
	      -ref ./diff/diff_nodif_mean.nii.gz \
	      -applyxfm -usesqform \
	      -out ./rdif/rdif_nodif_mean_resampled.nii.gz
	  fi
	fi
	# Merge b0 images for topup
	[[ -f b0_images.nii.gz ]] || fslmerge -t b0_images.nii.gz \
	  ./diff/diff_nodif_mean.nii.gz \
	  ./rdif/rdif_nodif_mean_resampled.nii.gz

    diff_ped=$(get_meta_ped "diff"); diff_trt=$(get_meta_trt "diff")
    rdif_ped=$(get_meta_ped "rdif"); rdif_trt=$(get_meta_trt "rdif")

    # Fallback to legacy encode/param if embedded meta is missing
	# Fill diff from legacy only if needed
	if [[ -z "$diff_ped" || -z "$diff_trt" ]]; then
	  if [[ -n "${encode:-}" && -n "${param:-}" ]]; then
	    read -r legacy_diff_ped legacy_diff_trt < <(get_legacy_ped_trt diff)
	    [[ -z "$diff_ped" ]] && diff_ped="$legacy_diff_ped"
	    [[ -z "$diff_trt" ]] && diff_trt="$legacy_diff_trt"
	    echo "WARNING: diff metadata incomplete; using legacy encode/param where needed (encode=$encode, param=$param)"
	  fi
	fi
	
	# Fill rdif from legacy only if needed
	if [[ -z "$rdif_ped" || -z "$rdif_trt" ]]; then
	  if [[ -n "${encode:-}" && -n "${param:-}" ]]; then
	    read -r legacy_rdif_ped legacy_rdif_trt < <(get_legacy_ped_trt rdif)
	    [[ -z "$rdif_ped" ]] && rdif_ped="$legacy_rdif_ped"
	    [[ -z "$rdif_trt" ]] && rdif_trt="$legacy_rdif_trt"
	    echo "WARNING: rdif metadata incomplete; using legacy encode/param where needed (encode=$encode, param=$param)"
	  fi
	fi

	# assume rdif is opposite of diff
	if [[ -z "$rdif_ped" && -n "$diff_ped" ]]; then
	  case "$diff_ped" in
	    i)  rdif_ped="i-" ;;
	    i-) rdif_ped="i" ;;
	    j)  rdif_ped="j-" ;;
	    j-) rdif_ped="j" ;;
	    k)  rdif_ped="k-" ;;
	    k-) rdif_ped="k" ;;
	  esac
	  echo "WARNING: rdif PhaseEncodingDirection missing; assuming opposite of diff ($diff_ped -> $rdif_ped)"
	fi

	# assume same TRT
	if [[ -z "$rdif_trt" && -n "$diff_trt" ]]; then
	  rdif_trt="$diff_trt"
	  echo "WARNING: rdif TotalReadoutTime missing; assuming same as diff ($diff_trt)"
	fi

	# assume same TRT across diff and rdif if only one is available
	if [[ -z "$diff_trt" && -n "$rdif_trt" ]]; then
	  diff_trt="$rdif_trt"
	  echo "WARNING: diff TotalReadoutTime missing; assuming same as rdif ($rdif_trt)"
	fi
	
	if [[ -z "$diff_ped" || -z "$diff_trt" || -z "$rdif_ped" || -z "$rdif_trt" ]]; then
	    echo "ERROR: cannot determine acq_params."
	    echo "Resolved values:"
	    echo "  diff_ped=$diff_ped diff_trt=$diff_trt"
	    echo "  rdif_ped=$rdif_ped rdif_trt=$rdif_trt"
	    echo "Provide either:"
	    echo "  (a) _inputs[].meta.PhaseEncodingDirection + _inputs[].meta.TotalReadoutTime for diff and rdif, or"
	    echo "  (b) legacy encode + param in config.json, or"
	    echo "  (c) epi1/epi2 + epi1_json/epi2_json"
	    exit 1
	fi

	# VECS

    vec_a=$(pe_to_vec "$diff_ped"); vec_b=$(pe_to_vec "$rdif_ped")
    if [[ -z "$vec_a" || -z "$vec_b" ]]; then
      echo "ERROR: Unsupported PhaseEncodingDirection in embedded meta."
      exit 1
    fi
    [[ -f acq_params.txt ]] || printf "%s %s\n%s %s\n" "$vec_a" "$diff_trt" "$vec_b" "$rdif_trt" > acq_params.txt
  fi
fi

# -----------------------
# Optional: mask for topup inputs (sstrip == true)
# -----------------------
topup_mask_opt=""
if [[ "$sstrip" == "true" ]]; then
  echo "sstrip=true: creating mask for topup inputs"
  if [[ ! -f b0_images_mean.nii.gz ]]; then
    fslmaths b0_images.nii.gz -Tmean b0_images_mean.nii.gz
  fi
  if [[ ! -f b0_images_mean_brain_mask.nii.gz ]]; then
    bet b0_images_mean.nii.gz b0_images_mean_brain.nii.gz -m -f 0.3
  fi
  topup_mask_opt="--mask=b0_images_mean_brain_mask.nii.gz"
fi



# -----------------------
# Sanity check
# -----------------------

# Validate topup inputs; rebuild if stale/invalid
if [[ ! -f b0_images.nii.gz ]]; then
  echo "ERROR: b0_images.nii.gz missing"
  exit 1
fi

dim4=$(fslinfo b0_images.nii.gz | awk '/^dim4/ {print $2}')
if [[ -z "${dim4:-}" ]]; then
  echo "ERROR: could not read dim4 from b0_images.nii.gz"
  exit 1
fi

if [[ "$dim4" -lt 2 ]]; then
  echo "ERROR: b0_images.nii.gz is not 4D with >=2 volumes (dim4=$dim4). Rebuilding."
  rm -f b0_images.nii.gz
  # force rebuild by deleting acq_params too
  rm -f acq_params.txt
fi

if [[ -f acq_params.txt ]]; then
  nrows=$(awk 'NF>0{c++} END{print c+0}' acq_params.txt)
  if [[ "$nrows" -ne "$dim4" ]]; then
    echo "ERROR: acq_params.txt rows ($nrows) != b0_images dim4 ($dim4). Rebuilding."
    rm -f b0_images.nii.gz acq_params.txt
  fi
fi


echo "=== TOPUP DIAGNOSTICS ==="
which topup
ls -l "$(which topup)"
file "$(which topup)" || true
head -n 5 "$(which topup)" || true

echo "FSLDIR=${FSLDIR:-<unset>}"
echo "PATH=$PATH"
echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"

# If it's a real ELF binary, this will list its library deps (and show missing ones)
ldd "$(which topup)" || true



ls -lh b0_images.nii.gz acq_params.txt || true
if [[ -f topup_config.cnf ]]; then
  ls -lh topup_config.cnf
  head -n 5 topup_config.cnf
else
  echo "topup_config.cnf not present (topup likely ran via CLI or was skipped)"
fi


# -----------------------
# TOPUP (try CLI; if fails, fall back to --config)
# -----------------------
if [[ -f my_unwarped_images.nii.gz ]]; then
  echo "my_unwarped_images.nii.gz exists. skipping topup"
else
  set +e
  run_topup_cli
  topup_status=$?
  set -e

  if [[ $topup_status -ne 0 ]]; then
    echo "topup CLI-style options failed (status=$topup_status). Falling back to --config mode."
    run_topup_config
  fi
fi

# Average unwarped b0s + brain mask (used for eddy)
if [[ ! -f my_unwarped_images_avg.nii.gz ]]; then
  fslmaths my_unwarped_images.nii.gz -Tmean my_unwarped_images_avg.nii.gz
fi
if [[ ! -f my_unwarped_images_avg_brain_mask.nii.gz ]]; then
  bet my_unwarped_images_avg.nii.gz my_unwarped_images_avg_brain.nii.gz -m
fi

# -----------------------
# Build eddy input data (data.nii.gz), bvals, bvecs, index.txt
# -----------------------
if [[ -f data.nii.gz && -f bvals && -f bvecs && -f index.txt ]]; then
  echo "eddy inputs exist. skipping creation"
else
  if [[ "$merge_full" == "true" ]]; then
    echo "mergefull=true: merging diff + rdif for eddy"
    [[ -f data.nii.gz ]] || fslmerge -t data.nii.gz ./diff/dwi.nii.gz ./rdif/dwi.nii.gz
    [[ -f bvecs ]] || paste ./diff/dwi.bvecs ./rdif/dwi.bvecs > bvecs
    [[ -f bvals ]] || paste ./diff/dwi.bvals ./rdif/dwi.bvals > bvals

    if [[ ! -f index.txt ]]; then
      indx=""
      for ((i=0; i<diff_num; ++i)); do indx="${indx} 1"; done
      for ((i=0; i<rdif_num; ++i)); do indx="${indx} 2"; done
      echo "$indx" > index.txt
    fi
  else
    echo "mergefull=false: using diff only for eddy"
    [[ -f data.nii.gz ]] || cp ./diff/dwi.nii.gz data.nii.gz
    [[ -f bvecs ]] || cp ./diff/dwi.bvecs bvecs
    [[ -f bvals ]] || cp ./diff/dwi.bvals bvals

    if [[ ! -f index.txt ]]; then
      indx=""
      for ((i=0; i<diff_num; ++i)); do indx="${indx} 1"; done
      echo "$indx" > index.txt
    fi
  fi
fi


# -----------------------
# EDDY (applies TOPUP field to diffusion data)
# -----------------------
if [[ -f dwi/dwi.nii.gz ]]; then
  echo "Final dwi/dwi.nii.gz exists. skipping eddy"
else
  echo "Running $EDDY_BIN with --topup=my_topup_results"

  # NOTE: removed --ref_scan because many builds don't support it; add back only if your eddy supports it.
	# -----------------------
	# Optional: write slspec file for slice-to-volume correction
	# -----------------------
	#if [[ -n "$slspec" ]]; then
	#  printf "%s\n" "$slspec" > slspec.txt
	#fi

	
	EDDY_OPTS=()

	if [[ "$harmonize_shells" == "true" ]]; then
	  harmonize_bvals_file bvals "$shell_targets" "$shell_tolerance"
	  data_is_shelled="true"
	fi
	
	data_is_shelled="$(norm_bool "$data_is_shelled")"
	if [[ "$data_is_shelled" == "true" ]]; then
	  EDDY_OPTS+=(--data_is_shelled)
	fi

	if [[ "$repol" == "true" ]]; then
	  EDDY_OPTS+=(--repol)
	fi
	
	if [[ -n "${mporder:-}" && "$mporder" != "0" ]]; then
	  EDDY_OPTS+=(--mporder="$mporder")
	
	  if [[ -n "${slspec:-}" ]]; then
	    echo "Formatting slspec from config..."
	
	    # normalize whitespace → one number per line
	    echo "$slspec" | tr ' ' '\n' | awk 'NF' > slspec_flat.txt
	
	    # count entries
	    n=$(wc -l < slspec_flat.txt)
	
	    # expect multiples of 3
	    if (( n % 3 != 0 )); then
	      echo "ERROR: slspec length ($n) is not divisible by 3"
	      exit 1
	    fi
	
	    # reshape into 3 columns
	    paste - - - < slspec_flat.txt > slspec.txt
	
	    echo "slspec (first rows):"
	    head slspec.txt
	
	    EDDY_OPTS+=(--slspec=slspec.txt)
	  else
	    echo "ERROR: mporder > 0 but slspec is missing"
	    exit 1
	  fi
	fi

	if [[ "${DEBUG:-0}" -eq 1 ]]; then
		echo "data_is_shelled=$data_is_shelled" 
		printf 'EDDY_OPTS: %s\n' "${EDDY_OPTS[*]:-<none>}"
	fi
	
	[[ "${DEBUG:-0}" -eq 1 ]] && debug_dump
	sanitize_and_validate_eddy_inputs

  "$EDDY_BIN" \
	--imain=data.nii.gz \
	--mask=my_unwarped_images_avg_brain_mask.nii.gz \
	--acqp=acq_params.txt \
	--index=index.txt \
	--bvecs=bvecs \
	--bvals=bvals \
	--topup=my_topup_results \
	"${EDDY_OPTS[@]}" \
	--out=eddy_corrected_data


  mv eddy_corrected_data.nii.gz dwi/dwi.nii.gz
  cp eddy_corrected_data.eddy_rotated_bvecs dwi/dwi.bvecs
  cp bvals dwi/dwi.bvals
fi

# -----------------------
# Mask output for downstream
# -----------------------
cp my_unwarped_images_avg_brain_mask.nii.gz mask/mask.nii.gz

# -----------------------
# Cleanup / archive intermediates
# -----------------------
mkdir -p raw
mv eddy_corrected_data.* raw/ 2>/dev/null || true
mv index.txt raw/ 2>/dev/null || true
mv data.nii.gz raw/ 2>/dev/null || true
mv bvals raw/ 2>/dev/null || true
mv bvecs raw/ 2>/dev/null || true
mv acq_params.txt raw/ 2>/dev/null || true
mv topup_config.cnf raw/ 2>/dev/null || true
mv b0_images*.nii.gz raw/ 2>/dev/null || true
mv b0_images_mean* raw/ 2>/dev/null || true
mv my_* raw/ 2>/dev/null || true
mv diff raw/ 2>/dev/null || true
mv rdif raw/ 2>/dev/null || true

echo "TOPUP+EDDY complete: dwi/dwi.nii.gz, dwi/dwi.bvecs, dwi/dwi.bvals, mask/mask.nii.gz"
