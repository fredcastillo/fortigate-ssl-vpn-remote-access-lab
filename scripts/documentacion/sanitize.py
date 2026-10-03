#!/usr/bin/env python3
"""Redactar credenciales de exports, conservando red y políticas.

No ejecutar una configuración sanitizada como reemplazo de un backup privado.
"""
import argparse
import re
from pathlib import Path

def sanitize(text):
    text = re.sub(r'(?ims)^(\s*set (?:private-key|password|passwd|psksecret|secret|passphrase|ca-password))\s+".*?"\s*$', r'\1 "[REDACTED]"', text)
    text = re.sub(r'(?im)^(\s*set\s+\S*(?:password|passwd|psksecret|secret|token)\S*)\s+.*$', r'\1 "[REDACTED]"', text)
    text = re.sub(r'(?im)^(username\s+\S+.*?\s+(?:secret|password))\s+.*$', r'\1 [REDACTED]', text)
    text = re.sub(r'(?im)^(\s*(?:enable (?:secret|password)|password|snmp-server community|crypto isakmp key))\s+.*$', r'\1 [REDACTED]', text)
    text = re.sub(r'(?s)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----.*?-----END (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', '[PRIVATE KEY REDACTED]', text)
    text = re.sub(r'(?m)^.*\[7m--More--.*\n?', '', text)
    text = re.sub(r'\x1b\[[0-9;?]*[A-Za-z]', '', text)
    text = re.sub(r'--More--\s*\x08*', '', text).replace('\x08','')
    return text

if __name__ == '__main__':
    p=argparse.ArgumentParser(); p.add_argument('source'); p.add_argument('dest'); a=p.parse_args()
    Path(a.dest).write_text(sanitize(Path(a.source).read_text()))
    print('Export sanitizado guardado.')
