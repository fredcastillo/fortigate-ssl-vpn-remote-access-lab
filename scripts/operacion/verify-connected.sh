#!/usr/bin/env bash
set -Eeuo pipefail
# Ejecutar desde el host GNS3 VM. Todas las pruebas usan el nodo cliente.
LAB_CLIENT=$(docker ps -q --filter 'name=GNS3.CLIENTE-FORTICLIENT-1.ea145aa2-7392-4eb2-b990-4b81dd21a346')
test -n "$LAB_CLIENT"
test "$(printf '%s\n' "$LAB_CLIENT" | wc -l)" = 1
docker exec "$LAB_CLIENT" lab-vpn status
docker exec -u vpnuser "$LAB_CLIENT" ssh -o BatchMode=yes -o ConnectTimeout=5 labssh@10.21.75.130 'whoami; hostname; echo "$SSH_CONNECTION"'
docker exec "$LAB_CLIENT" traceroute -T -p 22 -n -q 1 -w 2 10.21.75.130
