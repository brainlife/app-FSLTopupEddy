#!/bin/bash
set -euo pipefail

mkdir -p eddy_quad regressors

BASE="./eddy_quad/eddy_corrected_data"
OUTDIR="./eddy_quad/qc"

# Copy/link final corrected image with original eddy basename
ln -sf ../dwi/dwi.nii.gz "${BASE}.nii.gz"

# Copy/link eddy sidecars from raw
ln -sf ../raw/eddy_corrected_data.eddy_parameters "${BASE}.eddy_parameters"
ln -sf ../raw/eddy_corrected_data.eddy_movement_rms "${BASE}.eddy_movement_rms"
ln -sf ../raw/eddy_corrected_data.eddy_restricted_movement_rms "${BASE}.eddy_restricted_movement_rms"
ln -sf ../raw/eddy_corrected_data.eddy_rotated_bvecs "${BASE}.eddy_rotated_bvecs"
ln -sf ../raw/eddy_corrected_data.eddy_outlier_map "${BASE}.eddy_outlier_map"
ln -sf ../raw/eddy_corrected_data.eddy_outlier_report "${BASE}.eddy_outlier_report"
ln -sf ../raw/eddy_corrected_data.eddy_outlier_n_stdev_map "${BASE}.eddy_outlier_n_stdev_map"
ln -sf ../raw/eddy_corrected_data.eddy_outlier_n_sqr_stdev_map "${BASE}.eddy_outlier_n_sqr_stdev_map"

if [[ -f "${OUTDIR}/qc.pdf" ]]; then
    echo "eddy_quad completed. skipping"
else
    rm -rf "$OUTDIR"

    eddy_quad "$BASE" \
        -idx raw/index.txt \
        -par raw/acq_params.txt \
        -m mask/mask.nii.gz \
        -b dwi/dwi.bvals \
        -g dwi/dwi.bvecs \
        -o "$OUTDIR" \
        -f raw/my_field.nii.gz
fi

echo "eddy QC complete: $OUTDIR"
