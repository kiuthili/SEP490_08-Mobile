#!/usr/bin/env bash
# Cài dependency build Flutter Linux desktop (Ubuntu/Debian).
set -euo pipefail

echo "Cài clang, GTK3, ninja, cmake..."
sudo apt update
sudo apt install -y \
  clang \
  build-essential \
  cmake \
  ninja-build \
  pkg-config \
  libgtk-3-dev \
  liblzma-dev

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/tool/flutter_env.sh"

echo ""
echo "=== flutter doctor (Linux) ==="
flutter doctor -v | sed -n '/Linux toolchain/,/^$/p' || true
echo ""
echo "Chạy app:"
echo "  cd $ROOT"
echo "  ./tool/run_linux.sh"
