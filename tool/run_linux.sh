#!/usr/bin/env bash
# Linux desktop — API mặc định http://127.0.0.1:5046 (Gateway trên máy local).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=/dev/null
source "$ROOT/tool/flutter_env.sh"

# Tránh lỗi CXX=clang++ khi chưa cài clang.
if [[ -n "${CXX:-}" ]] && ! command -v "${CXX%% *}" >/dev/null 2>&1; then
  unset CXX
  echo "Đã unset CXX (compiler không tồn tại)."
fi

if ! flutter doctor 2>/dev/null | grep -q 'Linux toolchain.*• Ubuntu clang'; then
  if ! command -v clang++ >/dev/null 2>&1; then
    echo "Thiếu clang/GTK. Chạy: ./tool/setup_linux.sh"
    exit 1
  fi
fi

if [[ -z "${API_BASE_URL:-}" ]]; then
  if RESP=$(curl -sf --max-time 2 "http://127.0.0.1:7010/api/tours/public?pageSize=1" 2>/dev/null) \
     && [[ "$RESP" == *'"data"'* || "$RESP" == *'"total"'* ]]; then
    API_URL="http://127.0.0.1:7010"
    echo "Phát hiện backend Docker (gateway :7010)."
  else
    API_URL="http://127.0.0.1:5046"
    echo "Dùng Gateway local :5046 (dotnet run). Docker thường là :7010."
    echo "Lưu ý: không dùng :5173 (frontend nginx trả 405 cho POST /api)."
  fi
else
  API_URL="$API_BASE_URL"
fi
echo "Chạy Linux desktop — API_BASE_URL=$API_URL"
flutter pub get
flutter run -d linux --dart-define=API_BASE_URL="$API_URL" "$@"
