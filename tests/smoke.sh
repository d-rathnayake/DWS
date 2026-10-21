#!/usr/bin/env bash
# ==========================================================
#  DWS smoke test — used by CI and by hand:  bash tests/smoke.sh
#  Installs into a throw-away HOME, so your real files are never touched.
# ==========================================================
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
mkdir -p "$HOME"
export DWS_SKIP_PKG=1 DWS_NO_EXEC=1
DWS="$HOME/.dws/bin/dws"

pass=0
fail=0
check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    pass=$(( pass + 1 )); printf 'PASS  %s\n' "$label"
  else
    fail=$(( fail + 1 )); printf 'FAIL  %s\n' "$label"
  fi
}

# copy the project so the installer can run from a folder outside ~/.dws
cp -R "$ROOT" "$TMP/DWS"

check "install.sh parses"          bash -n "$ROOT/install.sh"
check "dws command parses"         bash -n "$ROOT/bin/dws"
check "install runs"               bash "$TMP/DWS/install.sh" </dev/null
check "dws command installed"      test -x "$DWS"
check "version is V1"              sh -c "\"$DWS\" version | grep -q 'DWS PREMIUM V1'"
check "help runs"                  "$DWS" help
check "dashboard runs"             "$DWS" dashboard
check "icon ls runs"               "$DWS" ls
check "ls -la runs"                "$DWS" ls -la
check "calc works"                 sh -c "\"$DWS\" calc '2^10' | grep -q 1024"
check "calc blocks code injection" sh -c "! \"$DWS\" calc 'system(1)' 2>/dev/null"
check "pass length 20"             sh -c "[ \"\$(\"$DWS\" pass 20 | tr -d '\\n' | wc -c)\" -eq 20 ]"
check "zsh hook written"           grep -qF "# >>> DWS >>>" "$HOME/.zshrc"
check "bash hook written"          grep -qF "# >>> DWS >>>" "$HOME/.bashrc"
check "name file written"          test -s "$HOME/.dws/name"

# re-running the installer must not duplicate anything
check "re-install runs"            bash "$TMP/DWS/install.sh" </dev/null
check "zsh hook not duplicated"    sh -c "[ \$(grep -c '# >>> DWS >>>' \"$HOME/.zshrc\") -eq 1 ]"
check "bash hook not duplicated"   sh -c "[ \$(grep -c '# >>> DWS >>>' \"$HOME/.bashrc\") -eq 1 ]"

# uninstall cancels without YES, and removes everything with YES
check "uninstall without YES keeps files" sh -c "echo no | \"$DWS\" uninstall >/dev/null; test -d \"$HOME/.dws\""
check "uninstall with YES"         sh -c "echo YES | \"$DWS\" uninstall >/dev/null"
check "~/.dws removed"             sh -c "! test -d \"$HOME/.dws\""
check "zsh hook removed"           sh -c "! grep -qF '# >>> DWS >>>' \"$HOME/.zshrc\" 2>/dev/null"

printf '\npassed=%d failed=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
