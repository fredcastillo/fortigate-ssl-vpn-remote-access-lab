#!/bin/bash
# Todo lo que pase aqui queda guardado en el log; si el contenedor vuelve
# a morir, se puede leer con: docker exec <id> cat /var/log/start-network.log
exec > /var/log/start-network.log 2>&1
set -e

IP_ADDR="${IP_ADDR:-10.21.75.146}"
PREFIX="${PREFIX:-28}"
GATEWAY="${GATEWAY:-10.21.75.145}"

echo ">> Esperando a que eth0 exista (GNS3 a veces conecta el cable con un pequeno retraso)..."
for i in $(seq 1 15); do
  ip link show eth0 >/dev/null 2>&1 && break
  sleep 1
done

echo ">> DB-Server: configurando eth0 con ${IP_ADDR}/${PREFIX}, gateway ${GATEWAY}"
ip addr flush dev eth0
ip addr add ${IP_ADDR}/${PREFIX} dev eth0
ip link set eth0 up
ip route replace default via ${GATEWAY}

# Limpieza defensiva de un pid/socket viejo si quedo alguno
rm -f /var/run/mysqld/mysqld.pid /var/run/mysqld/mysqld.sock

service mariadb start
echo ">> DB-Server listo."

# -F (mayuscula) reintenta si el archivo aun no existe, en vez de morir de una vez como -f
tail -F /var/log/mysql/error.log
