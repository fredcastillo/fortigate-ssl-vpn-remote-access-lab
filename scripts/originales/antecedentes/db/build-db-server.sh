#!/bin/bash
# =============================================================
# build-db-server.sh
# Crea la imagen Docker del DB-Server (MariaDB).
# La IP se asigna en tiempo de arranque via variables de entorno
# (IP_ADDR, PREFIX, GATEWAY) - no queda fija en la imagen.
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
RUN service mariadb start && \
    mysql -e "CREATE DATABASE labdb; \
    CREATE TABLE labdb.users (id INT PRIMARY KEY, name VARCHAR(50)); \
    INSERT INTO labdb.users VALUES (1,'alice'),(2,'bob'); \
    CREATE USER 'webuser'@'10.21.75.130' IDENTIFIED BY '[REDACTED]'; \
    GRANT SELECT ON labdb.* TO 'webuser'@'10.21.75.130'; \
    FLUSH PRIVILEGES;" && \
    sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf

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
set -e

IP_ADDR="${IP_ADDR:-10.21.75.146}"
PREFIX="${PREFIX:-28}"
GATEWAY="${GATEWAY:-10.21.75.145}"

echo ">> DB-Server: configurando eth0 con ${IP_ADDR}/${PREFIX}, gateway ${GATEWAY}"

ip addr flush dev eth0
ip addr add ${IP_ADDR}/${PREFIX} dev eth0
ip link set eth0 up
ip route add default via ${GATEWAY}

service mariadb start
echo ">> DB-Server listo."
tail -f /var/log/mysql/error.log
EOF
chmod +x "$DB_DIR/start-network.sh"

echo "[3/3] Construyendo imagen db-server-lab ..."
docker build -t db-server-lab "$DB_DIR"

echo "Listo:"
docker images | grep db-server-lab
