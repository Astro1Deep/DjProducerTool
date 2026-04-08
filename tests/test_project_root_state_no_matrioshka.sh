#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/DJProducerTools_MultiScript_ES.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PROJECT_ROOT="$TMP_ROOT/DJProducerTools_release_test"
mkdir -p "$PROJECT_ROOT/scripts"
touch "$PROJECT_ROOT/cli.py" "$PROJECT_ROOT/scripts/cli.py" "$PROJECT_ROOT/DJProducerTools_MultiScript_ES.sh" "$PROJECT_ROOT/scripts/DJProducerTools_MultiScript_ES.sh"

output="$(
  DJPT_SOURCED=1 \
  BASE_PATH="$PROJECT_ROOT" \
  DJPT_STATE_ANCHOR="$PROJECT_ROOT" \
  bash -lc '
    source "'"$SCRIPT"'"
    init_paths
    printf "STATE_DIR=%s\n" "$STATE_DIR"
  '
)"

printf "%s\n" "$output" | rg -q "^STATE_DIR=$PROJECT_ROOT$"
! test -d "$PROJECT_ROOT/_DJProducerTools"

echo "PASS project_root_state_no_matrioshka"
