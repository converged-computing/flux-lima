#!/bin/bash
server=${1}
echo "=== SERVER: ${server}"
echo "CLIENT: $(hostname)"
iperf3 -c ${server} -p 8080
echo "CLIENT BIDIRECTIONAL: $(hostname)"
# Will run 20x, bidirectional
iperf3 -c ${server} -p 8080 -bidir
