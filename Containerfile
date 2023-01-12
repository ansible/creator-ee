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

COPY _build/requirements.txt requirements.txt
COPY _build/requirements.yml requirements.yml
COPY _build/devtools-publish /usr/local/bin/devtools-publish
COPY _build/shells /etc/shells
RUN \
pip3 install --compile --only-binary :all: \
-r requirements.txt && \
mkdir -p ~/.ansible/roles /usr/share/ansible/roles /etc/ansible/roles && \
rm -rf $(pip3 cache dir) && \
# Avoid "fatal: detected dubious ownership in repository at" with newer git versions
# See https://github.com/actions/runner-images/issues/6775
git config --global --add safe.directory /

# In OpenShift, container will run as a random uid number and gid 0. Make sure things
# are writeable by the root group.
RUN for dir in \
      /home/runner \
      /home/runner/.ansible \
      /home/runner/.ansible/tmp \
      /runner \
      /home/runner \
      /runner/env \
      /runner/inventory \
      /runner/project \
      /runner/artifacts ; \
    do mkdir -m 0775 -p $dir ; chmod -R g+rwx $dir ; chgrp -R root $dir ; done && \
    for file in \
      /home/runner/.ansible/galaxy_token \
      /etc/passwd \
      /etc/group ; \
    do touch $file ; chmod g+rw $file ; chgrp root $file ; done
COPY collections/ /usr/share/ansible/collections

# add some helpful CLI commands to check we do not remove them inadvertently and output some helpful version information at build time.
RUN set -ex \
&& ansible --version \
&& ansible-lint --version \
&& ansible-runner --version \
&& molecule --version \
&& molecule drivers \
&& podman --version \
&& python3 --version \
&& git --version \
&& ansible-galaxy role list \
&& ansible-galaxy collection list \
&& rpm -qa \
&& rom -qa | grep python \
&& uname -a

ADD _build/entrypoint.sh /bin/entrypoint
RUN chmod +x /bin/entrypoint
ENTRYPOINT ["entrypoint"]
