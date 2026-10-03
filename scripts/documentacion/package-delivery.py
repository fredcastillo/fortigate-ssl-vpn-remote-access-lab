#!/usr/bin/env python3
"""Validar, calcular hashes y crear ZIP con la carpeta raíz, sin archivos privados."""
from pathlib import Path
import hashlib
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
def files():
    return sorted(p for p in ROOT.rglob('*') if p.is_file() and not any(x in p.parts for x in ['__pycache__','.git']))
subprocess.run([sys.executable,str(ROOT/'scripts/documentacion/check-delivery.py')],check=True)
lines=[]
for p in files():
    if p.name=='SHA256SUMS.txt':continue
    lines.append(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(ROOT)))
(ROOT/'SHA256SUMS.txt').write_text('\n'.join(lines)+'\n')
dest=ROOT.parent/(ROOT.name+'.zip')
with zipfile.ZipFile(dest,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
    for p in files():archive.write(p,arcname=str(Path(ROOT.name)/p.relative_to(ROOT)))
with zipfile.ZipFile(dest) as archive:
    assert archive.testzip() is None
    names=archive.namelist()
    assert not any('__pycache__' in p or p.endswith(('.deb','.qcow2','.pem','.key')) for p in names)
digest=hashlib.sha256(dest.read_bytes()).hexdigest()
Path(str(dest)+'.sha256').write_text(digest+'  '+dest.name+'\n')
print('ZIP verificado: '+str(dest))
print('Archivos: '+str(len(names))+'; bytes: '+str(dest.stat().st_size))
print('SHA256: '+digest)
