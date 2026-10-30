#!/usr/bin/env bash
set -Eeuo pipefail
log(){ echo "[update] $*"; }
err(){ echo "[update][ERROR] $*" >&2; }
mode="${1:-suite}"
[[ "$mode" == suite ]] || { err "Unknown mode: $mode"; exit 2; }
if command -v apk >/dev/null 2>&1; then
  log "Alpine: refresh repositories and upgrade installed packages"
  apk update
  apk upgrade --available
  apk info -v | grep -E '^(openssh|fail2ban|whois|rsyslog)' || true
elif command -v apt-get >/dev/null 2>&1; then
  log "Debian: refresh configured suite repositories"
  apt-get update -o APT::Update::Error-Mode=any
  log "Upgrading installed packages within configured Debian suite"
  DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confold" upgrade -y --no-install-recommends
  dpkg-query -W -f='${binary:Package} ${Version}\n' openssh-server openssh-client openssh-sftp-server fail2ban whois || true
  apt-get clean
else
  err "No supported package manager (apt-get or apk)"
  exit 3
fi
log "Package update completed. Distribution packages may lag upstream security fixes; run CVE review."
