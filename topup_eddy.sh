#!/bin/bash

set -x

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

#cuda/nvidia drivers comes from the host. it needs to be mounted by singularity
#export LD_LIBRARY_PATH=/opt/packages/cuda/8.0/lib64:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/pylon5/tr4s8pp/shayashi/cuda-8.0/lib64:$LD_LIBRARY_PATH
#export LD_LIBRARY_PATH=/usr/lib/nvidia-410:$LD_LIBRARY_PATH

#ln -sf ${FSLDIR}/bin/eddy_cuda8.0 ${FSLDIR}/bin/eddy_cuda

## File paths
diff=`jq -r '.diff' config.json`;
bvec=`jq -r '.bvec' config.json`;
bval=`jq -r '.bval' config.json`;
rdif=`jq -r '.rdif' config.json`;
rbvc=`jq -r '.rbvc' config.json`;
rbvl=`jq -r '.rbvl' config.json`;

# topup options
param_num=`jq -r '.param' config.json`;
encode_dir=`jq -r '.encode' config.json`;
warpres=`jq -r '.warpres' config.json`;
subsamp=`jq -r '.subsamp' config.json`;
fwhm=`jq -r '.fwhm' config.json`;
miter=`jq -r '.miter' config.json`;
lambda=`jq -r '.lambda' config.json`;
ssqlambda=`jq -r '.ssqlambda' config.json`;
regmod=`jq -r '.regmod' config.json`;
estmov=`jq -r '.estmov' config.json`;
minmet=`jq -r '.minmet' config.json`;
splineorder=`jq -r '.splineorder' config.json`;
numprec=`jq -r '.numprec' config.json`;
interp=`jq -r '.interp' config.json`;
scale=`jq -r '.scale' config.json`;
regrid=`jq -r '.regrid' config.json`;

# eddy options
merge_full=`jq -r '.mergefull' config.json`
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

# reslice
reslice=`jq -r '.reslice' config.json`

# phase dirs
phase="diff rdif"

## Create folder structures
mkdir dwi;
mkdir mask;
mkdir diff rdif;
if [[ ${reslice} == 'false' ]]; then
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
	if [[ $encode_dir == "PA" ]];
	then
		printf "0 1 0 ${param_num}\n0 -1 0 ${param_num}" > acq_params.txt;
	elif [[ $encode_dir == "AP" ]];
	then
		printf "0 -1 0 ${param_num}\n0 1 0 ${param_num}" > acq_params.txt
	elif [[ $encode_dir == "LR" ]];
	then
		printf "-1 0 0 ${paran_num}\n1 0 0 ${param_num}" > acq_params.txt
	else
		printf "1 0 0 ${param_num}\n-1 0 0 ${param_num}" > acq_params.txt;
	fi
fi

if [[ ${scale} == 'true' ]]; then
	scale=1
else
	scale=0
fi

if [[ ${regrid} == 'true' ]]; then
	regrid=1
else
	regrid=0
fi

## setting up top-up for susceptibility correction
if [ -f my_unwarped_images.nii.gz ];
then
	echo "unwarped images from topup exits. skipping"
else
	echo "topup"
	topup --imain=b0_images.nii.gz \
	      --datain=acq_params.txt \
	      --out=my_topup_results \
	      --fout=my_field \
	      --iout=my_unwarped_images\
	      --warpres=${warpres} \
	      --subsamp=${subsamp} \
	      --fwhm=${fwhm} \
	      --miter=${miter} \
	      --lambda=${lambda} \
	      --ssqlambda=${ssqlambda} \
	      --regmod=${regmod} \
	      --estmov=${estmov} \
	      --minmet=${minmet} \
	      --splineorder=${splineorder} \
	      --numprec=${numprec} \
	      --interp=${interp} \
	      --scale=${scale} \
	      --regrid=${regrid};
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

if [[ ${merge_full} == true ]]; then
	echo "merging both phase encoding directions"
	## merge both phase encoding directions
	if [ -f data.nii.gz ];
	then
		echo "both phase encoding directions merged already. skipping"
	else
		echo "merging phase encoding data"
		fslmerge -t data.nii.gz ./diff/dwi.nii.gz ./rdif/dwi.nii.gz;
	fi
	
	## merging bvecs
	if [ -f bvecs ];
	then
		echo "bvecs merged. skipping"
	else
		paste ${bvec} ${rbvc} >> bvecs
	fi
	
	## merging bvals
	if [ -f bvals ];
	then
		echo "bvals merged. skipping"
	else
		paste ${bval} ${rbvl} >> bvals
	fi
	
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
else
	echo "using first inputted dwi"
	## use diff
	if [ -f data.nii.gz ];
	then
		echo "both phase encoding directions merged already. skipping"
	else
		echo "merging phase encoding data"
		cp ./diff/dwi.nii.gz data.nii.gz;
	fi
	
	## merging bvecs
	if [ -f bvecs ];
	then
		echo "bvecs copied. skipping"
	else
		cp ${bvec} bvecs
	fi
	
	## merging bvals
	if [ -f bvals ];
	then
		echo "bvals copied. skipping"
	else
		cp ${bval} bvals
	fi
	
	## Creating a index.txt file for eddy
	if [ -f index.txt ];
	then
		echo "index.txt already exists. skipping"
	else
		indx=""
		for ((i=0; i<${diff_num}; ++i));do indx="${indx} 1";done
		echo $indx > index.txt;
	fi
fi

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

## Eddy correction
if [ -f eddy_corrected_data.nii.gz ];
then
	echo "eddy completed. skipping"
else
	echo "eddy"
	/usr/local/bin/eddy_cuda --imain=data \
		--mask=my_unwarped_images_avg_brain_mask \
		--acqp=acq_params.txt \
		--index=index.txt \
		--bvecs=bvecs \
		--bvals=bvals \
		--topup=my_topup_results \
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

if [ -f eddy_corrected_data.nii.gz ]; then
	echo "topup eddy complete"
else
	echo "failed"
	exit 1
fi
