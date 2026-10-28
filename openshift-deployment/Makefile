# Lab OpenShift deploy via Ansible k8s roles (source of truth).
# Requires: oc logged into the cluster, ansible + kubernetes.core, seeded secrets.
NS ?= rhel-cla-system
REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
PLAYBOOK := $(REPO_ROOT)/collections/ansible_collections/rhel/cla/playbooks/k8s.yml
LAB_VARS := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/lab-vars.yml
export ANSIBLE_CONFIG := $(REPO_ROOT)/ansible.cfg

.PHONY: apply seed verify status logs granite-check teardown render check

seed:
	@test -n "$${RHEL_PASS}" || (echo "Set RHEL_PASS=..." >&2; exit 1)
	./scripts/seed-secrets-from-rhel.sh

# Dump templated YAML via Ansible (gitignored generated/) — review aid only
render:
	./scripts/render.sh

# Preview cluster changes with the same playbook as apply
check:
	cd $(REPO_ROOT) && ansible-playbook -i localhost, -c local $(PLAYBOOK) \
		-e @$(LAB_VARS) --check --diff

apply:
	./scripts/apply.sh

verify:
	./scripts/verify.sh

status:
	oc -n $(NS) get pods,deploy,svc,route,pvc,secret,networkpolicy,quota,limitrange,job

logs:
	oc -n $(NS) logs -l app.kubernetes.io/part-of=rhel-cla --tail=100 --prefix=true

granite-check:
	# Re-apply Job from Ansible (deletes completed job first)
	oc -n $(NS) delete job granite-connectivity --ignore-not-found
	cd $(REPO_ROOT) && ansible-playbook -i localhost, -c local $(PLAYBOOK) \
		-e @$(LAB_VARS) -e cla_granite_connectivity_job=true --tags cla_k8s
	oc -n $(NS) wait --for=condition=complete job/granite-connectivity --timeout=180s
	oc -n $(NS) logs job/granite-connectivity

teardown:
	oc delete project $(NS)
