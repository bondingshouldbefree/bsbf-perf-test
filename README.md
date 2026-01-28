Run as root.

Install the tcp-in-udp object before running the scripts.

```
sudo mkdir -p /usr/local/share/tcp-in-udp
sudo curl https://raw.githubusercontent.com/bondingshouldbefree/bsbf-resources/refs/heads/main/bsbf-tcp-in-udp/files/usr/local/share/tcp-in-udp/tcp_in_udp_tc_le.o -o /usr/local/share/tcp-in-udp/tcp_in_udp_tc.o
```

```
Usage: ./bsbf-perf-test.sh <u32|ranged-flower|flower|no-matching|
                            disable-gso-gro|default>

Usage: ./bsbf-perf-proxy-test.sh <fw-u32|fw-flower|u32-u32|u32-flower|
                                  no-matching|disable-gso-gro|default>
                                 <sing-box-tun|sing-box-tproxy|v2ray-tproxy|
                                  xray-tun|xray-tproxy>
tc filter egress-ingress: fw-u32|fw-flower|u32-u32|u32-flower
```

For running on OpenWrt, install these packages:

```
ethtool ip-full tc-full kmod-sched kmod-sched-flower kmod-sched-bpf kmod-nft-tproxy kmod-veth coreutils-nproc iperf3 sing-box-tiny v2ray-core
```

Results on a 12-thread amd64 CPU, clock speed of every thread at ~4370 MHz
whilst testing, all tests utilise 100% total CPU unless stated otherwise:

## bsbf-perf-test
```
u32:                    15.2 Gbits/sec
ranged-flower:          20.1 Gbits/sec
flower:                 19.0 Gbits/sec
no-matching:            15.7 Gbits/sec
disable-gso-gro:        22.0 Gbits/sec
default:                336 Gbits/sec
```

## bsbf-perf-proxy-test sing-box-tun
```
fw-u32:                 7.02 Gbits/sec
fw-flower:              6.83 Gbits/sec
u32-u32:                6.94 Gbits/sec
u32-flower:             6.71 Gbits/sec
no-matching:            6.92 Gbits/sec
disable-gso-gro:        8.38 Gbits/sec
default:                14.6 Gbits/sec (~45% total CPU utilisation)
```

## bsbf-perf-proxy-test sing-box-tproxy
```
fw-u32:                 6.69 Gbits/sec
fw-flower:              6.41 Gbits/sec
u32-u32:                6.65 Gbits/sec
u32-flower:             6.47 Gbits/sec
no-matching:            6.78 Gbits/sec
disable-gso-gro:        8.12 Gbits/sec
default:                27.7 Gbits/sec
```

## bsbf-perf-proxy-test v2ray-tproxy
```
fw-u32:                 3.03 Gbits/sec (~55% total CPU utilisation)
fw-flower:              2.73 Gbits/sec (~55% total CPU utilisation)
u32-u32:                2.93 Gbits/sec (~55% total CPU utilisation)
u32-flower:             2.72 Gbits/sec (~55% total CPU utilisation)
no-matching:            3.01 Gbits/sec (~55% total CPU utilisation)
disable-gso-gro:        3.88 Gbits/sec (~60% total CPU utilisation)
default:                7.40 Gbits/sec (~45% total CPU utilisation)
```

Results on a 4-thread mips32 CPU, clock speed of every thread at 880 MHz whilst
testing, all tests utilise 100% total CPU unless stated otherwise:

## bsbf-perf-test
```
u32:                    294 Mbits/sec
ranged-flower:          464 Mbits/sec
flower:                 472 Mbits/sec
no-matching:            241 Mbits/sec
disable-gso-gro:        510 Mbits/sec
default:                1.71 Gbits/sec
```

## bsbf-perf-proxy-test sing-box-tun
```
fw-u32:                 66.6 Mbits/sec
fw-flower:              64.2 Mbits/sec
u32-u32:                67.3 Mbits/sec
u32-flower:             62.7 Mbits/sec
no-matching:            68.9 Mbits/sec
disable-gso-gro:        89.8 Mbits/sec
default:                147 Mbits/sec (~90% total CPU utilisation)
```

## bsbf-perf-proxy-test sing-box-tproxy
```
fw-u32:                 77.1 Mbits/sec
fw-flower:              76.1 Mbits/sec
u32-u32:                80.5 Mbits/sec
u32-flower:             73.6 Mbits/sec
no-matching:            76.9 Mbits/sec
disable-gso-gro:        112 Mbits/sec
default:                280 Mbits/sec
```

Results on a 4-thread arm64 CPU, clock speed of every thread at 1500 MHz whilst
testing, all tests utilise 100% total CPU unless stated otherwise:

## bsbf-perf-test
```
u32:                    3.31 Gbits/sec
ranged-flower:          4.71 Gbits/sec
flower:                 4.76 Gbits/sec
no-matching:            3.41 Gbits/sec
disable-gso-gro:        5.09 Gbits/sec
default:                27.9 Gbits/sec
```

## bsbf-perf-proxy-test sing-box-tun
```
fw-u32:                 1.14 Gbits/sec
fw-flower:              1.08 Gbits/sec
u32-u32:                1.13 Gbits/sec
u32-flower:             1.10 Gbits/sec
no-matching:            1.19 Gbits/sec
disable-gso-gro:        1.54 Gbits/sec
default:                2.72 Gbits/sec (~90% total CPU utilisation)
```

## bsbf-perf-proxy-test sing-box-tproxy
```
fw-u32:                 1.05 Gbits/sec
fw-flower:              1.01 Gbits/sec
u32-u32:                1.05 Gbits/sec
u32-flower:             1.01 Gbits/sec
no-matching:            1.07 Gbits/sec
disable-gso-gro:        1.40 Gbits/sec
default:                5.02 Gbits/sec
```

## bsbf-perf-proxy-test v2ray-tproxy
```
fw-u32:                 277 Mbits/sec (~55% total CPU utilisation)
fw-flower:              257 Mbits/sec Gbits/sec (~55% total CPU utilisation)
u32-u32:                254 Mbits/sec (~55% total CPU utilisation)
u32-flower:             221 Mbits/sec (~55% total CPU utilisation)
no-matching:            281 Mbits/sec (~55% total CPU utilisation)
disable-gso-gro:        316 Mbits/sec (~60% total CPU utilisation)
default:                522 Mbits/sec (~60% total CPU utilisation)
```
