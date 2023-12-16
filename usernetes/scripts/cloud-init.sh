#!/bin/bash
wget https://raw.githubusercontent.com/converged-computing/flux-lima/main/usernetes/scripts/install-flux.sh
wget https://raw.githubusercontent.com/converged-computing/flux-lima/main/usernetes/scripts/install-usernetes.sh
chmod +x ./install-flux.sh
chmod +x ./install-usernetes.sh
/bin/bash ./install-flux.sh
/bin/bash ./install-usernetes.sh
