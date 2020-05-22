# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt appendhistory autocd beep extendedglob nomatch notify

# Vim Support
export EDITOR="vim"
bindkey -v
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
bindkey '^P' history-search-backward
bindkey '^N' history-search-forward

# Map jk to <esc> and set KEYTIMEOUT=1 to avoid waiting when typing j
export KEYTIMEOUT=1
bindkey -M viins 'jk' vi-cmd-mode

# get the colors  
autoload -U colors && colors
autoload -Uz compinit && compinit

# load prompt functions  
setopt prompt_subst  
unsetopt transient_rprompt # leave the pwd

function git_prompt_wrapper() {
    local CODE
    git rev-parse 2> /dev/null
    CODE=$?
    if [[ $CODE -eq 0 ]]; then
        local TMP 
        TMP="%{$fg[green]%}("
        STATUS=$(git_status)
        [[ -n $(git_dirty) ]] && TMP="$TMP%{$fg[red]%}"
        TMP="$TMP$(git_branch)"
        [[ -n $STATUS ]] && TMP="$TMP %{$fg[red]%}$STATUS"
        TMP="$TMP%{$fg[green]%}) "
        echo $TMP
    fi
}

function git_branch() {
    local BRANCH
    BRANCH=$(command git symbolic-ref --short HEAD \
                  || git name-rev --name-only --no-undefined --always HEAD)
    echo $BRANCH
}

function git_dirty() {
    local STATUS
    STATUS=$(command git status --porcelain 2> /dev/null | tail -n 1)
    echo $STATUS
}

function git_status() {
    local INDEX STATUS
    INDEX=$(command git status --porcelain -b 2> /dev/null)
    STATUS=""
#    if $(echo "$INDEX" | command grep -E '^\?\? ' &> /dev/null); then
#        STATUS="?$STATUS" # Untracked
#    fi
#    if $(echo "$INDEX" | grep '^A  ' &> /dev/null); then
#        STATUS="A$STATUS" # Added
#    elif $(echo "$INDEX" | grep '^M  ' &> /dev/null); then
#        STATUS="A$STATUS" # Added
#    fi
#    if $(echo "$INDEX" | grep '^ M ' &> /dev/null); then
#        STATUS="M$STATUS" # Modified
#    elif $(echo "$INDEX" | grep '^AM ' &> /dev/null); then
#        STATUS="M$STATUS" # Modified
#    elif $(echo "$INDEX" | grep '^ T ' &> /dev/null); then
#        STATUS="M$STATUS" # Modified
#    fi
#    if $(echo "$INDEX" | grep '^R  ' &> /dev/null); then
#        STATUS="R$STATUS" # Renamed
#    fi
#    if $(echo "$INDEX" | grep '^ D ' &> /dev/null); then
#        STATUS="D$STATUS" # Deleted
#    elif $(echo "$INDEX" | grep '^D  ' &> /dev/null); then
#        STATUS="D$STATUS" # Deleted
#    elif $(echo "$INDEX" | grep '^AD ' &> /dev/null); then
#        STATUS="D$STATUS" # Deleted
#    fi
    if $(command git rev-parse --verify refs/stash >/dev/null 2>&1); then
        STATUS="S$STATUS" # Stashed
    fi
    if $(echo "$INDEX" | grep '^UU ' &> /dev/null); then
        STATUS="U$STATUS" # Unmerged
    fi
    if $(echo "$INDEX" | grep '^## .*ahead' &> /dev/null); then
        STATUS="+$STATUS" # Ahead
    fi
    if $(echo "$INDEX" | grep '^## .*behind' &> /dev/null); then
        STATUS="-$STATUS" # Behind
    fi
    if $(echo "$INDEX" | grep '^## .*diverged' &> /dev/null); then
        STATUS="µ$STATUS" # Diverged
    fi
    echo $STATUS
}

function __git_eread()
{
    local f="$1"
    shift
    test -r "$f" && read "$@" <"$f"
}

function __git_ps1 ()
{
    # Preserve exit status
    local exit=$?
    local ps1pc_start="%{$fg[cyan]%}%D{%K:%M} %{$fg[green]%}%m:%{$fg[blue]%}%c%{$reset_color%}"
    local ps1pc_end=" %{$fg[green]%}-%n-%{$reset_color%} "
    # For early exit
    PS1="$ps1pc_start$ps1pc_end"

    local repo_info rev_parse_exit_code
	repo_info="$(git rev-parse --git-dir --is-inside-git-dir \
		--is-bare-repository --is-inside-work-tree \
		--short HEAD 2>/dev/null)"
	rev_parse_exit_code="$?"

	if [ -z "$repo_info" ]; then
		return $exit
	fi

	local short_sha=""
	if [ "$rev_parse_exit_code" = "0" ]; then
		short_sha="${repo_info##*$'\n'}"
		repo_info="${repo_info%$'\n'*}"
	fi
	local inside_worktree="${repo_info##*$'\n'}"
	repo_info="${repo_info%$'\n'*}"
	local bare_repo="${repo_info##*$'\n'}"
	repo_info="${repo_info%$'\n'*}"
	local inside_gitdir="${repo_info##*$'\n'}"
	local g="${repo_info%$'\n'*}"
    
	local r=""
	local b=""
	local step=""
	local total=""
	if [ -d "$g/rebase-merge" ]; then
		__git_eread "$g/rebase-merge/head-name" b
		__git_eread "$g/rebase-merge/msgnum" step
		__git_eread "$g/rebase-merge/end" total
		if [ -f "$g/rebase-merge/interactive" ]; then
			r="|REBASE-i"
		else
			r="|REBASE-m"
		fi
	else
		if [ -d "$g/rebase-apply" ]; then
			__git_eread "$g/rebase-apply/next" step
			__git_eread "$g/rebase-apply/last" total
			if [ -f "$g/rebase-apply/rebasing" ]; then
				__git_eread "$g/rebase-apply/head-name" b
				r="|REBASE"
			elif [ -f "$g/rebase-apply/applying" ]; then
				r="|AM"
			else
				r="|AM/REBASE"
			fi
		elif [ -f "$g/MERGE_HEAD" ]; then
			r="|MERGING"
		elif [ -f "$g/CHERRY_PICK_HEAD" ]; then
			r="|CHERRY-PICKING"
		elif [ -f "$g/REVERT_HEAD" ]; then
			r="|REVERTING"
		elif [ -f "$g/BISECT_LOG" ]; then
			r="|BISECTING"
		fi

		if [ -n "$b" ]; then
			:
		elif [ -h "$g/HEAD" ]; then
			# symlink symbolic ref
			b="$(git symbolic-ref HEAD 2>/dev/null)"
		else
			local head=""
			if ! __git_eread "$g/HEAD" head; then
				return $exit
			fi
			# is it a symbolic ref?
			b="${head#ref: }"
			if [ "$head" = "$b" ]; then
				detached=yes
				b="$(
				case "${GIT_PS1_DESCRIBE_STYLE-}" in
				(contains)
					git describe --contains HEAD ;;
				(branch)
					git describe --contains --all HEAD ;;
				(describe)
					git describe HEAD ;;
				(* | default)
					git describe --tags --exact-match HEAD ;;
				esac 2>/dev/null)" ||

				b="$short_sha..."
				b="($b)"
			fi
		fi
	fi

	if [ -n "$step" ] && [ -n "$total" ]; then
		r="$r $step/$total"
	fi

	local w=""
	local i=""
	local s=""
	local u=""
	local c=""
	local p=""

	if [ "true" = "$inside_gitdir" ]; then
		if [ "true" = "$bare_repo" ]; then
			c="BARE:"
		else
			b="GIT_DIR!"
		fi
	elif [ "true" = "$inside_worktree" ]; then
        git diff --no-ext-diff --quiet || w="*"
        git diff --no-ext-diff --cached --quiet || i="+"
        if [ -z "$short_sha" ] && [ -z "$i" ]; then
            i="#"
        fi

		if git rev-parse --verify --quiet refs/stash >/dev/null
		then
			s="$"
		fi

		if git ls-files --others --exclude-standard --directory --no-empty-directory --error-unmatch -- ':/*' >/dev/null 2>/dev/null
		then
			u="%${ZSH_VERSION+%}"
		fi

        # Find how many commits we are ahead/behind our upstream
        count="$(git rev-list --count --left-right \
                "@{upstream}"...HEAD 2>/dev/null)"

        # calculate the result
        case "$count" in
        "") # no upstream
            p="" ;;
        "0	0") # equal to upstream
            p=" =" ;;
        "0	"*) # ahead of upstream
            p=" %{$fg[yellow]%}+${count#0	}%{$reset_color%}" ;;
        *"	0") # behind upstream
            p=" %{$fg[red]%}-${count%	0}%{$reset_color%}" ;;
        *)	    # diverged from upstream
            p=" %{$fg[red]%}+${count#*	}-${count%	*}%{$reset_color%}" ;;
        esac
	fi

	b=${b##refs/heads/}
    __git_ps1_branch_name=$b
    b="\${__git_ps1_branch_name}"

	local f="$w$i$s$u"
    local gitstring="%{$fg[magenta]%}(%{$fg[green]%}$c$b:$short_sha $f$r$p%{$fg[magenta]%})%{$reset_color%}"

    PS1="$ps1pc_start $gitstring$ps1pc_end"
    return $exit
}

virtual_env_wrapper()
{
    [ "${VIRTUAL_ENV}" ] && echo "(${VIRTUAL_ENV##*/}) "
}

if [[ `id -ru` == 0 ]]
then
    PROMPT='$(virtual_env_wrapper)%{$fg[red]%}%m $(git_prompt_wrapper)#%{$reset_color%} '
else
    PROMPT='$(virtual_env_wrapper)%{$fg[green]%}%m [%c] $(git_prompt_wrapper)-%n-%{$reset_color%} '
fi

# Custom MISC
umask 0002
UNAME=$(command uname -s)
if [[ $UNAME == 'Darwin' ]]
then
    #unalias run-help
    #autoload run-help
    HELPDIR=/usr/local/share/zsh/help
    alias ls='ls -G'
    # added by Snowflake SnowSQL installer v1.0
    export PATH=/Applications/SnowSQL.app/Contents/MacOS:$PATH
elif [[ $UNAME == 'FreeBSD' ]]
then
    alias ls='ls -G'
elif [[ $UNAME == 'OpenBSD' ]]
then
    alias ls='colorls -G'
elif [[ $UNAME == 'Linux' ]]
then
    alias ls='ls --color'
    PROMPT='%m# '
fi

# Github Token
# Custom Path Info
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"
export GPG_TTY=$(tty)

alias jq="jq --color-output"
alias less="less -r"

# virtualenv
export VIRTUAL_ENV_DISABLE_PROMPT=1


# PYENV
#export PYENV_ROOT="$HOME/.pyenv"
#export PATH="$PYENV_ROOT/bin:$PATH"
#export PYENV_VIRTUALENV_DISABLE_PROMPT=1
#eval "$(pyenv init -)"
#eval "$(pyenv virtualenv-init -)"
#alias brew="env PATH=${PATH//$(pyenv root)\/shims:/} brew"

