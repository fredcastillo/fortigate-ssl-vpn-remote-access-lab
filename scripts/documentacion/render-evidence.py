#!/usr/bin/env python3
"""Generar imagen de una transcripción real, sin alterar los resultados."""
from pathlib import Path
import html
import json

ROOT=Path(__file__).resolve().parents[2]
data=json.loads((ROOT/'evidence/with-vpn-final.json').read_text())
lines=['$ lab-vpn status',*data['vpn_status'].splitlines(),'','$ ssh labssh@10.21.75.130',*data['ssh'].splitlines(),'','$ traceroute -T -p 22 -n 10.21.75.130',*data['traceroute_tcp_22'].splitlines()]
height=155+len(lines)*26
body=f'<svg xmlns="http://www.w3.org/2000/svg" width="1140" height="{height}" viewBox="0 0 1140 {height}"><rect width="100%" height="100%" rx="18" fill="#10233f"/><text x="30" y="45" fill="#79dbc5" font-family="Arial" font-size="22" font-weight="bold">Evidencia de la conexión VPN y del acceso SSH</text><text x="30" y="78" fill="#bfd0e3" font-family="Arial" font-size="14">Transcripción de resultados reales · CLIENTE-FORTICLIENT · {html.escape(data["time_utc"])}</text>'
for i,line in enumerate(lines):
    body+=f'<text x="30" y="{115+i*26}" fill="{"#79dbc5" if line.startswith("$") else "#e8eff7"}" font-family="monospace" font-size="16">{html.escape(line)}</text>'
body+='</svg>'
(ROOT/'assets/images/evidencia-ssh-vpn.svg').write_text(body)
print('Imagen de transcripción real generada.')
