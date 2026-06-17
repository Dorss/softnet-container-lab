#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

#define ETH_P_IP    0x0800
#define IPPROTO_TCP 6
#define IPPROTO_UDP 17

/*
 * E16 — Configurable Port Firewall, Intermediate Level
 *
 * Requirement:
 * Drop traffic TO a configurable TCP/UDP destination port.
 *
 * The blocked ports are stored in a BPF hash map named blocked_ports.
 * Userspace can update this map after the program is attached, without
 * recompiling the eBPF program.
 *
 * The program is attached to both router interfaces:
 *   rt1:eth1  -> traffic from hs1 to hs2
 *   rt1:eth2  -> traffic from hs2 to hs1
 */

struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 256);
    __type(key, __u32);     /* destination port in host byte order */
    __type(value, __u8);    /* value exists => port is blocked */
} blocked_ports SEC(".maps");

SEC("xdp")
int xdp_port_firewall(struct xdp_md *ctx)
{
    void *data = (void *)(long)ctx->data;
    void *data_end = (void *)(long)ctx->data_end;

    struct ethhdr *eth = data;

    if ((void *)(eth + 1) > data_end)
        return XDP_PASS;

    /* This project filters IPv4 packets only. */
    if (eth->h_proto != bpf_htons(ETH_P_IP))
        return XDP_PASS;

    struct iphdr *ip = (void *)(eth + 1);

    if ((void *)(ip + 1) > data_end)
        return XDP_PASS;

    __u32 ip_header_len = ip->ihl * 4;

    if (ip_header_len < sizeof(*ip))
        return XDP_PASS;

    if ((void *)ip + ip_header_len > data_end)
        return XDP_PASS;

    void *l4_header = (void *)ip + ip_header_len;
    __u16 dst_port = 0;

    if (ip->protocol == IPPROTO_TCP) {
        struct tcphdr *tcp = l4_header;

        if ((void *)(tcp + 1) > data_end)
            return XDP_PASS;

        dst_port = bpf_ntohs(tcp->dest);

    } else if (ip->protocol == IPPROTO_UDP) {
        struct udphdr *udp = l4_header;

        if ((void *)(udp + 1) > data_end)
            return XDP_PASS;

        dst_port = bpf_ntohs(udp->dest);

    } else {
        return XDP_PASS;
    }

    __u32 key = dst_port;
    __u8 *blocked = bpf_map_lookup_elem(&blocked_ports, &key);

    if (blocked) {
        bpf_printk("E16 firewall: drop IPv4 packet to destination port %u", dst_port);
        return XDP_DROP;
    }

    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
