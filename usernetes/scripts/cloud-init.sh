#!/bin/bash

# Certificates first!
curl https://www-csp.llnl.gov/content/assets/csoc/cspca.crt > cspca.crt
cp cspca.crt /usr/local/share/ca-certificates
update-ca-certificates

# Add other nodes to /etc/hosts, manual and not great, but will get the job done!
# These are in ubuntu-vars.yaml. This was our first approach...
echo "192.168.65.121 u2204-01" >> /etc/hosts
echo "192.168.65.122 u2204-02" >> /etc/hosts
echo "192.168.65.123 u2204-03" >> /etc/hosts
echo "192.168.65.124 u2204-04" >> /etc/hosts

# This is a more robust approach (that will be an improvement over the above)
# we can likely remove the above but not tested yet.
echo "search llnl.gov" >> /etc/resolv.conf
echo "nameserver 192.168.65.1" >> /etc/resolv.conf

for script in flux usernetes lammps singularity; do
    echo "Installing $script"
    wget https://raw.githubusercontent.com/converged-computing/flux-lima/main/usernetes/scripts/install-${script}.sh
    chmod +x ./install-${script}.sh
    /bin/bash ./install-${script}.sh
done

# Start flux at the end!
systemctl enable flux
systemctl start flux
