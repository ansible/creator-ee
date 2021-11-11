# Ansible DevTools Execution Environment

This is a container (execution environment) aimed towards being used
for development and testing of the Ansible content. We should also mention
that this container must not be used in production by Ansible users.

It includes:

* ansible-core
* ansible-lint
* molecule

Among its main consumers, we can mention [ansible-navigator] and
[vscode-ansible] extension.

[ansible-navigator]: https://github.com/ansible/ansible-navigator
[vscode-ansible]: https://github.com/ansible/vscode-ansible

## Regenerating the build context with podman:

```console
$ tox -e podman
...
```

## Regenerating the build context with docker:

```console
$ tox -e docker
...
```
