#!/usr/bin/env bash
# Read-only audit: no bans, reloads, or firewall modifications.
set -Eeuo pipefail
bad=0
check(){ if "$@" >/dev/null 2>&1; then echo "[PASS] $*"; else echo "[FAIL] $*" >&2; bad=$((bad+1)); fi; }
command -v fail2ban-client >/dev/null || { echo "fail2ban-client missing" >&2; exit 1; }
check fail2ban-client -t
check fail2ban-client ping
echo "[INFO] Enabled jails:"
fail2ban-client status || bad=$((bad+1))
for jail in sshd sshd-cipher-mismatch sshd-banner-fail recidive; do
  if fail2ban-client status "$jail"; then
    echo "[INFO] $jail action details:"
    fail2ban-client get "$jail" actions || true
    fail2ban-client get "$jail" maxretry || true
    fail2ban-client get "$jail" bantime || true
  else echo "[FAIL] jail $jail absent" >&2; bad=$((bad+1)); fi
done
if [[ -r /config/log/auth.log ]]; then
  for filter in sshd sshd-cipher-mismatch sshd-banner-fail; do
    echo "[INFO] regex test $filter"
    fail2ban-regex /config/log/auth.log "$filter" 2>&1 | tail -n 18 || bad=$((bad+1))
  done
else echo "[WARN] auth.log missing/unreadable"; fi
echo "[INFO] Firewall inspection (no rules changed):"
if command -v nft >/dev/null; then nft list ruleset 2>&1 | grep -E 'f2b|fail2ban|ssh' || true; fi
if command -v iptables >/dev/null; then iptables -S 2>&1 | grep -E 'f2b|fail2ban' || true; fi
echo "[INFO] No packet-drop test conducted by this script."
(( bad == 0 ))
