#!/usr/bin/env bash
# Chạy app trên Android (emulator hoặc thiết bị USB). Tránh build Linux desktop.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=/dev/null
source "$ROOT/tool/flutter_env.sh"

API_URL="${API_BASE_URL:-https://10.0.2.2:7010}"
DEVICE="${FLUTTER_DEVICE:-}"

echo "API_BASE_URL=$API_URL"
flutter pub get

if [[ -n "$DEVICE" ]]; then
  flutter run -d "$DEVICE" --dart-define=API_BASE_URL="$API_URL" "$@"
else
  if flutter devices 2>/dev/null | grep -qE 'android|emulator'; then
    flutter run -d android --dart-define=API_BASE_URL="$API_URL" "$@"
  else
    echo "Không thấy thiết bị Android. Liệt kê:"
    flutter devices
    echo ""
    echo "Khởi động emulator: flutter emulators"
    echo "  flutter emulators --launch <emulator_id>"
    echo "Hoặc: FLUTTER_DEVICE=<id> ./tool/run_android.sh"
    exit 1
  fi
fi
