# Dfam TE Tools container including RepeatMasker, RepeatModeler, coseg

FROM debian:9 AS builder

RUN apt-get -y update && apt-get -y install \
    curl gcc g++ make zlib1g-dev libgomp1 \
    perl \
    libfile-which-perl \
    libtext-soundex-perl \
    libjson-perl liburi-perl libwww-perl

COPY src/* /opt/src/
WORKDIR /opt/src

# Extract RMBlast
RUN echo '1e7b3711f8d4d99d70fb212c58a144ac08ab578132494af7f03613223f90d7fc  rmblast-2.9.0+-p2-x64-linux.tar.gz' | sha256sum -c \
    && cd /opt \
    && mkdir rmblast \
    && tar --strip-components=1 -x -f src/rmblast-2.9.0+-p2-x64-linux.tar.gz -C rmblast \
    && rm src/rmblast-2.9.0+-p2-x64-linux.tar.gz

# Compile HMMER
RUN echo 'a56129f9d786ec25265774519fc4e736bbc16e4076946dcbd7f2c16efc8e2b9c  hmmer-3.2.1.tar.gz' | sha256sum -c \
    && tar -x -f hmmer-3.2.1.tar.gz \
    && cd hmmer-3.2.1 \
    && ./configure --prefix=/opt/hmmer && make && make install \
    && make clean

# Compile RepeatScout
RUN echo '31a44cf648d78356aec585ee5d3baf936d01eaba43aed382d9ac2d764e55b716  RepeatScout-1.0.6.tar.gz' | sha256sum -c \
    && tar -x -f RepeatScout-1.0.6.tar.gz \
    && cd RepeatScout-1.0.6 \
    && sed -i 's#^INSTDIR =.*#INSTDIR = /opt/RepeatScout#' Makefile \
    && make && make install

# Compile and configure RECON
RUN echo '699765fa49d18dbfac9f7a82ecd054464b468cb7521abe9c2bd8caccf08ee7d8  RECON-1.08.tar.gz' | sha256sum -c \
    && tar -x -f RECON-1.08.tar.gz \
    && mv RECON-1.08 ../RECON \
    && cd ../RECON \
    && make -C src && make -C src install \
    && sed -i 's#^\$path =.*#$path = "/opt/RECON/bin";#' scripts/recon.pl

# Compile cd-hit
RUN echo '26172dba3040d1ae5c73ff0ac6c3be8c8e60cc49fc7379e434cdf9cb1e7415de  cd-hit-v4.8.1-2019-0228.tar.gz' | sha256sum -c \
    && tar -x -f cd-hit-v4.8.1-2019-0228.tar.gz \
    && cd cd-hit-v4.8.1-2019-0228 \
    && make && mkdir /opt/cd-hit && PREFIX=/opt/cd-hit make install

# Compile genometools (for ltrharvest)
RUN echo 'a6aa7f158a3cef90fea8d0fe24bfad0c3ee96b17b3ba0c1f6462582593af679e  gt-1.5.10.tar.gz' | sha256sum -c \
    && tar -x -f gt-1.5.10.tar.gz \
    && cd genometools-1.5.10 \
    && make -j4 cairo=no && make cairo=no prefix=/opt/genometools install \
    && make cleanup

# Configure LTR_retriever
RUN echo 'a9ffaa26543eddb4fbb2ec35ff997105ba5696bac7025346f9dbf09dc515d38a  LTR_retriever-2.7.tar.gz' | sha256sum -c \
    && cd /opt \
    && tar -x -f src/LTR_retriever-2.7.tar.gz \
    && mv LTR_retriever-2.7 LTR_retriever \
    && cd LTR_retriever \
    && sh -c 'rm bin/trf*' \
    && ln -s /opt/trf bin/trf409.legacylinux64 \
    && sed -i \
        -e 's#BLAST+=#BLAST+=/opt/rmblast/bin#' \
        -e 's#RepeatMasker=#RepeatMasker=/opt/RepeatMasker#' \
        -e 's#HMMER=#HMMER=/opt/hmmer/bin#' \
        -e 's#CDHIT=#CDHIT=/opt/cd-hit#' \
        paths

# Compile MAFFT
RUN echo '6e22e0d6130862c67233ab3a13a70febf7f5a1e0a8ab0d73420ca70496b167bc  mafft-7.429-without-extensions-src.tgz' | sha256sum -c \
    && tar -x -f mafft-7.429-without-extensions-src.tgz \
    && cd mafft-7.429-without-extensions/core \
    && sed -i 's#^PREFIX =.*#PREFIX = /opt/mafft#' Makefile \
    && make clean && make && make install \
    && make clean

# Compile NINJA
RUN echo 'b9b948c698efc3838e63817f732ead35c08debe1c0ae36b5c74df7d26ca4c4b6  NINJA-cluster.tar.gz' | sha256sum -c \
    && cd /opt \
    && mkdir NINJA \
    && tar --strip-components=1 -x -f src/NINJA-cluster.tar.gz -C NINJA \
    && cd NINJA/NINJA \
    && make clean && make all

# Compile and configure coseg
RUN echo 'e666874cc602d6a03c45eb2f19dc53b2d95150c6aae83fea0842b7db1d157682  coseg-0.2.2.tar.gz' | sha256sum -c \
    && cd /opt \
    && tar -x -f src/coseg-0.2.2.tar.gz \
    && cd coseg \
    && sed -i 's#use lib "/usr/local/RepeatMasker";#use lib "/opt/RepeatMasker";#' preprocessAlignments.pl \
    && make

# Configure RepeatMasker
RUN echo '7370014c2a7bfd704f0e487cea82a42f05de100c40ea7cbb50f54e20226fe449  RepeatMasker-4.1.0.tar.gz' | sha256sum -c \
    && cd /opt \
    && tar -x -f src/RepeatMasker-4.1.0.tar.gz \
    && chmod a+w RepeatMasker/Libraries \
    && cd RepeatMasker \
    && ln -s /bin/true /opt/trf \
    && perl configure \
        -hmmer_dir=/opt/hmmer \
        -rmblast_dir=/opt/rmblast/bin \
        -libdir=/opt/RepeatMasker/Libraries \
        -trf_prgm=/opt/trf \
        -default_search_engine=rmblast \
    && rm /opt/trf \
    && cd .. && rm src/RepeatMasker-4.1.0.tar.gz

# Configure RepeatModeler
RUN echo '0fda277b7ee81f7fc9c989078a1220cf263d7b76c92b260d36eecc9db7179f5b  RepeatModeler-2.0.tar.gz' | sha256sum -c \
    && cd /opt \
    && tar -x -f src/RepeatModeler-2.0.tar.gz \
    && mv RepeatModeler-2.0 RepeatModeler \
    && cd RepeatModeler \
    && perl configure \
         -cdhit_dir=/opt/cd-hit -genometools_dir=/opt/genometools/bin \
         -ltr_retriever_dir=/opt/LTR_retriever -mafft_dir=/opt/mafft \
         -ninja_dir=/opt/NINJA/NINJA -recon_dir=/opt/RECON/bin \
         -repeatmasker_dir=/opt/RepeatMasker \
         -rmblast_dir=/opt/rmblast/bin -rscout_dir=/opt/RepeatScout \
         -trf_prgm=/opt/trf

FROM debian:9

# Install dependencies and some basic utilities
RUN apt-get -y update \
    && apt-get -y install \
        aptitude \
        libgomp1 \
        perl \
        libfile-which-perl \
        libtext-soundex-perl \
        libjson-perl liburi-perl libwww-perl \
    && aptitude install -y ~pstandard ~prequired \
        curl wget \
        vim nano \
        libpam-systemd-

RUN echo "PS1='(dfam-tetools) \w\$ '" >> /etc/bash.bashrc
COPY --from=builder /opt /opt
ENV LANG=C
ENV PATH=/opt/RepeatMasker:/opt/RepeatMasker/util:/opt/RepeatModeler:/opt/RepeatModeler/util:/opt/coseg:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin