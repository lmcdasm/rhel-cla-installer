#!/usr/bin/env bash
# Post-apply checks for the Ansible k8s lab deploy on the current oc context.
set -euo pipefail

NS="${NS:-rhel-cla-system}"
GRANITE_URL="${GRANITE_URL:-http://10.20.1.200:8000/v1/models}"
FAIL=0

echo "==> Context: $(oc config current-context)"
echo "==> Namespace: ${NS}"

echo "==> Deployments"
oc -n "${NS}" get deploy -o wide || FAIL=1

echo "==> Pods"
oc -n "${NS}" get pods -o wide || FAIL=1

echo "==> PVC"
oc -n "${NS}" get pvc || true

echo "==> Secrets present (names only)"
oc -n "${NS}" get secret redhat-pull-secret okp-access-key -o custom-columns=NAME:.metadata.name,TYPE:.type --no-headers || FAIL=1

HOST=$(oc -n "${NS}" get route lightspeed-stack -o jsonpath='{.spec.host}' 2>/dev/null || true)
echo "==> Route host: ${HOST:-<missing>}"
if [[ -n "${HOST}" ]]; then
  echo "==> Liveness via route"
  if curl -skf --connect-timeout 10 "https://${HOST}/api/lightspeed/liveness"; then
    echo
  else
    echo "WARN: route liveness failed (pod may still be pulling/starting)" >&2
    FAIL=1
  fi
fi

echo "==> Lab Granite reachability from this workstation (${GRANITE_URL})"
if curl -sf --connect-timeout 5 "${GRANITE_URL}" >/dev/null; then
  echo "OK: Granite /v1/models reachable from here"
else
  echo "WARN: cannot reach Granite from this host (firewall/routing)." >&2
  echo "      OCP nodes may still reach it — check with:" >&2
  echo "      oc -n ${NS} run granite-check --rm -i --restart=Never --image=registry.access.redhat.com/ubi9/ubi-minimal -- curl -sf ${GRANITE_URL}" >&2
fi

echo "==> In-cluster DNS (RKB -> OKP) once pods are Ready"
RKB=$(oc -n "${NS}" get pod -l app=rhel-knowledge-bridge -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -n "${RKB}" ]]; then
  phase=$(oc -n "${NS}" get pod "${RKB}" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  if [[ "${phase}" == "Running" ]]; then
    oc -n "${NS}" exec "${RKB}" -- bash -c 'exec 3<>/dev/tcp/rh-offline-knowledge-portal/8983 && echo OK_solr_tcp || echo FAIL_solr_tcp' \
      2>/dev/null || echo "WARN: could not TCP-check OKP from RKB (image may lack bash)"
  else
    echo "RKB pod phase=${phase}; skip in-cluster check"
  fi
fi

if [[ "${FAIL}" -ne 0 ]]; then
  echo "verify: incomplete / not ready yet" >&2
  exit 1
fi
echo "verify: OK"
