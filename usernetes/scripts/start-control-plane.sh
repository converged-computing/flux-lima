#!/bin/bash

# This should be run as the flux user on the control plane node (index 0 or 01)
# machinectl shell flux@ /bin/bash
# cd ~/usernetes
# ./start-control-plane.sh

# Go to usernetes home
cd ~/usernetes

# We will need to get this for certs for all nodes
curl https://www-csp.llnl.gov/content/assets/csoc/cspca.crt > cspca.crt

# This is logic for the lead broker (we assume this one)
make up
docker exec -it usernetes-node-1 cp ./cspca.crt /usr/local/share/ca-certificates
docker exec -it usernetes-node-1 update-ca-certificates
docker exec -it usernetes-node-1 systemctl restart containerd

sleep 10
make kubeadm-init
sleep 5
make install-flannel
make kubeconfig
export KUBECONFIG=$HOME/usernetes/kubeconfig
make join-command
echo "export KUBECONFIG=$HOME/usernetes/kubeconfig" >> ~/.bashrc

# Try sending to other nodes with flux. This stages it...
flux filemap map -C /home/flux/usernetes join-command

# And this sends it! We send to all but the index 0
flux exec -x 0 -r all flux filemap get -C /home/flux/usernetes
