#!/bin/bash
job_name="flux-sample"
job_port="8080"

# Read all the hostname the job is running
nodenames=$(flux exec -r all hostname)
echo "Found nodes ${nodenames}"

# Get the number of nodes
nodes=$(echo "${#node_names[@]}")
leader=$(flux exec -r 0 hostname)
echo "The leader broker is ${leader}"
nodes=${FLUX_JOB_NNODES}
rank=${FLUX_TASK_RANK}
echo "I am hostname $(hostname) and rank ${rank} of ${nodes} nodes"

time torchrun --node_rank ${LOCAL_RANK} --nnodes ${nodes} --nproc_per_node 8 --master_addr ${leader} --master_port ${job_port} /main.py
