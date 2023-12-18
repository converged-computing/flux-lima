#!/bin/bash

# Certificates first!
curl https://www-csp.llnl.gov/content/assets/csoc/cspca.crt > cspca.crt
cp cspca.crt /usr/local/share/ca-certificates
update-ca-certificates

# Add other nodes to /etc/hosts, manual and not great, but will get the job done!
# These are in ubuntu-vars.yaml
echo "192.168.65.121 u2204-01" >> /etc/hosts
echo "192.168.65.122 u2204-02" >> /etc/hosts
echo "192.168.65.123 u2204-03" >> /etc/hosts
echo "192.168.65.124 u2204-04" >> /etc/hosts

wget https://raw.githubusercontent.com/converged-computing/flux-lima/main/usernetes/scripts/install-flux.sh
wget https://raw.githubusercontent.com/converged-computing/flux-lima/main/usernetes/scripts/install-usernetes.sh
chmod +x ./install-flux.sh
chmod +x ./install-usernetes.sh
/bin/bash ./install-flux.sh
/bin/bash ./install-usernetes.sh

# Start flux at the end!
systemctl enable flux
systemctl start flux
