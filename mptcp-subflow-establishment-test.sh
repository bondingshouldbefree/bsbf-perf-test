#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2025-2026 Chester A. Unal <chester.a.unal@arinc9.com>

if [ "$1" = "veth0" ]; then
	# Unplug veth0.
	ip netns exec client ip a del 10.0.1.1/24 dev veth0
	ip netns exec client ip mp e del id 1
	sleep 3

	# Plug in veth0.
	ip netns exec client ip a add 10.0.1.1/24 dev veth0
	ip netns exec client ip r add default via 10.0.1.2 metric 1
	ip netns exec client ip mp e add 10.0.1.1 subflow dev veth0

	exit
fi

if [ -n "$1" ]; then
	# Unplug veth1.
	ip netns exec client ip a del 10.0.2.1/24 dev veth1
	ip netns exec client ip mp e del id 2
	sleep 1

	# Unplug veth2.
	ip netns exec client ip a del 10.0.3.1/24 dev veth2
	ip netns exec client ip mp e del id 3
	sleep 1

	# Swap veth1 and veth2 networks.
	ip netns exec middle ip a del 10.0.2.2/24 dev veth1
	ip netns exec middle ip a del 10.0.3.2/24 dev veth2
	ip netns exec middle ip a add 10.0.3.2/24 dev veth1
	ip netns exec middle ip a add 10.0.2.2/24 dev veth2
	sleep 1

	# Plug in veth1.
	ip netns exec client ip a add 10.0.3.1/24 dev veth1
	ip netns exec client ip r add default via 10.0.3.2 metric 2
	ip netns exec client ip mp e add 10.0.3.1 subflow dev veth1
	sleep 1

	# Plug in veth2.
	ip netns exec client ip a add 10.0.2.1/24 dev veth2
	ip netns exec client ip r add default via 10.0.2.2 metric 3
	ip netns exec client ip mp e add 10.0.2.1 subflow dev veth2
	sleep 1

	exit
fi

# Create namespaces.
ip netns add client
ip netns add middle
ip netns add server

# Create veth pairs: client<->middle (x3) and middle<->server (x1).
ip netns exec client ip link add veth0 type veth peer name veth0 netns middle
ip netns exec client ip link add veth1 type veth peer name veth1 netns middle
ip netns exec client ip link add veth2 type veth peer name veth2 netns middle
ip netns exec middle ip link add veth3 type veth peer name veth0 netns server

# Assign addresses — each link gets its own /24 subnet.
ip netns exec client ip a add 10.0.1.1/24 dev veth0
ip netns exec client ip a add 10.0.2.1/24 dev veth1
ip netns exec client ip a add 10.0.3.1/24 dev veth2

ip netns exec middle ip a add 10.0.1.2/24 dev veth0
ip netns exec middle ip a add 10.0.2.2/24 dev veth1
ip netns exec middle ip a add 10.0.3.2/24 dev veth2
ip netns exec middle ip a add 10.0.0.2/24 dev veth3

ip netns exec server ip a add 10.0.0.1/24 dev veth0

# Bring all interfaces up.
ip netns exec client ip l set up veth0
ip netns exec client ip l set up veth1
ip netns exec client ip l set up veth2
ip netns exec middle ip l set up veth0
ip netns exec middle ip l set up veth1
ip netns exec middle ip l set up veth2
ip netns exec middle ip l set up veth3
ip netns exec server ip l set up veth0

# Set up lo interface on both sides for xray to work.
ip netns exec client ip l set up lo
ip netns exec middle ip l set up lo
ip netns exec server ip l set up lo

# Enable forwarding on the middle namespace.
ip netns exec middle sysctl -q net.ipv4.ip_forward=1

# Configure routing.
ip netns exec client ip r add default via 10.0.1.2 metric 1
ip netns exec client ip r add default via 10.0.2.2 metric 2
ip netns exec client ip r add default via 10.0.3.2 metric 3
ip netns exec server ip r add default via 10.0.0.2

# Add MPTCP endpoints.
ip netns exec client ip mp e add 10.0.1.1 subflow dev veth0
ip netns exec client ip mp e add 10.0.2.1 subflow dev veth1
ip netns exec client ip mp e add 10.0.3.1 subflow dev veth2

# Set subflow limit to maximum on client and server. This is necessary to be
# able to re-establish a primary flow as a subflow.
ip netns exec client ip mp l set subflows 8
ip netns exec server ip mp l set subflows 8

# Run nc on server.
ip netns exec server mptcpize run nc -l 5000 &
NC_PID=$!

# Start MPTCP monitor.
ip netns exec client ip mp m &
MPTCP_MONITOR_PID=$!

cleanup() {
	kill $PROXY_CLIENT_PID
	kill $PROXY_SERVER_PID
	kill $NC_PID
	kill $MPTCP_MONITOR_PID
	ip netns del client
	ip netns del middle
	ip netns del server
}
trap cleanup INT

# Send string using NC every second.
while true; do
	echo $index
	sleep 1
	index=$((index + 1))
done | ip netns exec client mptcpize run nc 10.0.0.1 5000
