#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_PATH="$REPO_ROOT"
BOOTSTRAP_PYTHON="${DJPT_BOOTSTRAP_PYTHON:-python3}"
INSTALL_MODE="${DJPT_BOOTSTRAP_MODE:-core}"
INCLUDE_DEV="${DJPT_BOOTSTRAP_DEV:-1}"

usage() {
  cat <<'EOF'
Uso: bootstrap_djpt_venv.sh [--root PATH] [--python BIN] [--core|--full] [--with-dev|--without-dev]

Opciones:
  --root PATH      Ruta raíz del proyecto DJProducerTools.
  --python BIN     Python base para crear el venv. Por defecto: python3
  --core           Instala solo dependencias core reproducibles.
  --full           Instala requirements.txt completo.
  --with-dev       Incluye requirements-dev.txt.
  --without-dev    Omite requirements-dev.txt.
  --help           Muestra esta ayuda.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_PATH="$2"
      shift 2
      ;;
    --python)
      BOOTSTRAP_PYTHON="$2"
      shift 2
      ;;
    --core)
      INSTALL_MODE="core"
      shift
      ;;
    --full)
      INSTALL_MODE="full"
      shift
      ;;
    --with-dev)
      INCLUDE_DEV="1"
      shift
      ;;
    --without-dev)
      INCLUDE_DEV="0"
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

ROOT_PATH="$(cd "$ROOT_PATH" && pwd)"
VENV_DIR="$ROOT_PATH/djpt_venv"

if ! command -v "$BOOTSTRAP_PYTHON" >/dev/null 2>&1; then
  echo "[ERR] Python base no encontrado: $BOOTSTRAP_PYTHON" >&2
  exit 1
fi

REQ_FILE="$ROOT_PATH/requirements-core.txt"
if [ "$INSTALL_MODE" = "full" ]; then
  REQ_FILE="$ROOT_PATH/requirements.txt"
fi

if [ ! -f "$REQ_FILE" ]; then
  echo "[ERR] Requirements no encontrado: $REQ_FILE" >&2
  exit 1
fi

echo "[INFO] Bootstrap root: $ROOT_PATH"
echo "[INFO] Venv objetivo: $VENV_DIR"
echo "[INFO] Modo de instalación: $INSTALL_MODE"

if [ ! -x "$VENV_DIR/bin/python3" ]; then
  echo "[INFO] Creando djpt_venv"
  "$BOOTSTRAP_PYTHON" -m venv "$VENV_DIR"
fi

PY_BIN="$VENV_DIR/bin/python3"

echo "[INFO] Actualizando pip/setuptools/wheel"
"$PY_BIN" -m pip install --upgrade pip setuptools wheel

echo "[INFO] Instalando dependencias desde $(basename "$REQ_FILE")"
"$PY_BIN" -m pip install -r "$REQ_FILE"

if [ "$INCLUDE_DEV" = "1" ]; then
  if [ -f "$ROOT_PATH/requirements-dev.txt" ]; then
    echo "[INFO] Instalando dependencias de desarrollo"
    "$PY_BIN" -m pip install -r "$ROOT_PATH/requirements-dev.txt"
  else
    echo "[WARN] requirements-dev.txt no encontrado; se omite"
  fi
fi

echo "[OK] djpt_venv listo: $PY_BIN"
