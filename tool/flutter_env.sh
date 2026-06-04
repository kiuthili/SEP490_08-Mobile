#!/usr/bin/env bash
# Tránh lỗi "Disk quota exceeded" khi pub tải package vào /tmp.
# Dùng: source tool/flutter_env.sh   rồi chạy flutter pub get / flutter run

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE_ROOT="$(cd "$ROOT/.." && pwd)"

export TMPDIR="${MOBILE_ROOT}/.tmp"
export PUB_CACHE="${MOBILE_ROOT}/.pub-cache"
mkdir -p "$TMPDIR" "$PUB_CACHE"

# Flutter SDK (tránh "command not found" nếu chưa thêm vào ~/.zshrc)
if [[ -d "${HOME}/flutter/bin" ]]; then
  export PATH="${HOME}/flutter/bin:${PATH}"
fi

echo "TMPDIR=$TMPDIR"
echo "PUB_CACHE=$PUB_CACHE"
if command -v flutter >/dev/null 2>&1; then
  echo "Flutter: $(flutter --version 2>/dev/null | head -1)"
  echo "Tiếp theo (Linux desktop): ./tool/run_linux.sh"
else
  echo "Cảnh báo: không tìm thấy flutter trong PATH."
  echo "Thêm vào ~/.zshrc: export PATH=\"\$HOME/flutter/bin:\$PATH\""
fi
