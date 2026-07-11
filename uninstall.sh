#!/usr/bin/env bash
set -euo pipefail

bin_dir="$HOME/.local/bin"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/battery-idle-shutdown"
systemd_user_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

systemctl --user disable --now swayidle.service 2>/dev/null || true
systemctl --user disable --now battery-idle-shutdown.timer 2>/dev/null || true

rm -f "$systemd_user_dir/swayidle.service" \
      "$systemd_user_dir/battery-idle-shutdown.service" \
      "$systemd_user_dir/battery-idle-shutdown.timer"
rm -f "$bin_dir/swayidle-wrapper.sh" "$bin_dir/battery-idle-shutdown.sh"

systemctl --user daemon-reload

echo "Removed units and scripts. Config left at $config_dir (delete manually if unwanted)."
echo "Note: ksmserverrc loginMode setting (KDE session restore) was left untouched."
echo "Note: powerdevil's LidAction=NoAction (disabled suspend-on-lid-close) was left"
echo "untouched -- re-enable via System Settings > Power Management > Energy Saving"
echo "if you want closing the lid to suspend the machine again."
