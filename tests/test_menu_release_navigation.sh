#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"
FAILURES=0

timeout_wrap() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 60 "$@"
    return
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout 60 "$@"
    return
  fi
  "$@"
}

run_direct_case() {
  local name="$1"
  local action="$2"
  local input="$3"
  local expected="$4"
  local out
  out="$(mktemp)"

  if ! printf "%b" "$input" | BASE_PATH="$ROOT_DIR" NO_INTERACTIVE=1 DJPT_NO_INTERACTIVE=1 DJPT_SKIP_MLX=1 DJPT_SKIP_TF=1 timeout_wrap bash "$SCRIPT" --no-interactive --run "$action" >"$out" 2>&1; then
    echo "[FAIL] $name: rc!=0"
    sed -n '1,200p' "$out"
    rm -f "$out"
    FAILURES=$((FAILURES + 1))
    return
  fi

  if ! rg -q "$expected" "$out"; then
    echo "[FAIL] $name: expected banner not found"
    sed -n '1,200p' "$out"
    rm -f "$out"
    FAILURES=$((FAILURES + 1))
    return
  fi

  if rg -n "command not found|Traceback|No module named|SyntaxError|no implementado|stub|Falló instalación de dependencias para TF Lab|Falló bootstrap de dependencias para TF Lab" "$out" >/dev/null; then
    echo "[FAIL] $name: runtime issue detected"
    sed -n '1,220p' "$out"
    rm -f "$out"
    FAILURES=$((FAILURES + 1))
    return
  fi

  echo "[PASS] $name"
  rm -f "$out"
}

run_alias_case() {
  local name="$1"
  local input="$2"
  local expected="$3"
  local out
  out="$(mktemp)"

  if ! printf "%b" "$input" | BASE_PATH="$ROOT_DIR" NO_INTERACTIVE=1 DJPT_NO_INTERACTIVE=1 DJPT_SKIP_MLX=1 DJPT_SKIP_TF=1 timeout_wrap bash "$SCRIPT" --no-interactive >"$out" 2>&1; then
    echo "[FAIL] $name: rc!=0"
    sed -n '1,220p' "$out"
    rm -f "$out"
    FAILURES=$((FAILURES + 1))
    return
  fi

  if ! rg -q "$expected" "$out"; then
    echo "[FAIL] $name: expected alias banner not found"
    sed -n '1,220p' "$out"
    rm -f "$out"
    FAILURES=$((FAILURES + 1))
    return
  fi

  if rg -n "command not found|Traceback|No module named|SyntaxError|no implementado|stub|INVALID_OPTION" "$out" >/dev/null; then
    echo "[FAIL] $name: alias runtime issue detected"
    sed -n '1,220p' "$out"
    rm -f "$out"
    FAILURES=$((FAILURES + 1))
    return
  fi

  echo "[PASS] $name"
  rm -f "$out"
}

run_direct_case "submenu 36 web clean" "36" $'B\n' "Limpiar WEB"
run_direct_case "submenu 54 profiles" "54" $'B\n' "Gestor de Perfiles"
run_direct_case "submenu 55 ableton" "55" $'B\n' "Ableton Tools"
run_direct_case "submenu 56 importers" "56" $'B\n' "Importers Cues/Playlists"
run_direct_case "submenu 57 excludes" "57" $'B\n' "Gestor de Exclusiones"
run_direct_case "submenu 65 tensorflow lab" "65" "" "TensorFlow Lab"
run_direct_case "submenu 71 backends manager" "71" $'0\n' "GESTOR DE BACKENDS IA"
run_direct_case "submenu 74 config hub" "74" $'0\n' "HUB DE CONFIGURACIÓN DE BACKENDS IA"
run_direct_case "submenu 75 train models" "75" $'0\n' "ENTRENAMIENTO DE MODELOS IA"
run_direct_case "submenu 77 ui config" "77" $'0\n' "CONFIGURACIÓN DE INTERFAZ ENRIQUECIDA"
run_direct_case "submenu 80 ai advanced" "80" $'0\n' "AI ADVANCED MENU"
run_direct_case "submenu 81 ai lab" "81" $'0\n' "AI Laboratory Options"
run_direct_case "submenu 82 ai optimization" "82" $'0\n' "AI Optimization Options"
run_direct_case "submenu 83 ai global config" "83" $'0\n' "Global AI Configuration"
run_direct_case "submenu 84 ai learning" "84" $'0\n' "AI Learning System Options"
run_direct_case "submenu 85 ai educator" "85" $'0\n' "AI Educator Options"
run_direct_case "submenu 86 ai docs" "86" $'0\n' "AI Document Analysis Options"
run_direct_case "submenu 87 install local models" "87" $'0\n' "Local Model Installation Options"
run_direct_case "submenu 88 local models alias" "88" $'0\n' "Local Model Installation Options"

run_alias_case "alias C chat" $'C\nB\n0\n' "Chat IA Integrado"
run_alias_case "alias R repair" $'R\nB\n0\n' "Reparación y Regeneración del Sistema"
run_alias_case "alias L libraries" $'L\nB\n0\n' "L\\) Librerías DJ & Cues"
run_alias_case "alias D dupes" $'D\nB\n0\n' "D\\) Duplicados generales"
run_alias_case "alias V visuals" $'V\nB\n0\n' "V\\) Visuales / DAW / OSC"
run_alias_case "alias H help" $'H\nB\n0\n' "H\\) Help & INFO"

if [ "$FAILURES" -gt 0 ]; then
  echo "[RESULT] $FAILURES failures"
  exit 1
fi

echo "[RESULT] OK"
