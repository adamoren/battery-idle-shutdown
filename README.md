# battery-idle-shutdown

[![shellcheck](https://github.com/adamoren/battery-idle-shutdown/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/adamoren/battery-idle-shutdown/actions/workflows/shellcheck.yml)
[![tests](https://github.com/adamoren/battery-idle-shutdown/actions/workflows/tests.yml/badge.svg)](https://github.com/adamoren/battery-idle-shutdown/actions/workflows/tests.yml)

Simulates "hibernation" on laptops that don't support real suspend-to-disk
(e.g. Apple Silicon Macs under Asahi Linux, where hibernation isn't
implemented). Instead of sleeping indefinitely and slowly draining the
battery, the machine powers off once it's both idle and the battery has
drifted down to a chosen level -- and restores your session on next login.

## How it works

- **Idle detection**: `swayidle` listens on the compositor's `ext-idle-notify-v1`
  Wayland protocol and touches/removes a flag file in `$XDG_RUNTIME_DIR` as
  the session goes idle/active. Event-driven, not polling.
- **Battery check**: a systemd user timer runs every 2 minutes, and powers
  off only if the session is idle *and* the battery is at or below the
  configured threshold *and* discharging (never triggers while charging).
- **Session restore**: `systemctl poweroff` broadcasts logind's
  `PrepareForShutdown` signal before shutting down, which lets desktop
  session managers save state cleanly. On KDE this is `ksmserver`'s
  `loginMode=restorePreviousLogout`, which the installer enables
  automatically -- open apps come back on next login. This is a "best
  effort" restore (whatever the DE/apps support), not a real memory
  snapshot -- unsaved work in apps without their own session restore will
  be lost.
- **Lid close**: on KDE, closing the lid suspends the machine by default
  (`powerdevil`'s `LidAction`), which happens within about a second --
  long before the idle timeout or the 2-minute battery-check timer ever
  get a chance to run. The installer sets `LidAction=NoAction` for the
  `AC`/`Battery`/`LowBattery` power profiles in `~/.config/powerdevilrc`
  so the machine keeps running (screen off, lid closed) until *this
  tool's* idle+battery logic decides to power off. Without this, the
  whole mechanism silently never fires.

## Requirements

- A Wayland compositor implementing `ext-idle-notify-v1` (KWin/Plasma 5.27+,
  sway, most wlroots compositors). Check with `wayland-info | grep idle`.
- systemd user session.
- `swayidle` and `notify-send` (installed automatically by `install.sh`).

## Install

```sh
git clone <this repo> ~/projects/battery-idle-shutdown
cd ~/projects/battery-idle-shutdown
./install.sh
```

Edit `~/.config/battery-idle-shutdown/config` to change the battery
threshold (default 50%), idle timeout (default 10 min), or warning grace
period (default 20s) before it takes effect (or re-run
`systemctl --user restart swayidle.service battery-idle-shutdown.timer`
after editing, if you changed `IDLE_SECONDS`).

## Uninstall

```sh
./uninstall.sh
```

## Notes

- Session restore setup (`ksmserverrc`) is currently KDE-specific. On other
  desktops the timer/idle/shutdown mechanism still works, but you'll rely on
  individual apps' own session restore (browsers, terminal multiplexers,
  etc.) rather than a full desktop session restore.
- The shutdown always re-checks conditions after the grace period, so
  plugging in or returning to the machine during the warning cancels it.
- On dual-battery laptops (e.g. some ThinkPads), only the first battery
  reported under `/sys/class/power_supply` is checked.

## Testing

```sh
sudo dnf install bats shellcheck   # or apt/pacman equivalents
shellcheck bin/*.sh install.sh uninstall.sh tests/*.bats
bats tests/
```

Tests mock `systemctl`/`notify-send`/`swayidle` via `PATH` and point the
scripts at a fake `/sys/class/power_supply` directory (via the
`POWER_SUPPLY_DIR` override) and a fake `$XDG_RUNTIME_DIR`, so they never
touch real hardware or actually power off the machine running them. Both
GitHub Actions workflows (`shellcheck`, `tests`) run on every push.
