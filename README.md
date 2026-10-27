# Red Hat Enterprise Linux Command Line Assistant Installer #

This is the installer for the self-managed RHEL CLA. It supports local and remote installations.

For an OpenShift/Kubernetes manifest-based lab deployment (same images as the
Podman Quadlet path, Granite left external for now), see
[OpenShift deployment][ocp_deploy].

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

1. Run the installer. If a password is required for `sudo`, add the `-K` option and enter the password when prompted.

    **Note**: Do not run the installer using `sudo`. Run it as a normal account with `sudo` privileges.

    ```
    ./rhel-cla-installer rhel.cla.local
    ```

    Adjust verbosity by adding `-v`. More v's give more verbosity.

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
[ocp_deploy]: openshift-deployment/OC-Deployment.md
