#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INIT_BRANCH="main"
ORIGIN_URL=""
APPLY=0

usage() {
  cat <<'EOF'
Uso: reanchor_git_in_place.sh [--branch NAME] [--origin URL] [--apply]

Reancla este árbol cuando .git (worktree pointer) está roto y no existe gitdir fuente.
Hace backup del puntero roto y crea un repo Git local nuevo (git init).

Opciones:
  --branch NAME   Rama inicial para git init (default: main)
  --origin URL    Configura remote origin después de init
  --apply         Ejecuta cambios reales
  --help          Muestra esta ayuda
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --branch)
      INIT_BRANCH="$2"
      shift 2
      ;;
    --origin)
      ORIGIN_URL="$2"
      shift 2
      ;;
    --apply)
      APPLY=1
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

cd "$REPO_ROOT"

if [ ! -e ".git" ]; then
  echo "[ERR] No existe .git en $REPO_ROOT" >&2
  exit 1
fi

if [ "$APPLY" -ne 1 ]; then
  echo "[INFO] Dry-run: sin cambios"
  echo "[INFO] REPO_ROOT=$REPO_ROOT"
  echo "[INFO] INIT_BRANCH=$INIT_BRANCH"
  if [ -f ".git" ]; then
    echo "[INFO] .git actual es archivo (worktree pointer)"
    echo "[INFO] contenido: $(head -n 1 .git || true)"
  else
    echo "[INFO] .git actual es directorio"
  fi
  if [ -n "$ORIGIN_URL" ]; then
    echo "[INFO] origin a configurar: $ORIGIN_URL"
  fi
  echo "[INFO] Para aplicar: bash scripts/reanchor_git_in_place.sh --apply [--branch ...] [--origin ...]"
  exit 0
fi

stamp="$(date +%Y%m%d_%H%M%S)"

if [ -f ".git" ]; then
  backup=".git.worktree_broken_${stamp}"
  cp .git "$backup"
  rm .git
  echo "[OK] backup pointer roto -> $backup"
elif [ -d ".git" ]; then
  echo "[WARN] .git ya es directorio; no se reemplaza"
fi

if [ ! -d ".git" ]; then
  git init -b "$INIT_BRANCH"
else
  current_branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
  if [ -z "$current_branch" ] && [ -n "$INIT_BRANCH" ]; then
    git checkout -b "$INIT_BRANCH" >/dev/null 2>&1 || true
  fi
fi

if [ -n "$ORIGIN_URL" ]; then
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$ORIGIN_URL"
  else
    git remote add origin "$ORIGIN_URL"
  fi
fi

echo "[OK] Reanclaje local completado"
git status --short >/dev/null 2>&1 || true
echo "[INFO] Rama actual: $(git branch --show-current 2>/dev/null || echo '<none>')"
if git remote get-url origin >/dev/null 2>&1; then
  echo "[INFO] origin: $(git remote get-url origin)"
else
  echo "[INFO] origin: <no configurado>"
fi
