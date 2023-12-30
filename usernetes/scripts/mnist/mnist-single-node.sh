#!/bin/bash

# This is updated to use a more modern mnist script with 10 epochs, and just on one node.
# Since we don't distribute, we don't need torchrun

job_name="flux-sample"
job_port="8080"
container="/home/flux/mnist/pytorch-mnist-cpu_latest.sif"

# Hard code the leader for now
leader=$(hostname)
nodes=${FLUX_JOB_NNODES}
rank=${FLUX_TASK_RANK}
echo "I am hostname $(hostname) and rank ${rank} of ${nodes} nodes"

if [[ ! -f "/home/flux/mnist/main-single.py" ]]; then
    wget -O /home/flux/mnist/main-single.py https://raw.githubusercontent.com/pytorch/examples/main/mnist/main.py
    chmod +x /home/flux/mnist/main-single.py
fi
time singularity exec ${container} python3 /home/flux/mnist/main-single.py
