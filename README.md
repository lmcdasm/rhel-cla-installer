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

### What now? (basic use cases) ###

Once the stack is up, a `curl` liveness check is only the start. Typical next steps:

#### 1. Open Lightspeed Core Stack in a browser ####

Browse to the published CLA port (default `8080`), for example
`http://<host>:8080`. You should see the **Lightspeed Core Stack** page with
links to Swagger UI and ReDoc.

#### 2. Install the `command-line-assistant` client ####

On this host, or any host that can reach the CLA API:

```
sudo dnf install -y command-line-assistant
```

Point the client at the **local CLA / Lightspeed API** (not Granite directly —
the Lightspeed stack is the front door):

```
sudoedit /etc/xdg/command-line-assistant/config.toml
```

Set something like:

```toml
endpoint = "http://127.0.0.1:8080/v1"
```

If that 404s, check which port the stack actually exposed
(`sudo podman ps` / installer defaults — sometimes another mapped port) and use
that host’s `/v1`.

Restart the client daemon if present:

```
sudo systemctl restart clad 2>/dev/null || true
```

#### 3. Use it ####

```
c "how do I check disk usage on RHEL?"
c "explain firewalld rich rules"
c "how do I enable linger for a user?"
```

That is the product loop: ask RHEL ops questions → local model + offline
knowledge answer, no cloud required.

#### 4. What each piece is for ####

| Piece | You use it for |
| --- | --- |
| `c "..."` client | Daily Q&A in the terminal |
| Lightspeed Core Stack (`:8080`) | CLA API front door (browser UI, client `endpoint`) |
| Granite (`:8000`) | LLM backend (usually invisible once CLA works) |
| OKP + knowledge bridge | Offline Red Hat knowledge glued into answers |

#### 5. Good first checks ####

```
c "what is SELinux enforcing mode and how do I check it?"
c "how do I list failed systemd units?"
```

#### Further reading ####

For more detailed install, config, and usage documentation:

**RHEL 9**

- Main guide (install / use / config):
  [Interacting with the command-line assistant powered by RHEL Lightspeed][cla_rhel9]
- Installing the client:
  [Installing the command-line assistant][cla_rhel9_install]
- Using `c` on RHEL systems:
  [Using the command-line assistant on RHEL systems][cla_rhel9_use]

**RHEL 10**

- Main guide:
  [Interacting with the command-line assistant powered by RHEL Lightspeed][cla_rhel10]
- Disconnected / containerized CLA (closest to what this installer deploys):
  [Containerized command-line assistant for disconnected environments][cla_rhel10_disconnected]

**Related**

- Offline Knowledge Portal:
  [Deploy / launch RHOKP][rhokp_docs]
- Dev preview overview (blog):
  [Use the RHEL command-line assistant offline][cla_offline_blog]
- Installer image (catalog):
  [rhel-cla/installer-rhel10][cla_installer_catalog]

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
[cla_rhel9]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/interacting_with_the_command-line_assistant_powered_by_rhel_lightspeed/index
[cla_rhel9_install]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/interacting_with_the_command-line_assistant_powered_by_rhel_lightspeed/installing-and-configuring-the-command-line-assistant-powered-by-rhel-lightspeed_using-command-line-assistant-to-manage-rhel-systems
[cla_rhel9_use]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/interacting_with_the_command-line_assistant_powered_by_rhel_lightspeed/using-the-command-line-assistant-powered-by-rhel-lightspeed-in-connected-rhel-systems_using-command-line-assistant-to-manage-rhel-systems
[cla_rhel10]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/interacting_with_the_command-line_assistant_powered_by_rhel_lightspeed/index
[cla_rhel10_disconnected]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/interacting_with_the_command-line_assistant_powered_by_rhel_lightspeed/containerized-command-line-assistant-for-disconnected-environments
[rhokp_docs]: https://docs.redhat.com/en/documentation/red_hat_offline_knowledge_portal/1/install-proc_launching_rhokp
[cla_offline_blog]: https://www.redhat.com/en/blog/use-rhel-command-line-assistant-offline-new-developer-preview
[cla_installer_catalog]: https://catalog.redhat.com/en/software/containers/rhel-cla/installer-rhel10/68af1cbe4a00895806fa0b48
