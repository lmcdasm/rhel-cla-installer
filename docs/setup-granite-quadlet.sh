#!/usr/bin/env bash
# Install Granite 4.1 8B Q4_1 as a persistent RamaLama/Podman Quadlet (CPU).
# Target API: http://127.0.0.1:8000/v1  (matches ramalama_config.base_url locally)
set -euo pipefail

NAME="${NAME:-granite}"
PORT="${PORT:-8000}"
IMAGE="${IMAGE:-quay.io/ramalama/ramalama:latest}"
MODEL="${MODEL:-hf://ibm-granite/granite-4.1-8b-GGUF:Q4_1}"
QUADLET_DIR="${QUADLET_DIR:-${HOME}/.config/containers/systemd}"

echo "==> Checking prerequisites"
command -v podman >/dev/null || { echo "podman is required"; exit 1; }
command -v ramalama >/dev/null || { echo "ramalama is required (curl -fsSL https://ramalama.ai/install.sh | bash)"; exit 1; }

echo "==> Ensuring Quadlet directory exists: ${QUADLET_DIR}"
mkdir -p "${QUADLET_DIR}"

# Stop a one-off container with the same name if present
if podman container exists "${NAME}" 2>/dev/null; then
  echo "==> Stopping existing container '${NAME}'"
  ramalama stop "${NAME}" 2>/dev/null || podman stop "${NAME}" 2>/dev/null || true
  podman rm -f "${NAME}" 2>/dev/null || true
fi

echo "==> Pulling model (first run can take a while): ${MODEL}"
ramalama pull "${MODEL}"

echo "==> Generating Quadlet into ${QUADLET_DIR}"
ramalama serve \
  --name "${NAME}" \
  --port "${PORT}" \
  --image "${IMAGE}" \
  --generate="quadlet:${QUADLET_DIR}" \
  "${MODEL}"

UNIT="${NAME}.container"
if [[ ! -f "${QUADLET_DIR}/${UNIT}" ]]; then
  # Some RamaLama versions write into CWD; relocate if needed
  if [[ -f "./${UNIT}" ]]; then
    mv "./${UNIT}" "${QUADLET_DIR}/${UNIT}"
  else
    echo "ERROR: expected ${QUADLET_DIR}/${UNIT} was not generated"
    ls -la "${QUADLET_DIR}" || true
    exit 1
  fi
fi

echo "==> Enabling lingering so user Quadlets survive logout/reboot"
loginctl enable-linger "$(id -un)" 2>/dev/null || \
  echo "WARN: could not enable linger (need root once: sudo loginctl enable-linger $(id -un))"

echo "==> Reloading and starting user service: ${NAME}.service"
systemctl --user daemon-reload
systemctl --user enable --now "${NAME}.service"

echo "==> Status"
systemctl --user --no-pager status "${NAME}.service" || true
podman ps --filter "name=${NAME}"

echo
echo "==> Smoke test"
sleep 2
curl -sf "http://127.0.0.1:${PORT}/v1/models" | (command -v jq >/dev/null && jq . || cat) || \
  echo "WARN: /v1/models not ready yet — check: journalctl --user -u ${NAME}.service -f"

echo
echo "Done. Inventory tip:"
echo "  base_url: http://127.0.0.1:${PORT}/v1"
echo "  default_model: use the id from /v1/models (often granite-4.1-8b-Q4_1)"
echo
echo "Ops:"
echo "  systemctl --user status ${NAME}"
echo "  systemctl --user restart ${NAME}"
echo "  journalctl --user -u ${NAME}.service -f"
echo "  podman logs -f ${NAME}"
