#!/usr/bin/env python3
"""Exportar show de Cisco por SSH desde namespace del cliente, sin mostrar secretos."""
import argparse
import fcntl
import getpass
import json
import os
import pty
import re
import select
import subprocess
import time
import termios
from pathlib import Path

p=argparse.ArgumentParser();p.add_argument('--host',required=True);p.add_argument('--user',default='admin');p.add_argument('--out',required=True);p.add_argument('commands',nargs='+');a=p.parse_args()
if any(not re.fullmatch(r'show\s+[a-zA-Z0-9 _./-]+',c) for c in a.commands):raise SystemExit('Solo comandos show')
password=getpass.getpass('Contraseña SSH (oculta): ')
ids=subprocess.check_output(['docker','ps','-q','--filter','name=GNS3.CLIENTE-FORTICLIENT-1.ea145aa2-7392-4eb2-b990-4b81dd21a346'],text=True).split()
if len(ids)!=1:raise SystemExit('Nodo cliente ambiguo')
pid=json.loads(subprocess.check_output(['docker','inspect',ids[0]]))[0]['State']['Pid']
master,slave=pty.openpty()
cmd=['sudo','-n','nsenter','-t',str(pid),'-n','ssh','-tt','-o','StrictHostKeyChecking=accept-new','-o','UserKnownHostsFile='+str(Path(a.out).parent/'cisco-known-hosts'),'-o','KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1','-o','HostKeyAlgorithms=+ssh-rsa','-o','Ciphers=+aes128-cbc,3des-cbc','-o','PubkeyAuthentication=no',a.user+'@'+a.host]
def controlling_tty():
    os.setsid()
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)
process=subprocess.Popen(cmd,stdin=slave,stdout=slave,stderr=slave,preexec_fn=controlling_tty);os.close(slave)
def read_until(pattern,timeout=40):
    text='';end=time.monotonic()+timeout
    while time.monotonic()<end:
        if not select.select([master],[],[],.15)[0]:continue
        try:chunk=os.read(master,65536)
        except OSError:break
        if not chunk:break
        part=chunk.decode(errors='replace').replace('\r','');text+=part
        if '--More--' in part:os.write(master,b' ')
        if re.search(pattern,text):return text
    raise RuntimeError('No se recibió prompt esperado; salida privada no publicada')
read_until(r'(?i)password:\s*$');os.write(master,(password+'\n').encode());password=None
read_until(r'\n[^\n]+[#>]\s*$')
parts=[]
for command in a.commands:
    os.write(master,(command+'\n').encode());parts.append(read_until(r'\n[^\n]+[#>]\s*$',120))
Path(a.out).write_text('\n'.join(parts));Path(a.out).chmod(0o600)
os.write(master,b'exit\n');process.wait(timeout=10);os.close(master)
print('Export SSH privado guardado; sanitizar antes de publicar.')
