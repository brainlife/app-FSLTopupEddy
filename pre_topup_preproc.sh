#!/bin/bash

# File paths
diff=`jq -r '.diff' config.json`;
bvec=`jq -r '.bvec' config.json`;
bval=`jq -r '.bval' config.json`;
rdif=`jq -r '.rdif' config.json`;
rbvc=`jq -r '.rbvc' config.json`;
rbvl=`jq -r '.rbvl' config.json`;

# phase dirs
phase="diff rdif"

## Create folder structures
mkdir dwi;
mkdir mask;
mkdir diff rdif;
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

for PHASE in $phase
	do
		## Reorient2std
		#fslreorient2std \
		#	./${PHASE}/${PHASE}.nii.gz \
		#	./${PHASE}/${PHASE}.nii.gz

		## Create b0 image (nodif)
		if [ -f ./${PHASE}/${PHASE}_nodif.nii.gz ];
		then
			echo "b0 exists. skipping"
		else
			echo "creating b0 image for each encoding phase"
			select_dwi_vols \
				./${PHASE}/dwi.nii.gz \
				./${PHASE}/dwi.bvals \
				./${PHASE}/${PHASE}_nodif.nii.gz \
				0;
		fi

		## Create mean b0 image
		if [ -f ./${PHASE}/${PHASE}_nodif_mean.nii.gz ];
		then
			echo "mean b0 exists. skipping"
		else
			fslmaths ./${PHASE}/${PHASE}_nodif \
				-Tmean ./${PHASE}/${PHASE}_nodif_mean;
		fi

		## Brain Extraction on mean b0 image
		if [ -f ./${PHASE}/${PHASE}_nodif_brain.nii.gz ];
		then
			echo "b0 brain mask exists. skipping"
		else
			bet ./${PHASE}/${PHASE}_nodif_mean \
				./${PHASE}/${PHASE}_nodif_brain \
				-f 0.3 \
				-g 0 \
				-m;
		fi
	done


## merging b0 images of each phase
if [ -f b0_images.nii.gz ];
then
	echo "merged b0 exists. skipping"
else
	echo "merging b0 images"
	fslmerge -t \
		b0_images \
		./diff/diff_nodif_mean \
		./rdif/rdif_nodif_mean;
fi