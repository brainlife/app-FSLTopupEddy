#!/bin/bash

## This app will combine opposite-encoding direction DWI images and perform eddy and motion
## correction using FSL's topup and eddy_openmp commands.
## Jesper L. R. Andersson, Mark S. Graham, Eniko Zsoldos and Stamatios N. Sotiropoulos. Incorporating outlier detection and replacement into a non-parametric framework for movement 
## and distortion correction of diffusion MR images. NeuroImage, 141:556-572, 2016.
## Jesper L. R. Andersson and Stamatios N. Sotiropoulos. An integrated approach to correction for off-resonance effects and subject movement in diffusion MR imaging. NeuroImage, 125:1063-1078, 
## 2016.
## J.L.R. Andersson, S. Skare, J. Ashburner How to correct susceptibility distortions in spin-echo echo-planar images: application to diffusion tensor imaging. NeuroImage, 20(2):870-888, 
## 2003.
## S.M. Smith, M. Jenkinson, M.W. Woolrich, C.F. Beckmann, T.E.J. Behrens, H. Johansen-Berg, P.R. Bannister, M. De Luca, I. Drobnjak, D.E. Flitney, R. Niazy, J. Saunders, J. Vickers, Y. Zhang, 
## N. De Stefano, J.M. Brady, and P.M. Matthews. Advances in functional and structural MR image analysis and implementation as FSL. NeuroImage, 23(S1):208-219, 2004.

## File paths
diff=`jq -r '.diff' config.json`;
bvec=`jq -r '.bvec' config.json`;
bval=`jq -r '.bval' config.json`;
rdif=`jq -r '.rdif' config.json`;
rbvc=`jq -r '.rbvc' config.json`;
rbvl=`jq -r '.rbvl' config.json`;
param_num=`jq -r '.param' config.json`;
encode_dir=`jq -r '.encode' config.json`;
phase="diff rdif"

## Create folder structures
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

## determine number of dirs per dwi
diff_num=`fslinfo ./diff/dwi.nii.gz | sed -n 5p | awk '{ print $2 $4 }'`;
rdif_num=`fslinfo ./rdif/dwi.nii.gz | sed -n 5p | awk '{ print $2 $4 }'`;

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

## Create acq_params.txt file for topup and eddy
if [ -f acq_params.txt ];
then
	echo "acq_params.txt exists. skipping"
else
	if [ $encode_dir="PA" ];
	then
		printf "0 -1 0 ${param_num}\n0 1 0 ${param_num}" > acq_params.txt;
	else
		printf "-1 0 0 ${param_num}\n1 0 0 ${param_num}" > acq_params.txt;
	fi
fi

## setting up top-up for susceptibility correction
if [ -f my_unwarped_images.nii.gz ];
then
	echo "unwarped images from topup exits. skipping"
else
	echo "topup"
	topup --imain=b0_images.nii.gz \
	      --datain=acq_params.txt \
	      --config=b02b0.cnf \
	      --out=my_topup_results \
	      --fout=my_field \
	      --iout=my_unwarped_images;
fi

## Averaging b0 images from topup
if [ -f my_unwarped_images_avg.nii.gz ];
then
	echo "averaged b0 images from topup already exists. skipping"
else
	echo "averaging b0 images from topup"
	fslmaths my_unwarped_images \
		-Tmean my_unwarped_images_avg;
fi

## Brain extraction of b0 images from topup
if [ -f my_unwarped_images_avg_brain.nii.gz ];
then
	echo "brain extracted b0 images from topup already exists. skipping"
else
	echo "creating brain extracted image from topup b0"
	bet my_unwarped_images_avg \
		my_unwarped_images_avg_brain \
		-m;
fi

## merge both phase encoding directions
if [ -f data.nii.gz ];
then
	echo "both phase encoding directions merged already. skipping"
else
	echo "merging phase encoding data"
	fslmerge -t data.nii.gz ./diff/dwi.nii.gz ./rdif/dwi.nii.gz;
fi

paste ${bvec} ${rbvc} >> bvecs
paste ${bval} ${rbvl} >> bvals

## Creating a index.txt file for eddy
if [ -f index.txt ];
then
	echo "index.txt already exists. skipping"
else
	indx=""
	for ((i=0; i<${diff_num}; ++i));do indx="${indx} 1";done
	for ((i=0; i<${rdif_num}; ++i));do indx="${indx} 2";done
	echo $indx > index.txt;
fi

## Eddy correction
if [ -f eddy_corrected_data.nii.gz ];
then
	echo "eddy completed. skipping"
else
	echo "eddy"
	eddy --imain=data \
		--mask=my_unwarped_images_avg_brain_mask \
		--acqp=acq_params.txt \
		--index=index.txt \
		--bvecs=bvecs \
		--bvals=bvals \
		--topup=my_topup_results \
		--repol \
		--out=eddy_corrected_data;
fi

## brain extraction on combined data image
if [ -f eddy_corrected_brain.nii.gz ];
then
	echo "brainmask from eddy_corrected data already exists. skipping"
else
	echo "generating brainmask from combined data"
	bet eddy_corrected_data \
		eddy_corrected_brain \
		-m;
fi

#mv eddy_corrected_data.nii.gz dwi.nii.gz;
#mv eddy_corrected_data.eddy_rotated_bvecs dwi.bvecs;
#cp -v ${bval} dwi.bvals;
#mv eddy_corrected_brain_mask.nii.gz mask.nii.gz;
#rm -rf *eddy_corrected* index.txt *my_* *b0_images* acq_params.txt diff rdif data.nii.gz bvecs bvals;



