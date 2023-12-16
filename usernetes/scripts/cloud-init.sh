#!/bin/bash

# Certificates first!
curl https://www-csp.llnl.gov/content/assets/csoc/cspca.crt > cspca.crt
cp cspca.crt /usr/local/share/ca-certificates
update-ca-certificates

wget https://raw.githubusercontent.com/converged-computing/flux-lima/main/usernetes/scripts/install-flux.sh
wget https://raw.githubusercontent.com/converged-computing/flux-lima/main/usernetes/scripts/install-usernetes.sh
chmod +x ./install-flux.sh
chmod +x ./install-usernetes.sh
/bin/bash ./install-flux.sh
/bin/bash ./install-usernetes.sh
