#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../bin/battery-idle-shutdown.sh"
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
  export POWER_SUPPLY_DIR="$TEST_DIR/power_supply"
  export XDG_RUNTIME_DIR="$TEST_DIR/run"
  export XDG_CONFIG_HOME="$TEST_DIR/config"
  FLAG_FILE="$XDG_RUNTIME_DIR/battery-idle-shutdown.idle"

  mkdir -p "$POWER_SUPPLY_DIR/BAT0" "$XDG_RUNTIME_DIR" \
    "$XDG_CONFIG_HOME/battery-idle-shutdown"
  echo "Battery" > "$POWER_SUPPLY_DIR/BAT0/type"

  cat > "$XDG_CONFIG_HOME/battery-idle-shutdown/config" <<EOF
BATTERY_THRESHOLD=50
GRACE_SECONDS=0
EOF

  # Fake systemctl/notify-send ahead of the real ones on PATH so the test
  # never actually powers off the runner, and records what was called.
  MOCK_BIN="$TEST_DIR/mockbin"
  mkdir -p "$MOCK_BIN"
  CALL_LOG="$TEST_DIR/calls.log"
  export CALL_LOG
  cat > "$MOCK_BIN/systemctl" <<'MOCK'
#!/usr/bin/env bash
echo "systemctl $*" >> "$CALL_LOG"
MOCK
  cat > "$MOCK_BIN/notify-send" <<'MOCK'
#!/usr/bin/env bash
echo "notify-send $*" >> "$CALL_LOG"
MOCK
  chmod +x "$MOCK_BIN"/systemctl "$MOCK_BIN"/notify-send
  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

set_battery() {
  echo "$1" > "$POWER_SUPPLY_DIR/BAT0/capacity"
  echo "$2" > "$POWER_SUPPLY_DIR/BAT0/status"
}

was_poweroff_called() {
  [ -f "$CALL_LOG" ] && grep -q "systemctl poweroff" "$CALL_LOG"
}

@test "idle + discharging + at/below threshold triggers poweroff" {
  set_battery 45 Discharging
  touch "$FLAG_FILE"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  was_poweroff_called
}

@test "not idle (no flag file) does not trigger poweroff" {
  set_battery 45 Discharging
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  run ! was_poweroff_called
}

@test "charging does not trigger poweroff even at/below threshold" {
  set_battery 45 Charging
  touch "$FLAG_FILE"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  run ! was_poweroff_called
}

@test "battery above threshold does not trigger poweroff" {
  set_battery 80 Discharging
  touch "$FLAG_FILE"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  run ! was_poweroff_called
}

@test "battery exactly at threshold triggers poweroff (boundary)" {
  set_battery 50 Discharging
  touch "$FLAG_FILE"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  was_poweroff_called
}

@test "no battery present exits cleanly without touching systemctl" {
  rm -rf "${POWER_SUPPLY_DIR:?}"/*
  touch "$FLAG_FILE"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  run ! was_poweroff_called
}

@test "plugging in during the grace period aborts the poweroff" {
  cat > "$XDG_CONFIG_HOME/battery-idle-shutdown/config" <<EOF
BATTERY_THRESHOLD=50
GRACE_SECONDS=1
EOF
  set_battery 45 Discharging
  touch "$FLAG_FILE"
  ( sleep 0.3; echo Charging > "$POWER_SUPPLY_DIR/BAT0/status" ) &
  run "$SCRIPT"
  wait
  [ "$status" -eq 0 ]
  run ! was_poweroff_called
}

@test "sends a warning notification before powering off" {
  set_battery 45 Discharging
  touch "$FLAG_FILE"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "notify-send" "$CALL_LOG"
}
