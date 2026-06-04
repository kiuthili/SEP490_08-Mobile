#!/usr/bin/env bash
# Kiểm tra Android SDK / emulator trước khi chạy app.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/tool/flutter_env.sh"

echo "=== flutter doctor (Android) ==="
flutter doctor -v 2>&1 | sed -n '/Android toolchain/,/^$/p' || true
echo ""
echo "=== Emulators ==="
if flutter emulators 2>&1 | grep -qi 'Unable to find any emulator'; then
  echo "Chưa có AVD. Cài Android Studio → Device Manager → Create Device,"
  echo "hoặc xem README mục «Cài Android SDK & emulator (lần đầu)»."
  exit 1
fi
flutter emulators
echo ""
echo "=== Devices ==="
flutter devices
