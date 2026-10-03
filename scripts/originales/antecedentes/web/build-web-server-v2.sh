#!/bin/bash
# =============================================================
# build-web-server.sh (v2 - misma proteccion defensiva que el DB, por consistencia)
# Crea la imagen Docker del WEB-Server (Apache + PHP + HTTPS).
#
# Direccionamiento (matricula 2175): 10.21.75.128/28
#   WEB-Server = 10.21.75.130   Gateway = 10.21.75.129
#
# Ejecutar DENTRO de la GNS3 VM (por SSH).
# Uso: bash build-web-server.sh
# =============================================================
set -e

WEB_DIR="$HOME/lab-images/web"
mkdir -p "$WEB_DIR"

echo "[1/3] Generando Dockerfile del WEB-Server ..."
cat > "$WEB_DIR/Dockerfile" <<'EOF'
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    apache2 php libapache2-mod-php php-mysqli \
    openssl iproute2 net-tools iputils-ping \
 && apt clean

# Certificado autofirmado para HTTPS (requerido para DPI/SSL inspection en FortiGate)
RUN mkdir -p /etc/ssl/lab && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/lab/web.key -out /etc/ssl/lab/web.crt \
    -subj "/C=DO/O=Lab/CN=web.lab.local"

RUN a2enmod ssl && \
    sed -i 's#/etc/ssl/certs/ssl-cert-snakeoil.pem#/etc/ssl/lab/web.crt#; s#/etc/ssl/private/ssl-cert-snakeoil.key#/etc/ssl/lab/web.key#' /etc/apache2/sites-available/default-ssl.conf && \
    a2ensite default-ssl

# Pagina vulnerable a proposito (SOLO laboratorio controlado) para probar el IPS/SQLi
RUN cat > /var/www/html/search.php <<'PHP'
<?php
$db_host = getenv('DB_IP') ?: '10.21.75.146';
$c = new mysqli($db_host,"webuser",'[REDACTED]',"labdb");
$id = $_GET['id'] ?? 1;
$r = $c->query("SELECT id,name FROM users WHERE id=$id");
while($row=$r->fetch_assoc()) echo $row['id']." - ".$row['name']."<br>";
PHP

# Archivo de prueba para el File Filter (.exe)
RUN cp /bin/ls /var/www/html/test.exe

# Valores por defecto: solo se usan si GNS3 no pasa variables de entorno
ENV IP_ADDR=10.21.75.130
ENV PREFIX=28
ENV GATEWAY=10.21.75.129
ENV DB_IP=10.21.75.146

COPY start-network.sh /start-network.sh
RUN chmod +x /start-network.sh
CMD ["/start-network.sh"]
EOF

echo "[2/3] Generando start-network.sh del WEB-Server ..."
cat > "$WEB_DIR/start-network.sh" <<'EOF'
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
EOF
chmod +x "$WEB_DIR/start-network.sh"

echo "[3/3] Construyendo imagen web-server-lab ..."
docker build -t web-server-lab "$WEB_DIR"

echo "Listo:"
docker images | grep web-server-lab
