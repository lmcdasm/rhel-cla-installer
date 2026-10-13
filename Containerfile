# https://github.com/operator-framework/ansible-operator-plugins/blob/main/images/ansible-operator/Dockerfile
FROM quay.io/operator-framework/ansible-operator:v1.42.3

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

LABEL konflux.additional-tags=${VERSION}
