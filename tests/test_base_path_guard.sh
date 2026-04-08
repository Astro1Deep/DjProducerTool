#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"
ROOT_ES_WRAPPER="$ROOT_DIR/DJProducerTools_MultiScript_ES.sh"
ROOT_EN_WRAPPER="$ROOT_DIR/DJProducerTools_MultiScript_EN.sh"
APP_WRAPPER_ES="$ROOT_DIR/app/DJProducerTools_MultiScript_ES.sh"
APP_WRAPPER_EN="$ROOT_DIR/app/DJProducerTools_MultiScript_EN.sh"

if [ ! -f "$APP_SCRIPT" ]; then
  echo "[FAIL] missing app script: $APP_SCRIPT"
  exit 1
fi

for wrapper in "$ROOT_ES_WRAPPER" "$ROOT_EN_WRAPPER" "$APP_WRAPPER_ES" "$APP_WRAPPER_EN"; do
  if [ ! -f "$wrapper" ]; then
    echo "[FAIL] missing wrapper: $wrapper"
    exit 1
  fi
done

if env -i PATH="$PATH" bash "$APP_SCRIPT" --help >/tmp/djpt_guard_unset.log 2>&1; then
  echo "[FAIL] BASE_PATH unset should be rejected"
  exit 1
fi

if ! grep -q "BASE_PATH environment variable is required" /tmp/djpt_guard_unset.log; then
  echo "[FAIL] unset BASE_PATH error message not found"
  exit 1
fi

if env -i PATH="$PATH" bash "$ROOT_ES_WRAPPER" --help >/tmp/djpt_guard_root_es_unset.log 2>&1; then
  echo "[FAIL] root ES wrapper should reject unset BASE_PATH"
  exit 1
fi
if ! grep -qi "BASE_PATH is required" /tmp/djpt_guard_root_es_unset.log; then
  echo "[FAIL] root ES wrapper missing BASE_PATH required message"
  exit 1
fi

if env -i PATH="$PATH" bash "$ROOT_EN_WRAPPER" --help >/tmp/djpt_guard_root_en_unset.log 2>&1; then
  echo "[FAIL] root EN wrapper should reject unset BASE_PATH"
  exit 1
fi
if ! grep -qi "BASE_PATH is required" /tmp/djpt_guard_root_en_unset.log; then
  echo "[FAIL] root EN wrapper missing BASE_PATH required message"
  exit 1
fi

if env -i PATH="$PATH" bash "$APP_WRAPPER_EN" --help >/tmp/djpt_guard_app_en_unset.log 2>&1; then
  echo "[FAIL] app EN wrapper should reject unset BASE_PATH"
  exit 1
fi
if ! grep -qi "BASE_PATH is required" /tmp/djpt_guard_app_en_unset.log; then
  echo "[FAIL] app EN wrapper missing BASE_PATH required message"
  exit 1
fi

if BASE_PATH="/Volumes/SeaGate2TB" ALLOW_FULL_VOLUME=0 bash "$APP_SCRIPT" --help >/tmp/djpt_guard_volume.log 2>&1; then
  echo "[FAIL] root volume BASE_PATH should be blocked"
  exit 1
fi

if ! grep -q "Full volume scan detected and blocked" /tmp/djpt_guard_volume.log; then
  echo "[FAIL] full volume block message not found"
  exit 1
fi

if BASE_PATH="/Volumes/SeaGate2TB" ALLOW_FULL_VOLUME=0 bash "$ROOT_ES_WRAPPER" --help >/tmp/djpt_guard_root_volume.log 2>&1; then
  echo "[FAIL] root wrapper should block root-volume BASE_PATH"
  exit 1
fi

if BASE_PATH="/Volumes/SeaGate2TB" ALLOW_FULL_VOLUME=0 bash "$APP_WRAPPER_EN" --help >/tmp/djpt_guard_app_en_volume.log 2>&1; then
  echo "[FAIL] app EN wrapper should block root-volume BASE_PATH"
  exit 1
fi

echo "[PASS] BASE_PATH guard blocks unset and full-volume paths (canonical + wrappers)"
