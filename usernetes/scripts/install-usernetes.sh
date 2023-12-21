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
mkdir -p /etc/flux/system/conf.d /etc/flux/system/cron.d
cat <<EOF | tee /etc/flux/system/conf.d/broker.toml
# Flux needs to know the path to the IMP executable
[exec]
imp = "/usr/libexec/flux/flux-imp"

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

# ubuntu does not have eth0
default_port = 8050
default_bind = "tcp://enp1s0:%p"
default_connect = "tcp://%h:%p"

# Rank 0 is the TBON parent of all brokers unless explicitly set with
# parent directives.
# The actual ip addresses (for both) need to be added to /etc/hosts
# of each VM for now.
hosts = [
   { host = "u2204-0[1-7]" },
]
# Speed up detection of crashed network peers (system default is around 20m)
[tbon]
tcp_user_timeout = "2m"
EOF
cat /etc/flux/system/conf.d/broker.toml
echo "DONE broker.toml"

echo "Creating flux user"
adduser --disabled-password --gecos "" fluxuser

# Deny ssh access for flux user (just being conservative for now)
echo "DenyUsers fluxuser flux" >> /etc/ssh/sshd_config
systemctl restart sshd

echo "Setting up usernetes"

# Note I'm setting this up for flux and fluxuser
# I think for our experiments we are good to use a single user instance (e.g., run as flux)
echo "export PATH=/usr/bin:$PATH" >> /home/fluxuser/.bashrc
echo "export XDG_RUNTIME_DIR=/home/fluxuser/.docker/run" >> /home/fluxuser/.bashrc
echo "export DOCKER_HOST=unix:///home/fluxuser/.docker/run/docker.sock" >> /home/fluxuser/.bashrc

echo "export PATH=/usr/bin:$PATH" >> /home/flux/.bashrc
echo "export XDG_RUNTIME_DIR=/home/flux/.docker/run" >> /home/flux/.bashrc
echo "export DOCKER_HOST=unix:///home/flux/.docker/run/docker.sock" >> /home/flux/.bashrc

echo "Installing docker user"
loginctl enable-linger fluxuser
loginctl enable-linger flux

# https://github.com/docker/docs/issues/14491
apt install -y systemd-container

# This is an attempt to run a bunch of stuff as the fluxuser
# Be careful with envars here, they would need to be escaped
# otherwise they are evaluated in root's environment
cat <<EOF | tee /home/fluxuser/docker-user-setup.sh
#!/bin/bash
ls /var/lib/systemd/linger
. /home/fluxuser/.bashrc
loginctl enable-linger fluxuser

export XDG_RUNTIME_DIR=/home/fluxuser/.docker/run
mkdir -p /home/fluxuser/.docker/run
export DOCKER_HOST=unix:///home/fluxuser/.docker/run/docker.sock
dockerd-rootless-setuptool.sh install
sleep 10
systemctl --user enable docker.service
systemctl --user start docker.service

# Not sure why this is happening, but it's starting here
ln -s /run/user/1001/docker.sock /home/fluxuser/.docker/run/docker.sock
docker run hello-world

# Clone usernetes, and also wget the scripts to start control plane and worker nodes
if [[ ! -d "/home/fluxuser/usernetes" ]]; then
    git clone https://github.com/rootless-containers/usernetes ~/usernetes
    cd ~/usernetes
    wget https://raw.githubusercontent.com/converged-computing/flux-lima/main/usernetes/scripts/start-control-plane.sh
    wget https://raw.githubusercontent.com/converged-computing/flux-lima/main/usernetes/scripts/start-worker.sh
    chmod +x ./start-control-plane.sh
    chmod +x ./start-worker.sh
fi
echo "Usernetes is in ~/usernetes"
EOF
chmod +x /home/fluxuser/docker-user-setup.sh
cat /home/fluxuser/docker-user-setup.sh

# Prepare one for flux too
cp /home/fluxuser/docker-user-setup.sh /home/flux/docker-user-setup.sh
sed -i 's/fluxuser/flux/g' /home/flux/docker-user-setup.sh
sed -i 's/1001/1002/g' /home/flux/docker-user-setup.sh

# We need to use this to run the script, otherwise
# the docker service won't work, see linked issue above
# This MUST be a full path
machinectl shell fluxuser@ /bin/bash /home/fluxuser/docker-user-setup.sh
machinectl shell flux@ /bin/bash /home/flux/docker-user-setup.sh

# interactive shell
# machinectl shell fluxuser@

echo "Done installing docker user"
chown flux /etc/flux/system/curve.cert
touch /tmp/finished.txt
