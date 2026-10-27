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
WORKDIR="${WORKDIR:-$(mktemp -d /tmp/cla-seed.XXXXXX)}"

cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

echo "==> Namespace: ${NS}"
oc get ns "${NS}" >/dev/null 2>&1 || oc create ns "${NS}"

ssh_rhel() {
  local cmd=$1
  if [[ -n "${RHEL_PASS}" ]]; then
    python3 - "$RHEL_HOST" "$RHEL_PASS" "$cmd" <<'PY'
import pty, os, select, sys, time
host, password, cmd = sys.argv[1], sys.argv[2]+"\n", sys.argv[3]
argv = ["ssh","-o","StrictHostKeyChecking=accept-new","-o","PreferredAuthentications=password","-o","PubkeyAuthentication=no",host, cmd]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(argv[0], argv)
out = b""; sent = False; end = time.time() + 90
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
text = out.decode("utf-8", "ignore")
lines = [l for l in text.splitlines() if "password:" not in l.lower()]
sys.stdout.write("\n".join(lines) + ("\n" if lines else ""))
PY
  else
    ssh -o StrictHostKeyChecking=accept-new "${RHEL_HOST}" "${cmd}"
  fi
}

echo "==> Fetching registry auth from ${RHEL_HOST}:${AUTH_PATH}"
ssh_rhel "echo ${RHEL_PASS:-} | sudo -S cat ${AUTH_PATH} 2>/dev/null" > "${WORKDIR}/auth.json"
python3 -c 'import json,sys; json.load(open(sys.argv[1])); print("auth.json OK")' "${WORKDIR}/auth.json"

# Convert containers/auth.json (auths) into a dockerconfigjson secret
python3 - "${WORKDIR}/auth.json" "${WORKDIR}/dockerconfig.json" <<'PY'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
data = json.load(open(src))
# already docker-compatible if it has auths
if "auths" not in data:
    raise SystemExit("auth.json missing auths map")
json.dump({"auths": data["auths"]}, open(dst, "w"))
print("wrote", dst, "registries:", sorted(data["auths"]))
PY

echo "==> Creating/updating pull secret redhat-pull-secret"
oc -n "${NS}" create secret docker-registry redhat-pull-secret \
  --from-file=.dockerconfigjson="${WORKDIR}/dockerconfig.json" \
  --dry-run=client -o yaml | oc apply -f -

echo "==> Fetching okp_access_key from ${HOSTS_YML}"
OKP_KEY=$(ssh_rhel "python3 - <<'PY'
import re, pathlib
text = pathlib.Path('${HOSTS_YML}').read_text()
m = re.search(r'okp_access_key:\\s*[\"\\']?([^\"\\'\\s]+)', text)
if not m:
    raise SystemExit('okp_access_key not found')
print(m.group(1))
PY")
if [[ -z "${OKP_KEY}" || "${OKP_KEY}" == "~" ]]; then
  echo "ERROR: could not read okp_access_key from inventory" >&2
  exit 1
fi

echo "==> Creating/updating secret okp-access-key"
oc -n "${NS}" create secret generic okp-access-key \
  --from-literal=ACCESS_KEY="${OKP_KEY}" \
  --dry-run=client -o yaml | oc apply -f -

echo "==> Linking pull secret to default SA as well"
oc -n "${NS}" patch sa default --type=json \
  -p='[{"op":"add","path":"/imagePullSecrets/-","value":{"name":"redhat-pull-secret"}}]' \
  2>/dev/null || oc -n "${NS}" patch sa default -p '{"imagePullSecrets":[{"name":"redhat-pull-secret"}]}'

echo "Done. Secrets ready in ${NS}."
