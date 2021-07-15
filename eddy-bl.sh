#!/bin/bash

set -e
set -x

echo "OMP_NUM_THREADS=$OMP_NUM_THREADS"
[ -z "$OMP_NUM_THREADS" ] && export OMP_NUM_THREADS=8

# inputs
dwi=`jq -r '.dwi' config.json`
bvals=`jq -r '.bvals' config.json`
bvecs=`jq -r '.bvecs' config.json`

# eddy options
encode_dir=`jq -r '.encode' config.json`
param_num=`jq -r '.param' config.json`
mb=`jq -r '.mb' config.json`;
mb_offs=`jq -r '.mb_offs' config.json`;
flm=`jq -r '.flm' config.json`;
slm=`jq -r '.slm' config.json`;
eddy_fwhm=`jq -r '.eddy_fwhm' config.json`;
eddy_niter=`jq -r '.eddy_niter' config.json`;
fep=`jq -r '.fep' config.json`;
eddy_interp=`jq -r '.eddy_interp' config.json`;
eddy_resamp=`jq -r '.eddy_resamp' config.json`;
nvoxhp=`jq -r '.nvoxhp' config.json`;
initrand=`jq -r '.initrand' config.json`;
ff=`jq -r '.ff' config.json`;
repol=`jq -r '.repol' config.json`;
resamp=`jq -r '.resamp' config.json`;
ol_nstd=`jq -r '.ol_nstd' config.json`;
ol_nvox=`jq -r '.ol_nvox' config.json`;
ol_type=`jq -r '.ol_type' config.json`;
ol_pos=`jq -r '.ol_pos' config.json`;
ol_sq=`jq -r '.ol_sq' config.json`;
mporder=`jq -r '.mporder' config.json`;
s2v_niter=`jq -r '.s2v_niter' config.json`;
s2v_lambda=`jq -r '.s2v_lambda' config.json`;
s2v_interp=`jq -r '.s2v_interp' config.json`;
estimate_move_by_susceptibility=`jq -r '.estimate_move_by_susceptibility' config.json`;
mbs_niter=`jq -r '.mbs_iter' config.json`;
mbs_lambda=`jq -r '.mbs_lambda' config.json`;
mbs_ksp=`jq -r '.mbs_ksp' config.json`;
dont_peas=`jq -r '.dont_peas' config.json`;
data_is_shelled=`jq -r '.data_is_shelled' config.json`;
slspec=`jq -r '.slspec' config.json`;

# mkdirs
[ ! -d output ] && mkdir output
[ ! -d raw ] && mkdir raw
[ ! -d eddy_quad ] && mkdir eddy_quad

## generate brainmask
# select b0 volumes and generate mean
[ ! -f nodif.nii.gz ] && select_dwi_vols ${dwi} ${bvals} nodif 0 -m

# create brainmask
[ ! -f nodif_brain_mask.nii.gz ] && bet nodif.nii.gz nodif_brain -f 0.2 -g 0 -m

## create acq_params.txt
if [ -f acq_params.txt ];
then
	echo "acq_params.txt exists. skipping"
else
	if [[ $encode_dir == "PA" ]];
	then
		printf "0 1 0 ${param_num}" > acq_params.txt;
	elif [[ $encode_dir == "AP" ]];
	then
		printf "0 -1 0 ${param_num}" > acq_params.txt
	elif [[ $encode_dir == "LR" ]];
	then
		printf "-1 0 0 ${paran_num}" > acq_params.txt
	else
		printf "1 0 0 ${param_num}" > acq_params.txt;
	fi
fi

## Creating a index.txt file for eddy
diff_num=`fslinfo ${dwi} | sed -n 5p | awk '{ print $2 $4 }'`;
if [ -f index.txt ];
then
	echo "index.txt already exists. skipping"
else
	indx=""
	for ((i=0; i<${diff_num}; ++i));do indx="${indx} 1";done
	echo $indx > index.txt;
fi

## run eddy
echo "running eddy to correct for eddy and motion artifacts"

# parse parameters for eddy that are set as flags only
[ ! -z "${slspec}" ] && echo "${slspec}" > slspec.txt && slspec="--slspec=slspec.txt" || slspec=""
[ ${mb} -eq 1 ] && mb="" || mb="--mb=${mb}"
[ ${mb_offs} -eq 0 ] && mb_offs="" || mb_offs="--mb_offs=${mb_offs}"
[[ ${flm} == "quadratic" ]] && flm="" || flm="--flm=${flm}"
[[ ${slm} == none ]] && slm="" || slm="--slm=${slm}"
[ ${eddy_fwhm} -eq 0 ] && eddy_fwhm="" || eddy_fwhm="--fwhm=${eddy_fwhm}"
[ ${eddy_niter} -eq 5 ] && eddy_niter="" || eddy_niter="--niter=${eddy_niter}"
[[ ${eddy_interp} == "spline" ]] && eddy_interp="" || eddy_interp="--interp=${eddy_interp}"
[[ ${resamp} == "jac" ]] && resamp="" || resamp="--resamp=${resamp}"
[ ${nvoxhp} -eq 1000 ] && nvoxhp="" || nvoxhp="--nvoxhp=${nvoxhp}"
[ ${ff} -eq 10 ] && ff="" || ff="--ff=${ff}"
[ ${ol_nstd} -eq 4 ] && ol_nstd="" || ol_nstd="--ol_nstd=${ol_nstd}"
[ ${ol_nvox} -eq 250 ] && ol_nvox="" || ol_nvox="--ol_nvox=${ol_nvox}"
[[ ${ol_type} == "sw" ]] && ol_type="" || ol_type="--ol_type=${ol_type}"
[ ${mporder} -eq 0 ] && mporder="" || mporder="--mporder=${mporder}"
[ ${s2v_niter} -eq 5 ] && s2v_niter="" || s2v_niter="--s2v_niter=${s2v_niter}"
[ ${s2v_lambda} -eq 1 ] && s2v_lambda="" || s2v_lambda="--s2v_lambda=${s2v_lambda}"
[[ ${s2v_interp} == "trilinear" ]] && s2v_interp="" || s2v_interp="--s2v_interp=${s2v_interp}"
[ ${mbs_niter} -eq 10 ] && mbs_niter="" || mbs_niter="--mbs_niter=${mbs_niter}"
[ ${mbs_lambda} -eq 10 ] && mbs_lambda="" || mbs_lambda="--mbs_lambda=${mbs_lambda}"
[ ${mbs_ksp} -eq 10 ] && mbs_ksp="" || mbs_ksp="--mbs_ksp=${mbs_ksp}"
[[ ${fep} == true ]] && fep="--fep" || fep=""
[[ ${repol} == true ]] && repol="--repol" || repol=""
[[ ${dont_sep_offs_move} == true ]] && dont_sep_offs_move="--dont_sep_offs_mov" || dont_sep_offs_move=""
[[ ${dont_peas} == true ]] && dont_peas="--dont_peas" || dont_peas=""
[[ ${ol_pos} == true ]] && ol_pos="--ol_pos" || ol_pos=""
[[ ${ol_sqr} == true ]] && ol_sqr="--ol_sqr" || ol_sqr=""
[[ ${estimate_move_by_susceptibility} == true ]] && estimate_move_by_susceptibility="--estimate_move_by_susceptibility" || estimate_move_by_susceptibility=""
[[ ${data_is_shelled} == true ]] && data_is_shelled="--data_is_shelled" || data_is_shelled=""

if [ -f eddy_corrected_data.nii.gz ];
then
	echo "eddy completed. skipping"
else
	echo "eddy"
	/usr/local/bin/eddy_cuda --imain=${dwi} \
		--mask=nodif_brain_mask.nii.gz \
		--index=index.txt \
		--acqp=acq_params.txt \
		--bvecs=${bvecs} \
		--bvals=${bvals} \
		--out=eddy_corrected_data \
		--cnr_maps \
		${flm} \
		${slm} \
		${eddy_fwhm} \
		${eddy_niter} \
		${fep} \
		${eddy_interp} \
		${resamp} \
		${nvoxhp} \
		${ff} \
		${dont_sep_offs_move} \
		${dont_peas} \
		${repol} \
		${ol_nstd} \
		${ol_nvox} \
		${ol_type} \
		${ol_pos} \
		${ol_sqr} \
		${mb} \
		${mb_offs} \
		${mporder} \
		${s2v_niter} \
		${s2v_lambda} \
		${s2v_interp} \
		${estimate_move_by_susceptibility} \
		${mbs_niter} \
		${mbs_lambda} \
		${mbs_ksp} \
		${data_is_shelled} \
		${slspec};
fi

## run eddy_quad
if [ ! -d eddy_corrected_data.qc ];
then
	echo "eddy_quad completed. skipping"
else
	echo "eddy_quad"
	eddy_quad eddy_corrected_data \
		-idx index.txt \
		-par acq_params.txt \
		-m ./nodif_brain_mask.nii.gz \
		-b ${bvals}
fi

## move final outputs
[ ! -f ./output/dwi.nii.gz ] && mv eddy_corrected_data.nii.gz ./output/dwi.nii.gz
[ ! -f ./output/dwi.bvecs ] && mv eddy_corrected_data.rotated_bvecs ./output/dwi.bvecs
[ ! -f ./output/dwi.bvals ] && cp ${bvals} ./output/dwi.bvals
mv index.txt acq_params.txt nodif* ./raw/
mv eddy_corrected_data.qc ./eddy_quad/qc && mv eddy_corrected_data.* ./eddy_quad

# final output check
if [ ! -f output/dwi.nii.gz ]; then
	echo "something went wrong. check derivatives and logs"
	#exit 1
else
	echo "eddy complete!"
	#exit 0
fi


