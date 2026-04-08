#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Chester A. Unal <chester.a.unal@arinc9.com>

# Create namespaces.
ip netns add peer1
ip netns add switch
ip netns add peer2

# Create veth pairs: peer1 <-> switch <-> peer2.
ip netns exec peer1 ip link add veth0 type veth peer name veth0 netns switch
ip netns exec switch ip link add veth1 type veth peer name veth0 netns peer2

# Bring all interfaces up.
ip netns exec peer1 ip l set up veth0
ip netns exec switch ip l set up veth0
ip netns exec switch ip l set up veth1
ip netns exec peer2 ip l set up veth0

# Set up lo interface.
ip netns exec peer1 ip l set up lo
ip netns exec switch ip l set up lo
ip netns exec peer2 ip l set up lo

# Put interfaces on switch in a bridge.
ip netns exec switch ip l add br0 type bridge
ip netns exec switch ip l set veth0 master br0
ip netns exec switch ip l set veth1 master br0
ip netns exec switch ip l set up br0

# Run fips on peer2.
ip netns exec peer2 fips -c resources/fips-peer2.yaml &
FIPS_PID=$!

# Drop packet too big response on peer1.
ip netns exec peer1 nft add table inet filter
ip netns exec peer1 nft add chain inet filter input '{ type filter hook input priority 0 ; policy accept ; }'
ip netns exec peer1 nft add rule inet filter input icmpv6 type packet-too-big drop

cleanup() {
	kill $FIPS_PID
	ip netns del peer1
	ip netns del switch
	ip netns del peer2
}
trap cleanup INT

# Run fips on peer1.
ip netns exec peer1 fips -c resources/fips-peer1.yaml
