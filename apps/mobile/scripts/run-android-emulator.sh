#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_HOME
export PATH="${FLUTTER_ROOT:-$HOME/development/flutter}/bin:$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"

AVD="${ANDROID_AVD:-bloomora_api35}"
EMU_LOG="${TMPDIR:-/tmp}/bloomora-api35-emulator.log"

echo "==> Ensuring API is reachable (optional: start with 'cd api && npm run start:dev')"
curl -sf "http://localhost:3000/api/v1" >/dev/null 2>&1 || \
  echo "WARN: API not responding on http://localhost:3000 — start Docker + api first."

pick_device_id() {
  adb devices | awk '/^emulator-.*device$/{print $1; exit}'
}

DEVICE_ID="$(pick_device_id || true)"

if [[ -z "${DEVICE_ID}" ]]; then
  echo "==> Starting Android emulator: $AVD"
  AVD_DIR="$HOME/.android/avd/${AVD}.avd"
  WIPE_ARGS=()
  if grep -q "Image is corrupt" "$EMU_LOG" 2>/dev/null; then
    echo "==> Corrupt AVD userdata detected; wiping on next boot"
    rm -f "$AVD_DIR/userdata-qemu.img.qcow2" "$AVD_DIR/userdata-qemu.img" "$AVD_DIR/cache.img.qcow2" 2>/dev/null || true
    WIPE_ARGS=(-wipe-data)
  fi
  rm -rf "$AVD_DIR/"*.lock 2>/dev/null || true
  pkill -f "emulator.*-avd $AVD" 2>/dev/null || true
  adb kill-server 2>/dev/null || true
  adb start-server
  nohup "$ANDROID_HOME/emulator/emulator" -avd "$AVD" -no-boot-anim -gpu host "${WIPE_ARGS[@]}" \
    > "$EMU_LOG" 2>&1 &
  disown
  adb wait-for-device
  for _ in $(seq 1 60); do
    if [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then
      break
    fi
    if ! pgrep -f "emulator.*-avd $AVD" >/dev/null 2>&1; then
      if grep -q "Image is corrupt" "$EMU_LOG"; then
        echo "==> Emulator crashed (corrupt userdata). Wipe the AVD in Android Studio Device Manager, then retry."
        exit 1
      fi
      echo "==> Emulator exited unexpectedly; see $EMU_LOG"
      exit 1
    fi
    sleep 4
  done
  DEVICE_ID="$(pick_device_id || true)"
fi

if [[ -z "${DEVICE_ID}" ]]; then
  echo "==> No Android emulator online. Start one with:"
  echo "    $ANDROID_HOME/emulator/emulator -avd $AVD"
  exit 1
fi

echo "==> Using device: $DEVICE_ID"
adb devices -l
cd "$ROOT"
exec flutter run -d "$DEVICE_ID" "$@"
