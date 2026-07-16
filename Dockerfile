FROM ubuntu:22.04

LABEL maintainer="Gabriele Amorosino <g.amorosino@gmail.com>"

ENV DEBIAN_FRONTEND=noninteractive
ENV FSLDIR=/usr/local/fsl
ENV PATH=${FSLDIR}/share/fsl/bin:${FSLDIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV FSLOUTPUTTYPE=NIFTI_GZ
ENV FSLMULTIFILEQUIT=TRUE
ENV FSLTCLSH=${FSLDIR}/bin/fsltclsh
ENV FSLWISH=${FSLDIR}/bin/fslwish
ENV FSLLOCKDIR=
ENV FSLMACHINELIST=
ENV FSLREMOTECALL=
ENV LD_LIBRARY_PATH=${FSLDIR}/lib
ENV SHELL=/bin/bash

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    bc \
    bzip2 \
    ca-certificates \
    curl \
    dc \
    file \
    libfontconfig1 \
    libfreetype6 \
    libgl1 \
    libglu1-mesa \
    libgomp1 \
    libice6 \
    libsm6 \
    libx11-6 \
    libxcursor1 \
    libxext6 \
    libxft2 \
    libxinerama1 \
    libxrandr2 \
    libxrender1 \
    libxt6 \
    python3 \
    sudo \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN curl -Ls https://fsl.fmrib.ox.ac.uk/fsldownloads/fslconda/releases/getfsl.sh -o /tmp/getfsl.sh && \
    bash /tmp/getfsl.sh ${FSLDIR} -V 6.0.7.22 && \
    rm -f /tmp/getfsl.sh

RUN echo ". ${FSLDIR}/etc/fslconf/fsl.sh" >> /etc/bash.bashrc

RUN ldconfig && mkdir -p /N/u /N/home /N/dc2 /N/soft /mnt/scratch

RUN rm -f /bin/sh && ln -s /bin/bash /bin/sh

CMD ["/bin/bash"]
