#!/bin/bash

# Certificates first!
curl https://www-csp.llnl.gov/content/assets/csoc/cspca.crt > cspca.crt
cp cspca.crt /usr/local/share/ca-certificates
update-ca-certificates

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
