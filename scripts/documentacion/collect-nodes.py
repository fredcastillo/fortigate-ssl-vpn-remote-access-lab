#!/usr/bin/env python3
"""Exportar configuraciones y estado de contenedores existentes, sin cambiarlos."""
import datetime
import json
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
PROJECT='ea145aa2-7392-4eb2-b990-4b81dd21a346'
NODES={'client':'CLIENTE-FORTICLIENT-1','server':'web-server-lab-1','browsers/users':'Browser-PC-1','browsers/aux':'browser-2'}
def call(args): return subprocess.check_output(args,text=True,timeout=20)
inventory={'collected_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'project_id':PROJECT,'nodes':[]}
for role,name in NODES.items():
    ids=call(['docker','ps','-q','--filter',f'name=GNS3.{name}.{PROJECT}']).split()
    if len(ids)!=1: raise SystemExit('No se encontró exactamente un nodo '+name)
    cid=ids[0];d=json.loads(call(['docker','inspect',cid]))[0]
    dest=ROOT/'configs'/role;dest.mkdir(parents=True,exist_ok=True)
    for filename,cmd in [('interfaces', ['cat','/etc/network/interfaces']),('ip-address.txt',['ip','-br','addr']),('routes.txt',['ip','route']),('listeners.txt',['ss','-lnt'])]:
        (dest/filename).write_text(call(['docker','exec',cid,*cmd]))
    inventory['nodes'].append({'name':name,'role':role,'image_reference':d['Config']['Image'],'image_id':d['Image'],'privileged':d['HostConfig']['Privileged'],'startup':d['Config']['Cmd'],'container_id':cid})
    if role=='client':
        for filename,source in [('lab.conf','/etc/openfortivpn/lab.conf'),('lab-tls.cnf','/etc/openfortivpn/lab-tls.cnf'),('start.sh','/usr/local/bin/start.sh'),('lab-vpn','/usr/local/bin/lab-vpn')]:
            content=call(['docker','exec',cid,'cat',source])
            if filename=='lab.conf': content='\n'.join(line for line in content.splitlines() if not line.lower().startswith('password'))+'\n'
            (dest/filename).write_text(content)
        (dest/'packages.txt').write_text(call(['docker','exec',cid,'dpkg-query','-W','forticlient','openfortivpn','ppp']))
        (ROOT/'evidence'/'vpn-status-current.txt').write_text(call(['docker','exec',cid,'lab-vpn','status']))
    if role=='server':
        (dest/'start-network.sh').write_text(call(['docker','exec',cid,'cat','/start-network.sh']))
        (dest/'sshd_config').write_text(call(['docker','exec',cid,'cat','/etc/ssh/sshd_config']))
        (dest/'sshd-effective.txt').write_text(call(['docker','exec',cid,'/usr/sbin/sshd','-T']))
        (dest/'apache-vhosts.txt').write_text(call(['docker','exec',cid,'apache2ctl','-S']))
        for filename,source in [('apache-000-default.conf','/etc/apache2/sites-available/000-default.conf'),('apache-default-ssl.conf','/etc/apache2/sites-available/default-ssl.conf')]:
            (dest/filename).write_text(call(['docker','exec',cid,'cat',source]))
        (dest/'packages.txt').write_text(call(['docker','exec',cid,'dpkg-query','-W','apache2','openssh-server','openssh-client']))
(ROOT/'inventory'/'nodes.json').write_text(json.dumps(inventory,indent=2)+'\n')
print('Configuraciones y estado reales de cuatro nodos exportados.')
