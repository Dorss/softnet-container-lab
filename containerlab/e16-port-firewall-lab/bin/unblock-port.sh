#!/bin/bash
set -euo pipefail

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

# BPF map key type is __u32, so encode the port as 4 bytes little-endian.
printf -v B0 "%02x" $(( PORT & 0xff ))
printf -v B1 "%02x" $((( PORT >> 8 ) & 0xff ))
printf -v B2 "%02x" $((( PORT >> 16 ) & 0xff ))
printf -v B3 "%02x" $((( PORT >> 24 ) & 0xff ))

echo "[INFO] Unblocking destination port ${PORT}"

MAP_IDS=$(docker exec "${RT_CONTAINER}" bpftool map show | awk '/name blocked_ports/ {gsub(":", "", $1); print $1}')

if [[ -z "${MAP_IDS}" ]]; then
    echo "[ERROR] No BPF map named blocked_ports found."
    echo "Did you run ./bin/attach-xdp.sh first?"
    exit 1
fi

for MAP_ID in ${MAP_IDS}; do
    echo "[INFO] Removing key from map id ${MAP_ID}"
    docker exec "${RT_CONTAINER}" bpftool map delete id "${MAP_ID}" \
        key hex "${B0}" "${B1}" "${B2}" "${B3}" 2>/dev/null || true
done

echo "[OK] Destination port ${PORT} is now unblocked"
