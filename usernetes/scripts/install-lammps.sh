#!/bin/bash

# Install a "bare metal" lammps

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Note we install to /usr so can be found by all users
git clone --depth 1 --branch stable_29Sep2021_update2 https://github.com/lammps/lammps.git /opt/lammps
cd /opt/lammps
mkdir build
cd build
. /etc/profile
cmake ../cmake -D PKG_REAXFF=yes -D BUILD_MPI=yes -D PKG_OPT=yes
make
make install

# where does it get installed to?
mv ./lmp /usr/bin/
# which lmp
# 

# examples are in:
# /opt/lammps/examples/reaxff/HNS
cp -R /opt/lammps/examples/reaxff/HNS /home/flux/lammps
cp -R /opt/lammps/examples/reaxff/HNS /home/fluxuser/lammps
chown -R flux /home/flux/lammps
chown -R fluxuser /home/fluxuser/lammps
