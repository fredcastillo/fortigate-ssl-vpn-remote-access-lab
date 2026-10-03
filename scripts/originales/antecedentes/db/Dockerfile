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
