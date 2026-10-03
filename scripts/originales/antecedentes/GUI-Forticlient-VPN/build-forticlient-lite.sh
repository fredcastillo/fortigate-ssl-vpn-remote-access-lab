#!/usr/bin/env bash
# =============================================================================
# build-forticlient-lite.sh
# Imagen Docker ligera con FortiClient Linux, instalada desde el repo APT
# OFICIAL de Fortinet (sin .deb manual, sin mirrors de terceros).
#
# ESTADO: NO PROBADO. Fue escrito sin acceso a repo.fortinet.com, asi que la
#         primera ejecucion real es la verificacion. Si algo falla, copia el
#         error y lo ajustamos.
#
# Uso (dentro de la GNS3 VM):
#   sudo ./build-forticlient-lite.sh              # usa FortiClient 7.2
#   sudo FC_VERSION=7.4 ./build-forticlient-lite.sh
#
# Nodo GNS3 recomendado (variante CLI, la mas ligera):
#   Console type : telnet      (sin VNC / sin X11)
#   Adapters     : 1  -> segmento de usuarios VLAN 10
#   RAM          : 512 MB      (medir con: docker stats)
#   CPU          : 1
#   Privileged   : ENABLED
# =============================================================================
set -euo pipefail

FC_VERSION="${FC_VERSION:-7.2}"
IMAGE="forticlient-lite:${FC_VERSION}"
WORKDIR="${WORKDIR:-/home/gns3/lab-images/forticlient-lite}"
REPO="https://repo.fortinet.com/repo/forticlient/${FC_VERSION}/ubuntu"

echo "[1/4] Comprobando que el repo oficial entrega la llave GPG real (no HTML)"
if ! curl -fsSL "${REPO}/DEB-GPG-KEY" | head -n1 | grep -q "BEGIN PGP"; then
  echo "ERROR: ${REPO}/DEB-GPG-KEY no devolvio una llave PGP."
  echo "       Revisa DNS/salida a Internet de la GNS3 VM (curl -I ${REPO}/DEB-GPG-KEY)."
  exit 1
fi

mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

echo "[2/4] Generando start.sh y Dockerfile en ${WORKDIR}"
cat > start.sh <<'EOF'
#!/bin/bash
# Arranque del nodo dentro de GNS3

# Dispositivos que la VPN necesita
mkdir -p /dev/net
[ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200
[ -c /dev/ppp ]     || mknod /dev/ppp c 108 0 2>/dev/null || true

# D-Bus
mkdir -p /run/dbus && rm -f /run/dbus/pid
dbus-daemon --system --fork 2>/dev/null || true

# Red: DHCP por eth0 (VLAN 10), en segundo plano
ip link set eth0 up
dhclient -nw eth0 || echo "AVISO: sin DHCP en eth0"
grep -q nameserver /etc/resolv.conf 2>/dev/null || echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Demonios de FortiClient: no hay systemd en el contenedor, asi que se leen
# los ExecStart de las units que instalo el paquete y se lanzan a mano.
for u in /lib/systemd/system/forti*.service /usr/lib/systemd/system/forti*.service; do
  [ -f "$u" ] || continue
  grep -E '^ExecStart=' "$u" | sed 's/^ExecStart=//; s/^[-@+!]*//' | while read -r c; do
    nohup $c >"/var/log/$(basename "$u").log" 2>&1 &
  done
done

echo "=== FortiClient listo. Prueba: forticlient vpn --help ==="
exec /bin/bash
EOF
chmod +x start.sh

cat > Dockerfile <<'EOF'
FROM ubuntu:22.04
ARG FC_VERSION=7.2
ENV DEBIAN_FRONTEND=noninteractive

# Evita que el postinst intente arrancar servicios durante el build
RUN printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates wget curl gnupg iproute2 iputils-ping traceroute \
      isc-dhcp-client openssh-client dbus procps net-tools nano less \
    && wget -qO- https://repo.fortinet.com/repo/forticlient/${FC_VERSION}/ubuntu/DEB-GPG-KEY \
         | gpg --dearmor -o /usr/share/keyrings/repo.fortinet.com.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/repo.fortinet.com.gpg] https://repo.fortinet.com/repo/forticlient/${FC_VERSION}/ubuntu/ stable non-free" \
         > /etc/apt/sources.list.d/repo.fortinet.com.list \
    && apt-get update \
    && (apt-get install -y libindicator3-7 || true) \
    && apt-get install -y --no-install-recommends forticlient \
    && rm -rf /var/lib/apt/lists/*

COPY start.sh /usr/local/bin/start.sh
CMD ["/usr/local/bin/start.sh"]
EOF

echo "[3/4] Construyendo ${IMAGE}"
docker build --build-arg FC_VERSION="${FC_VERSION}" -t "${IMAGE}" .

echo "[4/4] Verificacion: que quedo instalado y como se arrancan los demonios"
docker run --rm "${IMAGE}" bash -c '
  echo "--- binarios ---";  ls -l /opt/forticlient/ | head -40
  echo "--- units ---";     ls /lib/systemd/system /usr/lib/systemd/system 2>/dev/null | grep -i forti
  echo "--- ExecStart ---"; grep -H "^ExecStart" /lib/systemd/system/forti*.service /usr/lib/systemd/system/forti*.service 2>/dev/null
  echo "--- cli ---";       forticlient --help 2>&1 | head -20
'

cat <<MSG

Imagen lista: ${IMAGE}
Siguiente paso: GNS3 -> New template -> Docker -> Existing image -> ${IMAGE}
  Console type = telnet | Adapters = 1 | Privileged = ENABLED
Dentro del nodo:
  ls -l /dev/net/tun
  ip addr ; ping -c 3 10.21.75.1
  forticlient vpn edit lab-vpn
  forticlient vpn connect lab-vpn --user=<usuario> --password
MSG
