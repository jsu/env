# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt appendhistory autocd beep extendedglob nomatch notify

# Vim Support
export EDITOR="vim"
bindkey -v
bindkey "^R" history-incremental-search-backward
bindkey "^S" history-incremental-search-forward
bindkey "^P" history-search-backward
bindkey "^N" history-search-forward

# Map jk to <esc> and set KEYTIMEOUT=1 to avoid waiting when typing j
export KEYTIMEOUT=10
bindkey -M viins "jk" vi-cmd-mode

# get the colors
autoload -U colors && colors
autoload -Uz compinit && compinit

# load prompt functions
setopt prompt_subst
unsetopt transient_rprompt # leave the pwd

# plugins
plugins=(command-not-found)


## Virtual ENV
export VIRTUAL_ENV_DISABLE_PROMPT=1
virtual_env_wrapper()
{
    [ "${VIRTUAL_ENV}" ] && echo "($(basename ${VIRTUAL_ENV})) "
}

if [[ $(id -ru) == 0 ]]
then
    PROMPT="%m# "
else
    git_prompt_url="https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh"
    git_prompt_file="${HOME}/.git-prompt.sh"
    [ -f ${git_prompt_file} ] || curl --url ${git_prompt_url} -o ${git_prompt_file} -s
    source ${git_prompt_file}
    export GIT_PS1_SHOWDIRTYSTATE=true
    export GIT_PS1_SHOWSTASHSTATE=true
    export GIT_PS1_SHOWUNTRACKEDFILES=true
    export GIT_PS1_SHOWUPSTREAM="auto"
    export GIT_PS1_DESCRIBE_STYLE="branch"
    precmd () { __git_ps1 "$(virtual_env_wrapper)%{$fg[blue]%}%D{%T} %{$fg[green]%}%m [%c]" "%s -%n-%{$reset_color%} " }
fi

# Custom MISC
umask 0002
UNAME=$(command uname -s)
if [[ $UNAME == "Darwin" ]]
then
    #unalias run-help
    #autoload run-help
    HELPDIR=/usr/local/share/zsh/help
    alias ls="ls -G"
    alias history="history -i"
    # added by Snowflake SnowSQL installer v1.0
    export PATH=/Applications/SnowSQL.app/Contents/MacOS:$PATH
    # Disable "allow mouse reporting" on OSX Terminal app
    osascript -e 'tell application "System Events" to keystroke "r" using command down'
elif [[ $UNAME == "FreeBSD" ]]
then
    alias ls="ls -G"
elif [[ $UNAME == "OpenBSD" ]]
then
    alias ls="colorls -G"
elif [[ $UNAME == "Linux" ]]
then
    alias ls="ls --color"
    export HISTTIMEFORMAT="%d/%m/%y %T "
fi

# Github Token
# Custom Path Info
export LC_ALL="en_US.UTF-8"
export LANG=${LC_ALL}
export GPG_TTY=$(tty)

alias jq="jq --color-output"
alias less="less -r"

# AWS
if [ -f ~/.aws/credentials ]
then
    export AWS_DEFAULT_REGION=$(cat ~/.aws/credentials | awk -F= '/^region/ {gsub(/ /, "", $2); print $2; exit}')
    export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | awk -F= '/^aws_access_key_id/ {gsub(/ /, "", $2); print $2; exit}')
    export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | awk -F= '/^aws_secret_access_key/ {gsub(/ /, "", $2); print $2; exit}')
fi

export PATH=${HOME}/sbin:${PATH}


# added by Snowflake SnowSQL installer v1.2
export PATH=/Applications/SnowSQL.app/Contents/MacOS:$PATH
