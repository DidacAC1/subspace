#!/usr/bin/env sh
set -o errexit
set -o nounset
set -o xtrace

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
Address = 10.11.12.1/24
PrivateKey = $(cat /opt/subspace/data/wireguard/server.private)
ListenPort = 57575
SaveConfig = true

WGSERVER
cat /opt/subspace/data/wireguard/peers/*.conf >>/opt/subspace/data/wireguard/server.conf

if ip link show server 2>/dev/null; then
  wg-quick down /opt/subspace/data/wireguard/server.conf
fi

wg-quick up /opt/subspace/data/wireguard/server.conf
