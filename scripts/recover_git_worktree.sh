#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_TREE="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_REPO=""
TARGET_DIR=""
BRANCH=""
STAMP="$(date +%Y%m%d_%H%M%S)"
MODE="clone"

usage() {
  cat <<USAGE
Uso: recover_git_worktree.sh --source /ruta/al/repo.git-o-clon-vivo --target /ruta/arbol_recuperado [--branch rama] [--mode clone|worktree]

Recupera trazabilidad Git creando un árbol NUEVO y válido a partir de un repo sano,
y después superpone el contenido del árbol actual roto encima.

No modifica el árbol actual: $CURRENT_TREE
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --source)
      SOURCE_REPO="$2"
      shift 2
      ;;
    --target)
      TARGET_DIR="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
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

if [ -z "$SOURCE_REPO" ] || [ -z "$TARGET_DIR" ]; then
  usage >&2
  exit 2
fi

if ! git -C "$SOURCE_REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[ERR] SOURCE_REPO no es un repo Git válido: $SOURCE_REPO" >&2
  exit 1
fi

if [ -e "$TARGET_DIR" ] && [ -n "$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
  echo "[ERR] TARGET_DIR debe no existir o estar vacío: $TARGET_DIR" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

if [ "$MODE" = "worktree" ]; then
  branch_name="$BRANCH"
  if [ -z "$branch_name" ]; then
    branch_name="recovered-$STAMP"
  fi
  rm -rf "$TARGET_DIR"
  echo "[INFO] Creando worktree desde $SOURCE_REPO -> $TARGET_DIR ($branch_name)"
  git -C "$SOURCE_REPO" worktree add -b "$branch_name" "$TARGET_DIR"
else
  echo "[INFO] Clonando repo sano desde $SOURCE_REPO -> $TARGET_DIR"
  git clone "$SOURCE_REPO" "$TARGET_DIR" >/dev/null
  if [ -n "$BRANCH" ]; then
    git -C "$TARGET_DIR" checkout "$BRANCH" >/dev/null
  fi
fi

RSYNC_EXCLUDES=(
  --exclude '.git'
  --exclude 'dist'
  --exclude 'djpt_venv'
  --exclude 'venv'
  --exclude '__pycache__'
  --exclude '.pytest_cache'
)

echo "[INFO] Superponiendo árbol actual sobre checkout limpio"
rsync -a "${RSYNC_EXCLUDES[@]}" "$CURRENT_TREE/" "$TARGET_DIR/"

cat <<REPORT
[OK] Árbol recuperado creado
SOURCE_REPO=$SOURCE_REPO
TARGET_DIR=$TARGET_DIR
MODE=$MODE
BRANCH=${BRANCH:-<source-default-or-generated>}

Siguientes pasos sugeridos:
  1. cd "$TARGET_DIR"
  2. git status
  3. revisar y commit de los cambios superpuestos
REPORT
