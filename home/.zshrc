
# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/.local/share/kiro-cli/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/zshrc.pre.zsh"

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
    HELPDIR=/usr/local/share/zsh/help
    alias ls="ls -G"
    alias history="history -i"
    # added by Snowflake SnowSQL installer v1.0
    export PATH=/Applications/SnowSQL.app/Contents/MacOS:$PATH
    # Disable "allow mouse reporting" on OSX Terminal app
    osascript -e 'tell application "System Events" to keystroke "r" using command down'
    stty -a | grep mouse && stty -ixon
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

# My env
export PATH=${HOME}/scripts:${PATH}

# Homebrew
HOMEBREW=/opt/homebrew/bin
[ -d ${HOMEBREW} ] && export PATH=${HOMEBREW}:${PATH}

# uv
LOCAL_BIN=${HOME}/.local/bin
[ -d ${LOCAL_BIN} ] && export PATH="${LOCAL_BIN}:${PATH}"

# Pyenv
PYENV_ROOT="${HOME}/.pyenv"
if [ -d ${PYEN_ROOT} ]; then
    export PYENV_ROOT=${PYENV_ROOT}
    [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
    alias brew='env PATH="${PATH//$(pyenv root)\/shims:/}" brew'
fi

# added by Snowflake SnowSQL installer v1.2
export PATH=/Applications/SnowSQL.app/Contents/MacOS:$PATH
export PATH=${HOME}/bin:$PATH

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/jsu/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/jsu/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/jsu/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/jsu/Downloads/google-cloud-sdk/completion.zsh.inc'; fi

# AWS
export AWS_REGION=us-west-2

# Claude Code
CLAUDE_CODE_PATH="$HOME/.claude/local"
if [ -d $CLAUDE_CODE_PATH ]
then
    export CLAUDE_CODE_USE_BEDROCK=1
    export PATH="$CLAUDE_CODE_PATH:$PATH"
    alias claude="AWS_PROFILE=dataeng-dev ~/.claude/local/claude"
fi

# NPM
NPM_GLOBAL="$HOME/.npm-global/bin"
[ -d $NPM_GLOBAL ] && export PATH="$NPM_GLOBAL:$PATH"



# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/.local/share/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/zshrc.post.zsh"

# add Pulumi to the PATH
export PATH=$PATH:/home/jsu/.pulumi/bin
