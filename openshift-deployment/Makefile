# Convenience targets for the lab OpenShift overlay.
NS ?= rhel-cla-system
OVERLAY := overlays/lab

.PHONY: build apply seed verify status logs granite-check teardown

build:
	oc kustomize $(OVERLAY)

apply:
	./scripts/apply.sh

seed:
	@test -n "$${RHEL_PASS}" || (echo "Set RHEL_PASS=..." >&2; exit 1)
	./scripts/seed-secrets-from-rhel.sh

verify:
	./scripts/verify.sh

status:
	oc -n $(NS) get pods,deploy,svc,route,pvc,secret,networkpolicy,quota,limitrange,job

logs:
	oc -n $(NS) logs -l app.kubernetes.io/part-of=rhel-cla --tail=100 --prefix=true

granite-check:
	oc -n $(NS) delete job granite-connectivity --ignore-not-found
	oc apply -f base/granite-connectivity-job.yaml
	oc -n $(NS) wait --for=condition=complete job/granite-connectivity --timeout=180s
	oc -n $(NS) logs job/granite-connectivity

teardown:
	oc delete project $(NS)
