#!/bin/bash
# Complete local gate: Python algorithms + Swift build + snapshots + live decoding.
set -euo pipefail
export PYTHONNOUSERSITE=1
export PYTHONDONTWRITEBYTECODE=1
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# Explicit override wins; otherwise reuse an existing complete environment.
PY="${TRANSIT_TEST_PYTHON:-}"
if [ -z "$PY" ]; then
  for candidate in "$ROOT_DIR/.venv/bin/python" python3 /Library/Frameworks/Python.framework/Versions/Current/bin/python3 /opt/homebrew/bin/python3; do
    if "$candidate" -c 'import pytest, swisseph, jsonschema' >/dev/null 2>&1; then
      PY="$("$candidate" -c 'import sys; print(sys.executable)')"
      break
    fi
  done
fi
if [ -z "$PY" ] || ! "$PY" -c 'import pytest, swisseph, jsonschema'; then
  echo "缺少测试依赖：请使用 requirements-dev.txt 准备环境，或设置 TRANSIT_TEST_PYTHON。" >&2
  exit 1
fi
# Existing subprocess tests invoke python3; keep them on the selected runtime.
export PATH="$(dirname "$PY"):$PATH"
export TRANSIT_TEST_PYTHON="$PY"
export TRANSIT_LIVE_CONTRACTS=1
BUILD_PATH="${SWIFTPM_BUILD_PATH:-$ROOT_DIR/.build}"

echo "1/4 Python 后端完整测试"
"$PY" -m pytest -p no:cacheprovider python_tests/ -q

echo "2/4 Swift 构建"
swift build --disable-sandbox --scratch-path "$BUILD_PATH"

echo "3/4 Swift 测试（含全部 Examples 实时后端 → 前端解码）"
swift test --disable-sandbox --scratch-path "$BUILD_PATH"

echo "4/4 差异格式检查"
git diff --check

echo "完整门禁通过。发布时仍须核对版本、安装产物和提交状态。"
