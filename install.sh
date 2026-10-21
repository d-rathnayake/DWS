#!/usr/bin/env bash
# ==========================================================
#  DWS PREMIUM V1 — installer (Termux and Debian/Ubuntu)
#  Developer : d-rathnayake
#
#  One progress bar, updated in place. All command output goes
#  to ~/.dws/install.log. Network: package installs only.
# ==========================================================
set -u

ESC=$'\033'
RESET="${ESC}[0m"
BOLD="${ESC}[1m"
PINK="${ESC}[1;38;5;213m"
MINT="${ESC}[1;38;5;84m"
GOLD="${ESC}[1;38;5;220m"
SKY="${ESC}[1;38;5;117m"
RED="${ESC}[1;38;5;203m"
GREY="${ESC}[38;5;245m"
WHITE="${ESC}[1;38;5;255m"
VIO="${ESC}[38;5;141m"

SRC_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DWS_HOME="$HOME/.dws"
BIN_DIR="$DWS_HOME/bin"
BACKUP_DIR="$DWS_HOME/backup"
NAME_FILE="$DWS_HOME/name"
LOG_FILE="$DWS_HOME/install.log"
MARK_BEGIN="# >>> DWS >>>"
MARK_END="# <<< DWS <<<"
STEP_TIMEOUT="${DWS_STEP_TIMEOUT:-900}"
TERMUX_PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
TTY=0; if [ -t 1 ]; then TTY=1; fi
PCT=0
SPIN_I=0
SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
START_TS=$(date +%s)
DELETE_SRC=0
NAME=""

is_termux() { [ -d /data/data/com.termux/files/usr ]; }

restore_cursor() { if [ "$TTY" -eq 1 ]; then printf '\033[?25h'; fi; }
trap restore_cursor EXIT INT TERM

# ---------- the one progress bar ----------------------------
# draw <percent> <label>
draw() {
  [ "$TTY" -eq 1 ] || return 0
  local p="$1" label="$2" w=30 f i out="" el mm
  if [ "$p" -gt 100 ]; then p=100; fi
  if [ "$p" -lt 0 ]; then p=0; fi
  f=$(( p * w / 100 ))
  for ((i = 0; i < w; i++)); do
    if [ "$i" -lt "$f" ]; then out+="█"; else out+="░"; fi
  done
  el=$(( $(date +%s) - START_TS ))
  mm=$(printf '%02d:%02d' $(( el / 60 )) $(( el % 60 )))
  printf '\r\033[2K  %s%s%s %s%s%s %s%3d%%%s  %s%-22s%s %s%s%s' \
    "$PINK" "${SPIN[SPIN_I % 10]}" "$RESET" \
    "$SKY" "$out" "$RESET" \
    "$BOLD" "$p" "$RESET" \
    "$WHITE" "$label" "$RESET" \
    "$GREY" "$mm" "$RESET"
  SPIN_I=$(( SPIN_I + 1 ))
}

# set_to <percent> <label> — jump the bar (used for quick steps)
set_to() {
  PCT="$1"
  draw "$PCT" "$2"
}

# fail <label> — stop the bar, show the log tail and a hint
fail() {
  local label="$1" hint="${2:-}"
  if [ "$TTY" -eq 1 ]; then printf '\r\033[2K'; fi
  printf '\n  %s✖ install stopped at:%s %s\n' "$RED" "$RESET" "$label"
  if [ -s "$LOG_FILE" ]; then
    printf '  %slast lines of %s:%s\n' "$GREY" "$LOG_FILE" "$RESET"
    tail -n 12 "$LOG_FILE" | LC_ALL=C tr -cd '[:print:]\n' | sed 's/^/    /'
  fi
  if [ -n "$hint" ]; then printf '  %shint:%s %s\n' "$GOLD" "$RESET" "$hint"; fi
  printf '  run %sbash install.sh%s again after fixing it. Your settings are kept.\n\n' "$MINT" "$RESET"
  exit 1
}

# run_phase <from> <to> <expected-seconds> <label> <command…>
# Runs a command in the background, moves the bar smoothly from <from>
# toward <to>, and finishes at <to> when the command succeeds.
run_phase() {
  local from="$1" to="$2" expect="$3" label="$4" pid t0 el span add rc
  shift 4
  if [ "$TTY" -ne 1 ]; then
    "$@" >>"$LOG_FILE" 2>&1 </dev/null
    return $?
  fi
  "$@" >>"$LOG_FILE" 2>&1 </dev/null &
  pid=$!
  t0=$(date +%s)
  span=$(( to - from - 1 )); if [ "$span" -lt 0 ]; then span=0; fi
  while kill -0 "$pid" 2>/dev/null; do
    el=$(( $(date +%s) - t0 ))
    if [ "$el" -ge "$STEP_TIMEOUT" ]; then
      kill "$pid" 2>/dev/null; sleep 1; kill -9 "$pid" 2>/dev/null
      break
    fi
    add=$(( span * el / expect )); if [ "$add" -gt "$span" ]; then add=$span; fi
    draw $(( from + add )) "$label"
    sleep 0.12
  done
  wait "$pid" 2>/dev/null
  rc=$?
  if [ "$rc" -eq 0 ]; then set_to "$to" "$label"; fi
  return "$rc"
}

# ---------- questions (asked before the bar starts) ---------
ask_questions() {
  if [ "$TTY" -ne 1 ]; then return 0; fi
  printf '\n %s%sDWS PREMIUM V1%s  %sinstaller · d-rathnayake%s\n\n' "$BOLD" "$PINK" "$RESET" "$GREY" "$RESET"

  if [ ! -f "$NAME_FILE" ]; then
    printf ' %s?%s Banner name %s(1-10 letters, numbers or hyphen · Enter = DWS)%s\n   ' "$PINK" "$RESET" "$GREY" "$RESET"
    local tries=0 n=""
    while [ "$tries" -lt 5 ]; do
      printf ' %s›%s ' "$MINT" "$RESET"
      read -r n || n=""
      n="${n// /}"
      if [ -z "$n" ]; then n="DWS"; fi
      if [[ "$n" =~ ^[A-Za-z0-9-]{1,10}$ ]]; then break; fi
      printf '   %s✖ use 1-10 letters, numbers or hyphen%s\n' "$RED" "$RESET"
      n=""; tries=$(( tries + 1 ))
    done
    if [ -z "$n" ]; then n="DWS"; fi
    NAME="$n"
  fi

  printf ' %s?%s Delete this installer folder when done? %s[Y/n]%s ' "$PINK" "$RESET" "$GREY" "$RESET"
  local a=""
  read -r a || a=""
  case "$a" in n|N|no|NO) DELETE_SRC=0 ;; *) DELETE_SRC=1 ;; esac
  printf '\n'
}

# ---------- phases ------------------------------------------
phase_packages() {
  local need=() p
  for p in zsh git curl; do
    if ! command -v "$p" >/dev/null 2>&1; then need+=("$p"); fi
  done
  if [ "${DWS_SKIP_PKG:-0}" = "1" ] || [ "${#need[@]}" -eq 0 ]; then
    set_to 60 "packages ready"
    return 0
  fi

  if is_termux; then
    run_phase 0 18 30 "updating package index" pkg update -y || true
    run_phase 18 60 150 "installing ${need[*]}" \
      pkg install -y -o Dpkg::Options::=--force-confold "${need[@]}" \
      || fail "installing ${need[*]}" "check your internet, or change mirror with: termux-change-repo"
  else
    local sudo_cmd=""
    if [ "$(id -u)" -ne 0 ]; then sudo_cmd="sudo"; fi
    export DEBIAN_FRONTEND=noninteractive
    run_phase 0 18 30 "updating package index" $sudo_cmd apt-get update -y || true
    run_phase 18 60 150 "installing ${need[*]}" \
      $sudo_cmd apt-get install -y -o Dpkg::Options::=--force-confold "${need[@]}" \
      || fail "installing ${need[*]}" "check your internet and sudo access"
  fi
}

phase_files() {
  set_to 64 "creating folders"
  mkdir -p "$BIN_DIR" "$BACKUP_DIR" >>"$LOG_FILE" 2>&1 || fail "creating ~/.dws" "check free space in your home folder"
  rm -rf "$DWS_HOME/src"
  if [ -f "$HOME/.zshrc.dws-backup" ]; then mv -f "$HOME/.zshrc.dws-backup" "$BACKUP_DIR/zshrc.old" 2>/dev/null; fi
  if [ -f "$HOME/.bashrc.dws-backup" ]; then mv -f "$HOME/.bashrc.dws-backup" "$BACKUP_DIR/bashrc.old" 2>/dev/null; fi

  set_to 70 "installing dws command"
  cp "$SRC_HERE/bin/dws" "$BIN_DIR/dws" >>"$LOG_FILE" 2>&1 || fail "copying the dws command" "is the DWS folder complete?"
  chmod 755 "$BIN_DIR/dws"
  cp "$SRC_HERE/config/dws.zsh" "$DWS_HOME/dws.zsh" >>"$LOG_FILE" 2>&1 || fail "copying dws.zsh" "is the DWS folder complete?"

  if [ -n "$NAME" ]; then
    printf '%s\n' "$NAME" > "$NAME_FILE" || fail "saving the banner name"
  fi
  if [ ! -f "$NAME_FILE" ]; then printf 'DWS\n' > "$NAME_FILE"; fi
}

# strip the exact lines written by DWS V2 (they had no markers)
strip_legacy() {
  local file="$1" list rc
  [ -f "$file" ] || return 0
  list="$(mktemp 2>/dev/null)" || return 0
  cat > "$list" <<'LEGACY'
export PATH="$HOME/.dws/bin:$PATH"
[ -r "$HOME/.dws/dws.zsh" ] && . "$HOME/.dws/dws.zsh"
if [ -t 1 ] && [ -z "${ZSH_VERSION:-}" ] && command -v zsh >/dev/null 2>&1; then exec zsh; fi
LEGACY
  grep -vxF -f "$list" "$file" > "$file.dws-tmp" 2>/dev/null
  rc=$?
  if [ "$rc" -le 1 ]; then mv -f "$file.dws-tmp" "$file"; else rm -f "$file.dws-tmp"; fi
  rm -f "$list"
}

backup_once() {
  local file="$1" name
  [ -f "$file" ] || return 0
  name="$(basename "$file" | tr -d '.')"
  if [ ! -f "$BACKUP_DIR/$name.orig" ] && ! grep -qF "$MARK_BEGIN" "$file"; then
    cp "$file" "$BACKUP_DIR/$name.orig"
  fi
}

# add or replace the managed block; lines outside the markers are kept
set_block() {
  local file="$1" body="$2" tmp
  touch "$file" || return 1
  tmp="$(mktemp)" || return 1
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" \
    '$0==b {skip=1; next} $0==e {skip=0; next} !skip' "$file" > "$tmp" || return 1
  { cat "$tmp"; printf '%s\n%s\n%s\n' "$MARK_BEGIN" "$body" "$MARK_END"; } > "$file" || return 1
  rm -f "$tmp"
}

phase_shell() {
  set_to 74 "backing up your shell files"
  backup_once "$HOME/.zshrc"
  backup_once "$HOME/.bashrc"
  set_to 78 "cleaning old DWS lines"
  strip_legacy "$HOME/.zshrc"
  strip_legacy "$HOME/.bashrc"

  local zsh_block bash_block
  zsh_block='export PATH="$HOME/.dws/bin:$PATH"
[ -r "$HOME/.dws/dws.zsh" ] && . "$HOME/.dws/dws.zsh"'
  bash_block='if [ -t 1 ] && [ -z "${ZSH_VERSION:-}" ] && command -v zsh >/dev/null 2>&1; then exec zsh; fi'
  set_to 84 "writing shell hooks"
  set_block "$HOME/.zshrc" "$zsh_block" || fail "writing ~/.zshrc" "check that the file is writable"
  set_block "$HOME/.bashrc" "$bash_block" || fail "writing ~/.bashrc" "check that the file is writable"
}

phase_termux() {
  if ! is_termux; then set_to 92 "no Termux extras needed"; return 0; fi
  set_to 87 "saving Termux welcome message"
  local motd="$TERMUX_PREFIX/etc/motd"
  if [ -f "$motd" ] && [ ! -f "$BACKUP_DIR/motd.orig" ]; then cp "$motd" "$BACKUP_DIR/motd.orig" 2>/dev/null; fi
  if [ -f "$motd" ]; then : > "$motd" 2>/dev/null; fi

  set_to 90 "applying colour scheme"
  mkdir -p "$HOME/.termux"
  local target="$HOME/.termux/colors.properties"
  if [ -f "$target" ] && [ ! -f "$BACKUP_DIR/colors.properties" ]; then
    cp "$target" "$BACKUP_DIR/colors.properties"
  elif [ ! -f "$target" ]; then
    : > "$BACKUP_DIR/colors.none"
  fi
  cp "$SRC_HERE/config/colors.properties" "$target" >>"$LOG_FILE" 2>&1 || true
  if command -v termux-reload-settings >/dev/null 2>&1; then termux-reload-settings >/dev/null 2>&1 || true; fi
  set_to 92 "colour scheme applied"
}

phase_finish() {
  set_to 95 "checking the install"
  [ -x "$BIN_DIR/dws" ] || fail "checking the install" "the dws command is missing"
  [ -f "$DWS_HOME/dws.zsh" ] || fail "checking the install" "dws.zsh is missing"
  grep -qF "$MARK_BEGIN" "$HOME/.zshrc" || fail "checking the install" "shell hook not written"

  set_to 98 "cleaning up"
  rm -f "$LOG_FILE"
  if [ "$DELETE_SRC" -eq 1 ]; then
    case "$SRC_HERE" in
      "$HOME"/?*)
        if [ "$SRC_HERE" != "$DWS_HOME" ]; then
          cd "$HOME" && rm -rf -- "$SRC_HERE"
        fi ;;
    esac
  fi
  set_to 100 "done"
}

summary_box() {
  local name; name="$(head -n 1 "$NAME_FILE" 2>/dev/null)"
  [ -n "$name" ] || name="DWS"
  local w=46 i
  local l1=" DONE  DWS PREMIUM V1 is installed"
  local l2=" banner : ${name}"
  local l3=" start  : dws help"
  printf '\n  %s+' "$VIO"; for ((i = 0; i < w; i++)); do printf '-'; done; printf '+%s\n' "$RESET"
  printf '  %s|%s%s%-*s%s|%s\n' "$VIO" "$MINT$BOLD" "" "$w" "$l1" "$VIO" "$RESET"
  printf '  %s|%s%-*s%s|%s\n' "$VIO" "$SKY" "$w" "$l2" "$VIO" "$RESET"
  printf '  %s|%s%-*s%s|%s\n' "$VIO" "$GREY" "$w" "$l3" "$VIO" "$RESET"
  printf '  %s+' "$VIO"; for ((i = 0; i < w; i++)); do printf '-'; done; printf '+%s\n\n' "$RESET"
}

# ---------- main --------------------------------------------
main() {
  if [ "$(uname -s)" != "Linux" ]; then
    printf 'DWS runs on Termux or Linux only.\n' >&2
    exit 1
  fi

  mkdir -p "$DWS_HOME" "$BACKUP_DIR" 2>/dev/null
  : > "$LOG_FILE"

  ask_questions

  # sudo password (Linux only) is asked BEFORE the bar, so the bar never stops for it
  if ! is_termux && [ "${DWS_SKIP_PKG:-0}" != "1" ]; then
    local need_any=0 p
    for p in zsh git curl; do command -v "$p" >/dev/null 2>&1 || need_any=1; done
    if [ "$need_any" -eq 1 ] && [ "$(id -u)" -ne 0 ]; then
      command -v sudo >/dev/null 2>&1 || { printf 'install sudo first, or run as root\n' >&2; exit 1; }
      sudo -v || { printf 'sudo password is needed for packages\n' >&2; exit 1; }
    fi
  fi

  if [ "$TTY" -eq 1 ]; then printf '\033[?25l'; fi
  START_TS=$(date +%s)
  set_to 0 "starting"

  phase_packages
  phase_files
  phase_shell
  phase_termux
  phase_finish

  if [ "$TTY" -eq 1 ]; then printf '\r\033[2K'; printf '\033[?25h'; fi
  summary_box

  if [ "$TTY" -eq 1 ] && [ -t 0 ] && command -v zsh >/dev/null 2>&1 && [ "${DWS_NO_EXEC:-0}" != "1" ]; then
    sleep 1.5
    printf '\033[H\033[2J\033[3J'
    printf '\033[?25h'
    exec zsh
  fi
}

main "$@"
