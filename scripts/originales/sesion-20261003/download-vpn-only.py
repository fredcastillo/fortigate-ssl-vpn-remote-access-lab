#!/usr/bin/env python3
"""Download the official VPN-only package without overwriting existing files."""
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import hashlib
import json
import time
import urllib.request

ROOT = Path(__file__).resolve().parent
URL = "https://links.fortinet.com/forticlient/deb/vpnagent"
DEST = ROOT / "forticlient-vpn-official.deb"
PARTS = ROOT / "download-parts"

def main():
    if DEST.exists():
        raise SystemExit("Destination already exists; refusing to overwrite it")
    with urllib.request.urlopen(urllib.request.Request(URL, method="HEAD"), timeout=30) as response:
        resolved = response.url
        size = int(response.headers["Content-Length"])
    if not resolved.startswith("https://filestore.fortinet.com/forticlient/"):
        raise SystemExit("Unexpected download origin")
    PARTS.mkdir(exist_ok=True)
    block = 4 * 1024 * 1024
    ranges = [(i, min(i + block - 1, size - 1)) for i in range(0, size, block)]

    def fetch(bounds):
        start, end = bounds
        target = PARTS / f"{start:012d}.part"
        if target.exists() and target.stat().st_size == end - start + 1:
            return target
        request = urllib.request.Request(resolved, headers={"Range": f"bytes={start}-{end}"})
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=30) as response:
                    expected = f"bytes {start}-{end}/{size}"
                    if response.status != 206 or response.headers.get("Content-Range") != expected:
                        raise RuntimeError("Server returned an unexpected byte range")
                    with target.open("wb") as output:
                        while chunk := response.read(256 * 1024):
                            output.write(chunk)
                if target.stat().st_size != end - start + 1:
                    raise RuntimeError("Incomplete download segment")
                return target
            except Exception:
                if attempt == 2:
                    raise
                time.sleep(1)

    with ThreadPoolExecutor(max_workers=8) as pool:
        for done, task in enumerate(as_completed([pool.submit(fetch, bounds) for bounds in ranges]), 1):
            task.result()
            print(f"Official download: {done}/{len(ranges)} segments verified", flush=True)
    with DEST.open("xb") as output:
        for start, _ in ranges:
            with (PARTS / f"{start:012d}.part").open("rb") as source:
                while chunk := source.read(1024 * 1024):
                    output.write(chunk)
    with DEST.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    metadata = {"source": URL, "resolved_url": resolved, "size": size, "sha256": digest}
    (ROOT / "download.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(json.dumps(metadata, indent=2), flush=True)

if __name__ == "__main__":
    main()
