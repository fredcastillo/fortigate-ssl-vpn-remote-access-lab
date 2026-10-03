#!/bin/bash
exec > /var/log/start-network.log 2>&1
set -e

IP_ADDR="${IP_ADDR:-10.21.75.110}"
PREFIX="${PREFIX:-25}"
GATEWAY="${GATEWAY:-10.21.75.1}"
DNS_SERVER="${DNS_SERVER:-8.8.8.8}"

echo ">> Esperando a que eth0 exista..."
for i in $(seq 1 15); do
  ip link show eth0 >/dev/null 2>&1 && break
  sleep 1
done

echo ">> Browser-PC: configurando eth0 con ${IP_ADDR}/${PREFIX}, gateway ${GATEWAY}"
ip addr flush dev eth0
ip addr add ${IP_ADDR}/${PREFIX} dev eth0
ip link set eth0 up
ip route replace default via ${GATEWAY}

echo ">> Configurando DNS (${DNS_SERVER}) de forma persistente"
echo "nameserver ${DNS_SERVER}" > /etc/resolv.conf

echo ">> Lanzando Firefox (GNS3 debe inyectar su propio Xvfb+x11vnc via consola VNC)"
exec firefox-esr --no-remote --new-instance
