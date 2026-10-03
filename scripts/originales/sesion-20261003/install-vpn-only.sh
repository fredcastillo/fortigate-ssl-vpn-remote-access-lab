#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CLIENT="$(docker ps -q --filter 'name=GNS3.CLIENTE-FORTICLIENT-1.ea145aa2-7392-4eb2-b990-4b81dd21a346')"
test -n "$CLIENT"
test "$(printf '%s\n' "$CLIENT" | wc -l)" = 1
PACKAGE="$ROOT/forticlient-vpn-official.deb"
test -s "$ROOT/client-before.image-id"
docker image inspect lab-backup/client-pre-vpnonly:20261003 >/dev/null
test "$(docker inspect -f '{{.State.Running}}' "$CLIENT")" = true
python3 - "$ROOT" <<'PY'
from pathlib import Path
import hashlib,json,sys
root=Path(sys.argv[1]); metadata=json.loads((root/'download.json').read_text())
p=root/'forticlient-vpn-official.deb'
assert metadata['resolved_url'].startswith('https://filestore.fortinet.com/forticlient/')
assert p.stat().st_size == metadata['size']
with p.open('rb') as stream:
    assert hashlib.file_digest(stream,'sha256').hexdigest() == metadata['sha256']
PY
test "$(dpkg-deb -f "$PACKAGE" Package)" = forticlient
test "$(dpkg-deb -f "$PACKAGE" Architecture)" = amd64
test "$(dpkg-deb -f "$PACKAGE" Version)" = 7.4.3.5411
docker cp "$PACKAGE" "$CLIENT:/tmp/forticlient-vpn-official.deb"
docker exec "$CLIENT" dpkg --force-confold -i /tmp/forticlient-vpn-official.deb
if ! docker exec "$CLIENT" pgrep -x fctsched >/dev/null; then
    docker exec -d "$CLIENT" /opt/forticlient/fctsched
fi
sleep 3
docker exec "$CLIENT" dpkg-query -W forticlient
docker exec -u vpnuser -e XDG_RUNTIME_DIR=/run/user/1000 "$CLIENT" forticlient vpn status
