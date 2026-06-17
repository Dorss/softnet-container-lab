## Project Documentation

### E16 — Configurable Port Firewall with eBPF/XDP

This repository contains my implementation of project **E16 — Configurable Port Firewall**.

The complete project documentation is available in the following public Google Document:

[Open E16 Project Documentation](https://docs.google.com/document/d/1taA5d4H96eE-SeZhcvVIA5ELj_pwyWDZca7MJ3IQ-u4/edit?usp=sharing)

Project folder in this repository:

[containerlab/e16-port-firewall-lab/](containerlab/e16-port-firewall-lab/)

The documentation includes:

* Project results and screenshots of experimental outcomes.
* Instructions for reproducing the experiments.
* Development notes explaining the design choices and implementation process.

Summary of implemented features:

* eBPF/XDP firewall attached to the router node `rt1`.
* Runtime blocked-port configuration using the `blocked_ports` BPF map.
* Scripts to block and unblock destination ports.
* Packet classification counters using the `packet_stats` BPF map.
* Statistics export using `bin/read-stats.sh`.

