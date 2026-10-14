#!/bin/bash

set -eu

CONTAINER_RUNTIME=${CONTAINER_RUNTIME:-$(command -v podman || command -v docker)}
if [[ -z "$CONTAINER_RUNTIME" ]]; then
    echo "Error: neither podman nor docker is available; set CONTAINER_RUNTIME explicitly." >&2
    exit 1
fi

IMAGE=${IMAGE:-quay.io/redhat-user-workloads/rhel-lightspeed-tenant/rhel-cla-installer:latest}

if [[ ! -d local ]]; then
    mkdir local
fi

if [[ -f local/rhel-cla-installer ]]; then
    rm -f local/rhel-cla-installer
fi

# Copy the zipapp and config to container host
echo "Extracting installer from container..."
"$CONTAINER_RUNTIME" run --rm -i --entrypoint sh "$IMAGE" -c 'tar -cf - rhel-cla-installer' | tar -C local -xf -

if [[ ! -f local/ansible.cfg ]]; then
    echo "Extracting ansible.cfg from container..."
    "$CONTAINER_RUNTIME" run --rm -i --entrypoint sh "$IMAGE" -c 'tar -cf - ansible.cfg' | tar -C local -xf -
fi

echo "Installer extracted to local/rhel-cla-installer."
