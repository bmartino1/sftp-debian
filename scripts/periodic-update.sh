#!/usr/bin/env bash
# Opt-in Debian timed updates. Running SSH sessions are NOT restarted.
set -Eeuo pipefail
hours="${AUTO_UPDATE_INTERVAL_HOURS:-0}"
[[ "$hours" =~ ^[0-9]+$ ]] || { echo "[periodic-update][ERROR] invalid interval" >&2; exit 2; }
(( hours > 0 )) || exit 0
while sleep "$((hours * 3600))"; do
  echo "[periodic-update] checking APT updates at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  before="$(dpkg-query -W -f='${Version}' openssh-server 2>/dev/null || echo absent)"
  if /usr/local/bin/update-inplace.sh suite; then
    after="$(dpkg-query -W -f='${Version}' openssh-server 2>/dev/null || echo absent)"
    /usr/local/bin/report-versions.sh periodic || true
    if [[ "$before" != "$after" ]]; then
      printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ) OpenSSH: $before -> $after" > /config/debug/restart-required.txt
      echo "[periodic-update][RESTART REQUIRED] OpenSSH $before -> $after; restart/recreate container in a maintenance window"
    fi
  else
    echo "[periodic-update][ERROR] APT upgrade failed; inspect logs" >&2
  fi
done
