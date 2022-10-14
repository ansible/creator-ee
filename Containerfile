# Overly simplified single stage build process: we take all binary dependencies
# using dnf and use pip to install the rest.
ARG EE_BASE_IMAGE=quay.io/ansible/creator-base:latest
FROM $EE_BASE_IMAGE

# https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.source https://github.com/ansible/creator-ee
LABEL org.opencontainers.image.authors "Ansible DevTools"
LABEL org.opencontainers.image.vendor "Red Hat"
LABEL org.opencontainers.image.licenses "GPL-3.0"

LABEL ansible-execution-environment=true

USER root
WORKDIR /tmp

COPY _build/requirements.in requirements.in
COPY _build/requirements.txt requirements.txt
COPY _build/requirements.yml requirements.yml
RUN \
pip3 install -r requirements.in -c requirements.txt && \
mkdir -p ~/.ansible/roles && \
mkdir -p ~/.ansible/collections/ansible_collections && \
ansible-galaxy collection install -r requirements.yml && \
rm -rf $(pip3 cache dir)
# add some helpful CLI commands to check we do not remove them inadvertently and output some helpful version information at build time.
RUN set -ex \
&& ansible-lint --version \
&& molecule --version \
&& molecule drivers \
&& podman --version \
&& python3 --version \
&& git --version \
&& ansible-galaxy role list \
&& ansible-galaxy collection list \
&& uname -a

ADD _build/entrypoint.sh /bin/entrypoint
RUN chmod +x /bin/entrypoint
ENTRYPOINT ["entrypoint"]
