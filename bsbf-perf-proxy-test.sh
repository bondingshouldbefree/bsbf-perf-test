#!/bin/sh
# This script sets up a client and server network namespaces, runs a proxy
# programme server and client to proxy iperf3 traffic, and runs an iperf3 server
# and client with or without TCP-in-UDP conversion.
# Author: Chester A. Unal <chester.a.unal@arinc9.com>

if [ $# -ne 2 ]; then
	echo "Usage: $0 <fw-u32|fw-flower|u32-u32|u32-flower|no-matching|disable-gso-gro|default> <sing-box-tun|sing-box-tproxy|v2ray-tproxy|xray-tun|xray-tproxy>"
	echo "tc filter egress-ingress: fw-u32|fw-flower|u32-u32|u32-flower"
	exit 1
fi

MODE="$1"
PROXY_PROGRAMME="$2"
PROGRAMME=/usr/local/share/tcp-in-udp/tcp_in_udp_tc.o
BASE_MARK=0x200
MARK_MASK=0xfffffe00
BASE_PORT=0x8000
PORT_MASK=0xfe00

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

# Set up lo interface on both sides for sing-box and v2ray to work.
ip netns exec client ip l set up lo
ip netns exec server ip l set up lo

# Load TCP-in-UDP for client.
if [ "$MODE" = "fw-u32" ] || [ "$MODE" = "fw-flower" ] || [ "$MODE" = "u32-u32" ] || [ "$MODE" = "u32-flower" ] || [ "$MODE" = "no-matching" ] || [ "$MODE" = "disable-gso-gro" ]; then
ip netns exec client ethtool -K veth0 gro off 2>/dev/null
ip netns exec client ip link set veth0 gso_max_segs 0
fi

if [ "$MODE" = "no-matching" ]; then
ip netns exec client tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec client tc qdisc replace dev veth0 clsact
ip netns exec client tc filter add dev veth0 egress bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec client tc filter add dev veth0 ingress bpf object-file "$PROGRAMME" section tc direct-action
elif [ "$MODE" = "u32-flower" ]; then
ip netns exec client tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec client tc qdisc replace dev veth0 clsact
ip netns exec client tc filter add dev veth0 egress u32 match mark 2 0xffff action goto chain 1
ip netns exec client tc filter add dev veth0 ingress protocol ip flower ip_proto udp src_port 32768 action goto chain 1
ip netns exec client tc filter add dev veth0 egress chain 1 bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec client tc filter add dev veth0 ingress chain 1 bpf object-file "$PROGRAMME" section tc direct-action
elif [ "$MODE" = "u32-u32" ]; then
ip netns exec client tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec client tc qdisc replace dev veth0 clsact
ip netns exec client tc filter add dev veth0 egress u32 match mark 2 0xffff action goto chain 1
ip netns exec client tc filter add dev veth0 ingress u32 match ip sport 32768 0xffff action goto chain 1
ip netns exec client tc filter add dev veth0 egress chain 1 bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec client tc filter add dev veth0 ingress chain 1 bpf object-file "$PROGRAMME" section tc direct-action
elif [ "$MODE" = "fw-flower" ]; then
ip netns exec client tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec client tc qdisc replace dev veth0 clsact
ip netns exec client tc filter add dev veth0 egress handle 2 fw action goto chain 1
ip netns exec client tc filter add dev veth0 ingress protocol ip flower ip_proto udp src_port 32768 action goto chain 1
ip netns exec client tc filter add dev veth0 egress chain 1 bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec client tc filter add dev veth0 ingress chain 1 bpf object-file "$PROGRAMME" section tc direct-action
elif [ "$MODE" = "fw-u32" ]; then
ip netns exec client tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec client tc qdisc replace dev veth0 clsact
ip netns exec client tc filter add dev veth0 egress handle 2 fw action goto chain 1
ip netns exec client tc filter add dev veth0 ingress u32 match ip sport 32768 0xffff action goto chain 1
ip netns exec client tc filter add dev veth0 egress chain 1 bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec client tc filter add dev veth0 ingress chain 1 bpf object-file "$PROGRAMME" section tc direct-action
fi

# Load TCP-in-UDP for server.
if [ "$MODE" = "fw-u32" ] || [ "$MODE" = "fw-flower" ] || [ "$MODE" = "u32-u32" ] || [ "$MODE" = "u32-flower" ] || [ "$MODE" = "no-matching" ] || [ "$MODE" = "disable-gso-gro" ]; then
ip netns exec server ethtool -K veth0 gro off 2>/dev/null
ip netns exec server ip link set veth0 gso_max_segs 0
fi

if [ "$MODE" = "no-matching" ]; then
ip netns exec server tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec server tc qdisc replace dev veth0 clsact
ip netns exec server tc filter add dev veth0 egress bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec server tc filter add dev veth0 ingress bpf object-file "$PROGRAMME" section tc direct-action
elif [ "$MODE" = "u32-flower" ]; then
ip netns exec server tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec server tc qdisc replace dev veth0 clsact
ip netns exec server tc filter add dev veth0 egress u32 match mark "$BASE_MARK" "$MARK_MASK" action goto chain 1
ip netns exec server tc filter add dev veth0 ingress protocol ip flower ip_proto udp dst_port 32768-33279 action goto chain 1
ip netns exec server tc filter add dev veth0 egress chain 1 bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec server tc filter add dev veth0 ingress chain 1 bpf object-file "$PROGRAMME" section tc direct-action
elif [ "$MODE" = "u32-u32" ]; then
ip netns exec server tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec server tc qdisc replace dev veth0 clsact
ip netns exec server tc filter add dev veth0 egress u32 match mark "$BASE_MARK" "$MARK_MASK" action goto chain 1
ip netns exec server tc filter add dev veth0 ingress u32 match ip dport "$BASE_PORT" "$PORT_MASK" action goto chain 1
ip netns exec server tc filter add dev veth0 egress chain 1 bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec server tc filter add dev veth0 ingress chain 1 bpf object-file "$PROGRAMME" section tc direct-action
elif [ "$MODE" = "fw-flower" ]; then
ip netns exec server tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec server tc qdisc replace dev veth0 clsact
ip netns exec server tc filter add dev veth0 egress handle "$BASE_MARK"/"$MARK_MASK" fw action goto chain 1
ip netns exec server tc filter add dev veth0 ingress protocol ip flower ip_proto udp dst_port 32768-33279 action goto chain 1
ip netns exec server tc filter add dev veth0 egress chain 1 bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec server tc filter add dev veth0 ingress chain 1 bpf object-file "$PROGRAMME" section tc direct-action
elif [ "$MODE" = "fw-u32" ]; then
ip netns exec server tc qdisc del dev veth0 clsact 2>/dev/null
ip netns exec server tc qdisc replace dev veth0 clsact
ip netns exec server tc filter add dev veth0 egress handle "$BASE_MARK"/"$MARK_MASK" fw action goto chain 1
ip netns exec server tc filter add dev veth0 ingress u32 match ip dport "$BASE_PORT" "$PORT_MASK" action goto chain 1
ip netns exec server tc filter add dev veth0 egress chain 1 bpf object-file "$PROGRAMME" section tc action csum udp
ip netns exec server tc filter add dev veth0 ingress chain 1 bpf object-file "$PROGRAMME" section tc direct-action
fi

# Run the proxy programme on the server and client.
if [ "$PROXY_PROGRAMME" = "sing-box-tun" ] || [ "$PROXY_PROGRAMME" = "sing-box-tproxy" ]; then
ip netns exec server sing-box run -c resources/sing-box-server.json &
elif [ "$PROXY_PROGRAMME" = "v2ray-tproxy" ]; then
ip netns exec server v2ray run -c resources/v2ray-server.json &
elif [ "$PROXY_PROGRAMME" = "xray-tun" ] || [ "$PROXY_PROGRAMME" = "xray-tproxy" ]; then
ip netns exec server xray run -c resources/xray-server.json &
fi
PROXY_SERVER_PID=$!

if [ "$PROXY_PROGRAMME" = "sing-box-tun" ]; then
ip netns exec client sing-box run -c resources/sing-box-client-tun.json &
elif [ "$PROXY_PROGRAMME" = "sing-box-tproxy" ]; then
ip netns exec client sing-box run -c resources/sing-box-client-tproxy.json &
elif [ "$PROXY_PROGRAMME" = "v2ray-tproxy" ]; then
ip netns exec client v2ray run -c resources/v2ray-client-tproxy.json &
elif [ "$PROXY_PROGRAMME" = "xray-tun" ]; then
ip netns exec client xray run -c resources/xray-client-tun.json &
sleep 1
ip netns exec client ip a add 172.18.0.1 dev tun0
elif [ "$PROXY_PROGRAMME" = "xray-tproxy" ]; then
ip netns exec client xray run -c resources/xray-client-tproxy.json &
fi
PROXY_CLIENT_PID=$!

# Load the nftables rules and configure policy routing for tproxy.
if [ "$PROXY_PROGRAMME" = "sing-box-tproxy" ] || [ "$PROXY_PROGRAMME" = "v2ray-tproxy" ] || [ "$PROXY_PROGRAMME" = "xray-tproxy" ] || [ "$PROXY_PROGRAMME" = "xray-tun" ]; then
ip netns exec client nft -f resources/bsbf-perf-proxy-test.nft
ip netns exec client ip rule add fwmark 1 table 100 priority 0
ip netns exec client ip route add local default dev lo table 100
fi

# Run iperf3 server on server and start an upload test to server.
ip netns exec server iperf3 -s -D
IPERF3_SERVER_PID=$!
sleep 1
if [ "$PROXY_PROGRAMME" = "sing-box-tproxy" ] || [ "$PROXY_PROGRAMME" = "v2ray-tproxy" ] || [ "$PROXY_PROGRAMME" = "xray-tproxy" ]; then
ip netns exec client iperf3 -c 10.0.0.1 -P $(nproc) -Z
elif [ "$PROXY_PROGRAMME" = "sing-box-tun" ]  || [ "$PROXY_PROGRAMME" = "xray-tun" ]; then
ip netns exec client iperf3 -c 10.0.0.1 -P $(nproc) -Z --bind-dev tun0
fi

# Clean up.
kill $IPERF3_SERVER_PID
kill $PROXY_CLIENT_PID
kill $PROXY_SERVER_PID
ip netns del client
ip netns del server
