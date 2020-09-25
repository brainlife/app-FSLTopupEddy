#!/bin/bash

diff=`jq -r '.diff' config.json`
bvec=`jq -r '.bvec' config.json`;
bval=`jq -r '.bval' config.json`;
rdif=`jq -r '.rdif' config.json`;
rbvc=`jq -r '.rbvc' config.json`;
rbvl=`jq -r '.rbvl' config.json`;

mkdir -p diff rdif

if [ -f ./diff/dwi.nii.gz ];
then
    echo "file exists. skipping copying"
else
    cp -v ${diff} ./diff/dwi.nii.gz;
    cp -v ${bvec} ./diff/dwi.bvecs;
    cp -v ${bval} ./diff/dwi.bvals;
    cp -v ${rdif} ./rdif/dwi.nii.gz;
    cp -v ${rbvc} ./rdif/dwi.bvecs;
    cp -v ${rbvl} ./rdif/dwi.bvals;
fi 

mri_vol2vol --mov ./rdif/dwi.nii.gz --targ ./diff/dwi.nii.gz --regheader --o ./rdif/dwi.nii.gz
