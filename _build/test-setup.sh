#!/bin/bash
#
# This tool is used to setup the environment for running the tests. Its name
# name and location is based on Zuul CI, which can automatically run it.
# (cspell: disable-next-line)
set -euo pipefail

PIP_LOG_FILE=out/log/pip.log
HOSTNAME="${HOSTNAME:-localhost}"
ERR=0
NC='\033[0m' # No Color

mkdir -p out/log
# we do not want pip logs from previous runs
:> "${PIP_LOG_FILE}"

# Function to retrieve the version number for a specific command. If a second
# argument is passed, it will be used as return value when tool is missing.
get_version () {
    if command -v "${1:-}" >/dev/null 2>&1; then
        _cmd=("${@:1}")
        # if we did not pass any arguments, we add --version ourselves:
        if [[ $# -eq 1 ]]; then
            _cmd+=('--version')
        fi
        "${_cmd[@]}" | head -n1 | sed -r 's/^[^0-9]*([0-9][0-9\\w\\.]*).*$/\1/'
    else
        log error "Got $? while trying to retrieve ${1:-} version"
        return 99
    fi
}

# Use "log [notice|warning|error] message" to  print a colored message to
# stderr, with colors.
log () {
    local prefix
    if [ "$#" -ne 2 ]; then
        log error "Incorrect call ($*), use: log [notice|warning|error] 'message'."
        exit 2
    fi
    case $1 in
        notice)   prefix='\033[0;36mNOTICE:  ';;
        warning)  prefix='\033[0;33mWARNING: ';;
        error)    prefix='\033[0;31mERROR:   ';;
        *)        log error "log first argument must be 'notice', 'warning' or 'error', not $1."; exit 2;;
    esac
    >&2 echo -e "${prefix}${2}${NC}"
}

if [[ -f "/usr/bin/apt-get" ]]; then
    INSTALL=0
    # qemu-user-static is required by podman on arm64
    # python3-dev is needed for headers as some packages might need to compile
    DEBS=(curl git python3-pip python3-venv qemu-user-static jq gh)
    for DEB in "${DEBS[@]}"; do
        [[ "$(dpkg-query --show --showformat='${db:Status-Status}\n' \
            "${DEB}" || true)" != 'installed' ]] && INSTALL=1
    done
    if [[ "${INSTALL}" -eq 1 ]]; then
        printf '%s\n' "We need sudo to install some packages: ${DEBS[*]}"
        # mandatory or other apt-get commands fail
        sudo apt-get update -qq -o=Dpkg::Use-Pty=0
        # install all required packages
        sudo apt-get -qq install -y \
            --no-install-recommends \
            --no-install-suggests \
            -o=Dpkg::Use-Pty=0 "${DEBS[@]}"
    fi
fi

# Ensure that git is configured properly to allow unattended commits, something
# that is needed by some tasks, like devel or deps.
git config user.email >/dev/null 2>&1 || GIT_NOT_CONFIGURED=1
git config user.name  >/dev/null 2>&1 || GIT_NOT_CONFIGURED=1
if [[ "${GIT_NOT_CONFIGURED:-}" == "1" ]]; then
    echo CI="${CI:-}"
    if [ -z "${CI:-}" ]; then
        log error "git config user.email or user.name are not configured."
        exit 40
    else
        git config user.email ansible-devtools@redhat.com
        git config user.name "Ansible DevTools"
    fi
fi

# macos specific
if [[ "${OS:-}" == "darwin" && "${SKIP_PODMAN:-}" != '1' ]]; then
    command -v podman >/dev/null 2>&1 || {
        HOMEBREW_NO_ENV_HINTS=1 time brew install podman
        time podman machine init
        time podman machine start
        podman info
        podman run hello-world
    }
fi

# Fail-fast if run on Windows or under WSL1/2 on /mnt/c because it is so slow
# that we do not support it at all. WSL use is ok, but not on mounts.
if [[ "${OS:-}" == "windows" ]]; then
    log error "You cannot use Windows build tools for development, try WSL."
    exit 1
fi
if grep -qi microsoft /proc/version >/dev/null 2>&1; then
    # resolve pwd symlinks and ensure than we do not run under /mnt (mount)
    if [[ "$(pwd -P || true)" == /mnt/* ]]; then
        log warning "Under WSL, you must avoid running from mounts (/mnt/*) due to critical performance issues."
    fi
fi

# User specific environment
if ! [[ "${PATH}" == *"${HOME}/.local/bin"* ]]; then
    # shellcheck disable=SC2088
    log warning "~/.local/bin was not found in PATH, attempting to add it."
    cat >>"${HOME}/.bashrc" <<EOF
# User specific environment
if ! [[ "${PATH}" =~ "${HOME}/.local/bin" ]]; then
    PATH="${HOME}/.local/bin:${PATH}"
fi
export PATH
EOF
    PATH="${HOME}/.local/bin:${PATH}"
fi

# fail-fast if we detect incompatible filesystem (o-w)
# https://github.com/ansible/ansible/pull/42070
python3 -c "import os, stat, sys; sys.exit(os.stat('.').st_mode & stat.S_IWOTH)" || {
    log error "Cannot run from world-writable filesystem, try moving code to a secured location and read https://github.com/ansible/devtools/wiki/permissions#ansible-filesystem-requirements"
    exit 100
}

python3 -m pre_commit --version >/dev/null 2>&1 || {
    python3 -m pip install -q pre-commit ansible-core
}

# Detect podman and ensure that it is usable (unless SKIP_PODMAN)
PODMAN_VERSION="$(get_version podman || echo null)"
if [[ "${PODMAN_VERSION}" != 'null' ]] && [[ "${SKIP_PODMAN:-}" != '1' ]]; then
    if [[ "$(podman machine ls --format '{{.Running}}' --noheading || true)" \
            == "false" ]]; then
        log notice "Starting podman machine"
        podman machine start
        while [[ "$(podman machine ls --format '{{.Running}}' \
                --noheading || true)" != "true" ]]; do
            sleep 1
            echo -n .
        done
        echo .
    fi
fi

# Create a build manifest so we can compare between builds and machines, this
# also has the role of ensuring that the required executables are present.
#
cat >out/log/manifest.yml <<EOF
system:
  uname: $(uname)
env:
  ARCH: ${ARCH:-null}  # taskfile
  OS: ${OS:-null}    # taskfile
  OSTYPE: ${OSTYPE}
tools:
  bash: $(get_version bash)
  gh: $(get_version gh || echo null)
  git: $(get_version git)
  pre-commit: $(get_version pre-commit)
  python: $(get_version python)
  task: $(get_version task)
containers:
  podman: ${PODMAN_VERSION}
EOF

[[ $ERR -eq 0 ]] && level=notice || level=error
log "${level}" "${0##*/} -> out/log/manifest.yml and returned ${ERR}"
exit "${ERR}"
