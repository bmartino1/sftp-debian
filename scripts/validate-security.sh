#!/usr/bin/env bash
# Non-destructive SSHD / Fail2Ban preflight for the container.
set -Eeuo pipefail
config="${1:-/etc/ssh/sshd_config}"
errors=0
warn() { printf '[audit][WARN] %s\n' "$*" >&2; }
pass() { printf '[audit][PASS] %s\n' "$*"; }
fail() { printf '[audit][FAIL] %s\n' "$*" >&2; errors=$((errors+1)); }
command -v sshd >/dev/null || { fail 'sshd not installed'; exit 1; }
[[ -r "$config" ]] || { fail "cannot read $config"; exit 1; }
if ! sshd -t -f "$config"; then fail 'sshd -t failed'; exit 1; fi
pass 'sshd syntax and host keys checked'
effective="$(sshd -T -f "$config")" || { fail 'sshd -T failed'; exit 1; }
# OpenSSH 10.6 may print mixed-case option names in sshd -T output.
# Match option names case-insensitively while preserving the setting value.
get() { awk -v k="$1" 'tolower($1)==tolower(k) {$1=""; sub(/^ /,""); print; exit}' <<<"$effective"; }
expect() { local key="$1" wanted="$2" actual; actual="$(get "$key")"; [[ "$actual" == "$wanted" ]] && pass "$key=$wanted" || fail "$key expected '$wanted', got '$actual'"; }
expect permitrootlogin no
expect passwordauthentication yes
expect kbdinteractiveauthentication no
expect pubkeyauthentication no
expect permittty no
expect x11forwarding no
expect allowtcpforwarding no
expect disableforwarding yes
expect allowagentforwarding no
expect permituserenvironment no
expect permittunnel no
expect forcecommand 'internal-sftp -f AUTHPRIV -l INFO'
expect chrootdirectory '%h'
grace="$(get logingracetime)"
if [[ "$grace" =~ ^[0-9]+$ ]] && (( grace > 0 && grace <= 60 )); then pass "bounded logingracetime=$grace"; else fail "logingracetime should be 1..60s, got '$grace'"; fi
if command -v fail2ban-client >/dev/null; then
  if fail2ban-client -d >/dev/null 2>&1; then pass 'Fail2Ban configuration parses'; else warn 'Fail2Ban config did not parse (requires mounted jail/config files)'; fi
  if fail2ban-client ping >/dev/null 2>&1; then
    pass 'Fail2Ban daemon responds'
    fail2ban-client status sshd || warn 'sshd jail not running'
  else warn 'Fail2Ban daemon not responding (offline/build tests may be expected)'; fi
else warn 'Fail2Ban binary not installed'; fi
printf '[audit] completed with %d SSHD failure(s)\n' "$errors"
(( errors == 0 ))
