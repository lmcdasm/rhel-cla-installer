# How to set up a local Granite instance #

Run Granite in a RamaLama/Podman container on CPU, serving an OpenAI-compatible API at
`http://<host>:8000/v1` so RHEL CLA can use it as the `ramalama` provider.

For a public lab endpoint later, point inventory at `https://granite.dasmlab.org/v1`
after TLS and a reverse proxy are in place.

## 1. Host prep (RHEL) ##

```
sudo dnf install -y podman
curl -fsSL https://ramalama.ai/install.sh | bash
ramalama version
podman info >/dev/null
```

Rough sizing for `granite-4.1-8b-Q4_1`:

- ~8–12 GB RAM free (model ~5.6 GB plus runtime headroom)
- ~10 GB disk for model and image

## 2. Force CPU (skip GPU discovery) ##

Use the CPU/Vulkan-capable base image explicitly:

```
export RAMALAMA_IMAGE=quay.io/ramalama/ramalama:latest
```

Optional sanity-check chat (downloads the model on first run):

```
ramalama run --image quay.io/ramalama/ramalama:latest \
  hf://ibm-granite/granite-4.1-8b-GGUF:Q4_1
```

Quit with `/bye` or Ctrl+D once you get a coherent reply.

## 3. Serve OpenAI-compatible API ##

```
ramalama serve -d \
  --name granite \
  --port 8000 \
  --image quay.io/ramalama/ramalama:latest \
  hf://ibm-granite/granite-4.1-8b-GGUF:Q4_1
```

That gives you:

- API base: `http://127.0.0.1:8000/v1`
- Model id for clients: typically whatever RamaLama registers (often a short or
  file-derived name — confirm with the models list in the next step)

## 4. Verify ##

```
podman ps
curl -s http://127.0.0.1:8000/v1/models | jq .
curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer sk-no-key-required' \
  -d '{
    "model": "granite-4.1-8b-Q4_1",
    "messages": [{"role":"user","content":"Say hello in one sentence."}],
    "max_tokens": 64
  }' | jq .
```

If `model` returns 404, copy the exact id from `/v1/models` into inventory
`default_model`.

## 5. Align `hosts.yml` for local first ##

```yaml
rhel_cla_provider: ramalama
ramalama_config:
  default_model: granite-4.1-8b-Q4_1   # or exact id from /v1/models
  api_key: sk-no-key-required
  base_url: http://127.0.0.1:8000/v1   # switch to https://granite.dasmlab.org/v1 after TLS/proxy
```

See `inventory/hosts.example.yml` for the full example shape.

## Useful ops ##

```
ramalama stop granite      # or: podman stop granite
ramalama list              # cached models
podman logs -f granite
```

## Notes ##

- This path is RamaLama + Podman + Granite GGUF for a local MVP. It does not install
  full RHEL AI appliance components.
- The first pull is slow (container image plus ~5.6 GB GGUF).
- CPU inference is slower than GPU; that is fine for wiring CLA.
- After local verification, add a reverse proxy and TLS for
  `granite.dasmlab.org`, then flip `base_url`.
- Optional follow-up: a systemd/quadlet unit so the container survives reboot on
  the lab host.
