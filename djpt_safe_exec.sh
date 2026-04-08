#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: djpt_safe_exec.sh [--timeout SECONDS] -- command [args...]
EOF
}

timeout_secs=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout)
      timeout_secs="${2:-0}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -gt 0 ]] || { usage; exit 1; }

if [[ "$timeout_secs" =~ ^[0-9]+$ ]] && [[ "$timeout_secs" -gt 0 ]] && command -v timeout >/dev/null 2>&1; then
  exec timeout "$timeout_secs" "$@"
fi
exec "$@"
