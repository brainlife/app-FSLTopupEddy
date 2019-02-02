FROM brainlife/fsl:5.0.9 

MAINTAINER Brad Caron <bacaron@iu.edu>

RUN apt-get update 

## run distributed script to set up fsl
RUN . /etc/fsl/fsl.sh

RUN apt-get install -y fsl-first-data fsl-atlases 

## add better eddy functions
RUN wget https://fsl.fmrib.ox.ac.uk/fsldownloads/patches/eddy-patch-fsl-5.0.11/centos6/eddy_cuda8.0
RUN mv eddy_cuda8.0 /usr/local/bin/eddy_cuda
RUN wget https://fsl.fmrib.ox.ac.uk/fsldownloads/patches/eddy-patch-fsl-5.0.11/centos6/eddy_openmp -P /usr/local/bin
RUN chmod +x /usr/local/bin/eddy_cuda
RUN chmod +x /usr/local/bin/eddy_openmp

#make it work under singularity 
RUN ldconfig && mkdir -p /N/u /N/home /N/dc2 /N/soft /mnt/scratch

#https://wiki.ubuntu.com/DashAsBinSh 
RUN rm /bin/sh && ln -s /bin/bash /bin/sh
