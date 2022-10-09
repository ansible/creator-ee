# Overly simplified single stage build process: we take all binary dependencies
# using dnf and use pip to install the rest.
ARG EE_BASE_IMAGE=quay.io/ansible/creator-base:latest
FROM $EE_BASE_IMAGE
USER root

COPY _build/requirements.in /root/requirements.in
COPY _build/requirements.txt /root/requirements.txt
RUN \
pip3 install -r /root/requirements.in -c /root/requirements.txt && \
rm -rf $(pip3 cache dir)
# add some helpful CLI commands to check we do not remove them inadvertently and output some helpful version information at build time.
RUN set -ex \
&& ansible-lint --version \
&& molecule --version \
&& molecule drivers \
&& podman --version \
&& python3 --version \
&& git --version \
&& uname -a
