#!/usr/bin/env bash
# Seed OpenShift secrets for rhel-cla-system from the live RHEL Quadlet host.
# Defaults match the lab box used as the source of truth for this MVP.
set -euo pipefail

NS="${NS:-rhel-cla-system}"
RHEL_HOST="${RHEL_HOST:-dasm@10.20.1.200}"
RHEL_PASS="${RHEL_PASS:-}"
INSTALLER_DIR="${INSTALLER_DIR:-/home/dasm/rhel-cla-installer}"
AUTH_PATH="${AUTH_PATH:-/etc/containers/auth.json}"
HOSTS_YML="${HOSTS_YML:-${INSTALLER_DIR}/inventory/hosts.yml}"
OKP_UNIT="${OKP_UNIT:-/etc/containers/systemd/rh-offline-knowledge-portal.container}"
WORKDIR="${WORKDIR:-$(mktemp -d /tmp/cla-seed.XXXXXX)}"

cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

echo "==> Namespace: ${NS}"
oc get ns "${NS}" >/dev/null 2>&1 || oc create ns "${NS}"

# Password SSH helper — writes remote stdout to a file (avoids nested heredoc hell).
ssh_capture() {
  local remote_cmd=$1
  local out_file=$2
  python3 - "$RHEL_HOST" "${RHEL_PASS}" "${remote_cmd}" "${out_file}" <<'PY'
import pty, os, select, sys, time
host, password, cmd, out_file = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
argv = [
    "ssh",
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "PreferredAuthentications=password",
    "-o", "PubkeyAuthentication=no",
    host,
    cmd,
]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(argv[0], argv)
out = b""
sent = False
end = time.time() + 90
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
            os.write(fd, (password + "\n").encode())
            sent = True
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
text = out.decode("utf-8", "ignore")
lines = [l for l in text.splitlines() if "password:" not in l.lower()]
open(out_file, "w").write("\n".join(lines) + "\n")
PY
}

if [[ -z "${RHEL_PASS}" ]]; then
  echo "ERROR: set RHEL_PASS for password SSH to ${RHEL_HOST}" >&2
  echo "  (or extend this script for key-based SSH)" >&2
  exit 1
fi

echo "==> Fetching registry auth from ${RHEL_HOST}:${AUTH_PATH}"
ssh_capture "echo ${RHEL_PASS} | sudo -S cat ${AUTH_PATH} 2>/dev/null" "${WORKDIR}/auth.json"
python3 -c 'import json,sys; json.load(open(sys.argv[1])); print("auth.json OK")' "${WORKDIR}/auth.json"

python3 - "${WORKDIR}/auth.json" "${WORKDIR}/dockerconfig.json" <<'PY'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
data = json.load(open(src))
if "auths" not in data:
    raise SystemExit("auth.json missing auths map")
json.dump({"auths": data["auths"]}, open(dst, "w"))
print("wrote", dst, "registries:", sorted(data["auths"]))
PY

echo "==> Creating/updating pull secret redhat-pull-secret"
oc -n "${NS}" create secret docker-registry redhat-pull-secret \
  --from-file=.dockerconfigjson="${WORKDIR}/dockerconfig.json" \
  --dry-run=client -o yaml | oc apply -f -

echo "==> Fetching OKP ACCESS_KEY (prefer live Quadlet unit, fallback inventory)"
ssh_capture "echo ${RHEL_PASS} | sudo -S cat ${OKP_UNIT} 2>/dev/null; echo '---HOSTS---'; cat ${HOSTS_YML} 2>/dev/null" "${WORKDIR}/okp-src.txt"
python3 - "${WORKDIR}/okp-src.txt" "${WORKDIR}/okp_key.txt" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
key = None
m = re.search(r"ACCESS_KEY=(\S+)", text)
if m:
    key = m.group(1)
if not key:
    m = re.search(r"okp_access_key:\s*[\"']?([^\"'\s]+)", text)
    if m:
        key = m.group(1)
if not key or key == "~":
    raise SystemExit("could not find ACCESS_KEY / okp_access_key")
open(sys.argv[2], "w").write(key)
print("okp key length", len(key))
PY

echo "==> Creating/updating secret okp-access-key"
oc -n "${NS}" create secret generic okp-access-key \
  --from-file=ACCESS_KEY="${WORKDIR}/okp_key.txt" \
  --dry-run=client -o yaml | oc apply -f -

echo "==> Linking pull secret to default + workload SAs"
for sa in default rh-offline-knowledge-portal rhel-knowledge-bridge lightspeed-stack; do
  if oc -n "${NS}" get sa "${sa}" >/dev/null 2>&1; then
    oc -n "${NS}" patch sa "${sa}" -p '{"imagePullSecrets":[{"name":"redhat-pull-secret"}]}' >/dev/null
  fi
done

echo "Done. Secrets ready in ${NS}."
# Note: Ansible SA templates also set imagePullSecrets when cla_pull_secret_name is set.
