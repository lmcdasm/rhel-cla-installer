# https://github.com/operator-framework/ansible-operator-plugins/blob/main/images/ansible-operator/Dockerfile
FROM quay.io/operator-framework/ansible-operator:v1.42.3 AS final

ARG VERSION=2.0.0

USER 0
RUN microdnf install -y \
    tar \
    && microdnf clean all \
    && rm -rf /var/cache/dnf

USER ${USER_UID}

ENV PWD $HOME

COPY ansible.cfg ${HOME}/ansible.cfg
COPY requirements/requirements.yml ${HOME}/requirements.yml
RUN ansible-galaxy collection install -r ${HOME}/requirements.yml \
 && chmod -R ug+rwx ${HOME}/.ansible

COPY watches.yaml ${HOME}/watches.yaml
COPY collections/ansible_collections/rhel ${HOME}/collections/ansible_collections/rhel

LABEL konflux.additional-tags=$VERSION
LABEL version=$VERSION


# 2026-10-13
FROM registry.access.redhat.com/ubi10/ubi:10.2-1791893534@sha256:a75ad754aa048d808dd3260243452f8c9a665831d0493b4c9d92f0c88fe2f8c3 AS builder

USER 0

COPY --from=final /opt/ansible/collections /opt/setup/collections
COPY requirements/*.txt /opt/setup/
COPY scripts/build-zipapp.py /opt/setup/
RUN /opt/setup/build-zipapp.py


FROM final
COPY --from=builder /opt/rhel-cla-installer ${HOME}/rhel-cla-installer
