#!/usr/bin/env bash
# Lab-only: republish Granite Quadlet on 0.0.0.0:8000 so OCP pods can reach
# http://10.20.1.200:8000/v1. Does not change the repo's setup-granite-quadlet.sh;
# it only patches the running user Quadlet on the RHEL lab host.
set -euo pipefail

RHEL_HOST="${RHEL_HOST:-dasm@10.20.1.200}"
RHEL_PASS="${RHEL_PASS:-}"
UNIT="${UNIT:-${HOME}/.config/containers/systemd/granite.container}"
# On the remote host the path is relative to that user
REMOTE_UNIT="${REMOTE_UNIT:-/home/dasm/.config/containers/systemd/granite.container}"

ssh_rhel() {
  local cmd=$1
  if [[ -n "${RHEL_PASS}" ]]; then
    python3 - "$RHEL_HOST" "$RHEL_PASS" "$cmd" <<'PY'
import pty, os, select, sys, time
host, password, cmd = sys.argv[1], sys.argv[2]+"\n", sys.argv[3]
argv = ["ssh","-tt","-o","StrictHostKeyChecking=accept-new","-o","PreferredAuthentications=password","-o","PubkeyAuthentication=no",host, cmd]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(argv[0], argv)
out = b""; sent = False; end = time.time() + 120
while time.time() < end:
    r, _, _ = select.select([fd], [], [], 1)
    if fd in r:
        try:
            chunk = os.read(fd, 8192)
        except OSError:
            break
        if not chunk:
            break
        out += chunk
        if (not sent) and b"assword:" in out.lower():
            os.write(fd, password.encode()); sent = True
    wpid, _ = os.waitpid(pid, os.WNOHANG)
    if wpid:
        while True:
            r, _, _ = select.select([fd], [], [], 0.2)
            if fd not in r:
                break
            try:
                chunk = os.read(fd, 8192)
            except OSError:
                break
            if not chunk:
                break
            out += chunk
        break
sys.stdout.write(out.decode("utf-8", "ignore"))
PY
  else
    ssh -tt -o StrictHostKeyChecking=accept-new "${RHEL_HOST}" "${cmd}"
  fi
}

echo "==> Patching PublishPort on ${RHEL_HOST}:${REMOTE_UNIT}"
ssh_rhel "python3 - <<'PY'
from pathlib import Path
p = Path('${REMOTE_UNIT}')
text = p.read_text()
old = 'PublishPort=127.0.0.1:8000:8000'
new = 'PublishPort=8000:8000'
if old not in text and 'PublishPort=8000:8000' in text:
    print('already exposed on 0.0.0.0:8000')
else:
    if old not in text:
        raise SystemExit('expected PublishPort line not found')
    p.write_text(text.replace(old, new, 1))
    print('updated', p)
PY
systemctl --user daemon-reload
systemctl --user restart granite.service
sleep 2
ss -lntp | grep 8000 || true
curl -sf http://127.0.0.1:8000/v1/models | head -c 200
echo
"

echo "==> Verify from this workstation (LAN)"
curl -sf --connect-timeout 5 "http://10.20.1.200:8000/v1/models" | head -c 300 || {
  echo "WARN: LAN reachability to 10.20.1.200:8000 failed — check firewall/firewalld" >&2
  exit 1
}
echo
echo "Granite is reachable for OCP option-B inference."
