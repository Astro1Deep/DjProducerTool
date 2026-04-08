#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAMP="$(date +%Y%m%d_%H%M%S)"
ZIP_PATH=""
WORK_DIR=""
REPORT_PATH=""
FULL_NETWORK=0
RUN_PYTEST=1
INSTALL_MODE="${DJPT_CERT_INSTALL_MODE:-core}"
BASE_PYTHON="${DJPT_BOOTSTRAP_PYTHON:-python3}"

usage() {
  cat <<'EOF'
Uso: certify_fresh_install.sh [--zip PATH] [--workdir PATH] [--report PATH] [--full-network] [--skip-pytest] [--core|--full]

Certifica una instalación limpia extraída desde el zip de release fuera del repo.
EOF
}

latest_zip() {
  ls -1t "$REPO_ROOT"/dist/DJProducerTools_release_*.zip 2>/dev/null | head -n 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --zip)
      ZIP_PATH="$2"
      shift 2
      ;;
    --workdir)
      WORK_DIR="$2"
      shift 2
      ;;
    --report)
      REPORT_PATH="$2"
      shift 2
      ;;
    --full-network)
      FULL_NETWORK=1
      shift
      ;;
    --skip-pytest)
      RUN_PYTEST=0
      shift
      ;;
    --core)
      INSTALL_MODE="core"
      shift
      ;;
    --full)
      INSTALL_MODE="full"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[ERR] Opción no reconocida: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$ZIP_PATH" ]; then
  ZIP_PATH="$(latest_zip)"
fi

if [ -z "$ZIP_PATH" ] || [ ! -f "$ZIP_PATH" ]; then
  echo "[ERR] Zip de release no encontrado." >&2
  exit 1
fi

if [ -z "$WORK_DIR" ]; then
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/djpt_fresh_install_${STAMP}.XXXXXX")"
fi

if [ -z "$REPORT_PATH" ]; then
  mkdir -p "$REPO_ROOT/reports"
  REPORT_PATH="$REPO_ROOT/reports/fresh_install_certification_${STAMP}.md"
fi

mkdir -p "$(dirname "$REPORT_PATH")"

LOG_FILE="$WORK_DIR/fresh_install.log"
HEALTH_JSON="$WORK_DIR/ai_health.json"
CONTRACT_JSON="$WORK_DIR/menu_contract.json"
PACKAGE_ROOT="$WORK_DIR/_DJProducerTools"
VERIFY_ARGS=(--root "$PACKAGE_ROOT" --full-inventory)

if [ "$FULL_NETWORK" -eq 1 ]; then
  VERIFY_ARGS+=(--full-network)
fi

run_step() {
  local name="$1"
  shift
  echo "[CERT] $name" | tee -a "$LOG_FILE"
  "$@" 2>&1 | tee -a "$LOG_FILE"
  return "${PIPESTATUS[0]}"
}

run_step_allow() {
  local name="$1"
  shift
  local allowed=()
  while [ $# -gt 0 ]; do
    if [ "$1" = "--" ]; then
      shift
      break
    fi
    allowed+=("$1")
    shift
  done

  echo "[CERT] $name" | tee -a "$LOG_FILE"
  set +e
  "$@" 2>&1 | tee -a "$LOG_FILE"
  local rc="${PIPESTATUS[0]}"
  set -e
  local candidate
  for candidate in "${allowed[@]}"; do
    if [ "$rc" = "$candidate" ]; then
      return 0
    fi
  done
  return "$rc"
}

echo "[INFO] Fresh-install certification zip: $ZIP_PATH"
echo "[INFO] Fresh-install workdir: $WORK_DIR"

unzip -q "$ZIP_PATH" -d "$WORK_DIR"

if [ ! -d "$PACKAGE_ROOT" ]; then
  echo "[ERR] El zip no contiene _DJProducerTools en la raíz esperada." >&2
  exit 1
fi

run_step "bootstrap_djpt_venv" \
  bash "$PACKAGE_ROOT/scripts/bootstrap_djpt_venv.sh" \
  --root "$PACKAGE_ROOT" \
  --python "$BASE_PYTHON" \
  --"$INSTALL_MODE" \
  --with-dev

PY_BIN="$PACKAGE_ROOT/djpt_venv/bin/python3"

if [ ! -x "$PY_BIN" ]; then
  echo "[ERR] Python del djpt_venv no disponible tras bootstrap: $PY_BIN" >&2
  exit 1
fi

export BASE_PATH="$PACKAGE_ROOT"
export DJPT_EXPLICIT_BASE_PATH="$PACKAGE_ROOT"
export DJPT_PYTHON_BIN="$PY_BIN"
export PYTHON_BIN="$PY_BIN"
export VENV_DIR="$PACKAGE_ROOT/djpt_venv"

run_step_allow "ai_health" 0 1 -- bash -lc "'$PY_BIN' '$PACKAGE_ROOT/scripts/ai_health.py' > '$HEALTH_JSON'"
run_step "run_smoke" bash "$PACKAGE_ROOT/tests/run_smoke.sh"
run_step "startup_home_guard" bash "$PACKAGE_ROOT/tests/test_startup_home_and_double_click.sh"
run_step "menu_contract" bash -lc "'$PY_BIN' '$PACKAGE_ROOT/scripts/menu_contract_tools.py' validate-json > '$CONTRACT_JSON'"
run_step "verify_and_test" bash "$PACKAGE_ROOT/tests/VERIFY_AND_TEST.sh" "${VERIFY_ARGS[@]}"

if [ "$RUN_PYTEST" -eq 1 ]; then
  run_step "pytest_full" bash -lc "cd '$PACKAGE_ROOT' && '$PY_BIN' -m pytest -q tests"
fi

{
  printf "# DJProducerTools Fresh Install Certification\n\n"
  printf "## Scope\n"
  printf -- '- Zip certified: `%s`\n' "$ZIP_PATH"
  printf -- '- Workdir: `%s`\n' "$WORK_DIR"
  printf -- '- Install mode: `%s`\n' "$INSTALL_MODE"
  printf -- '- Full network: `%s`\n' "$FULL_NETWORK"
  printf -- '- Full pytest: `%s`\n\n' "$RUN_PYTEST"
  printf "## Commands Executed\n"
  printf -- '- bootstrap_djpt_venv\n'
  printf -- '- ai_health\n'
  printf -- '- tests/run_smoke.sh\n'
  printf -- '- tests/test_startup_home_and_double_click.sh\n'
  printf -- '- scripts/menu_contract_tools.py validate-json\n'
  printf -- '- tests/VERIFY_AND_TEST.sh --full-inventory%s\n' "$( [ "$FULL_NETWORK" -eq 1 ] && printf ' --full-network' )"
  if [ "$RUN_PYTEST" -eq 1 ]; then
    printf -- '- python3 -m pytest -q tests\n'
  fi
  printf "\n## Result\n"
  printf -- '- PASS\n'
  printf "\n## Artifacts\n"
  printf -- '- Log: `%s`\n' "$LOG_FILE"
  printf -- '- AI health JSON: `%s`\n' "$HEALTH_JSON"
  printf -- '- Menu contract JSON: `%s`\n' "$CONTRACT_JSON"
} >"$REPORT_PATH"

echo "[OK] Fresh-install certification complete"
echo "REPORT_PATH=$REPORT_PATH"
echo "WORK_DIR=$WORK_DIR"
