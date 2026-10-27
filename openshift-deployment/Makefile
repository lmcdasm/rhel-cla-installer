# Convenience targets for the lab OpenShift overlay.
NS ?= rhel-cla-system
OVERLAY := overlays/lab

.PHONY: build apply seed verify status logs teardown

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
	oc -n $(NS) get pods,deploy,svc,route,pvc,secret

logs:
	oc -n $(NS) logs -l app.kubernetes.io/part-of=rhel-cla --tail=100 --prefix=true

teardown:
	oc delete project $(NS)
