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
