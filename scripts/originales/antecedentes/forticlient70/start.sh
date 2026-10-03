#!/bin/bash
set -e

mkdir -p /dev/net

if [ ! -e /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200 || true
fi

if [ -e /dev/ppp ]; then
    chmod 666 /dev/ppp || true
fi

mkdir -p /run/dbus
mkdir -p /run/user/1000
chown 1000:1000 /run/user/1000

export XDG_RUNTIME_DIR=/run/user/1000

dbus-daemon --system --fork || true

dhclient -nw eth0 || true

if [ -f /lib/systemd/system/forticlient.service ]; then
    EXEC_START="$(grep '^ExecStart=' /lib/systemd/system/forticlient.service | head -1 | cut -d= -f2- || true)"

    if [ -n "$EXEC_START" ]; then
        echo "[+] Starting FortiClient service:"
        echo "$EXEC_START"

        bash -c "$EXEC_START" &
    fi
fi

sleep 5

echo
echo "[+] FortiClient container ready"
echo

if [ -t 0 ]; then
    exec /bin/bash
else
    exec tail -f /dev/null
fi
