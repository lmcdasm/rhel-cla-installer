#!/usr/bin/env bash
# Apply CLA stack to the current oc context via Ansible k8s roles.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT}/.." && pwd)"
NS="${NS:-rhel-cla-system}"
PLAYBOOK="${REPO_ROOT}/collections/ansible_collections/rhel/cla/playbooks/k8s.yml"
LAB_VARS="${ROOT}/lab-vars.yml"
export ANSIBLE_CONFIG="${REPO_ROOT}/ansible.cfg"

echo "==> Current context: $(oc config current-context)"
echo "==> Namespace: ${NS}"
echo "==> Playbook: ${PLAYBOOK}"
echo "==> Vars: ${LAB_VARS}"

if ! oc -n "${NS}" get secret okp-access-key >/dev/null 2>&1; then
  echo "WARN: secret/okp-access-key missing in ${NS}." >&2
  echo "      Run: RHEL_PASS=… make -C openshift-deployment seed" >&2
fi
if ! oc -n "${NS}" get secret redhat-pull-secret >/dev/null 2>&1; then
  echo "WARN: secret/redhat-pull-secret missing in ${NS}." >&2
  echo "      Run: RHEL_PASS=… make -C openshift-deployment seed" >&2
fi

cd "${REPO_ROOT}"
ansible-playbook -i localhost, -c local "${PLAYBOOK}" -e @"${LAB_VARS}"

echo "==> Waiting for deployments (OKP first boot can take a long time)"
for d in rh-offline-knowledge-portal rhel-knowledge-bridge lightspeed-stack; do
  oc -n "${NS}" rollout status "deployment/${d}" --timeout=3600s
done

echo "==> Route"
oc -n "${NS}" get route lightspeed-stack -o jsonpath='{.spec.host}{"\n"}' || true

echo "==> Pods"
oc -n "${NS}" get pods -o wide

HOST=$(oc -n "${NS}" get route lightspeed-stack -o jsonpath='{.spec.host}' 2>/dev/null || true)
if [[ -n "${HOST}" ]]; then
  echo "==> Liveness via route"
  curl -skf "https://${HOST}/api/lightspeed/liveness" || curl -skf "http://${HOST}/api/lightspeed/liveness" || true
  echo
fi
