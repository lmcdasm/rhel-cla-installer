# Red Hat Enterprise Linux Command Line Assistant Installer #

This is the installer for the self-managed RHEL CLA. It supports local, remote installations. OpenShift support is stil in development.

## Prerequisites ##

- Python 3.11 or later
- [`podman`]
- `tar`
- A [Red Hat Offline Knowledge Portal key][rhokp_key]
- 30GB of free disk space for the Red Hat Offline Knowledge Portal.
- Valid login credentials in `/etc/containers/auth.json`.

Create the required login credentials. This needs to be done on both local and remote systems, or the auth file can be generated once and copied to remote systems.

```
sudo podman login --authfile /etc/containers/auth.json registry.redhat.io
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
    podman run --rm -i --entrypoint sh "$IMAGE" -c 'tar -cf - ansible.cfg rhel-cla-installer inventory' | tar -xf -
    ```

1. Update the variables in `inventory.hosts.yml`, such as `okp_access_key`. Some variables depend on the external provider.

1. Run the installer.

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

### Uninstall ###

Run `./rhel-cla-installer rhel.cla.uninstall_local`.


[`podman`]: https://podman.io/
[rhokp_key]: https://access.redhat.com/offline/access/
