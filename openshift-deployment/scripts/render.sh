#!/usr/bin/env bash
# Dump rendered k8s manifests via Ansible (same templates/vars as apply).
# Output is review-only — never edit generated/ by hand.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT}/.." && pwd)"
LAB_VARS="${ROOT}/lab-vars.yml"
OUT="${ROOT}/generated"
export ANSIBLE_CONFIG="${REPO_ROOT}/ansible.cfg"

mkdir -p "${OUT}"
rm -f "${OUT}"/*.yml

cd "${REPO_ROOT}"
ansible-playbook -i localhost, -c local \
  "${ROOT}/scripts/render-playbook.yml" \
  -e @"${LAB_VARS}" \
  -e "cla_render_dir=${OUT}"

echo "==> Rendered manifests in ${OUT}"
ls -la "${OUT}"
