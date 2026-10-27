# Red Hat Enterprise Linux Command Line Assistant Installer #

This is the installer for the self-managed RHEL CLA. It supports local and remote installations. OpenShift support is still in development.

# Getting Started #

Follow these instructions to get started using the RHEL CLA installer.

See the [contributing] docs for information on project development and maintenance.

## Prerequisites ##

- RHEL 9.5 or later
- Python 3.11 or later
- [`podman`] 5 or later
- `tar`
- A [Red Hat Offline Knowledge Portal key][rhokp_key]
- 30GB of free disk space for the Red Hat Offline Knowledge Portal.
- Valid container registry login credentials in `/etc/containers/auth.json`.
- If using a provider that requires credentials stored in a file, create the secret in `podman`.
- `sudo` permissions on all systems where RHEL CLA will be installed. This includes when installing locally.

**Note (RHEL 9.x only):** The platform `python3` on RHEL 9 is 3.9 and is required by `dnf` and other system tooling.
Do **not** remove Python 3.9. Install 3.11 alongside it and point the installer at 3.11:

```
sudo dnf install -y python3.11 python3.11-pip python3.11-devel
python3 --version       # stays 3.9 (system) — expected
python3.11 --version    # 3.11.x

export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3.11
python3.11 ./rhel-cla-installer -K rhel.cla.local
```

Optional (user shell only — does not replace the system Python):

```
echo 'alias python3=python3.11' >> ~/.bashrc
echo 'export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3.11' >> ~/.bashrc
source ~/.bashrc
```

Prefer `python3.11` / `ANSIBLE_PYTHON_INTERPRETER` over changing the system
`/usr/bin/python3` via `alternatives`, so platform tools keep using 3.9.
This note does not apply to RHEL 10+, where the system Python is already newer.

Create the container registry login credentials. This needs to be done on both local and remote systems, or the auth file can be generated once and copied to remote systems.

```
sudo podman login --authfile /etc/containers/auth.json registry.redhat.io
```

If necessary for your inference provider, create a `podman` secret. See `inventory/hosts.example.yml` for details.

```
sudo podman secret create [secret name] [path to file]
```

Set the secret name in the inventory variables for our provider.
```yaml
vertex_config:
  default_model: publishers/google/models/gemini-2.5-flash
  credentials_secret_name: secret_name
  project_id: my_project
  location: global
```


## Local Installation ##

1. Create a directory for the installer and its configuration.

    ```
    mkdir rhel-cla-installer
    cd rhel-cla-installer
    ```

1. Extract the installer from the container image in order to run it against `localhost`.

    ```
    export IMAGE=quay.io/redhat-user-workloads/rhel-lightspeed-tenant/rhel-cla-installer
    podman run --rm -i --entrypoint sh "$IMAGE" -c 'tar -cf - ansible.cfg rhel-cla-installer' | tar -xf -
    ```

    If you have not yet created an inventory, extract the example inventory as a starting point. This will overwrite existing inventory without warning.

    ```
    podman run --rm -i --entrypoint sh "$IMAGE" -c 'tar -cf - inventory' | tar -xf -
    ```

1. Update the variables in `inventory/hosts.yml`, such as `okp_access_key`. Some variables depend on the external provider.

    If using RamaLama with a local Granite model, see [How to set up a local Granite instance][local_granite].

1. Run the installer. If a password is required for `sudo`, add the `-K` option and enter the password when prompted.

    **Note**: Do not run the installer using `sudo`. Run it as a normal account with `sudo` privileges.

    On RHEL 9.x, launch with Python 3.11 (see Prerequisites). Do not remove the system Python 3.9.

    ```
    export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3.11
    python3.11 ./rhel-cla-installer -K rhel.cla.local
    ```

    On hosts where `python3` is already 3.11+:

    ```
    ./rhel-cla-installer rhel.cla.local
    ```

    Adjust verbosity by adding `-v`. More v's give more verbosity.

    **Note (OKP / Offline Knowledge Portal):** The RHOKP image is large. The
    installer often sits on `TASK [rhel.cla.okp : Start RHOKP]` for 10–30+ minutes
    on a VM disk while Podman pulls and extracts the image. That is normal —
    be patient. Do **not** Ctrl+C unless the pull process is gone and the unit
    is `failed`.

    When the image unit goes `active`/`dead` (success), the portal service should
    start and the Ansible task should flip to `ok`/`changed`.

    To watch progress in another terminal while that task is running:

    ```
    # still pulling/extracting?
    pgrep -a 'pigz|storage-untar|podman image pull'
    # or inspect a specific PID from the output above:
    # ps -p <pid> -o etime,pcpu,pmem,cmd

    # when the pull finishes you should see the image listed:
    sudo podman images | grep rhokp
    ```

### Verify Installation ###

Check the pod and container status.

```
sudo systemctl status rhel-cla-pod.service
sudo systemctl status rhel-knowledge-bridge.service
sudo systemctl status rh-offline-knowledge-portal.service
sudo systemctl status lightspeed-stack.service
```

Look at logs in the running containers.

```
sudo journalctl -f -u lightspeed-stack -u rhel-knowledge-bridge -u rh-offline-knowledge-portal
```

Test the local API.

```
curl http://localhost:8080/api/lightspeed/liveness
```

### Uninstall ###

Run `./rhel-cla-installer rhel.cla.local_uninstall`

This will keep container images on the system by default. To remove container images, set `remove_images=yes`

```
./rhel-cla-installer rhel.cla.local_uninstall -e remove_images=yes
```

### Client Configurations ###

#### Goose (goose-redhat)


1. Add the following to the `[backend]` section of `/etc/xdg/goose-proxy/config.toml`:

    ```toml
    endpoint = "http://127.0.0.1:8080/v1"
    ```

1. Restart the proxy.

    ```
    sudo systemctl restart goose-proxy
    ```

[`podman`]: https://podman.io/
[rhokp_key]: https://access.redhat.com/offline/access/
[contributing]: docs/contributing.md
[local_granite]: docs/local-granite-setup.md
