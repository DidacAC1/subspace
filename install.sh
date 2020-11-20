#!/usr/bin/env sh
set -o errexit
set -o nounset
set -o xtrace

# ipv4 - DNS Leak Protection
if ! /sbin/iptables -t nat --check OUTPUT -s 10.11.12.0/24 -p udp --dport 53 -j DNAT --to 10.11.12.1:53; then
  /sbin/iptables -t nat --append OUTPUT -s 10.11.12.0/24 -p udp --dport 53 -j DNAT --to 10.11.12.1:53
fi

if ! /sbin/iptables -t nat --check OUTPUT -s 10.11.12.0/24 -p tcp --dport 53 -j DNAT --to 10.11.12.1:53; then
  /sbin/iptables -t nat --append OUTPUT -s 10.11.12.0/24 -p tcp --dport 53 -j DNAT --to 10.11.12.1:53
fi

# ipv6 - DNS Leak Protection
if ! /sbin/ip6tables --wait -t nat --check OUTPUT -s fd00::10:97:0/64 -p udp --dport 53 -j DNAT --to fd00::10:97:1; then
  /sbin/ip6tables --wait -t nat --append OUTPUT -s fd00::10:97:0/64 -p udp --dport 53 -j DNAT --to fd00::10:97:1
fi

if ! /sbin/ip6tables --wait -t nat --check OUTPUT -s fd00::10:97:0/64 -p tcp --dport 53 -j DNAT --to fd00::10:97:1; then
  /sbin/ip6tables --wait -t nat --append OUTPUT -s fd00::10:97:0/64 -p tcp --dport 53 -j DNAT --to fd00::10:97:1
fi
#
# WireGuard (10.11.12.0/24)
#
if ! test -d /opt/subspace/data/wireguard; then
  mkdir /opt/subspace/data/wireguard
  cd /opt/subspace/data/wireguard

  mkdir clients
  touch clients/null.conf # So you can cat *.conf safely
  mkdir peers
  touch peers/null.conf # So you can cat *.conf safely

  # Generate public/private server keys.
  wg genkey | tee server.private | wg pubkey > server.public
fi

cat <<WGSERVER >/opt/subspace/data/wireguard/server.conf
[Interface]
PrivateKey = $(cat /opt/subspace/data/wireguard/server.private)
ListenPort = 57575

WGSERVER
cat /opt/subspace/data/wireguard/peers/*.conf >>/opt/subspace/data/wireguard/server.conf

if ip link show wg0 2>/dev/null; then
  ip link del wg0
fi
ip link add wg0 type wireguard
ip addr add 10.11.12.1/24 dev wg0
ip addr add fd00::10:97:1/64 dev wg0
wg setconf wg0 /opt/subspace/data/wireguard/server.conf
ip link set wg0 up

# dnsmasq service
if ! test -d /etc/service/dnsmasq; then
  cat <<DNSMASQ >/etc/dnsmasq.conf
    # Only listen on necessary addresses.
    listen-address=127.0.0.1,10.11.12.1,fd00::10:97:1

    # Never forward plain names (without a dot or domain part)
    domain-needed

    # Never forward addresses in the non-routed address spaces.
    bogus-priv
DNSMASQ

  mkdir -p /etc/service/dnsmasq
  cat <<RUNIT >/etc/service/dnsmasq/run
#!/bin/sh
exec /usr/sbin/dnsmasq --no-daemon
RUNIT
  chmod +x /etc/service/dnsmasq/run

  # dnsmasq service log
  mkdir -p /etc/service/dnsmasq/log/main
  cat <<RUNIT >/etc/service/dnsmasq/log/run
#!/bin/sh
exec svlogd -tt ./main
RUNIT
  chmod +x /etc/service/dnsmasq/log/run
fi