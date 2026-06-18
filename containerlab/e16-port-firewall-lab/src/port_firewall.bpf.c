#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

#define ETH_P_IP        0x0800
#define ETH_P_IPV6      0x86DD

#define IPPROTO_ICMP    1
#define IPPROTO_TCP     6
#define IPPROTO_UDP     17

#define STAT_TOTAL      0
#define STAT_IPV4       1
#define STAT_IPV6       2
#define STAT_TCP        3
#define STAT_UDP        4
#define STAT_ICMP       5
#define STAT_OTHER_L4   6
#define STAT_DROPPED    7
#define STAT_PASSED     8
#define STAT_MAX        9

/*
 * Runtime firewall configuration map.
 * Key: destination port in host byte order.
 * Value: dummy flag. If the key exists, the port is blocked.
 */

struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 256);
    __type(key, __u32);
    __type(value, __u8);
} blocked_ports SEC(".maps");





/*
 * Packet classification counters.
 * Each index represents one class, such as IPv4, TCP, ICMP, dropped, or passed.
 */

struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, STAT_MAX);
    __type(key, __u32);
    __type(value, __u64);
} packet_stats SEC(".maps");




/*
 * Increment one packet counter.
 * The key selects which counter to update inside packet_stats.
 */

static __always_inline void bump_stat(__u32 key)
{
    __u64 *value;

    value = bpf_map_lookup_elem(&packet_stats, &key);
    if (value)
        __sync_fetch_and_add(value, 1);
}





/*
 * Pass the packet and update the passed-packet counter.
 */

static __always_inline int pass_packet(void)
{
    bump_stat(STAT_PASSED);
    return XDP_PASS;
}




/*
 * Drop the packet and update the dropped-packet counter.
 */

static __always_inline int drop_packet(void)
{
    bump_stat(STAT_DROPPED);
    return XDP_DROP;
}

SEC("xdp")
int xdp_port_firewall(struct xdp_md *ctx)
{
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;

    struct ethhdr *eth;
    struct iphdr *ip;
    __u16 h_proto;
    __u8 protocol;
    void *l4_header;
    __u32 ip_header_len;
    __u32 key;
    __u16 dst_port = 0;
    __u8 *blocked;

    bump_stat(STAT_TOTAL);


    /*
     * Start parsing from the Ethernet header.
     * Every XDP packet begins at ctx->data and must be checked against data_end.
    */
    eth = data;
    if ((void *)(eth + 1) > data_end)
        return pass_packet();

    h_proto = bpf_ntohs(eth->h_proto);

    if (h_proto == ETH_P_IPV6) {
        bump_stat(STAT_IPV6);
        return pass_packet();
    }

    if (h_proto != ETH_P_IP)
        return pass_packet();


    /*
     * The firewall applies port filtering only to IPv4 TCP/UDP packets.
     * IPv6 is counted and passed, while IPv4 continues to L4 parsing.
    */

    bump_stat(STAT_IPV4);

    ip = (void *)(eth + 1);
    if ((void *)(ip + 1) > data_end)
        return pass_packet();

    ip_header_len = ip->ihl * 4;

    if (ip_header_len < sizeof(*ip))
        return pass_packet();

    if ((void *)ip + ip_header_len > data_end)
        return pass_packet();

    protocol = ip->protocol;
    l4_header = (void *)ip + ip_header_len;


    /*
    * Classify the IPv4 payload.
    * TCP and UDP packets have destination ports, so they can be filtered.
    * ICMP has no port number, so it is only counted and passed.
    */
    if (protocol == IPPROTO_TCP) {
        struct tcphdr *tcp = l4_header;

        bump_stat(STAT_TCP);

        if ((void *)(tcp + 1) > data_end)
            return pass_packet();

        dst_port = bpf_ntohs(tcp->dest);

    } else if (protocol == IPPROTO_UDP) {
        struct udphdr *udp = l4_header;

        bump_stat(STAT_UDP);

        if ((void *)(udp + 1) > data_end)
            return pass_packet();

        dst_port = bpf_ntohs(udp->dest);

    } else if (protocol == IPPROTO_ICMP) {
        bump_stat(STAT_ICMP);
        return pass_packet();

    } else {
        bump_stat(STAT_OTHER_L4);
        return pass_packet();
    }



    /*
    * Firewall decision:
    * if the destination port exists in blocked_ports, drop the packet.
    * Otherwise, allow it to pass.
    */
    key = dst_port;
    blocked = bpf_map_lookup_elem(&blocked_ports, &key);

    if (blocked)
        return drop_packet();

    return pass_packet();
}

char _license[] SEC("license") = "GPL";
