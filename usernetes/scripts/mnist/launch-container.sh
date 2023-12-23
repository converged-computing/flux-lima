#!/bin/bash
job_name="flux-sample"
job_port="8080"

# Read all the hostname the job is running
nodenames=$(flux exec -r all hostname)
echo "Found nodes ${nodenames}"
# separate the names into an array
IFS=' '
read -ra node_names <<< ${nodenames}
leader=${node_names[0]}
echo "The leader broker is ${leader}"

# Get the number of nodes
nodes=$(echo "${#node_names[@]}")
echo "There are ${nodes} nodes in the cluster"

# Get the task rank
rank=0
for host in "${node_names[@]}"
do
   if [[ "${host}" == "$(hostname)" ]]; then
       echo "This is ${host} with rank ${rank}"
       break
   fi
   ((rank++))
done

echo "I am hostname $(hostname) and rank ${rank} of ${nodes} nodes. The job is ${job_name} and master is on port ${job_port}"

# This will be parsed by the main.py to get the rank
export LOCAL_RANK=${rank}

time torchrun --node_rank ${LOCAL_RANK} --nnodes ${nodes} --nproc_per_node 2 --master_addr ${leader} --master_port ${job_port} /main.py
