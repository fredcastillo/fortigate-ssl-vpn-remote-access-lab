#!/usr/bin/env bash
set -Eeuo pipefail

VPN_HOST="203.0.113.26"
VPN_PORT="10443"
USER_BROWSER_IP="10.21.75.110"
VPN_USER="vpnuser"
IMAGE_BACKUP="forticlient-vpn-lab:7.0.9-reparado"
LOG="$HOME/infra3-recovery-$(date +%Y%m%d-%H%M%S).log"

exec > >(tee -a "$LOG") 2>&1

ok()   { echo "[OK] $*"; }
warn() { echo "[AVISO] $*"; }
fail() { echo "[ERROR] $*"; exit 1; }

echo
echo "=============================================================="
echo " RECUPERACION INTEGRAL - INFRAESTRUCTURA 3"
echo "=============================================================="
echo

# ============================================================
# 1. CONFIRMAR QUE ESTAMOS EN GNS3 VM
# ============================================================

echo "[1/9] Verificando GNS3 VM..."

command -v docker >/dev/null 2>&1 || {
    echo
    echo "ESTE SCRIPT DEBE EJECUTARSE EN:"
    echo "    gns3@gns3vm:~$"
    echo
    exit 1
}

ok "Docker disponible: $(docker --version)"

echo
echo "Host:"
hostname
echo

# ============================================================
# 2. LOCALIZAR CLIENTE FORTICLIENT
# ============================================================

echo "[2/9] Localizando CLIENTE-FORTICLIENT..."

CLIENT="$(
    docker ps -a --format '{{.Names}}' |
    grep -i 'CLIENTE-FORTICLIENT' |
    head -n1 || true
)"

if [ -z "$CLIENT" ]; then
    fail "No encontré ningún contenedor CLIENTE-FORTICLIENT."
fi

ok "Contenedor encontrado:"
echo "    $CLIENT"

docker start "$CLIENT" >/dev/null 2>&1 || true
sleep 2

echo
docker inspect     --format='Imagen actual: {{.Config.Image}} | Privileged: {{.HostConfig.Privileged}}'     "$CLIENT" || true

# ============================================================
# 3. LOCALIZAR BROWSER-PC DE USUARIOS
# ============================================================

echo
echo "[3/9] Localizando Browser-PC de Usuarios ($USER_BROWSER_IP)..."

USER_BROWSER=""

while IFS= read -r C; do
    [ -n "$C" ] || continue

    ADDRS="$(
        docker exec "$C" sh -c         'ip -4 -o addr show eth0 2>/dev/null || true'         2>/dev/null || true
    )"

    if printf '%s\n' "$ADDRS" |
       grep -q "${USER_BROWSER_IP}/"; then
        USER_BROWSER="$C"
        break
    fi
done < <(docker ps --format '{{.Names}}')

if [ -n "$USER_BROWSER" ]; then
    ok "Browser-PC de Usuarios:"
    echo "    $USER_BROWSER"

    docker exec "$USER_BROWSER" sh -c '
        echo "--- IP ---"
        ip -4 addr show eth0
        echo
        echo "--- ROUTING ---"
        ip route
    ' || true

    echo
    echo "Probando TCP $VPN_HOST:$VPN_PORT desde la VLAN 10..."

    if docker exec "$USER_BROWSER"         bash -c "timeout 5 bash -c '</dev/tcp/$VPN_HOST/$VPN_PORT'"         >/dev/null 2>&1; then

        ok "Usuario -> FortiGate TCP $VPN_PORT FUNCIONA."
    else
        fail "El puerto $VPN_PORT dejó de responder desde Usuarios. No modificaré FortiClient."
    fi
else
    warn "No encontré automáticamente $USER_BROWSER_IP."
    warn "Continuaré porque ya comprobamos manualmente TCP/10443."
fi

# ============================================================
# 4. REPARAR ENTORNO DEL CONTENEDOR FORTICLIENT
# ============================================================

echo
echo "[4/9] Reparando runtime del FortiClient..."

docker exec -u root "$CLIENT" bash -c '
set +e

# TUN
mkdir -p /dev/net

if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

chmod 666 /dev/net/tun 2>/dev/null || true

# PPP
if [ ! -c /dev/ppp ]; then
    mknod /dev/ppp c 108 0 2>/dev/null || true
fi

chmod 666 /dev/ppp 2>/dev/null || true

# Usuario
if ! id vpnuser >/dev/null 2>&1; then
    useradd -m -u 1000 -s /bin/bash vpnuser
fi

# XDG runtime
mkdir -p /run/user/1000
chown vpnuser:vpnuser /run/user/1000
chmod 700 /run/user/1000

grep -q "XDG_RUNTIME_DIR=/run/user/1000"     /home/vpnuser/.profile 2>/dev/null ||
echo "export XDG_RUNTIME_DIR=/run/user/1000"     >> /home/vpnuser/.profile

grep -q "XDG_RUNTIME_DIR=/run/user/1000"     /home/vpnuser/.bashrc 2>/dev/null ||
echo "export XDG_RUNTIME_DIR=/run/user/1000"     >> /home/vpnuser/.bashrc

chown -R vpnuser:vpnuser /home/vpnuser

# DBUS
mkdir -p /run/dbus
rm -f /run/dbus/pid
dbus-daemon --system --fork 2>/dev/null || true

# Interface
ip link set eth0 up 2>/dev/null || true

if ! ip -4 addr show eth0 | grep -q "inet "; then
    dhclient eth0 2>/dev/null || dhclient -nw eth0 2>/dev/null || true
fi

echo
echo "--- vpnuser ---"
getent passwd vpnuser

echo
echo "--- runtime ---"
ls -ld /run/user/1000

echo
echo "--- tun ---"
ls -l /dev/net/tun

echo
echo "--- IP ---"
ip -4 addr show eth0

echo
echo "--- route ---"
ip route
'

ok "Runtime básico reparado."

# ============================================================
# 5. COMPROBAR FORTICLIENT ACTUAL
# ============================================================

echo
echo "[5/9] Revisando FortiClient actual..."

CURRENT_STATUS="$(
docker exec     -u "$VPN_USER"     -e XDG_RUNTIME_DIR=/run/user/1000     "$CLIENT"     bash -lc '
        if command -v forticlient >/dev/null 2>&1; then
            forticlient vpn status 2>&1 || true
        elif [ -x /opt/forticlient/fortivpn ]; then
            /opt/forticlient/fortivpn status 2>&1 || true
        else
            echo "NO_FORTICLIENT_CLI"
        fi
    ' 2>&1 || true
)"

echo "$CURRENT_STATUS"

if echo "$CURRENT_STATUS" |
   grep -qi 'trial has expired'; then

    warn "CONFIRMADO: el FortiClient completo tiene el trial expirado."
    NEED_VPN_ONLY=1
else
    NEED_VPN_ONLY=0
fi

# ============================================================
# 6. CONSEGUIR FORTICLIENT VPN-ONLY 7.0.9
# ============================================================

echo
echo "[6/9] Buscando FortiClient VPN-only 7.0.9..."

DEB="$(
find     "$HOME"     "$HOME/Downloads"     /tmp     -maxdepth 4     -type f     \(        -name 'forticlient_vpn_server_7.0.9*_amd64.deb'        -o -name 'forticlient_vpn_7.0.9*_amd64.deb'     \)     2>/dev/null |
head -n1 || true
)"

# Intento oficial directo, SOLO si no lo tenemos.
if [ -z "$DEB" ]; then

    warn "No encontré todavía el paquete 7.0.9."
    echo "Intentaré dos rutas oficiales de Fortinet."

    mkdir -p "$HOME/forticlient-packages"

    DEST="$HOME/forticlient-packages/forticlient_vpn_7.0.9.0322_amd64.deb"

    URLS=(
      "https://filestore.fortinet.com/forticlient/downloads/forticlient_vpn_7.0.9.0322_amd64.deb"
      "https://filestore.fortinet.com/forticlient/forticlient_vpn_7.0.9.0322_amd64.deb"
    )

    for URL in "${URLS[@]}"; do
        echo
        echo "Probando:"
        echo "    $URL"

        rm -f "$DEST"

        if curl -fL --connect-timeout 15             --max-time 120             "$URL"             -o "$DEST"; then

            if dpkg-deb --info "$DEST" >/dev/null 2>&1; then
                DEB="$DEST"
                ok "Paquete .deb oficial válido descargado."
                break
            else
                rm -f "$DEST"
            fi
        fi
    done
fi

if [ -z "$DEB" ]; then
    echo
    echo "=============================================================="
    echo " UNICO ELEMENTO QUE NO PUEDO FABRICAR CON UN SCRIPT"
    echo "=============================================================="
    echo
    echo "Necesitamos el instalador OFICIAL:"
    echo
    echo " forticlient_vpn_server_7.0.9.xxxx_amd64.deb"
    echo "          O"
    echo " forticlient_vpn_7.0.9.xxxx_amd64.deb"
    echo
    echo "Fortinet lo publica como su cliente gratuito VPN-only."
    echo
    echo "Colócalo en:"
    echo
    echo "    /home/gns3/"
    echo
    echo "y vuelve a ejecutar:"
    echo
    echo "    bash ~/RECUPERAR_INFRA3.sh"
    echo
    echo "NO borres nada. El script se detuvo antes de modificar"
    echo "tu FortiClient instalado."
    echo
    echo "Log:"
    echo "    $LOG"
    exit 20
fi

ok "Paquete VPN-only encontrado:"
echo "    $DEB"

echo
echo "Información del paquete:"
dpkg-deb --info "$DEB" | grep -E 'Package:|Version:|Architecture:' || true

# ============================================================
# 7. SUSTITUIR FULL FORTICLIENT POR VPN-ONLY
# ============================================================

echo
echo "[7/9] Sustituyendo FortiClient full por VPN-only..."

docker cp "$DEB" "$CLIENT":/tmp/forticlient-vpn-only.deb

docker exec -u root "$CLIENT" bash -c '
set +e

echo "[+] Deteniendo procesos anteriores..."

pkill -f /opt/forticlient 2>/dev/null || true
sleep 2

echo "[+] Eliminando paquete FortiClient anterior..."

dpkg -r forticlient 2>/dev/null || true

echo "[+] Eliminando estado anterior del trial..."

rm -rf /opt/forticlient
rm -rf /etc/forticlient
rm -rf /root/.config/FortiClient
rm -rf /home/vpnuser/.config/FortiClient
rm -rf /home/vpnuser/.cache/FortiClient

mkdir -p /home/vpnuser/.config
chown -R vpnuser:vpnuser /home/vpnuser

echo "[+] Instalando VPN-only..."

dpkg -i /tmp/forticlient-vpn-only.deb
RC=$?

if [ $RC -ne 0 ]; then
    echo
    echo "dpkg reportó dependencias pendientes."
    echo "Intentando reparar con paquetes ya disponibles..."
    apt-get -f install -y
fi

echo
echo "[+] Paquete instalado:"
dpkg -l | grep -i forti || true

echo
echo "[+] Binarios:"
find /opt/forticlient      -maxdepth 2      -type f      \( -name fortivpn -o -name vpn -o -name fctsched -o -name forticlient \)      -print 2>/dev/null || true

# runtime otra vez
mkdir -p /run/user/1000
chown vpnuser:vpnuser /run/user/1000
chmod 700 /run/user/1000

mkdir -p /run/dbus
rm -f /run/dbus/pid
dbus-daemon --system --fork 2>/dev/null || true

mkdir -p /dev/net
[ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200
chmod 666 /dev/net/tun

# iniciar servicio FortiClient sin systemd
if [ -x /opt/forticlient/fctsched ]; then
    nohup /opt/forticlient/fctsched       >/var/log/fctsched.log 2>&1 &
fi

for UNIT in   /lib/systemd/system/forti*.service   /usr/lib/systemd/system/forti*.service
do
    [ -f "$UNIT" ] || continue

    CMD="$(grep "^ExecStart=" "$UNIT" |
           head -1 |

    [ -n "$CMD" ] || continue

    EXE="$(printf "%s\n" "$CMD" | awk "{print $1}")"

    if [ -x "$EXE" ]; then
        pgrep -f "$EXE" >/dev/null 2>&1 ||
            nohup bash -c "$CMD"             >>/var/log/forticlient-services.log 2>&1 &
    fi
done

sleep 5
'

# ============================================================
# 8. PROBAR VPN-ONLY COMO USUARIO NORMAL
# ============================================================

echo
echo "[8/9] Validando VPN-only como vpnuser..."

FINAL_STATUS="$(
docker exec   -u "$VPN_USER"   -e HOME=/home/vpnuser   -e XDG_RUNTIME_DIR=/run/user/1000   "$CLIENT"   bash -lc '
    if [ -x /opt/forticlient/fortivpn ]; then
        /opt/forticlient/fortivpn status 2>&1 || true
    elif command -v forticlient >/dev/null 2>&1; then
        forticlient vpn status 2>&1 || true
    elif [ -x /opt/forticlient/vpn ]; then
        /opt/forticlient/vpn --help 2>&1 || true
    else
        echo "ERROR: No encuentro CLI VPN."
    fi
  ' 2>&1 || true
)"

echo
echo "$FINAL_STATUS"
echo

if echo "$FINAL_STATUS" |
   grep -qi 'trial has expired'; then
    fail "El paquete sigue reportando trial. NO continuaré ocultando ni modificando licencias."
fi

ok "Ya no aparece el bloqueo 'trial has expired'."

# ============================================================
# 9. GUARDAR LA REPARACION
# ============================================================

echo
echo "[9/9] Guardando imagen de respaldo..."

docker commit "$CLIENT" "$IMAGE_BACKUP" >/dev/null

ok "Imagen guardada:"
echo "    $IMAGE_BACKUP"

echo
echo "=============================================================="
echo " RECUPERACION TERMINADA"
echo "=============================================================="
echo
echo "Cliente GNS3:"
echo "    $CLIENT"
echo
echo "Log:"
echo "    $LOG"
echo
echo "SIGUIENTE PASO:"
echo
echo "1) Entra al nodo CLIENTE-FORTICLIENT desde GNS3."
echo
echo "2) Ejecuta:"
echo
echo "       su - vpnuser"
echo
echo "3) Luego:"
echo
echo "       /opt/forticlient/fortivpn status"
echo
echo "4) Si dice Not Running o equivalente, crea el perfil:"
echo
echo "       /opt/forticlient/fortivpn edit INFRA3-SSLVPN"
echo
echo "   Gateway: 203.0.113.26"
echo "   Port:    10443"
echo "   User:    vpnuser"
echo
echo "5) Después conecta:"
echo
echo "       /opt/forticlient/fortivpn connect INFRA3-SSLVPN --user=vpnuser --password"
echo
echo "=============================================================="
