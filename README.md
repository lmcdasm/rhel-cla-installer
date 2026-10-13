# Red Hat Enterprise Linux Command Line Assistant Installer #

This is the installer for the self-managed RHEL CLA. It supports local, remote installations. OpenShift support is stil in development.

## Prerequisites ##

- Python 3.11 or later
- [`podman`]
- A [Red Hat Offline Knowledge Portal key][rhokp_key]

## Local Installation ##

1. Extract the installer from the container image in order to run it against `localhost`.

    ```
    ./scripts/extract.sh
    ```

    This will extract the installer from the container into a single executable to a `local` directory.

    If any errors are encountered when extracting the installer, run `bash -s scripts/extract.sh` to see more verbose output.

    It is possible to override `IMAGE` and `CONTAINER_RUNTIME` if needed.

    ```
    CONTAINER_RUNTIME=docker ./scripts/extract.sh
    ```

1. Configure inventory.

    Make a copy of the example inventory file and fill in the required variables.

    ```
    mkdir local/inventory
    cp inventory/hosts.example.yml local/inventory/hosts.yml
    ```

    For local installation, no host definitions are necessary.

1. Run the installer.

    ```
    cd local
    ./rhel-cla-installer rhel.cla.local
    ```

    Adjust verbosity by adding `-v`. More v's give more verbosity.

### Verify Installation ###

Check the pod and container status.

```
sudo systemctl status rhel-cla-pod.service
sudo systemctl status rhel-knowledge-bridge.service
sudo systemctl rh-offline-knowledge-portal.service
sudo systemctl lightspeed-stack.service
```

### Uninstall ###

Run `./rhel-cla-installer rhel.cla.uninstall_local`.


[`podman`]: https://podman.io/
[rhokp_key]: https://access.redhat.com/offline/access/
