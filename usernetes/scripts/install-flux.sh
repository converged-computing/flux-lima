#!/bin/bash

set -euo pipefail

# Assumes running as root / sudo

echo "START flux build"

# Install dependencies (might be some left over from BDF)
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apt-transport-https ca-certificates curl clang llvm jq apt-utils wget
apt-get install -y libelf-dev libpcap-dev libbfd-dev binutils-dev build-essential make 
apt-get install -y linux-tools-common linux-tools-$(uname -r) 
apt-get install -y bpfcc-tools python3-pip git net-tools

# cmake is needed for flux now!
export CMAKE=3.23.1
curl -s -L https://github.com/Kitware/CMake/releases/download/v$CMAKE/cmake-$CMAKE-linux-x86_64.sh > cmake.sh
sh cmake.sh --prefix=/usr/local --skip-license
apt-get install -y man flex ssh sudo vim luarocks munge lcov ccache lua5.2 mpich
apt-get install -y valgrind build-essential pkg-config autotools-dev libtool
apt-get install -y libffi-dev autoconf automake make clang clang-tidy
apt-get install -y gcc g++ libpam-dev apt-utils
apt-get install -y libsodium-dev libzmq3-dev libczmq-dev libjansson-dev libmunge-dev
apt-get install -y libncursesw5-dev liblua5.2-dev liblz4-dev libsqlite3-dev uuid-dev
apt-get install -y libhwloc-dev libmpich-dev libs3-dev libevent-dev libarchive-dev
apt-get install -y libboost-graph-dev libboost-system-dev libboost-filesystem-dev
apt-get install -y libboost-regex-dev libyaml-cpp-dev libedit-dev uidmap dbus-user-session

# Let's use mamba python and do away with system annoyances
curl -L https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-Linux-x86_64.sh > mambaforge.sh
bash mambaforge.sh -b -p /opt/conda
export PATH=/opt/conda/bin:$PATH
pip install --upgrade --ignore-installed markupsafe coverage cffi ply six pyyaml jsonschema
pip install --upgrade --ignore-installed sphinx sphinx-rtd-theme sphinxcontrib-spelling

# Prepare lua rocks things I don't understand
apt-get install -y faketime libfaketime pylint cppcheck aspell aspell-en
locale-gen en_US.UTF-8
luarocks install luaposix

# openpmix... back... back evil spirits!
mkdir -p /opt/prrte
cd /opt/prrte
git clone https://github.com/openpmix/openpmix.git
git clone https://github.com/openpmix/prrte.git
set -x
cd openpmix
git checkout fefaed568f33bf86f28afb6e45237f1ec5e4de93
./autogen.pl
./configure --prefix=/usr --disable-static && make -j 4 install
ldconfig

# prrte you are sure looking perrrty today
cd /opt/prrte/prrte
git checkout 477894f4720d822b15cab56eee7665107832921c
./autogen.pl
./configure --prefix=/usr && make -j 4 install

# flux security
git clone --depth 1 https://github.com/flux-framework/flux-security /opt/flux-security
cd /opt/flux-security
./autogen.sh
PYTHON=/opt/conda/bin/python ./configure --prefix=/usr --sysconfdir=/etc
make && make install

# Create the user that will run flux, "flux" with sudo access
# ubuntu is already 1000, and flux user 1001, so flux is 1002
groupadd -g 1002 flux 
useradd -g flux -u 1002 -d /home/flux -m flux 
printf "flux ALL= NOPASSWD: ALL\\n" >> /etc/sudoers

# The VMs will share the same munge key
mkdir -p /var/run/munge
dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
chown -R munge /etc/munge/munge.key /var/run/munge
chmod 600 /etc/munge/munge.key

# Make the flux run directory
mkdir -p /home/flux/run/flux
chown -R flux /home/flux

# Flux core
git clone https://github.com/flux-framework/flux-core /opt/flux-core
cd /opt/flux-core

# note we change the runstatedir to flux home, it sometimes does not create
# in run and I get weird behavior
./autogen.sh
PYTHON=/opt/conda/bin/python PYTHON_PREFIX=PYTHON_EXEC_PREFIX=/opt/conda/lib/python3.8/site-packages ./configure --prefix=/usr --sysconfdir=/etc --runstatedir=/home/flux/run --with-flux-security
make clean
make && make install

# Flux sched
git clone https://github.com/flux-framework/flux-sched /opt/flux-sched
cd /opt/flux-sched
git fetch
git checkout v0.30.0
./autogen.sh
PYTHON=/opt/conda/bin/python ./configure --prefix=/usr --sysconfdir=/etc
make && make install && ldconfig
echo "DONE flux build"

# Flux curve.cert
# Ensure we have a shared curve certificate
wget -O /tmp/curve.cert https://gist.githubusercontent.com/vsoch/58cb5eeca8ac88d2e968f4950769add4/raw/42d447d377b414b4e040d43aadc243f5be1dd3d5/curve.cert
# flux keygen /tmp/curve.cert
mkdir -p /etc/flux/system
cp /tmp/curve.cert /etc/flux/system/curve.cert
chown flux /etc/flux/system/curve.cert
chmod o-r /etc/flux/system/curve.cert
chmod g-r /etc/flux/system/curve.cert

# /var/lib/flux needs to be owned by the instance owner
mkdir -p /var/lib/flux
chown -R flux /var/lib/flux
