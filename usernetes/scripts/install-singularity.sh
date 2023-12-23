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

wget https://github.com/sylabs/singularity/releases/download/v4.0.2/singularity-ce_4.0.2-jammy_amd64.deb
dpkg -i singularity-ce_4.0.2-jammy_amd64.deb

# Pull singularity down and put in flux home
singularity pull docker://ghcr.io/rse-ops/lammps-mpich:tag-latest
singularity pull docker://kubeflowkatib/pytorch-mnist-cpu:latest 

# Containers for lammps and mnist
mv lammps-mpich_tag-latest.sif /home/flux/lammps/lammps-mpich_tag-latest.sif
mkdir -p /home/flux/mnist
mv pytorch-mnist-cpu_latest.sif /home/flux/pytorch-mnist-cpu_latest.sif
cd /home/flux/mnist
wget https://raw.githubusercontent.com/converged-computing/flux-lima/main/usernetes/scripts/mnist/main.py
wget https://raw.githubusercontent.com/converged-computing/flux-lima/main/usernetes/scripts/mnist/launch.sh

chown -R flux /home/flux/mnist
chown flux /home/flux/lammps/lammps-mpich_tag-latest.sif
touch /tmp/singularity-finished.txt
