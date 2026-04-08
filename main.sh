#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/bin/djpt"

if [ ! -x "$TARGET" ]; then
  echo "[ERR] Missing canonical launcher: $TARGET" >&2
  exit 1
fi

exec "$TARGET" "$@"
