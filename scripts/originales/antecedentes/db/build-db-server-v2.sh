#!/bin/bash
# =============================================================
# build-db-server.sh (v2 - corrige crash "Exited (1)" en el primer boot)
# Crea la imagen Docker del DB-Server (MariaDB).
#
# Direccionamiento (matricula 2175): 10.21.75.144/28
#   DB-Server = 10.21.75.146   Gateway = 10.21.75.145
#
# Ejecutar DENTRO de la GNS3 VM (por SSH).
# Uso: bash build-db-server.sh
# =============================================================
set -e

DB_DIR="$HOME/lab-images/db"
mkdir -p "$DB_DIR"

echo "[1/3] Generando Dockerfile del DB-Server ..."
cat > "$DB_DIR/Dockerfile" <<'EOF'
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y mariadb-server iproute2 net-tools iputils-ping && apt clean

# bind-address 0.0.0.0 porque al momento del build aun no existe la IP final (se asigna en runtime)
# webuser solo puede conectarse desde la IP del WEB-Server (10.21.75.130), no desde cualquier host
# IMPORTANTE: apagamos mariadb limpio (service ... stop) y borramos pid/socket antes de que
# Docker congele esta capa - si no, queda un pid fantasma que hace fallar el arranque real.
RUN service mariadb start && \
    mysql -e "CREATE DATABASE labdb; \
    CREATE TABLE labdb.users (id INT PRIMARY KEY, name VARCHAR(50)); \
    INSERT INTO labdb.users VALUES (1,'alice'),(2,'bob'); \
    CREATE USER 'webuser'@'10.21.75.130' IDENTIFIED BY '[REDACTED]'; \
    GRANT SELECT ON labdb.* TO 'webuser'@'10.21.75.130'; \
    FLUSH PRIVILEGES;" && \
    sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf && \
    service mariadb stop && \
    rm -f /var/run/mysqld/mysqld.pid /var/run/mysqld/mysqld.sock

# Valores por defecto: solo se usan si GNS3 no pasa variables de entorno
ENV IP_ADDR=10.21.75.146
ENV PREFIX=28
ENV GATEWAY=10.21.75.145

COPY start-network.sh /start-network.sh
RUN chmod +x /start-network.sh
CMD ["/start-network.sh"]
EOF

echo "[2/3] Generando start-network.sh del DB-Server ..."
cat > "$DB_DIR/start-network.sh" <<'EOF'
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
EOF
chmod +x "$DB_DIR/start-network.sh"

echo "[3/3] Construyendo imagen db-server-lab ..."
docker build -t db-server-lab "$DB_DIR"

echo "Listo:"
docker images | grep db-server-lab
