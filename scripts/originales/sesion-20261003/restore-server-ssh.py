#!/usr/bin/env python3
"""Restore SSH on the existing web node, with a backup and a lab key."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent
def container(name):
    ids = subprocess.check_output(["docker", "ps", "-q", "--filter", "name=" + name]).decode().split()
    if len(ids) != 1:
        raise SystemExit("Expected exactly one running container: " + name)
    return ids[0]

SERVER = container("GNS3.web-server-lab-1.ea145aa2-7392-4eb2-b990-4b81dd21a346")
CLIENT = container("GNS3.CLIENTE-FORTICLIENT-1.ea145aa2-7392-4eb2-b990-4b81dd21a346")
BACKUP = "lab-backup/web-pre-ssh:20261003"

def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)

def main():
    probe = subprocess.run(["docker", "image", "inspect", BACKUP], capture_output=True)
    if probe.returncode == 0:
        raise SystemExit("Backup already exists; inspect current state before repeating")
    (ROOT / "web-before.inspect.json").write_bytes(
        subprocess.check_output(["docker", "inspect", SERVER])
    )
    run("docker", "cp", SERVER + ":/start-network.sh", str(ROOT / "web-start-before.sh"))
    run("docker", "commit", "--no-pause", SERVER, BACKUP)
    run("docker", "cp", "/home/gns3/ssh-debs", SERVER + ":/tmp/lab-ssh-debs")
    run("docker", "exec", "-e", "DEBIAN_FRONTEND=noninteractive", SERVER,
        "sh", "-c", "dpkg -i /tmp/lab-ssh-debs/*.deb")
    run("docker", "exec", SERVER, "sh", "-c",
        "getent passwd labssh >/dev/null || useradd -m -s /bin/bash labssh")
    run("docker", "exec", "-u", "vpnuser", CLIENT, "sh", "-c",
        "umask 077; mkdir -p /home/vpnuser/.ssh; "
        "test -f /home/vpnuser/.ssh/id_ed25519 || "
        "ssh-keygen -q -t ed25519 -N '' -C gns3-lab-ssl-vpn "
        "-f /home/vpnuser/.ssh/id_ed25519")
    public_key = subprocess.check_output([
        "docker", "exec", "-u", "vpnuser", CLIENT,
        "cat", "/home/vpnuser/.ssh/id_ed25519.pub"
    ])
    run("docker", "exec", SERVER, "install", "-d", "-m", "700",
        "-o", "labssh", "-g", "labssh", "/home/labssh/.ssh")
    run("docker", "exec", "-i", SERVER, "sh", "-c",
        "umask 077; cat >> /home/labssh/.ssh/authorized_keys; "
        "chown labssh:labssh /home/labssh/.ssh/authorized_keys; "
        "chmod 600 /home/labssh/.ssh/authorized_keys", input=public_key)
    previous = (ROOT / "web-start-before.sh").read_text()
    marker = "service apache2 start\n"
    if previous.count(marker) != 1:
        raise SystemExit("Unexpected startup script: refusing to edit")
    changed = previous.replace(marker, "mkdir -p /run/sshd\n/usr/sbin/sshd -t\n"
                               "/usr/sbin/sshd\n\n" + marker, 1)
    output = ROOT / "web-start-with-ssh.sh"
    output.write_text(changed)
    run("docker", "cp", str(output), SERVER + ":/start-network.sh")
    run("docker", "exec", SERVER, "chmod", "755", "/start-network.sh")
    run("docker", "exec", SERVER, "mkdir", "-p", "/run/sshd")
    run("docker", "exec", SERVER, "/usr/sbin/sshd", "-t")
    run("docker", "exec", SERVER, "/usr/sbin/sshd")
    run("docker", "exec", SERVER, "ss", "-lnt")

if __name__ == "__main__":
    main()
