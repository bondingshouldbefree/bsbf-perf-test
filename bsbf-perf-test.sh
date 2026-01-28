#!/bin/sh
# This script sets up a client and server network namespaces, and runs an iperf3
# server and client with or without TCP-in-UDP conversion.
# Author: Chester A. Unal <chester.a.unal@arinc9.com>

if [ $# -ne 1 ]; then
	echo "Usage: $0 <u32|ranged-flower|flower|no-matching|disable-gso-gro|default>"
	exit 1
fi

MODE="$1"
PROGRAMME=/usr/local/share/tcp-in-udp/tcp_in_udp_tc.o

# Add client and server network namespaces and create interfaces that connect to
# each other.
ip netns add client
ip netns add server
ip netns exec client ip link add veth0 type veth peer name veth0 netns server

# Add an IP address to both interfaces and set them up.
ip netns exec client ip a add 10.0.0.2/24 dev veth0
ip netns exec server ip a add 10.0.0.1/24 dev veth0
ip netns exec client ip l set up veth0
ip netns exec server ip l set up veth0

# Load TCP-in-UDP for client.
if [ "$MODE" = "u32" ] || [ "$MODE" = "ranged-flower" ] || [ "$MODE" = "flower" ] || [ "$MODE" = "no-matching" ] || [ "$MODE" = "disable-gso-gro" ]; then
ip netns exec client ethtool -K veth0 gro off 2>/dev/null
ip netns exec client ip link set veth0 gso_max_segs 0
fi

if [ "$MODE" = "no-matching" ]; then
ip netns exec client tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec client tc qdisc replace dev veth0 clsact
ip netns exec client tc filter add dev veth0 egress bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec client tc filter add dev veth0 ingress bpf object-file "$PROGRAMME" section tc direct-action
elif [ "$MODE" = "flower" ]; then
ip netns exec client tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec client tc qdisc replace dev veth0 clsact
ip netns exec client tc filter add dev veth0 egress protocol ip flower ip_proto tcp dst_port 5201 action goto chain 1
ip netns exec client tc filter add dev veth0 ingress protocol ip flower ip_proto udp src_port 5201 action goto chain 1
ip netns exec client tc filter add dev veth0 egress chain 1 bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec client tc filter add dev veth0 ingress chain 1 bpf object-file "$PROGRAMME" section tc direct-action
elif [ "$MODE" = "ranged-flower" ]; then
ip netns exec client tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec client tc qdisc replace dev veth0 clsact
ip netns exec client tc filter add dev veth0 egress protocol ip flower ip_proto tcp dst_port 5201-5203 action goto chain 1
ip netns exec client tc filter add dev veth0 ingress protocol ip flower ip_proto udp src_port 5201-5203 action goto chain 1
ip netns exec client tc filter add dev veth0 egress chain 1 bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec client tc filter add dev veth0 ingress chain 1 bpf object-file "$PROGRAMME" section tc direct-action
elif [ "$MODE" = "u32" ]; then
ip netns exec client tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec client tc qdisc replace dev veth0 clsact
ip netns exec client tc filter add dev veth0 egress u32 match ip dport 5201 0xffff action goto chain 1
ip netns exec client tc filter add dev veth0 ingress u32 match ip sport 5201 0xffff action goto chain 1
ip netns exec client tc filter add dev veth0 egress chain 1 bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec client tc filter add dev veth0 ingress chain 1 bpf object-file "$PROGRAMME" section tc direct-action
fi

# Load TCP-in-UDP for server.
if [ "$MODE" = "u32" ] || [ "$MODE" = "ranged-flower" ] || [ "$MODE" = "flower" ] || [ "$MODE" = "no-matching" ] || [ "$MODE" = "disable-gso-gro" ]; then
ip netns exec server ethtool -K veth0 gro off 2>/dev/null
ip netns exec server ip link set veth0 gso_max_segs 0
fi

if [ "$MODE" = "no-matching" ]; then
ip netns exec server tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec server tc qdisc replace dev veth0 clsact
ip netns exec server tc filter add dev veth0 egress bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec server tc filter add dev veth0 ingress bpf object-file "$PROGRAMME" section tc direct-action
elif [ "$MODE" = "flower" ]; then
ip netns exec client tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec client tc qdisc replace dev veth0 clsact
ip netns exec client tc filter add dev veth0 egress protocol ip flower ip_proto tcp src_port 5201 action goto chain 1
ip netns exec client tc filter add dev veth0 ingress protocol ip flower ip_proto udp dst_port 5201 action goto chain 1
ip netns exec client tc filter add dev veth0 egress chain 1 bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec client tc filter add dev veth0 ingress chain 1 bpf object-file "$PROGRAMME" section tc direct-action
elif [ "$MODE" = "ranged-flower" ]; then
ip netns exec client tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec client tc qdisc replace dev veth0 clsact
ip netns exec client tc filter add dev veth0 egress protocol ip flower ip_proto tcp src_port 5201-5203 action goto chain 1
ip netns exec client tc filter add dev veth0 ingress protocol ip flower ip_proto udp dst_port 5201-5203 action goto chain 1
ip netns exec client tc filter add dev veth0 egress chain 1 bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec client tc filter add dev veth0 ingress chain 1 bpf object-file "$PROGRAMME" section tc direct-action
elif [ "$MODE" = "u32" ]; then
ip netns exec server tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec server tc qdisc replace dev veth0 clsact
ip netns exec server tc filter add dev veth0 egress u32 match ip sport 5201 0xffff action goto chain 1
ip netns exec server tc filter add dev veth0 ingress u32 match ip dport 5201 0xffff action goto chain 1
ip netns exec server tc filter add dev veth0 egress chain 1 bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec server tc filter add dev veth0 ingress chain 1 bpf object-file "$PROGRAMME" section tc direct-action
fi

# Run iperf3 server on server and start an upload test to server.
ip netns exec server iperf3 -s -D
IPERF3_SERVER_PID=$!
ip netns exec client iperf3 -c 10.0.0.1 -P $(nproc) -Z

# Clean up.
kill $IPERF3_SERVER_PID
ip netns del client
ip netns del server
