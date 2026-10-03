#!/usr/bin/env python3
"""Lectura de consola Telnet: autentica por prompt y permite solo show/get.

Guarda la salida cruda fuera del repositorio; sanitizar antes de publicar.
"""
import argparse
import getpass
import re
import select
import socket
import time
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--host', default='127.0.0.1')
p.add_argument('--port', type=int, required=True)
p.add_argument('--user', default='admin')
p.add_argument('--out', required=True)
p.add_argument('--already-authenticated', action='store_true', help='Exigir una sesión previamente autenticada')
p.add_argument('commands', nargs='+')
a = p.parse_args()
if any(not re.fullmatch(r'(show|get)(\s+[a-zA-Z0-9 _./-]+)?', c) for c in a.commands):
    raise SystemExit('Solo se permiten comandos show/get de lectura')
password = None if a.already_authenticated else getpass.getpass('Contraseña de consola (oculta): ')
s = socket.create_connection((a.host, a.port), 5)
s.setblocking(False)
buffer = b''

def read(seconds=1):
    global buffer
    result = bytearray()
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        if not select.select([s], [], [], .1)[0]:
            continue
        chunk = s.recv(65536)
        if not chunk:
            raise RuntimeError('Consola cerrada')
        buffer += chunk
        while buffer:
            if buffer[0] != 255:
                result.append(buffer[0]); buffer = buffer[1:]; continue
            if len(buffer) < 2:
                break
            cmd = buffer[1]
            if cmd in (251, 252, 253, 254):
                if len(buffer) < 3: break
                option = buffer[2]
                if cmd == 251: s.sendall(bytes([255, 253 if option in (0, 1, 3) else 254, option]))
                if cmd == 253: s.sendall(bytes([255, 251 if option in (0, 3) else 252, option]))
                buffer = buffer[3:]
            elif cmd == 250:
                marker = buffer.find(bytes([255, 240]), 2)
                if marker == -1: break
                buffer = buffer[marker + 2:]
            else:
                buffer = buffer[2:]
    return re.sub(r'\x1b\[[0-9;?]*[A-Za-z]', '', result.decode(errors='replace')).replace('\r', '')

s.sendall(b'\r')
text = read(2)
for _ in range(4):
    if re.search(r'(Username:|login:|Password:|[#>])\s*$', text, re.I): break
    text += read(1)
if re.search(r'(Username:|login:)\s*$', text, re.I):
    if a.already_authenticated: raise SystemExit('La consola requiere autenticación')
    s.sendall((a.user + '\r').encode()); text = read(2)
if re.search(r'Password:\s*$', text, re.I):
    if password is None: raise SystemExit('La consola requiere autenticación')
    s.sendall((password + '\r').encode()); text = read(4)
password = None
if not re.search(r'[#>]\s*$', text):
    raise SystemExit('No se obtuvo un prompt autenticado; no se enviaron comandos')
outputs = []
for command in a.commands:
    s.sendall((command + '\r').encode())
    output = ''
    deadline = time.monotonic() + 300
    while time.monotonic() < deadline:
        part = read(.04)
        output += part
        if '--More--' in part or 'More:' in part:
            s.sendall(b' ')
        elif re.search(r'\n[^\n]*[#>]\s*$', output):
            break
    else:
        raise SystemExit('Lectura incompleta: no se recibió prompt final')
    outputs.append(output)
target = Path(a.out)
target.write_text('\n'.join(outputs))
target.chmod(0o600)
s.close()
print('Captura de lectura guardada; sanitizar antes de publicar.')
