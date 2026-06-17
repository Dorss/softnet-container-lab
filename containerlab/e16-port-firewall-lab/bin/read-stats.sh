#!/bin/bash
set -euo pipefail

RT_CONTAINER="clab-e16-port-firewall-lab-rt1"

if ! docker ps --format '{{.Names}}' | grep -q "^${RT_CONTAINER}$"; then
    echo "[ERROR] Router container is not running: ${RT_CONTAINER}"
    exit 1
fi

MAP_IDS=$(docker exec "${RT_CONTAINER}" bpftool map show | awk '/name packet_stats/ {gsub(":", "", $1); print $1}')

if [[ -z "${MAP_IDS}" ]]; then
    echo "[ERROR] No BPF map named packet_stats found."
    echo "Compile, deploy, and attach the XDP program first."
    exit 1
fi

NAMES=("total" "ipv4" "ipv6" "tcp" "udp" "icmp" "other_l4" "dropped" "passed")
TOTALS=(0 0 0 0 0 0 0 0 0)

lookup_value() {
    local map_id="$1"
    local key="$2"

    local k0 k1 k2 k3
    printf -v k0 "%02x" $(( key & 0xff ))
    printf -v k1 "%02x" $((( key >> 8 ) & 0xff ))
    printf -v k2 "%02x" $((( key >> 16 ) & 0xff ))
    printf -v k3 "%02x" $((( key >> 24 ) & 0xff ))

    docker exec "${RT_CONTAINER}" bpftool map lookup id "${map_id}" \
        key hex "${k0}" "${k1}" "${k2}" "${k3}" 2>/dev/null | python3 -c '
import sys, re

text = sys.stdin.read()

# Case 1: bpftool prints JSON-style decimal output:
# "value": 18
m = re.search(r"\"value\"\s*:\s*(\d+)", text)
if m:
    print(m.group(1))
    sys.exit(0)

# Case 2: bpftool prints hex byte output:
# value: 12 00 00 00 00 00 00 00
m = re.search(r"value:\s*((?:[0-9a-fA-F]{2}\s*)+)", text)
if m:
    bs = [int(x, 16) for x in m.group(1).split()]
    value = 0
    for i, b in enumerate(bs):
        value += b << (8 * i)
    print(value)
    sys.exit(0)

print(0)
'
}

echo "=== E16 packet statistics ==="
echo ""

for map_id in ${MAP_IDS}; do
    echo "[INFO] Reading packet_stats map id ${map_id}"

    for key in "${!NAMES[@]}"; do
        value=$(lookup_value "${map_id}" "${key}")
        TOTALS[$key]=$(( TOTALS[$key] + value ))
    done
done

echo ""
printf "%-12s %s\n" "class" "count"
printf "%-12s %s\n" "-----" "-----"

for key in "${!NAMES[@]}"; do
    printf "%-12s %s\n" "${NAMES[$key]}" "${TOTALS[$key]}"
done
