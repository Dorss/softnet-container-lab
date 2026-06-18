#!/bin/bash
set -euo pipefail

# This script adds a destination port to the blocked_ports BPF map.
# After this, the XDP program will drop TCP/UDP packets going to that port.

LAB_NAME="e16-port-firewall-lab"
RT_CONTAINER="clab-${LAB_NAME}-rt1"
PORT="${1:-}"

if [[ -z "${PORT}" ]]; then
    echo "Usage: $0 <port>"
    echo "Example: $0 80"
    exit 1
fi

if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
    echo "[ERROR] Invalid port: ${PORT}"
    exit 1
fi

# Convert the port number to the 4-byte key format expected by bpftool.
printf -v B0 "%02x" $(( PORT & 0xff ))
printf -v B1 "%02x" $((( PORT >> 8 ) & 0xff ))
printf -v B2 "%02x" $((( PORT >> 16 ) & 0xff ))
printf -v B3 "%02x" $((( PORT >> 24 ) & 0xff ))

echo "[INFO] Blocking destination port ${PORT}"
echo "[INFO] Updating all BPF maps named blocked_ports inside ${RT_CONTAINER}"



# Remove the port from all blocked_ports maps, because the XDP program
# is attached to both router interfaces.
MAP_IDS=$(docker exec "${RT_CONTAINER}" bpftool map show | awk '/name blocked_ports/ {gsub(":", "", $1); print $1}')

if [[ -z "${MAP_IDS}" ]]; then
    echo "[ERROR] No BPF map named blocked_ports found."
    echo "Did you run ./bin/attach-xdp.sh first?"
    exit 1
fi

for MAP_ID in ${MAP_IDS}; do
    echo "[INFO] Updating map id ${MAP_ID}"
    docker exec "${RT_CONTAINER}" bpftool map update id "${MAP_ID}" \
        key hex "${B0}" "${B1}" "${B2}" "${B3}" \
        value hex 01
done

echo "[OK] Destination port ${PORT} is now blocked"
