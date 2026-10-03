#!/bin/bash
exec > /var/log/start-network.log 2>&1
set -e

IP_ADDR="${IP_ADDR:-10.21.75.130}"
PREFIX="${PREFIX:-28}"
GATEWAY="${GATEWAY:-10.21.75.129}"

echo ">> Esperando a que eth0 exista..."
for i in $(seq 1 15); do
  ip link show eth0 >/dev/null 2>&1 && break
  sleep 1
done

echo ">> WEB-Server: configurando eth0 con ${IP_ADDR}/${PREFIX}, gateway ${GATEWAY}"
ip addr flush dev eth0
ip addr add ${IP_ADDR}/${PREFIX} dev eth0
ip link set eth0 up
ip route replace default via ${GATEWAY}

service apache2 start
echo ">> WEB-Server listo. Apuntando a DB_IP=${DB_IP}"
tail -F /var/log/apache2/access.log
