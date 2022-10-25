# Ansible Creator Execution Environment

This is a container (execution environment) aimed towards being used
for the development and testing of the Ansible content. We should also mention
that this container must not be used in production by Ansible users.

It includes:

- [ansible-core]
- [ansible-lint]
- [molecule]

Among its main consumers, we can mention [ansible-navigator] and
[vscode-ansible] extension.

[ansible-core]: https://github.com/ansible/ansible
[ansible-lint]: https://github.com/ansible/ansible-lint
[ansible-navigator]: https://github.com/ansible/ansible-navigator
[molecule]: https://github.com/ansible-community/molecule
[vscode-ansible]: https://github.com/ansible/vscode-ansible

## Contributing

We use [taskfile](https://taskfile.dev/) as build tool, so you should run
`task -l` to list available. If you run just `task`, it will run the default
set of build tasks. If these are passing, you are ready to open a pull request
with your changes.
