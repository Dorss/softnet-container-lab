# XDP Packet Counter Lab

## Overview

Two-node point-to-point lab demonstrating eBPF XDP program loading and inspection. Each node runs an `xdp_counter` program that increments a BPF map counter for every packet traversing `eth1` and logs packet count via `bpf_printk` to the kernel trace buffer.

## Architecture

```
node1 (10.0.3.1/24) ──── eth1 ────── eth1 ──── node2 (10.0.3.2/24)
                            (veth, mtu 1500)
```

Both nodes have `/sys/kernel/debug` and `/sys/fs/bpf` mounted for BPF debugging and map inspection. `bpf_printk` output is available on `eth1` via the trace pipe.

## Pre-requisites

- containerlab v0.73+
- Docker
- `/sys/kernel/btf/vmlinux` (BTF support)

## Student Workflow

### 1. Compile the BPF program

```bash
cd containerlab/xdp-lab/src
make
```

This automatically generates `vmlinux.h` from the host kernel BTF and compiles `test_xdp.bpf.c` into `test_xdp.o` inside the `bpf-builder` container.

### 2. Deploy the lab

```bash
cd ..
./deploy.sh
```

### 3. Attach the XDP program

```bash
docker exec clab-xdp-lab-node1 ip link set dev eth1 xdp obj /work/bpf/test_xdp.o sec xdp
```

### 4. Verify XDP is attached

```bash
docker exec clab-xdp-lab-node1 ip -d link show dev eth1 | grep xdp
```

### 5. Generate traffic

```bash
docker exec clab-xdp-lab-node2 ping -c 5 10.0.3.1
```

### 6. Inspect trace_pipe output

```bash
# In node1, trace_pipe blocks until new data arrives
# Use timeout to avoid hanging:
docker exec clab-xdp-lab-node1 timeout 3 cat /sys/kernel/debug/tracing/trace_pipe
```

Expected output:

```
            node1-XXXXX   [000] ....   123.456789: <xdp>: xdp: packet 10
```

### 7. Read the BPF map

```bash
docker exec clab-xdp-lab-node1 bpftool map show | grep packets_map
docker exec clab-xdp-lab-node1 bpftool map dump name packets_map
```

### 8. Clean up

```bash
docker exec clab-xdp-lab-node1 ip link set dev eth1 xdp off
cd containerlab/xdp-lab
./destroy.sh
```
