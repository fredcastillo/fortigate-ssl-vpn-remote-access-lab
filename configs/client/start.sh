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

mkdir -p /run/user/1000 && chown 1000:1000 /run/user/1000 && chmod 700 /run/user/1000
echo "=== FortiClient listo. Prueba: forticlient vpn --help ==="
if [ -t 0 ]; then exec /bin/bash; else exec tail -f /dev/null; fi
