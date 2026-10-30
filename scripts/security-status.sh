#!/usr/bin/env bash
set -Eeuo pipefail
printf 'Timestamp: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
grep -E '^(ID|VERSION_ID)=' /etc/os-release || true
ssh -V 2>&1
sshd -V 2>&1 || true
fail2ban-client -V 2>&1 || true
if command -v dpkg-query >/dev/null; then
  dpkg-query -W -f='${binary:Package} ${Version}\n' openssh-server openssh-client openssh-sftp-server fail2ban whois || true
  apt-cache policy openssh-server || true
elif command -v apk >/dev/null; then
  apk info -v | grep -E '^(openssh|fail2ban|whois|rsyslog)' || true
  apk policy openssh-server || true
fi
printf 'Upstream: https://www.openssh.org/security.html\nDebian: https://security-tracker.debian.org/tracker/source-package/openssh\nAlpine: https://security.alpinelinux.org/\n'
printf 'Version inventory only: no automatic CVE applicability verdict.\n'
