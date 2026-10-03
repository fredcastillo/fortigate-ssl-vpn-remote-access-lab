#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="forticlient-vpn-lab:7.0.9"
WORKDIR="$HOME/forticlient-vpn-final"

echo
echo "============================================================"
echo " FORTICLIENT VPN-ONLY 7.0.9 - GNS3 LAB"
echo "============================================================"
echo

# ------------------------------------------------------------
# 0. Debemos estar en la GNS3 VM, NO dentro de un contenedor
# ------------------------------------------------------------

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker no existe en este shell."
    echo
    echo "Debes ejecutar este script desde:"
    echo "    gns3@gns3vm:~$"
    echo
    echo "NO desde:"
    echo "    root@CLIENTE-FORTICLIENT:/#"
    exit 1
fi

echo "[OK] Docker encontrado:"
docker --version
echo

# ------------------------------------------------------------
# 1. Buscar paquete VPN-only oficial
# ------------------------------------------------------------

DEB="$(find \
    "$HOME" \
    "$HOME/Downloads" \
    /tmp \
    -maxdepth 3 \
    -type f \
    \( -name 'forticlient_vpn_server_7.0.9*_amd64.deb' \
       -o -name 'forticlient_vpn_server_7.0.9*.deb' \) \
    2>/dev/null | head -n1 || true)"

if [ -z "$DEB" ]; then
    echo "============================================================"
    echo " FALTA EL PAQUETE OFICIAL VPN-ONLY"
    echo "============================================================"
    echo
    echo "No encontré:"
    echo
    echo " forticlient_vpn_server_7.0.9.xxxx_amd64.deb"
    echo
    echo "Coloca el .deb oficial de Fortinet en:"
    echo
    echo " $HOME/"
    echo
    echo "y vuelve a ejecutar:"
    echo
    echo " bash ~/build-forticlient-vpn-final.sh"
    echo
    exit 2
fi

echo "[OK] Paquete encontrado:"
echo "     $DEB"
echo

# ------------------------------------------------------------
# 2. Preparar build limpio
# ------------------------------------------------------------

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

cp "$DEB" "$WORKDIR/forticlient-vpn.deb"

cat > "$WORKDIR/start.sh" <<'EOF'
#!/bin/bash

set -u

echo
echo "============================================================"
echo " CLIENTE FORTICLIENT VPN - LAB"
echo "============================================================"

# TUN requerido para SSL-VPN
mkdir -p /dev/net

if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200 2>/dev/null || true
fi

chmod 666 /dev/net/tun 2>/dev/null || true

# PPP por compatibilidad
if [ ! -c /dev/ppp ]; then
    mknod /dev/ppp c 108 0 2>/dev/null || true
fi

chmod 666 /dev/ppp 2>/dev/null || true

# Runtime de D-Bus
mkdir -p /run/dbus
rm -f /run/dbus/pid

dbus-daemon --system --fork 2>/dev/null || true

# Runtime del usuario no-root
mkdir -p /run/user/1000
chown vpnuser:vpnuser /run/user/1000
chmod 700 /run/user/1000

# Levantar interfaz
ip link set eth0 up 2>/dev/null || true

# DHCP
dhclient -r eth0 2>/dev/null || true
dhclient eth0 2>/dev/null || dhclient -nw eth0 2>/dev/null || true

# DNS de emergencia solamente si está vacío
if ! grep -q '^nameserver ' /etc/resolv.conf 2>/dev/null; then
    echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
fi

# ------------------------------------------------------------
# Iniciar procesos FortiClient
# ------------------------------------------------------------

if [ -x /opt/forticlient/fctsched ]; then
    nohup /opt/forticlient/fctsched \
        >/var/log/fctsched.log 2>&1 &
fi

# Buscar otros servicios definidos por el paquete
for UNIT in \
    /lib/systemd/system/forti*.service \
    /usr/lib/systemd/system/forti*.service
do
    [ -f "$UNIT" ] || continue

    grep '^ExecStart=' "$UNIT" 2>/dev/null \
    | sed 's/^ExecStart=//; s/^[-@+!]*//' \
    | while IFS= read -r CMD
      do
          [ -n "$CMD" ] || continue

          EXE="$(printf '%s\n' "$CMD" | awk '{print $1}')"

          if [ -x "$EXE" ]; then
              pgrep -f "$EXE" >/dev/null 2>&1 || \
                  nohup bash -c "$CMD" \
                  >>/var/log/forticlient-services.log 2>&1 &
          fi
      done
done

sleep 3

echo
echo "[+] RED"
ip -4 addr show eth0 2>/dev/null || true
echo
ip route 2>/dev/null || true

echo
echo "[+] TUN"
ls -l /dev/net/tun 2>/dev/null || true

echo
echo "[+] FORTICLIENT"
if [ -x /opt/forticlient/fortivpn ]; then
    echo "FortiVPN disponible:"
    echo "    /opt/forticlient/fortivpn"
else
    echo "ADVERTENCIA: no encuentro /opt/forticlient/fortivpn"
fi

echo
echo "============================================================"
echo " PARA USAR EL CLIENTE:"
echo
echo " su - vpnuser"
echo
echo " /opt/forticlient/fortivpn status"
echo "============================================================"
echo

# GNS3 mantiene consola interactiva.
# Docker normal mantiene contenedor vivo.
if [ -t 0 ]; then
    exec /bin/bash
else
    exec tail -f /dev/null
fi
EOF

chmod +x "$WORKDIR/start.sh"

# ------------------------------------------------------------
# 3. Dockerfile
# ------------------------------------------------------------

cat > "$WORKDIR/Dockerfile" <<'EOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN printf '#!/bin/sh\nexit 101\n' \
      > /usr/sbin/policy-rc.d \
 && chmod +x /usr/sbin/policy-rc.d

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      iproute2 \
      iputils-ping \
      traceroute \
      isc-dhcp-client \
      openssh-client \
      openssl \
      dbus \
      procps \
      net-tools \
      ppp \
      nano \
      less \
      libnss3 \
      libx11-6 \
      libxext6 \
      libxrender1 \
 && rm -rf /var/lib/apt/lists/*

COPY forticlient-vpn.deb /tmp/forticlient-vpn.deb

RUN apt-get update \
 && apt-get install -y /tmp/forticlient-vpn.deb \
 || (apt-get -f install -y \
     && apt-get install -y /tmp/forticlient-vpn.deb) \
 && rm -f /tmp/forticlient-vpn.deb \
 && rm -rf /var/lib/apt/lists/*

RUN if ! id vpnuser >/dev/null 2>&1; then \
        useradd -m -u 1000 -s /bin/bash vpnuser; \
    fi \
 && mkdir -p /run/user/1000 \
 && chown vpnuser:vpnuser /run/user/1000 \
 && chmod 700 /run/user/1000 \
 && printf '\nexport XDG_RUNTIME_DIR=/run/user/1000\n' \
      >> /home/vpnuser/.profile \
 && printf '\nexport XDG_RUNTIME_DIR=/run/user/1000\n' \
      >> /home/vpnuser/.bashrc \
 && chown vpnuser:vpnuser \
      /home/vpnuser/.profile \
      /home/vpnuser/.bashrc

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]
EOF

# ------------------------------------------------------------
# 4. Construcción
# ------------------------------------------------------------

echo
echo "============================================================"
echo " CONSTRUYENDO $IMAGE"
echo "============================================================"
echo

docker build --no-cache -t "$IMAGE" "$WORKDIR"

echo
echo "============================================================"
echo " VERIFICANDO PAQUETE"
echo "============================================================"
echo

docker run --rm \
    --entrypoint /bin/bash \
    "$IMAGE" \
    -lc '
        echo "--- paquetes FortiClient ---"
        dpkg -l | grep -i forti || true

        echo
        echo "--- binarios ---"
        find /opt/forticlient -maxdepth 2 -type f \
          \( -name "fortivpn" \
             -o -name "vpn" \
             -o -name "forticlient*" \
             -o -name "fctsched" \) \
          -print 2>/dev/null || true

        echo
        echo "--- usuario ---"
        getent passwd vpnuser
    '

# ------------------------------------------------------------
# 5. Prueba de ejecución
# ------------------------------------------------------------

echo
echo "============================================================"
echo " PRUEBA TEMPORAL"
echo "============================================================"
echo

docker rm -f fc-vpn-test >/dev/null 2>&1 || true

docker run -d \
    --name fc-vpn-test \
    --privileged \
    "$IMAGE" >/dev/null

sleep 8

echo
echo "--- red ---"
docker exec fc-vpn-test ip -4 addr show eth0 || true

echo
echo "--- TUN ---"
docker exec fc-vpn-test ls -l /dev/net/tun || true

echo
echo "--- usuario 1000 ---"
docker exec fc-vpn-test \
    bash -lc 'ls -ld /run/user/1000; getent passwd vpnuser'

echo
echo "--- FortiVPN status COMO vpnuser ---"

docker exec \
    -u vpnuser \
    -e XDG_RUNTIME_DIR=/run/user/1000 \
    fc-vpn-test \
    /opt/forticlient/fortivpn status || true

echo
echo "============================================================"
echo " FIN"
echo "============================================================"
echo
echo "Imagen creada:"
echo
echo "    $IMAGE"
echo
echo "Si arriba NO aparece 'trial has expired',"
echo "ya eliminamos el bloqueo de licencia usando"
echo "el cliente oficial VPN-only."
echo
echo "Puedes borrar el contenedor temporal con:"
echo
echo "    docker rm -f fc-vpn-test"
echo
echo "En GNS3 usa esta imagen:"
echo
echo "    $IMAGE"
echo
echo "Privileged: ON"
echo "Adapters: 1"
echo "Console: Telnet"
echo
