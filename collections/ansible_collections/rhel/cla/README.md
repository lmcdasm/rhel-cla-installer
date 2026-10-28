# Ansible Collection - rhel.cla

Collection of roles and playbooks for self-managed RHEL CLA.

### Playbooks ###

**Installation**

- `rhel.cla.local` → Install RHEL CLA on a single local host (Podman Quadlet).
- `rhel.cla.install` → Install RHEL CLA on one or more remote systems.
- `rhel.cla.k8s` → Deploy RHEL CLA to a Kubernetes or OpenShift cluster using
  role Jinja templates (`templates/k8s/*.j2`) and `kubernetes.core.k8s`.

**Removal**

- `rhel.cla.local_uninstall` → Completely remove a local installation.
- `rhel.cla.uninstall` → Completely remove a remote installation.
- `rhel.cla.k8s_uninstall` → Remove the cluster deployment (sets resource state
  to `absent`).

### OpenShift / Kubernetes ###

OpenShift resources live in the same roles used for Quadlet-adjacent installs.
The playbook applies them with Ansible — the same interface as local install:

```bash
# Via the self-contained installer (preferred for customers)
./rhel-cla-installer rhel.cla.k8s -e @examples/openshift-lab-vars.yml

# Or directly with ansible-playbook
ansible-playbook -i localhost, -c local \
  collections/ansible_collections/rhel/cla/playbooks/k8s.yml \
  -e @examples/openshift-lab-vars.yml
```

Preview changes without applying:

```bash
ansible-playbook -i localhost, -c local \
  collections/ansible_collections/rhel/cla/playbooks/k8s.yml \
  -e @examples/openshift-lab-vars.yml --check --diff
```

Uninstall:

```bash
./rhel-cla-installer rhel.cla.k8s_uninstall -e @examples/openshift-lab-vars.yml
```

Important variables (see role defaults and `examples/openshift-lab-vars.yml`):

| Variable | Purpose |
| --- | --- |
| `cla_namespace` | Target namespace / project |
| `cla_create_namespace` | Create the namespace |
| `cla_network_policies` / `cla_resource_quota` | Optional cluster scaffolding |
| `okp_use_pvc` | OKP Solr data on a PVC |
| `rhel_cla_provider` | Inference provider (`ramalama`, `vertex`, …) |
| `*_container_image_digest` | Optional digest pins |
| `ls_create_route` | OpenShift Route for Lightspeed |

Pull secrets and OKP access keys are **not** managed by the playbook; create
them in the namespace before apply (lab helper scripts may exist under
`openshift-deployment/scripts/` but are optional convenience only).
