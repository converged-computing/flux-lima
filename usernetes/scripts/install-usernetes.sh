#!/bin/bash
# This also is run as root!

set -euo pipefail

echo "START updating cgroups2"
cat /etc/default/grub | grep GRUB_CMDLINE_LINUX=
GRUB_CMDLINE_LINUX=""
sed -i -e 's/^GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"/' /etc/default/grub
update-grub

mkdir -p /etc/systemd/system/user@.service.d
cat <<EOF | tee /etc/systemd/system/user@.service.d/delegate.conf
[Service]
Delegate=cpu cpuset io memory pids
EOF
systemctl daemon-reload
echo "DONE updating cgroups2"

echo "START updating kernel modules"
modprobe ip_tables
tee /etc/modules-load.d/usernetes.conf <<EOF >/dev/null
br_netfilter
vxlan
EOF
systemctl restart systemd-modules-load.service
echo "DONE updating kernel modules"

echo "START 99-usernetes.conf"
echo "net.ipv4.conf.default.rp_filter = 2" > /tmp/99-usernetes.conf
mv /tmp/99-usernetes.conf /etc/sysctl.d/99-usernetes.conf
sysctl --system
echo "DONE 99-usernetes.conf"

echo "START modprobe"
modprobe vxlan
systemctl daemon-reload
echo "net.ipv4.conf.default.rp_filter=2" | tee -a /etc/sysctl.conf
sysctl -p
systemctl daemon-reload
echo "DONE modprobe"

echo "START kubectl"
cd /tmp
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
mv ./kubectl /usr/bin/kubectl
echo "DONE kubectl"

echo "Installing docker"
curl -o install.sh -fsSL https://get.docker.com
chmod +x install.sh
./install.sh
echo "done installing docker"

echo "START broker.toml"
mkdir -p /etc/flux/system
cat <<EOF | tee /etc/flux/system/broker.toml
# Flux needs to know the path to the IMP executable
# Disabled for now, not signing jobs
# [exec]
# imp = "/usr/libexec/flux/flux-imp"

# Allow users other than the instance owner (guests) to connect to Flux
# Optionally, root may be given "owner privileges" for convenience
[access]
allow-guest-user = true
allow-root-owner = true

# Point to shared network certificate generated flux-keygen(1).
# Define the network endpoints for Flux's tree based overlay network
# and inform Flux of the hostnames that will start flux-broker(1).
[bootstrap]
curve_cert = "/etc/flux/system/curve.cert"

default_port = 8050
default_bind = "tcp://eth0:%p"
default_connect = "tcp://%h.internal:%p"

# Rank 0 is the TBON parent of all brokers unless explicitly set with
# parent directives.
# The actual ip addresses (for both) need to be added to /etc/hosts
# of each VM for now.
hosts = [
   { host = "u2204-0[1-4]" },
]
# Speed up detection of crashed network peers (system default is around 20m)
[tbon]
tcp_user_timeout = "2m"
EOF
cat /etc/flux/system/broker.toml
echo "DONE broker.toml"


echo "Creating flux user"
adduser --disabled-password --gecos "" fluxuser

# control-plane or worker
echo "Installing docker user"
su fluxuser dockerd-rootless-setuptool.sh install

# TODO need to run this with user...
echo "Setting up usernetes"
echo "export PATH=/usr/bin:$PATH" >> /home/fluxuser/.bashrc
echo "export DOCKER_HOST=unix://${XDG_RUNTIME_DIR}/docker.sock" >> /home/fluxuser/.bashrc

export PATH=/usr/bin:$PATH
export DOCKER_HOST=unix://${XDG_RUNTIME_DIR}/docker.sock
sleep 10   
# loginctl enable-linger fluxuser
# systemctl --user enable docker.service
# systemctl --user start docker.service

# su fluxuser docker run hello-world
# git clone https://github.com/rootless-containers/usernetes ~/usernetes
# cd ~/usernetes
# echo "Usernetes is in $PWD"
# sudo loginctl enable-linger $(whoami)
# loginctl enable-linger $USER
# echo "Done installing docker user"
chown fluxuser /etc/flux/system/curve.cert
touch /tmp/finished.txt
