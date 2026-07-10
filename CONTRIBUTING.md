# Contributing

This is a small personal utility, but PRs and issues are welcome.

## Setup

```sh
sudo dnf install bats shellcheck   # or apt/pacman equivalents
```

## Before submitting a change

```sh
shellcheck -S style bin/*.sh install.sh uninstall.sh tests/*.bats
bats tests/
```

Both must pass locally -- they also run in CI on every push/PR (see the
badges in the README).

## Guidelines

- Keep scripts POSIX-ish `bash` with `set -euo pipefail`; shellcheck must be
  clean at `style` severity.
- If you touch `bin/battery-idle-shutdown.sh` or `bin/swayidle-wrapper.sh`,
  add or update a case in `tests/*.bats`. Tests mock `systemctl`,
  `notify-send`, and `swayidle` via `PATH` and use the `POWER_SUPPLY_DIR`
  env var to fake battery state -- they must never touch real hardware or
  actually power off the machine running them.
- Config knobs (thresholds, timeouts) belong in `config/config.example`,
  not hardcoded in scripts.
- If you add desktop-specific behavior (session restore, etc.) beyond KDE,
  gate it the same way `install.sh` gates on `$XDG_CURRENT_DESKTOP` and
  document the limitation in the README rather than assuming one desktop.

## Reporting bugs

Open a GitHub issue with your distro, desktop environment/compositor, and
the output of `wayland-info | grep -i idle` if the problem is idle-detection
related.
