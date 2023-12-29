#!/bin/bash

# We are hardcoding these for now, would be better to use envars
# Get the number of nodes (I think JOB_COMPLETIONS would work here)
job_port="8080"
nodes=6
leader=flux-sample-0

echo "The leader broker is ${leader}"
rank=${JOB_COMPLETION_INDEX}
echo "I am hostname $(hostname) and rank ${rank} of ${nodes} nodes"

time torchrun --node_rank ${rank} --nnodes ${nodes} --nproc_per_node 8 --master_addr ${leader} --master_port ${job_port} /main.py
