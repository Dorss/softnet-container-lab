#!/bin/bash
set -euo pipefail

# This script attaches the compiled XDP firewall program to the router interfaces.



LAB_NAME="e16-port-firewall-lab"
RT_CONTAINER="clab-${LAB_NAME}-rt1"
BPF_OBJ="/work/bpf/port_firewall.bpf.o"
SECTION="xdp"


# The compiled eBPF object must exist before it can be attached.
echo "[INFO] Attaching E16 XDP port firewall on router: ${RT_CONTAINER}"
echo "[INFO] Blocked ports are configured through the blocked_ports BPF map"
echo ""

echo "[INFO] Checking that the BPF object exists inside rt1..."
docker exec "${RT_CONTAINER}" test -f "${BPF_OBJ}"



# Remove any old XDP program first, so the new attachment starts cleanly.
echo "[INFO] Removing old XDP programs if present..."
docker exec "${RT_CONTAINER}" bash -c 'ip link set dev eth1 xdpgeneric off 2>/dev/null || true'
docker exec "${RT_CONTAINER}" bash -c 'ip link set dev eth2 xdpgeneric off 2>/dev/null || true'



# Attach the XDP program to both router interfaces for bidirectional filtering.
# Generic XDP is used because it is compatible with Containerlab veth interfaces.
echo "[INFO] Attaching XDP firewall to rt1:eth1"
docker exec "${RT_CONTAINER}" ip link set dev eth1 xdpgeneric obj "${BPF_OBJ}" sec "${SECTION}"

echo "[INFO] Attaching XDP firewall to rt1:eth2"
docker exec "${RT_CONTAINER}" ip link set dev eth2 xdpgeneric obj "${BPF_OBJ}" sec "${SECTION}"

echo ""
echo "[OK] XDP firewall attached on rt1 eth1 and eth2"
echo ""



# Print the XDP status as evidence that the program is attached.
echo "[INFO] Current XDP status on eth1:"
docker exec "${RT_CONTAINER}" bpftool net show dev eth1 || true

echo ""
echo "[INFO] Current XDP status on eth2:"
docker exec "${RT_CONTAINER}" bpftool net show dev eth2 || true
