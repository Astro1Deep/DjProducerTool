#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

check_target() {
  local file="$1"
  local expected="$2"
  if ! grep -q "$expected" "$file"; then
    echo "[FAIL] $file does not point to $expected"
    exit 1
  fi
}

check_target "$ROOT_DIR/DJPT_ES.sh" "DJProducerTools_MultiScript_ES.sh"
check_target "$ROOT_DIR/DJPT_EN.sh" "DJProducerTools_MultiScript_EN.sh"

echo "[PASS] legacy wrappers point to canonical entrypoints"
