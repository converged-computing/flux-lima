#!/bin/bash

# Read all the hostname the job is running
nodes=$(flux exec -r all hostname)
echo "Found batch nodes $nodes"

# separate the names into an array
IFS=' '
read -ra names <<< $nodes
lead_broker=${names[0]}
echo $lead_broker

echo "The lead broker is ${lead_broker}"

# Write submit job file
cat <<EOF | tee /tmp/lima/submit-job.sh
#!/bin/bash

lead_broker=\${1}

# Each node has already cloned usernetes in home
rm -rf /tmp/lima/join-command /tmp/lima/done.txt /tmp/lima/join-done.txt

if [[ "\$lead_broker" == \$(hostname) ]]; then
    echo "I'm the leader, \${lead_broker}"
    # TODO shouldn't need shared fs
    make up
    sleep 10
    make kubeadm-init
    sleep 5
    make install-flannel
    make kubeconfig
    export KUBECONFIG=\$HOME/usernetes/kubeconfig
    make join-command
    echo "export KUBECONFIG=\$HOME/kubeconfig" >> ~/.bashrc
    cp ./join-command /tmp/lima/join-command
    echo "Join command is generated"
    touch /tmp/lima/done.txt
else
    echo "I'm a follower, \$(hostname)"
    until [ -f /tmp/lima/done.txt ]
    do
        sleep 5
    done
    echo "Join command is READY"
    cp /tmp/lima/join-command ./join-command
    make -C ~/usernetes up kubeadm-join || make -C ~/usernetes up kubeadm-join
    sleep 10
    touch /tmp/lima/join-done.txt    
fi

echo "Sleeping a bit..."
sleep 30
if [[ "\$lead_broker" == \$(hostname) ]]; then
    echo "Lead broker waiting for join of worker"
    until [ -f /tmp/lima/join-done.txt ]
    do
        sleep 5
    done
    kubectl get pods -n kube-system
    kubectl get nodes
fi
# Removes volumes too
make down-v
EOF

chmod +x /tmp/lima/submit-job.sh

# Assume still submit to 2 nodes
ls
# Write output and error to the same file to preserve order
flux submit -N 2 --watch --error ./usernetes-job.out --output ./usernetes-job.out /tmp/lima/submit-job.sh "${lead_broker}"
echo "Stick a fork in me"  
