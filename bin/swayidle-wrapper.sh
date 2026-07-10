#!/usr/bin/env bash
# Tracks idle state via the compositor's idle protocol and drops a flag
# file that battery-idle-shutdown.sh polls. Runs under systemd --user.
set -euo pipefail

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/battery-idle-shutdown/config"
# shellcheck disable=SC1090
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

IDLE_SECONDS="${IDLE_SECONDS:-600}"
FLAG_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/battery-idle-shutdown.idle"

exec swayidle -w \
  timeout "$IDLE_SECONDS" "touch '$FLAG_FILE'" \
  resume "rm -f '$FLAG_FILE'"
