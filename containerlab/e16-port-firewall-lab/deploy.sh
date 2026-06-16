#!/bin/bash
LAB_NAME="e16-port-firewall-lab"
IMAGE="clab-softnet-e16:latest"
TOPOLOGY="e16-port-firewall-lab.clab.yml"
NODES="hs1 rt1 hs2"
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LAB_DIR}/../lib/deploy.sh"
