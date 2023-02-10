#!/bin/bash
PROMPT_COMMAND=__prompt_command

__prompt_command() {
    local RC="$?"
    RC_MSG=""
    if [ "$RC" != 0 ]; then
        RC_MSG="\[$(tput sgr0)\]\[\033[38;5;9m\]$RC\[$(tput sgr0)\]"
    fi
    PS1="\[\033[38;5;56m\]\u\[$(tput sgr0)\]\[\033[38;5;8m\]@\[$(tput sgr0)\]\[\033[38;5;130m\]${CONTAINER_NAME}\[$(tput sgr0)\]: \[$(tput sgr0)\]\[\033[38;5;25m\]\w\[$(tput sgr0)\] \[$(tput sgr0)\]\[\033[38;5;28m\]\$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/')\[$(tput sgr0)\]$RC_MSG\n\\$ \[$(tput sgr0)\]"
}
