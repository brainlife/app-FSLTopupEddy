#!/bin/bash

bvals=`jq -r '.bvals' config.json`
bvecs=`jq -r '.bvecs' config.json`

# eddy qc - NEED TO FIX CURRENTLY
eddy_quad eddy_corrected_data -idx index.txt -par acq_params.txt -m nodif_brain_mask -b ${bvals} -g ${bvecs} -o ./eddy_quad/

if [ -d raw ]; then
	# cleanup
	cp eddy_corrected_data.nii.gz ./output/dwi.nii.gz;
	cp eddy_corrected_data.eddy_rotated_bvecs ./output/dwi.bvecs;
	cp ${bvals} ./output/dwi.bvals;
	#cp eddy_corrected_brain_mask.nii.gz ./mask/mask.nii.gz;
	
	# mv everything else to raw
	mv *eddy_corrected* ./eddy_quad/
	mv *.nii.gz ./raw/
	mv index.txt ./raw/
	mv acq_params.txt ./raw/
else
	echo "failed"
	exit 1
fi
