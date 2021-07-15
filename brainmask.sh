#!/bin/bash

dwi=`jq -r '.dwi' config.json`
bvals=`jq -r '.bvals' config.json`
bvecs=`jq -r '.bvecs' config.json`

## generate brainmask
# select b0 volumes and generate mean
[ ! -f nodif.nii.gz ] && select_dwi_vols ${dwi} ${bvals} nodif 0 -m

# create brainmask
[ ! -f nodif_brain_mask.nii.gz ] && bet nodif.nii.gz nodif_brain -f 0.2 -g 0 -m
