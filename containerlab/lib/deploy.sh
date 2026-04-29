#!/bin/bash
# Generic deploy logic. Must be sourced by a lab-specific wrapper that sets:
#   LAB_NAME   - containerlab topology name (matches 'name:' in .clab.yml)
#   IMAGE      - docker image tag to build and use
#   TOPOLOGY   - topology filename (e.g. basic-lab.clab.yml)
#   LAB_DIR    - absolute path to the lab directory
set -euo pipefail

echo "=== Deploy ${LAB_NAME} ==="

cd "${LAB_DIR}"

echo ""
echo "== Step 1: Check/build Docker image =="
if ! docker images "${IMAGE}" --format '{{.Repository}}:{{.Tag}}' | grep -q "${IMAGE}"; then
    echo "[INFO] Building Docker image ${IMAGE}..."
    docker build -t "${IMAGE}" .
    echo "[OK] Docker image built"
else
    echo "[OK] Docker image already exists: ${IMAGE}"
fi

echo ""
echo "== Step 2: Deploy containerlab topology =="
if containerlab inspect -t "${TOPOLOGY}" >/dev/null 2>&1; then
    echo "[WARN] Topology already running, destroying first..."
    containerlab destroy -t "${TOPOLOGY}" --cleanup
fi

containerlab deploy -t "${TOPOLOGY}"
echo "[OK] Topology deployed"

echo ""
echo "== Step 3: Verify deployment =="
containerlab inspect -t "${TOPOLOGY}"

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Access nodes:"
echo "  docker exec -it clab-${LAB_NAME}-node1 bash"
echo "  docker exec -it clab-${LAB_NAME}-node2 bash"
echo ""
echo "Test connectivity:"
echo "  docker exec clab-${LAB_NAME}-node1 ping -c 3 10.0.0.2"
echo "  docker exec clab-${LAB_NAME}-node1 ping -6 -c 3 fc00::2"
echo ""
echo "Destroy: ${LAB_DIR}/destroy.sh"
