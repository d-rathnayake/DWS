# ==========================================================
#  DWS PREMIUM V1 — shell config
#  Developer : d-rathnayake
#  Set DWS_QUIET=1 before this file loads to hide the banner.
#  Set DWS_NOSUGGEST=1 to turn off history suggestions.
# ==========================================================

export DWS_HOME="$HOME/.dws"
export PATH="$DWS_HOME/bin:$PATH"
export TERM="${TERM:-xterm-256color}"
export EDITOR="${EDITOR:-nano}"

# ---- banner name (validated, falls back to DWS) ------------
DWS_NAME="DWS"
if [[ -r $DWS_HOME/name ]]; then
  _dws_n=$(head -n 1 "$DWS_HOME/name" 2>/dev/null)
  if [[ $_dws_n =~ '^[A-Za-z0-9-]{1,10}$' ]]; then
    DWS_NAME=$_dws_n
  fi
  unset _dws_n
fi

# ---- history -----------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=5000
SAVEHIST=5000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS SHARE_HISTORY
setopt PROMPT_SUBST AUTO_CD INTERACTIVE_COMMENTS

# ---- completion (Tab completes; no menus) ------------------
autoload -Uz compinit
compinit -C -d "$DWS_HOME/.zcompdump" 2>/dev/null

# ---- icon-coloured listings, powered by `dws ls` -----------
alias ls='dws ls'
alias ll='dws ls -l'
alias la='dws ls -a'
alias lla='dws ls -la'
alias c='clear'
alias cls='clear'

# ---- prompt ------------------------------------------------
autoload -Uz colors && colors
PROMPT="%F{39}┌─[%F{213}${DWS_NAME}%F{39}]─[%F{45}%~%F{39}]%f
%F{39}└─%F{220}❯%F{214}❯%F{208}❯%f "
RPROMPT='%(?..%F{203}✖ %?%f )%F{245}%D{%H:%M:%S}%f'

# ---- command timer (shows runs of 2 seconds or more) -------
zmodload zsh/datetime 2>/dev/null
dws_preexec() { DWS_T0=$EPOCHSECONDS }
dws_precmd() {
  if [[ -n ${DWS_T0-} ]]; then
    local d=$(( EPOCHSECONDS - DWS_T0 ))
    if (( d >= 2 )); then
      print -P "%F{245}  ⏱ ran for ${d}s%f"
    fi
    unset DWS_T0
  fi
  # refresh the history cache used by the suggestions (oldest first)
  _dws_hist=("${(@f)$(fc -ln 1 2>/dev/null)}")
}
autoload -Uz add-zsh-hook
add-zsh-hook preexec dws_preexec
add-zsh-hook precmd dws_precmd

# ---- history suggestions (grey ghost text, fish-style) -----
# How it works:
#   - the history is cached in _dws_hist at every prompt
#   - after each key press, dws_suggest_update looks for the newest
#     history line that starts with what is typed so far
#   - the rest of that line is drawn grey after the cursor (POSTDISPLAY)
#   - Right arrow (cursor at end) or Ctrl+E accepts it
typeset -ga _dws_hist
typeset -g  _dws_sug=""
typeset -g  _dws_last=""

dws_suggest_update() {
  emulate -L zsh
  if [[ $BUFFER == "$_dws_last" ]]; then
    return 0
  fi
  _dws_last=$BUFFER
  _dws_sug=""
  if [[ -n ${DWS_NOSUGGEST-} || -z $BUFFER ]]; then
    POSTDISPLAY=""
    region_highlight=()
    return 0
  fi
  local i cmd
  for (( i = ${#_dws_hist}; i > 0; i-- )); do
    cmd=${_dws_hist[i]}
    if [[ $cmd == "$BUFFER"* && $cmd != "$BUFFER" ]]; then
      _dws_sug=${cmd#"$BUFFER"}
      break
    fi
  done
  if [[ -n $_dws_sug ]]; then
    POSTDISPLAY=$_dws_sug
    region_highlight=("${#BUFFER} $(( ${#BUFFER} + ${#_dws_sug} )) fg=244")
  else
    POSTDISPLAY=""
    region_highlight=()
  fi
}

dws_suggest_clear() {
  POSTDISPLAY=""
  region_highlight=()
  _dws_last=""
}

dws_accept_suggestion() {
  if [[ -n $POSTDISPLAY && $CURSOR -eq $#BUFFER ]]; then
    BUFFER="$BUFFER$POSTDISPLAY"
    CURSOR=$#BUFFER
    POSTDISPLAY=""
    region_highlight=()
    _dws_last=$BUFFER
  else
    zle forward-char
  fi
}

dws_accept_or_end() {
  if [[ -n $POSTDISPLAY && $CURSOR -eq $#BUFFER ]]; then
    dws_accept_suggestion
  else
    zle end-of-line
  fi
}

autoload -Uz add-zle-hook-widget
add-zle-hook-widget line-pre-redraw dws_suggest_update
add-zle-hook-widget line-finish dws_suggest_clear

zle -N dws_accept_suggestion
zle -N dws_accept_or_end

bindkey '^[[C' dws_accept_suggestion   # Right arrow
bindkey '^[OC' dws_accept_suggestion   # Right arrow (keypad mode)
bindkey '^E'   dws_accept_or_end       # Ctrl+E

# ---- banner on every new interactive shell -----------------
if [[ -o interactive && -z ${DWS_QUIET-} && -x $DWS_HOME/bin/dws ]]; then
  "$DWS_HOME/bin/dws" 2>/dev/null
fi
