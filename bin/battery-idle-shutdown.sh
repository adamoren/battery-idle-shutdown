#!/usr/bin/env bash
# Runs periodically via battery-idle-shutdown.timer. If the session is idle
# (per swayidle-wrapper.sh's flag file) and the battery is at/below the
# configured threshold while discharging, warns the user and powers off.
# systemctl poweroff broadcasts PrepareForShutdown, which lets KDE's
# ksmserver save the session (see ksmserverrc loginMode=restorePreviousLogout)
# and lets other apps' shutdown inhibitors run first.
set -euo pipefail

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/battery-idle-shutdown/config"
# shellcheck disable=SC1090
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

BATTERY_THRESHOLD="${BATTERY_THRESHOLD:-50}"
GRACE_SECONDS="${GRACE_SECONDS:-20}"
FLAG_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/battery-idle-shutdown.idle"

battery_dir=""
for psu in /sys/class/power_supply/*; do
  [ -f "$psu/type" ] || continue
  if [ "$(cat "$psu/type")" = "Battery" ]; then
    battery_dir="$psu"
    break
  fi
done

if [ -z "$battery_dir" ]; then
  echo "battery-idle-shutdown: no battery found, nothing to do" >&2
  exit 0
fi

conditions_met() {
  [ -f "$FLAG_FILE" ] || return 1
  local capacity status
  capacity="$(cat "$battery_dir/capacity")"
  status="$(cat "$battery_dir/status")"
  [ "$status" = "Discharging" ] || return 1
  [ "$capacity" -le "$BATTERY_THRESHOLD" ] || return 1
  return 0
}

conditions_met || exit 0

notify-send --urgency=critical --expire-time=$((GRACE_SECONDS * 1000)) \
  "Battery at ${BATTERY_THRESHOLD}% and idle" \
  "Shutting down in ${GRACE_SECONDS}s to save power. Session will restore on next login." \
  2>/dev/null || true

sleep "$GRACE_SECONDS"

# Re-check: user may have returned or plugged in during the grace period.
conditions_met || exit 0

systemctl poweroff
