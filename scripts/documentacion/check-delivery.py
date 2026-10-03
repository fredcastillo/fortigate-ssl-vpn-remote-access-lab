#!/usr/bin/env python3
"""Revisión documental local: enlaces, exports, sintaxis y secretos evidentes."""
import ast
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
errors=[]
required=['README.md','video/GUION-5m40s.md','assets/diagrams/topologia.svg','assets/images/fortigate-ssl-vpn-monitor.png','configs/fortigate/running-config.sanitized.conf','configs/cisco/R1-CISCO-VPN.running-config.txt','configs/cisco/Router-ISP.running-config.txt','configs/switch/Switch-A.running-config.txt','inventory/configs-provenance.json','evidence/with-vpn-final.json','evidence/without-vpn-final.json']
for name in required:
    if not (ROOT/name).is_file():errors.append('Falta '+name)
for path in ROOT.rglob('*'):
    if not path.is_file() or '.git' in path.parts or '__pycache__' in path.parts:continue
    rel=str(path.relative_to(ROOT))
    if path.suffix in ['.deb','.qcow2','.vmdk','.pem','.key','.zip']:
        errors.append('Archivo excluido presente: '+rel)
    if path.suffix=='.png':continue
    try:text=path.read_text()
    except UnicodeDecodeError:continue
    if re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',text):errors.append('Clave privada: '+rel)
    if re.search(r'(?m)^\s*set\s+(?:password|passwd|psksecret)\s+(?!.*REDACTED).+',text):errors.append('Credencial sin redactar: '+rel)
    if path.suffix=='.md':
        prose=re.sub(r'(?ms)^```.*?^```\s*$', '', text)
        for target in re.findall(r'!?\[[^\]]*\]\(([^)\s]+)(?:\s+[^)]*)?\)',prose):
            if target.startswith(('http:','https:','#','URL_REAL')):continue
            local=target.split('#',1)[0]
            if local and not (path.parent/local).exists():errors.append('Enlace roto: '+rel+' → '+target)
    if path.suffix=='.py':
        try:ast.parse(text,filename=rel)
        except SyntaxError as e:errors.append('Sintaxis Python: '+rel+': '+str(e))
    if path.suffix in ['.sh','.ah']:
        result=subprocess.run(['bash','-n',str(path)],capture_output=True,text=True)
        if result.returncode:errors.append('Sintaxis Bash: '+rel)
for name in ['with-vpn-final.json','without-vpn-final.json']:
    try:json.loads((ROOT/'evidence'/name).read_text())
    except Exception as e:errors.append('Evidencia JSON inválida: '+name)
if errors:
    print('\n'.join(errors));sys.exit(1)
print('OK: archivos, enlaces locales, sintaxis y exclusiones verificados.')
