#!/bin/bash

# flux start mpirun -n 6 singularity exec singularity-mpi_mpich.sif /opt/mpitest
apt-get update && apt-get install -y libseccomp-dev libglib2.0-dev cryptsetup \
   libfuse-dev \
   squashfs-tools \
   squashfs-tools-ng \
   uidmap \
   zlib1g-dev

wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
tar -xvf go1.21.0.linux-amd64.tar.gz
mv go /usr/local && rm go1.21.0.linux-amd64.tar.gz

export PATH=/usr/local/go/bin:$PATH
SINGULARITY_VERSION=4.0.1
wget https://github.com/sylabs/singularity/releases/download/v${SINGULARITY_VERSION}/singularity-ce-${SINGULARITY_VERSION}.tar.gz
tar -xzvf singularity-ce-${SINGULARITY_VERSION}.tar.gz
cd singularity-ce-${SINGULARITY_VERSION}
./mconfig -p /usr/local
make -C builddir
make -C builddir install
cd ../
rm -rf singularity-ce-${SINGULARITY_VERSION}

# Pull singularity down and put in flux home
singularity pull docker://ghcr.io/rse-ops/lammps-mpich:tag-latest
mv lammps-mpich_tag-latest.sif /home/flux/lammps/lammps-mpich_tag-latest.sif
chown flux /home/flux/lammps/lammps-mpich_tag-latest.sif

touch /tmp/singularity-finished.txt
