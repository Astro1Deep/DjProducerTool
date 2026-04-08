#!/usr/bin/env bash
# Regression: wrappers must delegate to canonical scripts without false recursion errors.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

wrappers=(
  "$ROOT_DIR/DJProducerTools_MultiScript_ES.sh"
  "$ROOT_DIR/DJProducerTools_MultiScript_EN.sh"
  "$ROOT_DIR/app/DJProducerTools_MultiScript_ES.sh"
  "$ROOT_DIR/app/DJProducerTools_MultiScript_EN.sh"
)

for wrapper in "${wrappers[@]}"; do
  if [ ! -x "$wrapper" ]; then
    printf "[FAIL] wrapper missing or not executable: %s\n" "$wrapper"
    exit 1
  fi

  log_file="$(mktemp)"
  if ! env -i PATH="$PATH" HOME="${HOME:-/tmp}" BASE_PATH="$ROOT_DIR" DJPT_NO_INTERACTIVE=1 \
      bash "$wrapper" --no-interactive >"$log_file" 2>&1; then
    printf "[FAIL] wrapper returned non-zero: %s\n" "$wrapper"
    sed -n '1,40p' "$log_file"
    rm -f "$log_file"
    exit 1
  fi

  if grep -q "Recursive entrypoint invocation detected" "$log_file"; then
    printf "[FAIL] false recursion detected for wrapper: %s\n" "$wrapper"
    sed -n '1,40p' "$log_file"
    rm -f "$log_file"
    exit 1
  fi

  rm -f "$log_file"
done

echo "[PASS] wrappers delegate without false recursive-entrypoint errors"
