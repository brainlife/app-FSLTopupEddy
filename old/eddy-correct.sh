#!/bin/bash

dwi=`jq -r '.dwi' config.json`
bvals=`jq -r '.bvals' config.json`
bvecs=`jq -r '.bvecs' config.json`
refvol=`jq -r '.refvol' config.json`

# mkdirs
[ ! -d output ] && mkdir output
[ ! -d raw ] && mkdir raw

# run eddy-correct
echo "running eddy_correct to correct for eddy and motion artifacts"
[ ! -f output/dwi.nii.gz ] && eddy_correct ${dwi} dwi_ec ${refvol} && mv dwi_ec.nii.gz ./output/dwi.nii.gz

# correct bvectors
echo "correcting bvectors"
[ ! -f output/dwi.bvecs ] && fdt_rotate_bvecs ${bvecs} ./output/dwi.bvecs dwi_ec.ecclog

# copy over bvals
[ ! -f output/dwi.bvals ] && cp ${bvals} output/dwi.bvals

# final output check
if [ ! -f output/dwi.nii.gz ]; then
	echo "something went wrong. check derivatives and logs"
	exit 1
else
	echo "eddy_correct complete!"
	mv dwi_ec.ecclog ./raw/
	exit 0
fi


