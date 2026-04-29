# clab-softnet — Simple 2-Node ContainerLab Topology

**Purpose:** Minimal containerlab topology with dual-stack IPv4/IPv6 support

---

## Goal

A simple 2-node containerlab topology:
- Two Ubuntu nodes (node1, node2) connected by a single p2p link on eth1
- IPv4: `10.0.0.0/24`
- IPv6: `fc00::/64`

---

## Repository Structure

```
clab-softnet/
├── containerlab/
│   ├── lib/
│   │   ├── deploy.sh               # Shared deploy logic (sourced by lab wrappers)
│   │   └── destroy.sh              # Shared destroy logic (sourced by lab wrappers)
│   ├── basic-lab/                  # Lab 1: entrypoint baked into the image
│   │   ├── basic-lab.clab.yml
│   │   ├── Dockerfile
│   │   ├── bin/entrypoint.sh
│   │   ├── configs/
│   │   │   ├── node1.cfg
│   │   │   └── node2.cfg
│   │   ├── deploy.sh               # Thin wrapper → calls lib/deploy.sh
│   │   └── destroy.sh              # Thin wrapper → calls lib/destroy.sh
│   └── bind-entrypoint-lab/        # Lab 2: entrypoint bind-mounted at runtime
│       ├── bind-entrypoint-lab.clab.yml
│       ├── Dockerfile
│       ├── bin/entrypoint.sh
│       ├── configs/
│       │   ├── node1.cfg
│       │   └── node2.cfg
│       ├── deploy.sh
│       └── destroy.sh
├── scripts/
│   └── build-image.sh              # Build Docker image for a specific lab
├── PLAN.md                         # Architecture and design notes
├── README.md                       # This file
└── TROUBLESHOOTING.md              # Debug guide
```

---

## Prerequisites

- [containerlab](https://containerlab.dev)
- docker
- Linux

---

## Labs

### basic-lab

Entrypoint is baked into the Docker image via `COPY`. Changing the entrypoint requires rebuilding the image.

**Image:** `clab-softnet-basic:latest`

### bind-entrypoint-lab

Entrypoint is **not** in the image — it is bind-mounted from the host at runtime. Students can edit `bin/entrypoint.sh` and redeploy without rebuilding the image, demonstrating the value of keeping images generic.

**Image:** `clab-softnet-bind-ep:latest`

---

## Quick Start

### Deploy a lab

Each lab is self-contained. From the lab directory:

```bash
cd containerlab/basic-lab
./deploy.sh
```

The deploy script will build the Docker image if not present, then deploy the topology.

Or step by step:

```bash
cd containerlab/basic-lab
docker build -t clab-softnet-basic:latest .
containerlab deploy -t basic-lab.clab.yml
```

Containerlab will:
1. Start both containers (`sleep infinity` as PID 1)
2. Create the `node1:eth1 <-> node2:eth1` veth link
3. Run `bash /entrypoint.sh` inside each container via `exec`

The entrypoint output is shown directly in the deploy log.

### Verify connectivity

```bash
# Check node status (from lab directory)
cd containerlab/basic-lab
containerlab inspect -t basic-lab.clab.yml

# IPv4 ping
docker exec clab-basic-lab-node1 ping -c 3 10.0.0.2

# IPv6 ping
docker exec clab-basic-lab-node1 ping -6 -c 3 fc00::2
```

### Destroy

```bash
cd containerlab/basic-lab
./destroy.sh
```

### Build image only

```bash
./scripts/build-image.sh basic-lab
./scripts/build-image.sh bind-entrypoint-lab
```

---

## Configuration

### IP Addressing

| Node  | eth1 IPv4    | eth1 IPv6   | Peer IPv4 | Peer IPv6 |
|-------|-------------|-------------|-----------|-----------|
| node1 | 10.0.0.1/24 | fc00::1/64  | 10.0.0.2  | fc00::2   |
| node2 | 10.0.0.2/24 | fc00::2/64  | 10.0.0.1  | fc00::1   |

Each config file (`configs/node1.cfg`, `configs/node2.cfg`) defines all six values:
`NODE_IP`, `NODE_PREFIX`, `NODE_IP6`, `NODE_PREFIX6`, `PEER_IP`, `PEER_IP6`

### Network Topology

```
    +----------+       +----------+
    |  node1   | eth1  |  node2   |
    |10.0.0.1  |-------|10.0.0.2  |
    |fc00::1   |       |fc00::2   |
    +----------+       +----------+
```

---

## How exec Works

The topology uses containerlab's `exec` to run the entrypoint after links are created:

```yaml
nodes:
  node1:
    binds:
      - configs/node1.cfg:/etc/nodes/node1.cfg:ro
    exec:
      - bash /entrypoint.sh
```

This guarantees `eth1` already exists when the script runs — no polling loop needed.
The container stays alive via `CMD ["sleep", "infinity"]` in the Dockerfile.

---

## Adding a New Lab

1. Create a new directory under `containerlab/` with a `Dockerfile`, topology file, `configs/`, and `bin/entrypoint.sh`
2. Write a `deploy.sh` and `destroy.sh` wrapper (5 lines each) that set `LAB_NAME`, `IMAGE`, `TOPOLOGY`, `LAB_DIR` and source `../lib/deploy.sh` / `../lib/destroy.sh`
3. Deploy with `./deploy.sh` from the new lab directory

---

## Commands Reference

```bash
# Deploy (from lab directory)
./deploy.sh

# Inspect
containerlab inspect -t <topology>.clab.yml

# Shell access
docker exec -it clab-<lab-name>-node1 bash
docker exec -it clab-<lab-name>-node2 bash

# Destroy (from lab directory)
./destroy.sh
```

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

---

## License

GNU General Public License v3.0
