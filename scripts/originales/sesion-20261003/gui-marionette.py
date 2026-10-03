#!/usr/bin/env python3
"""Use the auxiliary node's visible Firefox GUI when agent-browser is absent."""
import base64
import getpass
import json
import socket
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sock = socket.create_connection(("127.0.0.1", 2828), 5)
sock.settimeout(35)
sequence = 0

def read_frame():
    header = bytearray()
    while True:
        b = sock.recv(1)
        if not b:
            raise RuntimeError("Marionette closed the connection")
        if b == b":":
            break
        header.extend(b)
    length = int(header)
    data = bytearray()
    while len(data) < length:
        data.extend(sock.recv(length - len(data)))
    return json.loads(data)

def command(name, params=None):
    global sequence
    sequence += 1
    body = json.dumps([0, sequence, name, params or {}]).encode()
    sock.sendall(str(len(body)).encode() + b":" + body)
    response = read_frame()
    if response[2]:
        raise RuntimeError(response[2].get("message", response[2].get("error")))
    return response[3]

def script(code):
    result = command("WebDriver:ExecuteScript", {"script": code, "args": [], "newSandbox": True})
    return result.get("value", result) if isinstance(result, dict) else result

print(json.dumps({"greeting": read_frame()}), flush=True)
admin_password = getpass.getpass("FortiGate admin password (hidden): ")
command("WebDriver:NewSession", {"capabilities": {"alwaysMatch": {"acceptInsecureCerts": True}}})
print("Visible auxiliary Firefox GUI connected", flush=True)

for line in sys.stdin:
    try:
        request = json.loads(line)
        op = request["op"]
        if op == "snapshot":
            result = script("return {url: location.href, title: document.title, text: document.body.innerText, "
                            "elements: Array.from(document.querySelectorAll('input,button,a')).map(e => "
                            "({tag:e.tagName,id:e.id,name:e.name,type:e.type,text:e.innerText," 
                            "href:e.getAttribute('href'),placeholder:e.getAttribute('placeholder')}))};")
            print(json.dumps(result), flush=True)
        elif op == "eval":
            print(json.dumps(script(request["script"])), flush=True)
        elif op == "fill":
            selector = request["selector"]
            result = command("WebDriver:FindElement", {"using": "css selector", "value": selector})
            element = result.get("value", result)
            element_id = element.get("element-6066-11e4-a52e-4f735466cecf", element.get("ELEMENT"))
            value = request.get("value", "")
            if request.get("secret"):
                value = admin_password
            command("WebDriver:ElementSendKeys", {"id": element_id, "text": value})
            print("Input filled" if not request.get("secret") else "Protected input filled", flush=True)
        elif op == "click":
            result = command("WebDriver:FindElement", {"using": "css selector", "value": request["selector"]})
            element = result.get("value", result)
            element_id = element.get("element-6066-11e4-a52e-4f735466cecf", element.get("ELEMENT"))
            command("WebDriver:ElementClick", {"id": element_id})
            print("GUI click completed", flush=True)
        elif op == "navigate":
            command("WebDriver:Navigate", {"url": request["url"]})
            print("GUI navigation completed", flush=True)
        elif op == "screenshot":
            result = command("WebDriver:TakeScreenshot", {"full": True})
            encoded = result.get("value", result) if isinstance(result, dict) else result
            path = ROOT / request.get("name", "fortigate-gui.png")
            path.write_bytes(base64.b64decode(encoded))
            print(str(path), flush=True)
        elif op == "close":
            command("WebDriver:DeleteSession")
            sock.close()
            print("GUI automation session closed", flush=True)
            break
    except Exception as error:
        print(json.dumps({"error": str(error)}), flush=True)
