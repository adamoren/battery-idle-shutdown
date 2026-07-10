#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../bin/swayidle-wrapper.sh"
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
  export XDG_RUNTIME_DIR="$TEST_DIR/run"
  export XDG_CONFIG_HOME="$TEST_DIR/config"
  mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME/battery-idle-shutdown"

  # Fake swayidle ahead of the real one on PATH: dumps the argv it received
  # so we can assert on how the wrapper invokes it, without needing a real
  # Wayland compositor in CI.
  MOCK_BIN="$TEST_DIR/mockbin"
  mkdir -p "$MOCK_BIN"
  ARGS_FILE="$TEST_DIR/swayidle-args"
  export ARGS_FILE
  cat > "$MOCK_BIN/swayidle" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$ARGS_FILE"
MOCK
  chmod +x "$MOCK_BIN/swayidle"
  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "defaults to a 600s idle timeout when unconfigured" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx -- "600" "$ARGS_FILE"
}

@test "honors IDLE_SECONDS from config" {
  echo "IDLE_SECONDS=30" > "$XDG_CONFIG_HOME/battery-idle-shutdown/config"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx -- "30" "$ARGS_FILE"
  run ! grep -qx -- "600" "$ARGS_FILE"
}

@test "timeout/resume commands touch and remove the flag file" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  flag_file="$XDG_RUNTIME_DIR/battery-idle-shutdown.idle"
  grep -qF "touch '$flag_file'" "$ARGS_FILE"
  grep -qF "rm -f '$flag_file'" "$ARGS_FILE"
}
