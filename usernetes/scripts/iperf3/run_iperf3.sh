#!/bin/bash
server=${1}
client=${2}
echo "=== SERVER: ${server}"
echo "CLIENT: ${client}"
iperf3 -c ${server} -p 8080
echo "CLIENT BIDIRECTIONAL: ${client}"
# Will run 20x, bidirectional
iperf3 -c ${server} -p 8080 -bidir
