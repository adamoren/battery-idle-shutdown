#!/usr/bin/env bash
# Installs battery-idle-shutdown for the current user.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="$HOME/.local/bin"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/battery-idle-shutdown"
systemd_user_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

echo "==> Checking dependencies (swayidle, notify-send)"
missing=()
command -v swayidle >/dev/null 2>&1 || missing+=(swayidle)
command -v notify-send >/dev/null 2>&1 || missing+=(libnotify)

if [ "${#missing[@]}" -gt 0 ]; then
  echo "Installing: ${missing[*]}"
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y "${missing[@]}"
  elif command -v apt >/dev/null 2>&1; then
    sudo apt install -y "${missing[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm "${missing[@]}"
  else
    echo "Unknown package manager; install manually: ${missing[*]}" >&2
    exit 1
  fi
fi

echo "==> Checking compositor idle protocol support (ext-idle-notify-v1)"
if command -v wayland-info >/dev/null 2>&1; then
  if ! wayland-info 2>/dev/null | grep -q ext_idle_notifier_v1; then
    echo "WARNING: compositor does not advertise ext_idle_notifier_v1 -- swayidle may not detect idle correctly." >&2
  fi
else
  echo "wayland-info not found, skipping idle-protocol check" >&2
fi

echo "==> Installing scripts to $bin_dir"
mkdir -p "$bin_dir"
install -m 755 "$repo_dir/bin/swayidle-wrapper.sh" "$bin_dir/swayidle-wrapper.sh"
install -m 755 "$repo_dir/bin/battery-idle-shutdown.sh" "$bin_dir/battery-idle-shutdown.sh"

echo "==> Installing config to $config_dir"
mkdir -p "$config_dir"
if [ ! -f "$config_dir/config" ]; then
  cp "$repo_dir/config/config.example" "$config_dir/config"
  echo "Wrote default config, edit $config_dir/config to change thresholds."
else
  echo "Existing config found at $config_dir/config, leaving it as-is."
fi

echo "==> Installing systemd user units to $systemd_user_dir"
mkdir -p "$systemd_user_dir"
cp "$repo_dir/systemd/swayidle.service" "$systemd_user_dir/"
cp "$repo_dir/systemd/battery-idle-shutdown.service" "$systemd_user_dir/"
cp "$repo_dir/systemd/battery-idle-shutdown.timer" "$systemd_user_dir/"

if [ "${XDG_CURRENT_DESKTOP:-}" = "KDE" ]; then
  echo "==> KDE detected: enabling session restore (ksmserverrc loginMode=restorePreviousLogout)"
  ksmserverrc="${XDG_CONFIG_HOME:-$HOME/.config}/ksmserverrc"
  if [ -f "$ksmserverrc" ] && grep -q '^\[General\]' "$ksmserverrc"; then
    if grep -q '^loginMode=' "$ksmserverrc"; then
      sed -i 's/^loginMode=.*/loginMode=restorePreviousLogout/' "$ksmserverrc"
    else
      sed -i '/^\[General\]/a loginMode=restorePreviousLogout' "$ksmserverrc"
    fi
  else
    printf '[General]\nloginMode=restorePreviousLogout\n' >> "$ksmserverrc"
  fi
else
  echo "Non-KDE desktop (${XDG_CURRENT_DESKTOP:-unknown}) detected."
  echo "Session restore on next login is desktop-specific -- for GNOME/other"
  echo "desktops, rely on individual apps' own session-restore settings"
  echo "(browsers, terminal multiplexers, etc.)."
fi

echo "==> Enabling systemd units"
systemctl --user daemon-reload
systemctl --user enable --now swayidle.service
systemctl --user enable --now battery-idle-shutdown.timer

echo "==> Done. Current status:"
systemctl --user status swayidle.service --no-pager || true
systemctl --user list-timers battery-idle-shutdown.timer --no-pager || true
