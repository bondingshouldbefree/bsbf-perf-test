#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2025-2026 Chester A. Unal <chester.a.unal@arinc9.com>

if [ -n "$1" ] && [ "$1" != "--no-tcp-in-udp" ]; then
	echo "Usage: $0 [--no-tcp-in-udp]"
	exit 1
fi

MODE="$1"
PROGRAMME=/usr/lib/bpf/tcp_in_udp_tc.o

# Create namespaces.
ip netns add client
ip netns add middle
ip netns add server

# Create veth pairs: client<->middle (x2) and middle<->server (x1).
ip netns exec client ip link add veth0 type veth peer name veth0 netns middle
ip netns exec client ip link add veth1 type veth peer name veth1 netns middle
ip netns exec middle ip link add veth2 type veth peer name veth0 netns server

# Assign addresses — each link gets its own /24 subnet.
ip netns exec client ip a add 10.0.0.2/24 dev veth0
ip netns exec client ip a add 10.0.1.2/24 dev veth1
ip netns exec middle ip a add 10.0.0.1/24 dev veth0
ip netns exec middle ip a add 10.0.1.1/24 dev veth1
ip netns exec middle ip a add 10.0.2.1/24 dev veth2
ip netns exec server ip a add 10.0.2.2/24 dev veth0

# Bring all interfaces up.
ip netns exec client ip l set up veth0
ip netns exec client ip l set up veth1
ip netns exec middle ip l set up veth0
ip netns exec middle ip l set up veth1
ip netns exec middle ip l set up veth2
ip netns exec server ip l set up veth0

# Enable forwarding on the middle namespace.
ip netns exec middle sysctl -q net.ipv4.ip_forward=1

# Configure routing.
ip netns exec client ip route add default via 10.0.0.1 metric 1
ip netns exec client ip route add default via 10.0.1.1 metric 2
ip netns exec server ip route add default via 10.0.2.1

# MPTCP endpoints.
ip netns exec client ip mptcp endpoint add 10.0.0.2 subflow dev veth0
ip netns exec client ip mptcp endpoint add 10.0.1.2 subflow dev veth1

if [ "$MODE" != "--no-tcp-in-udp" ]; then
	# Load TCP-in-UDP for client.
	ip netns exec client ethtool -K veth0 gro off 2>/dev/null
	ip netns exec client ip link set veth0 gso_max_segs 0
	ip netns exec client ethtool -K veth1 gro off 2>/dev/null
	ip netns exec client ip link set veth1 gso_max_segs 0

	ip netns exec client tc qdisc del dev veth0 clsact 2>/dev/null
	ip netns exec client tc qdisc replace dev veth0 clsact
	ip netns exec client tc filter add dev veth0 egress bpf object-file "$PROGRAMME" section tc action csum udp
	ip netns exec client tc filter add dev veth0 ingress bpf object-file "$PROGRAMME" section tc direct-action

	ip netns exec client tc qdisc del dev veth1 clsact 2>/dev/null
	ip netns exec client tc qdisc replace dev veth1 clsact
	ip netns exec client tc filter add dev veth1 egress bpf object-file "$PROGRAMME" section tc action csum udp
	ip netns exec client tc filter add dev veth1 ingress bpf object-file "$PROGRAMME" section tc direct-action

	# Load TCP-in-UDP for server.
	ip netns exec server ethtool -K veth0 gro off 2>/dev/null
	ip netns exec server ip link set veth0 gso_max_segs 0

	ip netns exec server tc qdisc del dev veth0 clsact 2>/dev/null
	ip netns exec server tc qdisc replace dev veth0 clsact
	ip netns exec server tc filter add dev veth0 egress bpf object-file "$PROGRAMME" section tc action csum udp
	ip netns exec server tc filter add dev veth0 ingress bpf object-file "$PROGRAMME" section tc direct-action
fi

# Add the netem queuing discipline as root.
# Configure client download.
ip netns exec middle tc qdisc add dev veth0 root netem rate 500mbit delay 100ms
ip netns exec middle tc qdisc add dev veth1 root netem rate 75mbit delay 10ms 10ms
# Configure client upload.
ip netns exec client tc qdisc add dev veth0 root netem rate 50mbit delay 100ms
ip netns exec client tc qdisc add dev veth1 root netem rate 25mbit delay 10ms 10ms

cleanup() {
	kill $IPERF3_SERVER_PID
	ip netns del client
	ip netns del middle
	ip netns del server
}
trap cleanup EXIT
# Exit on interrupt to call the EXIT trap.
trap 'exit 1' INT

# Run iperf3 server on server and start an upload test to server.
ip netns exec server mptcpize run iperf3 -s >/dev/null &
IPERF3_SERVER_PID=$!
ip netns exec client mptcpize run iperf3 -c 10.0.2.2 -P $(nproc) -Z -R >/dev/null &
ip netns exec client ./bsbf-netspeed 0.5 veth0 veth1
