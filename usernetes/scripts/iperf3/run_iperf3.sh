#!/bin/bash
server=${1}
client=${2}
logfile=${3}
echo "=== SERVER: ${server}"
echo "CLIENT: ${client}"
iperf3 -c ${server} -p 8080 --json > ${logfile}.json
echo "CLIENT BIDIRECTIONAL: ${client}"
# Will run 20x, bidirectional
iperf3 -c ${server} -p 8080 --json -bidir > ${logfile}-bidir.json
