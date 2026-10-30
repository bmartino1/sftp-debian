#!/usr/bin/env bash
# Installed package inventory. Prints versions, never credentials.
set -Eeuo pipefail
phase="${1:-runtime}"
stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[versions] phase=$phase utc=$stamp os=$(awk -F= '/^ID=/{gsub(/"/,"",$2);print $2}' /etc/os-release)"
echo "[versions] ssh_client=$(ssh -V 2>&1)"
echo "[versions] ssh_daemon=$(sshd -V 2>&1 || true)"
package_version() {
  local pkg="$1" line
  if command -v apk >/dev/null 2>&1; then
    # Alpine apk v3's 'apk info -v NAME' can return a description instead of
    # the installed version. Query installed package records explicitly.
    line="$(apk list --installed "$pkg" 2>/dev/null | awk -v pkg="$pkg" '$1 ~ ("^"pkg"-[0-9]") {print $1; exit}' || true)"
    printf '%s' "${line:-absent}"
  elif command -v dpkg-query >/dev/null 2>&1; then
    dpkg-query -W -f='${Package}=${Version}' "$pkg" 2>/dev/null || printf absent
  else
    printf unsupported
  fi
}
for pkg in openssh-server openssh-client openssh-sftp-server fail2ban whois rsyslog openssl libc6; do
  echo "[versions] package=$pkg installed=$(package_version "$pkg")"
done
echo "[versions] whois_path=$(command -v whois || echo absent)"
