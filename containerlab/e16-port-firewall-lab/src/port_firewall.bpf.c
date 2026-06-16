#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

#define ETH_P_IP    0x0800
#define IPPROTO_TCP 6
#define IPPROTO_UDP 17

/*
 * E16 — Configurable Port Firewall, Basic Level
 *
 * Requirement:
 * Drop traffic TO a fixed TCP/UDP port.
 *
 * This basic implementation blocks IPv4 TCP/UDP packets whose
 * destination port is 80.
 *
 * The program will be attached to both router interfaces:
 *   rt1:eth1  -> traffic from hs1 to hs2
 *   rt1:eth2  -> traffic from hs2 to hs1
 *
 * Therefore, port 80 is blocked in both directions.
 */
#define BLOCKED_PORT 80

SEC("xdp")
int xdp_port_firewall(struct xdp_md *ctx)
{
    void *data = (void *)(long)ctx->data;
    void *data_end = (void *)(long)ctx->data_end;

    struct ethhdr *eth = data;

    /* Safety check: Ethernet header must be inside packet bounds. */
    if ((void *)(eth + 1) > data_end)
        return XDP_PASS;

    /*
     * This project focuses on IPv4 packets.
     * Non-IPv4 packets are not filtered.
     */
    if (eth->h_proto != bpf_htons(ETH_P_IP))
        return XDP_PASS;

    struct iphdr *ip = (void *)(eth + 1);

    /* Safety check: IPv4 header must be inside packet bounds. */
    if ((void *)(ip + 1) > data_end)
        return XDP_PASS;

    /*
     * IPv4 header length is stored in 32-bit words.
     * Multiply by 4 to obtain bytes.
     */
    __u32 ip_header_len = ip->ihl * 4;

    if (ip_header_len < sizeof(*ip))
        return XDP_PASS;

    if ((void *)ip + ip_header_len > data_end)
        return XDP_PASS;

    void *l4_header = (void *)ip + ip_header_len;
    __u16 dst_port = 0;

    /*
     * Check TCP destination port.
     */
    if (ip->protocol == IPPROTO_TCP) {
        struct tcphdr *tcp = l4_header;

        if ((void *)(tcp + 1) > data_end)
            return XDP_PASS;

        dst_port = bpf_ntohs(tcp->dest);
    }

    /*
     * Check UDP destination port.
     */
    else if (ip->protocol == IPPROTO_UDP) {
        struct udphdr *udp = l4_header;

        if ((void *)(udp + 1) > data_end)
            return XDP_PASS;

        dst_port = bpf_ntohs(udp->dest);
    }

    /*
     * Other IPv4 protocols, such as ICMP, are allowed.
     */
    else {
        return XDP_PASS;
    }

    /*
     * E16 basic filtering rule:
     * Drop packets going TO the blocked destination port.
     */
    if (dst_port == BLOCKED_PORT) {
        bpf_printk("E16 firewall: drop IPv4 packet to destination port %u", dst_port);
        return XDP_DROP;
    }

    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
