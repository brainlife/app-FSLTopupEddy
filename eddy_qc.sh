#!/bin/bash

# eddy qc - NEED TO FIX CURRENTLY
if [ ! -d raw ]; then
        eddy_quad eddy_corrected_data -idx index.txt -par acq_params.txt -m eddy_corrected_brain_mask -b bvals -g bvecs -o ./raw/ -f my_field.nii.gz
fi

if [ -d raw ]; then
	# cleanup
	cp eddy_corrected_data.nii.gz ./dwi/dwi.nii.gz;
	cp eddy_corrected_data.eddy_rotated_bvecs ./dwi/dwi.bvecs;
	cp bvals ./dwi/dwi.bvals;
	cp eddy_corrected_brain_mask.nii.gz ./mask/mask.nii.gz;
	
	# mv everything else to raw
	mkdir -p raw
	mv *eddy_corrected* ./raw/
	mv index.txt ./raw/
	mv *my_* ./raw/
	mv *b0_images* ./raw/
	mv acq_params.txt ./raw/
else
	echo "failed"
	exit 1
fi
