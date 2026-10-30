#!/usr/bin/env bash
set -Eeuo pipefail
pgrep -x sshd >/dev/null
sshd -t -f /etc/ssh/sshd_config >/dev/null 2>&1
fail2ban-client ping >/dev/null 2>&1
fail2ban-client status sshd >/dev/null 2>&1
