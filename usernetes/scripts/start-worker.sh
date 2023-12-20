#!/bin/bash

# This should be run as the flux user on all worker nodes (not index 0 or 01)
# machinectl shell flux@ /bin/bash
# cd ~/usernetes
# ./start-worker.sh

# Go to usernetes home
cd ~/usernetes

# We will need to get this for certs for all nodes
curl https://www-csp.llnl.gov/content/assets/csoc/cspca.crt > cspca.crt

make up

sleep 5

# The nodes need the certs installed (this directory is bound via docker-compose)
# We have to restart containerd here for the certificate update to take
docker exec -it usernetes-node-1 cp ./cspca.crt /usr/local/share/ca-certificates
docker exec -it usernetes-node-1 update-ca-certificates
docker exec -it usernetes-node-1 systemctl restart containerd

sleep 5

# This assumes join-command is already here
make kubeadm-join
