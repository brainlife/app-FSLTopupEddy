#!/bin/bash
#PBS -l nodes=1:ppn=8,walltime=8:00:00
#PBS -N topup_eddy
#PBS -l vmem=16gb
#PBS -V

#module load cuda/8.0 #for bridges

# needs mrtrix3 container for eddy_openmp
#export SINGULARITYENV_OMP_NUM_THREADS=$OMP_NUM_THREADS

reslice=`jq -r '.reslice' config.json`
if [[ ${reslice} == 'true' ]]; then
	[ -z "$FREESURFER_LICENSE" ] && echo "Please set FREESURFER_LICENSE in .bashrc" && exit 1;
	echo $FREESURFER_LICENSE > license.txt

	# convert surfaces and generate appropriate summary statistic text files
	time singularity exec -e -B `pwd`/license.txt:/usr/local/freesurfer/license.txt docker://brainlife/freesurfer:6.0.0 ./reslice.sh
fi

time singularity exec -e --nv docker://brainlife/mrtrix3:3.0_RC3 ./topup_eddy.sh

# time singularity exec -e docker://brainlife/fsl:6.0.1 ./eddy_qc.sh

if [ -s ./dwi/dwi.nii.gz ];
then
	echo 0 > finished
else
	echo "output missing"
	echo 1 > finished
	exit 1
fi
