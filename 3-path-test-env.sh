#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2025-2026 Chester A. Unal <chester.a.unal@arinc9.com>

# Create namespaces.
ip netns add middle
ip netns add server

# Create veth pairs: client<->middle (x3) and middle<->server (x1).
ip link add veth0 type veth peer name veth0 netns middle
ip link add veth1 type veth peer name veth1 netns middle
ip link add veth2 type veth peer name veth2 netns middle
ip netns exec middle ip link add veth3 type veth peer name veth0 netns server

# Assign addresses — each link gets its own /24 subnet.
ip a add 10.0.1.1/24 dev veth0
ip a add 10.0.2.1/24 dev veth1
ip a add 10.0.3.1/24 dev veth2

ip netns exec middle ip a add 10.0.1.2/24 dev veth0
ip netns exec middle ip a add 10.0.2.2/24 dev veth1
ip netns exec middle ip a add 10.0.3.2/24 dev veth2
ip netns exec middle ip a add 10.0.0.2/24 dev veth3

ip netns exec server ip a add 10.0.0.1/24 dev veth0

# Bring all interfaces up.
ip l set up veth0
ip l set up veth1
ip l set up veth2
ip netns exec middle ip l set up veth0
ip netns exec middle ip l set up veth1
ip netns exec middle ip l set up veth2
ip netns exec middle ip l set up veth3
ip netns exec server ip l set up veth0

# Enable forwarding on the middle namespace.
ip netns exec middle sysctl -q net.ipv4.ip_forward=1

# Configure routing.
ip r add 10.0.0.1 via 10.0.1.2 metric 1
ip r add 10.0.0.1 via 10.0.2.2 metric 2
ip r add 10.0.0.1 via 10.0.3.2 metric 3
ip netns exec server ip r add default via 10.0.0.2

# Add MPTCP endpoints.
sudo systemctl stop bsbf-mptcp.service xray@bsbf-bonding.service
ip mp e f
ip mp e add 10.0.1.1 subflow dev veth0
ip mp e add 10.0.2.1 subflow dev veth1
ip mp e add 10.0.3.1 subflow dev veth2

# Set subflow limit to maximum on client and server. This is necessary to be
# able to re-establish a primary flow as a subflow.
ip mp l set subflows 8
ip netns exec server ip mp l set subflows 8

# Add the netem queuing discipline as root.
# Configure client download.
ip netns exec middle tc qdisc add dev veth0 root netem rate 100mbit delay 5ms
ip netns exec middle tc qdisc add dev veth1 root netem rate 100mbit delay 5ms
ip netns exec middle tc qdisc add dev veth2 root netem rate 100mbit delay 5ms

# Add the IFB interface and set it up.
ip netns exec middle ip link add ifb_veth0 type ifb
ip netns exec middle ip link add ifb_veth1 type ifb
ip netns exec middle ip link add ifb_veth2 type ifb
ip netns exec middle ip link set dev ifb_veth0 up
ip netns exec middle ip link set dev ifb_veth1 up
ip netns exec middle ip link set dev ifb_veth2 up

ip netns exec middle tc qdisc add dev veth0 ingress
ip netns exec middle tc qdisc add dev veth1 ingress
ip netns exec middle tc qdisc add dev veth2 ingress
ip netns exec middle tc filter add dev veth0 parent ffff: protocol all pref 10 \
	u32 match u32 0 0 action mirred egress redirect dev ifb_veth0
ip netns exec middle tc filter add dev veth1 parent ffff: protocol all pref 10 \
	u32 match u32 0 0 action mirred egress redirect dev ifb_veth1
ip netns exec middle tc filter add dev veth2 parent ffff: protocol all pref 10 \
	u32 match u32 0 0 action mirred egress redirect dev ifb_veth2

ip netns exec middle tc qdisc add dev ifb_veth0 root netem rate 100mbit delay 5ms
ip netns exec middle tc qdisc add dev ifb_veth1 root netem rate 100mbit delay 5ms
ip netns exec middle tc qdisc add dev ifb_veth2 root netem rate 100mbit delay 5ms

# Add clsact to prepare for what bsbf-rate-limiting expects.
tc qdisc add dev veth0 clsact
tc qdisc add dev veth1 clsact
tc qdisc add dev veth2 clsact
tc filter add dev veth0 ingress matchall action goto chain 1
tc filter add dev veth1 ingress matchall action goto chain 1
tc filter add dev veth2 ingress matchall action goto chain 1

# Run iperf3 server on server and start an upload test to server.
ip netns exec server mptcpize run iperf3 -s >/dev/null &
IPERF3_PID=$!

cleanup() {
	kill "$IPERF3_PID"
	ip netns del middle
	ip netns del server
	ip mp e f
	exit
}
trap cleanup INT

while true; do
	sleep 0.1
	mptcpize run iperf3 -c 10.0.0.1 -Z -R >/dev/null
	sleep 0.1
	mptcpize run iperf3 -c 10.0.0.1 -Z >/dev/null
done
