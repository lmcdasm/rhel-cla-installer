#!/usr/bin/env bash
# Apply the lab overlay to the current oc context (expect 2026-prod-1).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS="${NS:-rhel-cla-system}"
OVERLAY="${OVERLAY:-${ROOT}/overlays/lab}"

echo "==> Current context: $(oc config current-context)"
echo "==> Applying ${OVERLAY} into ${NS}"
oc apply -k "${OVERLAY}"

echo "==> Waiting for deployments"
for d in rh-offline-knowledge-portal rhel-knowledge-bridge lightspeed-stack; do
  oc -n "${NS}" rollout status "deployment/${d}" --timeout=600s
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
