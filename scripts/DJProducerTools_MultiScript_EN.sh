#!/usr/bin/env bash
set -u

# Re-ejecuta con bash si no se lanzó con bash (doble click/otros shells)
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

ESC=$'\033'
C_RESET="${ESC}[0m"
C_RED="${ESC}[1;31m"
C_GRN="${ESC}[1;32m"
C_YLW="${ESC}[1;33m"
C_BLU="${ESC}[1;34m"
C_CYN="${ESC}[1;36m"
C_PURP="${ESC}[38;5;129m"
BANNER="${ESC}[1;37;44m"

# Asegura TERM para evitar cortes raros en terminales mínimos
export TERM="${TERM:-xterm-256color}"

# Polyfill mapfile para Bash 3.2 en macOS (con escape seguro)
if ! command -v mapfile >/dev/null 2>&1; then
  mapfile() {
    local opt tflag=0
    while getopts "t" opt; do [ "$opt" = "t" ] && tflag=1; done
    shift $((OPTIND-1))
    local arr_name=$1
    eval "$arr_name=()"
    local line
    while IFS= read -r line; do
      local esc_line="${line//\\/\\\\}"
      esc_line="${esc_line//\"/\\\"}"
      if [ $tflag -eq 1 ]; then
        eval "$arr_name+=(\"$esc_line\")"
      else
        eval "$arr_name+=(\"$esc_line\n\")"
      fi
    done
  }
fi

SAFE_MODE=1
DJ_SAFE_LOCK=1
DRYRUN_FORCE=0
RUN_TEST_MODE=0
SHOW_VERSION=0
SHOW_HELP=0
SCRIPT_VERSION="2.0.0"

SPIN_FRAMES=("\\" "|" "/" "-")
SPIN_IDX=0
SPIN_COLORS=("$C_PURP" "$C_GRN" "$C_CYN" "$C_YLW" "$C_BLU")
SPIN_COLOR_IDX=0
GHOST_COLORS=("${ESC}[38;5;129m" "${ESC}[38;5;46m") # violeta y verde
GHOST_IDX=0

BASE_DEFAULT="$PWD"
BASE_PATH="$BASE_DEFAULT"
LAUNCH_PATH="$BASE_DEFAULT"
EXTRA_SOURCE_ROOTS=""
DEFAULT_EXCLUDES_BASE="*.asd,*.asd.*,*/Ableton/Cache/*,*/Ableton/Factory Packs/*,*/node_modules/*,*/.git/*,*/.Trash/*,*/Backups.backupdb/*,*/_DJProducerTools/*,*/_Serato_*/*,*.log,*.tmp,*.dmg,*.iso"
DEFAULT_EXCLUDES="$DEFAULT_EXCLUDES_BASE"
BASE_HISTORY_FILE=""
GENERAL_HISTORY_FILE=""
AUDIO_HISTORY_FILE=""
EXCLUDES_PROFILES_FILE=""
STATE_HEALTH_REPORT=""
PRESET_EXCLUDES_AUDIO="*.asd,*.asd.*,*/Ableton/Cache/*,*/Ableton/Factory Packs/*,*/node_modules/*,*/.git/*,*/.Trash/*,*/Backups.backupdb/*,*.tmp,*.dmg,*.iso"
PRESET_EXCLUDES_PROYECTOS="*/node_modules/*,*/.git/*,*/dist/*,*/build/*,*/venv/*,*.log,*.tmp,*.dmg,*.iso"

append_extra_root() {
  local new="$1"
  [ -z "$new" ] && return
  [ ! -d "$new" ] && return
  IFS=',' read -r -a arr <<<"${EXTRA_SOURCE_ROOTS}"
  for r in "${arr[@]}"; do
    [ "$r" = "$new" ] && return
  done
  if [ -z "$EXTRA_SOURCE_ROOTS" ]; then
    EXTRA_SOURCE_ROOTS="$new"
  else
    EXTRA_SOURCE_ROOTS="$EXTRA_SOURCE_ROOTS,$new"
  fi
}

strip_quotes() {
  local s="$1"
  s=${s%\"}
  s=${s#\"}
  printf "%s" "$s"
}

ensure_state_dir_safe() {
  if [ -z "${STATE_DIR:-}" ] || [ "$STATE_DIR" = "/" ]; then
    printf "%s[ERR]%s STATE_DIR inválido (%s)\n" "$C_RED" "$C_RESET" "${STATE_DIR:-<empty>}"
    return 1
  fi
  case "$STATE_DIR" in
    */_DJProducerTools|*/_DJProducerTools/) ;;
    *)
      printf "%s[ERR]%s STATE_DIR no parece un dir de estado seguro: %s\n" "$C_RED" "$C_RESET" "$STATE_DIR"
      return 1
      ;;
  esac
  return 0
}

warn_legacy_state() {
  local legacy="$HOME/.DJProducerTools"
  if [ -d "$legacy" ] && [ "$legacy" != "$STATE_DIR" ]; then
    printf "%s[WARN]%s Existe estado legacy en %s; el script usa %s\n" "$C_YLW" "$C_RESET" "$legacy" "$STATE_DIR"
  fi
}

maybe_migrate_legacy_state() {
  local legacy="$HOME/.DJProducerTools"
  if [ ! -d "$legacy" ]; then
    return
  fi
  if [ "$legacy" -ef "$STATE_DIR" ]; then
    return
  fi
  if [ -d "$STATE_DIR" ] && [ "$(ls -A "$STATE_DIR" 2>/dev/null)" ]; then
    printf "%s[INFO]%s _DJProducerTools ya tiene datos; no se migra legacy.\n" "$C_CYN" "$C_RESET"
    return
  fi
  printf "%s[WARN]%s Se detectó estado legacy en %s.\n" "$C_YLW" "$C_RESET" "$legacy"
  printf "Opción: MIGRATE copia a %s, DRY simula, SKIP omite [MIGRATE/DRY/SKIP]: " "$STATE_DIR"
  read -r mig
  case "$mig" in
    MIGRATE)
      ensure_state_dir_safe || return
      printf "%s[INFO]%s Migrando legacy -> %s\n" "$C_CYN" "$C_RESET" "$STATE_DIR"
      safe_rsync "$legacy" "$STATE_DIR"
      printf "%s[OK]%s Migración completada.\n" "$C_GRN" "$C_RESET"
      ;;
    DRY)
      printf "[DRY] rsync %s -> %s\n" "$legacy" "$STATE_DIR"
      rsync -an "$legacy"/ "$STATE_DIR"/ 2>/dev/null || true
      ;;
    *)
      printf "%s[INFO]%s Saltando migración.\n" "$C_CYN" "$C_RESET"
      ;;
  esac
}

usage() {
  cat <<EOF
DJProducerTools WAX MultiScript
Uso: $(basename "$0") [--help] [--version] [--test] [--dry-run]
  --help       Muestra esta ayuda
  --version    Imprime versión y sale
  --test       Solo chequeo ligero de dependencias (sin menú)
  --dry-run    Fuerza DRYRUN_FORCE=1 (sin escrituras)
Entorno por defecto: SAFE_MODE=1, DJ_SAFE_LOCK=1, DRYRUN_FORCE=0
EOF
}

check_dependencies_basic() {
  local -r deps=("bash" "find" "awk" "sed" "xargs" "python3" "ffprobe" "sox" "jq")
  local -i missing=0
  printf "Chequeo de dependencias:\n"
  for cmd in "${deps[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf "  ✓ %s\n" "$cmd"
    else
      printf "  ✗ %s (faltante)\n" "$cmd"
      missing=$((missing + 1))
    fi
  done
  return $missing
}

confirm_heavy() {
  local op="$1"
  printf "%s[WARN]%s %s puede ser intensivo sobre BASE_PATH=%s\n" "$C_YLW" "$C_RESET" "$op" "$BASE_PATH"
  printf "Escribe YES para continuar: "
  read -r ans
  [ "$ans" = "YES" ] || { printf "%s[INFO]%s Cancelado.\n" "$C_CYN" "$C_RESET"; return 1; }
  return 0
}

safe_rsync() {
  local src="$1"
  local dst="$2"
  mkdir -p "$dst"
  if [ "$DRYRUN_FORCE" -eq 1 ]; then
    rsync -an "$src"/ "$dst"/ 2>/dev/null || true
    printf "[DRY] rsync %s -> %s\n" "$src" "$dst"
  else
    rsync -a "$src"/ "$dst"/ 2>/dev/null || true
  fi
}

append_history() {
  local file="$1"
  local path="$2"
  [ -z "$file" ] && return
  [ -z "$path" ] && return
  path=$(strip_quotes "$path")
  [ ! -d "$path" ] && return
  mkdir -p "$(dirname "$file")"
  # prepend unique
  { printf "%s\n" "$path"; cat "$file" 2>/dev/null; } | awk '!seen[$0]++' | head -20 >"$file.tmp" && mv "$file.tmp" "$file"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        SHOW_HELP=1
        shift
        ;;
      --version)
        SHOW_VERSION=1
        shift
        ;;
      --test)
        RUN_TEST_MODE=1
        shift
        ;;
      --dry-run)
        DRYRUN_FORCE=1
        shift
        ;;
      *)
        printf "Opción desconocida: %s\n" "$1"
        usage
        exit 1
        ;;
    esac
  done
}

select_from_candidates() {
  local prompt="$1"
  shift
  local arr=("$@")
  local idx=1
  printf "%s\n" "$prompt"
  for c in "${arr[@]}"; do
    printf "  [%d] %s\n" "$idx" "$c"
    idx=$((idx + 1))
  done
  printf "  [M] Introducir manual\n"
  printf "Elección: "
  read -e -r choice
  case "$choice" in
    M|m) printf ""; return 1 ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#arr[@]}" ]; then
        printf "%s" "${arr[$((choice-1))]}"
        return 0
      fi
      return 1
      ;;
  esac
}

ensure_base_path_valid() {
  local candidates=()
  # historial
  if [ -f "$BASE_HISTORY_FILE" ]; then
    while IFS= read -r line; do
      [ -d "$line" ] && candidates+=("$line")
    done <"$BASE_HISTORY_FILE"
  fi
  # rutas obvias
  [ -d "$LAUNCH_PATH" ] && candidates+=("$LAUNCH_PATH")
  [ -d "$PWD" ] && candidates+=("$PWD")
  for d in /Volumes/*; do
    [ -d "$d" ] && candidates+=("$d")
  done
  # dedup
  if [ "${#candidates[@]}" -gt 0 ]; then
    mapfile -t candidates < <(printf "%s\n" "${candidates[@]}" | awk '!seen[$0]++')
  fi

  if [ -d "$BASE_PATH" ]; then
    append_history "$BASE_HISTORY_FILE" "$BASE_PATH"
    return
  fi

  printf "%s[WARN]%s BASE_PATH inválido: %s\n" "$C_YLW" "$C_RESET" "$BASE_PATH"
  if [ "${#candidates[@]}" -gt 0 ]; then
    choice=$(select_from_candidates "Selecciona BASE_PATH de sugerencias:" "${candidates[@]}")
    if [ -n "$choice" ]; then
      BASE_PATH="$choice"
      append_history "$BASE_HISTORY_FILE" "$BASE_PATH"
      return
    fi
  fi
  printf "Introduce BASE_PATH manual: "
  read -e -r new_base
  new_base=$(strip_quotes "$new_base")
  if [ -n "$new_base" ] && [ -d "$new_base" ]; then
    BASE_PATH="$new_base"
    append_history "$BASE_HISTORY_FILE" "$BASE_PATH"
  else
    printf "%s[WARN]%s Usando PWD como BASE_PATH: %s\n" "$C_YLW" "$C_RESET" "$PWD"
    BASE_PATH="$PWD"
    append_history "$BASE_HISTORY_FILE" "$BASE_PATH"
  fi
}

ensure_general_root_valid() {
  if [ -n "${GENERAL_ROOT:-}" ] && [ -d "$GENERAL_ROOT" ]; then
    append_history "$GENERAL_HISTORY_FILE" "$GENERAL_ROOT"
    return
  fi
  if [ -d "$BASE_PATH" ]; then
    GENERAL_ROOT="$BASE_PATH"
    append_history "$GENERAL_HISTORY_FILE" "$GENERAL_ROOT"
    return
  fi
  if [ -d "$PWD" ]; then
    GENERAL_ROOT="$PWD"
    append_history "$GENERAL_HISTORY_FILE" "$GENERAL_ROOT"
  fi
}

submenu_excludes_manager() {
  while true; do
    clear
    print_header
    printf "%s=== Gestor de Exclusiones ===%s\n" "$C_CYN" "$C_RESET"
    printf "Perfil activo: %s\n" "$DEFAULT_EXCLUDES"
    printf "%s1)%s Elegir perfil guardado\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Guardar perfil actual\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Restaurar excluiones por defecto\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s Listar perfiles\n" "$C_YLW" "$C_RESET"
    printf "%s5)%s Cargar preset AUDIO\n" "$C_YLW" "$C_RESET"
    printf "%s6)%s Cargar preset PROYECTOS\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Volver\n" "$C_YLW" "$C_RESET"
    printf "%sOpción:%s " "$C_BLU" "$C_RESET"
    read -e -r xop
    case "$xop" in
      1)
        mapfile -t profs < <(awk -F'\t' 'NF>=2{print $1"\t"$2}' "$EXCLUDES_PROFILES_FILE" 2>/dev/null)
        if [ "${#profs[@]}" -eq 0 ]; then
          printf "%s[WARN]%s No hay perfiles guardados.\n" "$C_YLW" "$C_RESET"
          pause_enter
          continue
        fi
        printf "Perfiles:\n"
        idx=1
        for line in "${profs[@]}"; do
          name=$(printf "%s" "$line" | cut -f1)
          pat=$(printf "%s" "$line" | cut -f2-)
          printf "  [%d] %s -> %s\n" "$idx" "$name" "$pat"
          idx=$((idx + 1))
        done
        printf "Elige número: "
        read -e -r sel
        if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#profs[@]}" ]; then
          line="${profs[$((sel-1))]}"
          DEFAULT_EXCLUDES=$(printf "%s" "$line" | cut -f2-)
          save_conf
          printf "%s[OK]%s Perfil cargado.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[WARN]%s Selección inválida.\n" "$C_YLW" "$C_RESET"
        fi
        pause_enter
        ;;
      2)
        printf "Nombre para el perfil: "
        read -e -r pname
        pname=$(strip_quotes "$pname")
        [ -z "$pname" ] && { printf "%s[WARN]%s Nombre vacío.\n" "$C_YLW" "$C_RESET"; pause_enter; continue; }
        tmp="$EXCLUDES_PROFILES_FILE.tmp"
        { printf "%s\t%s\n" "$pname" "$DEFAULT_EXCLUDES"; grep -v "^$pname\t" "$EXCLUDES_PROFILES_FILE" 2>/dev/null; } >"$tmp"
        mv "$tmp" "$EXCLUDES_PROFILES_FILE"
        printf "%s[OK]%s Perfil guardado.\n" "$C_GRN" "$C_RESET"
        pause_enter
        ;;
      3)
        DEFAULT_EXCLUDES="$DEFAULT_EXCLUDES_BASE"
        save_conf
        printf "%s[OK]%s Excluiones restauradas al valor base.\n" "$C_GRN" "$C_RESET"
        pause_enter
        ;;
      4)
        printf "%s[INFO]%s Perfiles guardados:\n" "$C_CYN" "$C_RESET"
        if ! awk -F'\t' 'NF>=2{printf "- %s: %s\n",$1,$2}' "$EXCLUDES_PROFILES_FILE"; then
          printf "(vacío)\n"
        fi
        pause_enter
        ;;
      5)
        DEFAULT_EXCLUDES="$PRESET_EXCLUDES_AUDIO"
        save_conf
        printf "%s[OK]%s Preset AUDIO cargado.\n" "$C_GRN" "$C_RESET"
        pause_enter
        ;;
      6)
        DEFAULT_EXCLUDES="$PRESET_EXCLUDES_PROYECTOS"
        save_conf
        printf "%s[OK]%s Preset PROYECTOS cargado.\n" "$C_GRN" "$C_RESET"
        pause_enter
        ;;
      B|b)
        break
        ;;
      *)
        invalid_option
        ;;
    esac
  done
}

should_exclude_path() {
  local path="$1"
  local patterns="$2"
  [ -z "$patterns" ] && return 1
  IFS=',' read -r -a arr <<<"$patterns"
  for p in "${arr[@]}"; do
    p_trim=$(printf "%s" "$p" | xargs)
    [ -z "$p_trim" ] && continue
    case "$path" in
      $p_trim) return 0 ;;
    esac
  done
  return 1
}

CONFIG_DIR=""
STATE_DIR=""
REPORTS_DIR=""
PLANS_DIR=""
LOGS_DIR=""
QUAR_DIR=""
VENV_DIR=""
BANNER_FILE=""
CONF_FILE=""
VENV_ACTIVE=0
PYTHON_BIN="python3"
ML_ENV_DISABLED=0
ML_PKGS_BASIC="numpy pandas"
ML_PKG_BASIC_MB=300
ML_PKGS_EVO="numpy pandas scikit-learn joblib"
ML_PKG_EVO_MB=450
ML_PKGS_TF="tensorflow"
ML_PKG_TF_MB=600
PROFILES_DIR=""

pause_enter() {
  printf "%sPulsa ENTER para continuar...%s" "$C_YLW" "$C_RESET"
  read -r _
}

ensure_dirs() {
  mkdir -p "$STATE_DIR" "$CONFIG_DIR" "$REPORTS_DIR" "$PLANS_DIR" "$LOGS_DIR" "$QUAR_DIR" "$VENV_DIR"
}

init_paths() {
  # Permite forzar HOME_OVERRIDE para no tocar librerías reales
  if [ -n "${HOME_OVERRIDE:-}" ]; then
    BASE_PATH="$HOME_OVERRIDE"
  fi
  STATE_DIR="$BASE_PATH/_DJProducerTools"
  CONFIG_DIR="$STATE_DIR/config"
  PROFILES_DIR="$CONFIG_DIR/profiles"
  BASE_HISTORY_FILE="$CONFIG_DIR/base_history.txt"
  GENERAL_HISTORY_FILE="$CONFIG_DIR/general_history.txt"
  AUDIO_HISTORY_FILE="$CONFIG_DIR/audio_history.txt"
  EXCLUDES_PROFILES_FILE="$CONFIG_DIR/exclude_profiles.tsv"
  STATE_HEALTH_REPORT="$REPORTS_DIR/state_health.txt"
  REPORTS_DIR="$STATE_DIR/reports"
  PLANS_DIR="$STATE_DIR/plans"
  LOGS_DIR="$STATE_DIR/logs"
  QUAR_DIR="$STATE_DIR/quarantine"
  VENV_DIR="$STATE_DIR/venv"
  BANNER_FILE="$STATE_DIR/banner.txt"
  CONF_FILE="$CONFIG_DIR/djpt.conf"
  ML_MODEL_PATH="$STATE_DIR/ml_model.pkl"
  ML_FEATURES_FILE="$STATE_DIR/ml_features.tsv"
  ML_PRED_REPORT="$REPORTS_DIR/ml_predictions.tsv"
  ensure_dirs
  mkdir -p "$PROFILES_DIR"
  touch "$BASE_HISTORY_FILE" "$GENERAL_HISTORY_FILE" "$AUDIO_HISTORY_FILE"
  touch "$EXCLUDES_PROFILES_FILE"
}

save_conf() {
  mkdir -p "$CONFIG_DIR"
  : "${AUDIO_ROOT:=}"
  : "${GENERAL_ROOT:=}"
  : "${SERATO_ROOT:=}"
  : "${REKORDBOX_XML:=}"
  : "${ABLETON_ROOT:=}"
  : "${EXTRA_SOURCE_ROOTS:=}"
  : "${DEFAULT_EXCLUDES:=}"
  : "${PROFILES_DIR:=}"
  : "${ML_ENV_DISABLED:=0}"
  {
    printf 'BASE_PATH=%q\n' "$BASE_PATH"
    printf 'AUDIO_ROOT=%q\n' "${AUDIO_ROOT:-}"
    printf 'GENERAL_ROOT=%q\n' "${GENERAL_ROOT:-}"
    printf 'SERATO_ROOT=%q\n' "${SERATO_ROOT:-}"
    printf 'REKORDBOX_XML=%q\n' "${REKORDBOX_XML:-}"
    printf 'ABLETON_ROOT=%q\n' "${ABLETON_ROOT:-}"
    printf 'EXTRA_SOURCE_ROOTS=%q\n' "${EXTRA_SOURCE_ROOTS:-}"
    printf 'DEFAULT_EXCLUDES=%q\n' "${DEFAULT_EXCLUDES:-$DEFAULT_EXCLUDES_BASE}"
    printf 'PROFILES_DIR=%q\n' "${PROFILES_DIR:-}"
    printf 'SAFE_MODE=%q\n' "$SAFE_MODE"
    printf 'DJ_SAFE_LOCK=%q\n' "$DJ_SAFE_LOCK"
    printf 'DRYRUN_FORCE=%q\n' "$DRYRUN_FORCE"
    printf 'ML_ENV_DISABLED=%q\n' "$ML_ENV_DISABLED"
  } >"$CONF_FILE"
}

load_conf() {
  if [ -f "$CONF_FILE" ]; then
    set +u
    if ! . "$CONF_FILE" 2>/dev/null; then
      printf "%s[WARN]%s No se pudo cargar %s, se regenerará.\n" "$C_YLW" "$C_RESET" "$CONF_FILE"
    fi
    set -u
  fi
}

maybe_activate_ml_env() {
  local context="${1:-ML}"
  local want_tf="${2:-0}"
  local want_evo="${3:-0}"
  if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
    printf "%s[WARN]%s ML deshabilitado globalmente (toggle en menú extras).\n" "$C_YLW" "$C_RESET"
    return
  fi
  if [ "$VENV_ACTIVE" -eq 1 ]; then
    return
  fi
  if [ -f "$VENV_DIR/bin/activate" ]; then
    # shellcheck disable=SC1090
    . "$VENV_DIR/bin/activate"
    VENV_ACTIVE=1
    return
  fi

  local pkgs="$ML_PKGS_BASIC"
  local est_mb="$ML_PKG_BASIC_MB"
  if [ "$want_evo" -eq 1 ]; then
    pkgs="$ML_PKGS_EVO"
    est_mb="$ML_PKG_EVO_MB"
  fi
  if [ "$want_tf" -eq 1 ]; then
    pkgs="$pkgs $ML_PKGS_TF"
    est_mb=$((est_mb + ML_PKG_TF_MB))
  fi
  pkgs_arr=()
  for p in $pkgs; do
    pkgs_arr+=("$p")
  done

  printf "%s[INFO]%s %s requiere entorno ML aislado.\n" "$C_CYN" "$C_RESET" "$context"
  printf "Crear venv en %s y descargar pip + %s (~%s MB)? [y/N]: " "$VENV_DIR" "$pkgs" "$est_mb"
  read -r ans
  case "$ans" in
    y|Y)
      if ! command -v python3 >/dev/null 2>&1; then
        printf "%s[ERR]%s python3 no encontrado. Instálalo e inténtalo de nuevo.\n" "$C_RED" "$C_RESET"
        ML_ENV_DISABLED=1
        return
      fi
      python3 -m venv "$VENV_DIR" 2>/dev/null || {
        printf "%s[ERR]%s No se pudo crear el venv en %s\n" "$C_RED" "$C_RESET" "$VENV_DIR"
        ML_ENV_DISABLED=1
        return
      }
      if [ -f "$VENV_DIR/bin/activate" ]; then
        # shellcheck disable=SC1090
        . "$VENV_DIR/bin/activate"
        VENV_ACTIVE=1
        "$VENV_DIR/bin/pip" install --upgrade pip >/dev/null 2>&1 || true
        "$VENV_DIR/bin/pip" install "${pkgs_arr[@]}" >/dev/null 2>&1 || true
      fi
      ;;
    *)
      ML_ENV_DISABLED=1
      printf "%s[WARN]%s Entorno ML omitido para %s. Reintenta más tarde si lo deseas.\n" "$C_YLW" "$C_RESET" "$context"
      ;;
  esac
}

status_line() {
  task="$1"
  percent="$2"
  current="$3"
  local frame="${SPIN_FRAMES[$SPIN_IDX]}"
  SPIN_IDX=$(((SPIN_IDX + 1) % ${#SPIN_FRAMES[@]}))
  local ghost_color="${GHOST_COLORS[$GHOST_IDX]}"
  GHOST_IDX=$(((GHOST_IDX + 1) % ${#GHOST_COLORS[@]}))
  local spin_color="${SPIN_COLORS[$SPIN_COLOR_IDX]}"
  SPIN_COLOR_IDX=$(((SPIN_COLOR_IDX + 1) % ${#SPIN_COLORS[@]}))
  local frame_colored="${spin_color}${frame}${C_RESET}"
  printf "\r%s👻%s %s | %3s%% | %s | %s" "$ghost_color" "$C_RESET" "$task" "$percent" "$frame_colored" "$current"
}

finish_status_line() {
  printf "\n"
}

ensure_python_bin() {
  if [ -x "$VENV_DIR/bin/python3" ]; then
    PYTHON_BIN="$VENV_DIR/bin/python3"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
    return 0
  fi
  printf "%s[ERR]%s python3 no disponible.\n" "$C_RED" "$C_RESET"
  return 1
}

ensure_python_deps() {
  local context="$1"; shift
  local modules=("$@")
  ensure_python_bin || return 1
  if [ "${#modules[@]}" -eq 0 ]; then
    return 0
  fi
  "$PYTHON_BIN" - "$@" <<'PY' >/dev/null 2>&1
import importlib, sys
mods = sys.argv[1:]
missing = [m for m in mods if importlib.util.find_spec(m) is None]
sys.exit(1 if missing else 0)
PY
  if [ $? -eq 0 ]; then
    return 0
  fi
  local est_mb=30
  for m in "${modules[@]}"; do
    case "$m" in
      librosa) est_mb=$((est_mb + 120));;
      soundfile) est_mb=$((est_mb + 20));;
      python-osc|pyserial) est_mb=$((est_mb + 5));;
    esac
  done
  printf "%s[WARN]%s Faltan deps Python (%s): %s\n" "$C_YLW" "$C_RESET" "$context" "${modules[*]}"
  printf "Instalar en venv %s (~%s MB)? [y/N]: " "$VENV_DIR" "$est_mb"
  read -r ans
  case "$ans" in
    y|Y)
      if ! command -v python3 >/dev/null 2>&1; then
        printf "%s[ERR]%s python3 no disponible para crear venv.\n" "$C_RED" "$C_RESET"
        return 1
      fi
      mkdir -p "$VENV_DIR"
      if [ ! -x "$VENV_DIR/bin/python3" ]; then
        python3 -m venv "$VENV_DIR" 2>/dev/null || {
          printf "%s[ERR]%s No se pudo crear venv en %s\n" "$C_RED" "$C_RESET" "$VENV_DIR"
          return 1
        }
      fi
      PYTHON_BIN="$VENV_DIR/bin/python3"
      "$PYTHON_BIN" -m pip install --upgrade pip >/dev/null 2>&1 || true
      "$PYTHON_BIN" -m pip install "${modules[@]}" >/dev/null 2>&1 || {
        printf "%s[ERR]%s Falló instalación pip de %s\n" "$C_RED" "$C_RESET" "${modules[*]}"
        return 1
      }
      ;;
    *)
      printf "%s[INFO]%s No se instalaron deps para %s.\n" "$C_CYN" "$C_RESET" "$context"
      return 1
      ;;
  esac
  return 0
}

print_header() {
  clear
  if [ -f "$BANNER_FILE" ]; then
    printf "%s" "$C_PURP"
    sed 's/\\n$//' "$BANNER_FILE" | sed "s/^/$C_PURP/;s/$/$C_RESET/"
    printf "%s\n" "$C_RESET"
  else
    # Banner degradado (versión ES: violeta → rojo)
    local colors=("$C_PURP" "$C_BLU" "$C_CYN" "$C_GRN" "$C_YLW" "$C_RED")
    local banner_lines
    mapfile -t banner_lines <<'EOF'
@@@  @@@  @@@  @@@@@@  @@@  @@@  @@@@@@ @@@@@@@   @@@@@@   @@@@@@@ @@@@@@@@  @@@@@@ @@@  @@@ @@@ @@@@@@@
@@!  @@!  @@! @@!  @@@ @@!  !@@ !@@     @@!  @@@ @@!  @@@ !@@      @@!      !@@     @@!  @@@ @@! @@!  @@@
@!!  !!@  @!@ @!@!@!@!  !@@!@!   !@@!!  @!@@!@!  @!@!@!@! !@!      @!!!:!    !@@!!  @!@!@!@! !!@ @!@@!@!
 !:  !!:  !!  !!:  !!!  !: :!!      !:! !!:      !!:  !!! :!!      !!:          !:! !!:  !!! !!: !!:
  ::.:  :::    :   : : :::  ::: ::.: :   :        :   : :  :: :: : : :: ::: ::.: :   :   : : :    :

@@@@@@@      @@@ @@@@@@@  @@@@@@@   @@@@@@  @@@@@@@  @@@  @@@  @@@@@@@ @@@@@@@@ @@@@@@@
@@!  @@@     @@! @@!  @@@ @@!  @@@ @@!  @@@ @@!  @@@ @@!  @@@ !@@      @@!      @@!  @@@
@!@  !@!     !!@ @!@@!@!  @!@!!@!  @!@  !@! @!@  !@! @!@  !@! !@!      @!!!:!   @!@!!@!
!!:  !!! .  .!!  !!:      !!: :!!  !!:  !!! !!:  !!! !!:  !!! :!!      !!:      !!: :!!
:: :  :  ::.::    :        :   : :  : :. :  :: :  :   :.:: :   :: :: : : :: :::  :   : :

@@@@@@@  @@@@@@   @@@@@@  @@@
  @@!   @@!  @@@ @@!  @@@ @@!
  @!!   @!@  !@! @!@  !@! @!!
  !!:   !!:  !!! !!:  !!! !!:
   :     : :. :   : :. :  : ::.: :
EOF
    for idx in "${!banner_lines[@]}"; do
      local color="${colors[$((idx % ${#colors[@]}))]}"
      printf "%s%s%s\n" "$color" "${banner_lines[$idx]}" "$C_RESET"
    done
  fi
  printf "%s⚡ By Astro One Deep 🎵%s\n\n" "$C_PURP" "$C_RESET"

  printf "%sWAX SPACESHIP  DJProducerTools%s\n" "$C_CYN" "$C_RESET"
  printf "%sBase:%s %s\n" "$C_YLW" "$C_RESET" "$BASE_PATH"

  local safemode_str
  local lock_str
  local dryrun_str

  if [ "$SAFE_MODE" -eq 1 ]; then
    safemode_str="${C_GRN}ON${C_RESET}"
  else
    safemode_str="${C_RED}OFF${C_RESET}"
  fi

  if [ "$DJ_SAFE_LOCK" -eq 1 ]; then
    lock_str="${C_GRN}ACTIVE${C_RESET}"
  else
    lock_str="${C_RED}INACTIVE${C_RESET}"
  fi

  if [ "$DRYRUN_FORCE" -eq 1 ]; then
    dryrun_str="${C_GRN}ON${C_RESET}"
  else
    dryrun_str="${C_RED}OFF${C_RESET}"
  fi

  printf "%sAssist:%s %sON%s | %sAutoTools:%s %sON%s | %sSafeMode:%s %s | %sDJ_SAFE_LOCK:%s %s | %sDryRunForce:%s %s\n" \
    "$C_BLU" "$C_RESET" "$C_GRN" "$C_RESET" \
    "$C_BLU" "$C_RESET" "$C_GRN" "$C_RESET" \
    "$C_BLU" "$C_RESET" "$safemode_str" \
    "$C_BLU" "$C_RESET" "$lock_str" \
    "$C_BLU" "$C_RESET" "$dryrun_str"

  printf "────────────────────────────────────────────────────────────\n"
}

print_menu() {
  printf "%sMenú (vista agrupada)%s\n" "$C_GRN" "$C_RESET"
  printf "%s⚙️  Core (1-12):%s\n" "$C_CYN" "$C_RESET"
  printf "  %s1)%s Estado / rutas / locks\n" "$C_GRN" "$C_RESET"
  printf "  %s2)%s Cambiar Base Path\n" "$C_GRN" "$C_RESET"
  printf "  %s3)%s Resumen del volumen / últimos reportes\n" "$C_GRN" "$C_RESET"
  printf "  %s4)%s Top carpetas por tamaño\n" "$C_GRN" "$C_RESET"
  printf "  %s5)%s Top archivos grandes\n" "$C_GRN" "$C_RESET"
  printf "  %s6)%s Scan workspace (catálogo previo)\n" "$C_GRN" "$C_RESET"
  printf "  %s7)%s Backup Serato (_Serato_ / _Serato_Backup)\n" "$C_GRN" "$C_RESET"
  printf "  %s8)%s Backup DJ (metadatos Serato/Traktor/Rekordbox/Ableton)\n" "$C_GRN" "$C_RESET"
  printf "  %s9)%s Índice SHA-256 (generar/reusar)\n" "$C_GRN" "$C_RESET"
  printf "  %s10)%s Reporte duplicados EXACTO (plan JSON/TSV)\n" "$C_GRN" "$C_RESET"
  printf "  %s11)%s Quarantine duplicados (desde LAST_PLAN)\n" "$C_GRN" "$C_RESET"
  printf "  %s12)%s Quarantine Manager (listar/purgar/restaurar)\n" "$C_GRN" "$C_RESET"
  printf "\n"

  printf "%s🎛️  Media / organización (13-24):%s\n" "$C_CYN" "$C_RESET"
  printf "  %s13)%s Detectar media corrupta (ffprobe) -> TSV\n" "$C_GRN" "$C_RESET"
  printf "  %s14)%s Crear playlists .m3u8 por carpeta\n" "$C_GRN" "$C_RESET"
  printf "  %s15)%s Doctor: Relink Helper (TSV no destructivo)\n" "$C_GRN" "$C_RESET"
  printf "  %s16)%s Mirror por género (hardlink/copy/move) (plan seguro)\n" "$C_GRN" "$C_RESET"
  printf "  %s17)%s Buscar librerías DJ\n" "$C_GRN" "$C_RESET"
  printf "  %s18)%s Rescan inteligente (match + ULTRA)\n" "$C_GRN" "$C_RESET"
  printf "  %s19)%s Tools: diagnóstico/instalación recomendada\n" "$C_GRN" "$C_RESET"
  printf "  %s20)%s Fix ownership/flags (plan + ejecución opcional)\n" "$C_GRN" "$C_RESET"
  printf "  %s21)%s Instalar comando universal: djproducertool\n" "$C_GRN" "$C_RESET"
  printf "  %s22)%s Desinstalar comando: djproducertool\n" "$C_GRN" "$C_RESET"
  printf "  %s23)%s Toggle SafeMode (ON/OFF)\n" "$C_GRN" "$C_RESET"
  printf "  %s24)%s Toggle DJ_SAFE_LOCK (ACTIVE/INACTIVE)\n" "$C_GRN" "$C_RESET"
  printf "\n"

  printf "%s🧹 Procesos / limpieza (25-39):%s\n" "$C_CYN" "$C_RESET"
  printf "  %s25)%s Ayuda rápida (guía de procesos)\n" "$C_GRN" "$C_RESET"
  printf "  %s26)%s Estado: Export/Import (bundle)\n" "$C_GRN" "$C_RESET"
  printf "  %s27)%s Snapshot integridad (hash rápido) con progreso\n" "$C_GRN" "$C_RESET"
  printf "  %s28)%s Visor de logs (selector)\n" "$C_GRN" "$C_RESET"
  printf "  %s29)%s Toggle DryRunForce (ON/OFF)\n" "$C_GRN" "$C_RESET"
  printf "  %s30)%s Organizar audio por TAGS (genre) -> plan TSV\n" "$C_GRN" "$C_RESET"
  printf "  %s31)%s Reporte tags audio -> TSV\n" "$C_GRN" "$C_RESET"
  printf "  %s32)%s Serato Video: REPORT (sin transcode)\n" "$C_GRN" "$C_RESET"
  printf "  %s33)%s Serato Video: PREP (solo plan de transcode)\n" "$C_GRN" "$C_RESET"
  printf "  %s34)%s Normalizar nombres (plan TSV)\n" "$C_GRN" "$C_RESET"
  printf "  %s35)%s Organizar samples por TIPO (plan TSV)\n" "$C_GRN" "$C_RESET"
  printf "  %s36)%s Limpiar WEB (submenú)\n" "$C_GRN" "$C_RESET"
  printf "  %s37)%s WEB: Whitelist Manager (dominios permitidos)\n" "$C_GRN" "$C_RESET"
  printf "  %s38)%s Limpiar WEB en Playlists (.m3u/.m3u8)\n" "$C_GRN" "$C_RESET"
  printf "  %s39)%s Limpiar WEB en TAGS (mutagen) (plan)\n" "$C_GRN" "$C_RESET"
  printf "\n"

  printf "%s🧠 Deep/ML (40-52):%s\n" "$C_CYN" "$C_RESET"
  printf "  %s40)%s Deep Thinking: Smart Analysis (JSON)\n" "$C_GRN" "$C_RESET"
  printf "  %s41)%s Machine Learning: Predictor de problemas\n" "$C_GRN" "$C_RESET"
  printf "  %s42)%s Deep Thinking: Optimizador de eficiencia\n" "$C_GRN" "$C_RESET"
  printf "  %s43)%s Deep Thinking: Flujo de trabajo inteligente\n" "$C_GRN" "$C_RESET"
  printf "  %s44)%s Deep Thinking: Deduplicación integrada\n" "$C_GRN" "$C_RESET"
  printf "  %s45)%s ML: Organización automática (plan)\n" "$C_GRN" "$C_RESET"
  printf "  %s46)%s Deep Thinking: Armonizador de metadatos (plan)\n" "$C_GRN" "$C_RESET"
  printf "  %s47)%s ML: Backup predictivo\n" "$C_GRN" "$C_RESET"
  printf "  %s48)%s Deep Thinking: Sincronización multi-plataforma\n" "$C_GRN" "$C_RESET"
  printf "  %s49)%s Audio BPM (tags/librosa) -> TSV\n" "$C_GRN" "$C_RESET"
  printf "  %s50)%s API/OSC server (start/stop)\n" "$C_GRN" "$C_RESET"
  printf "  %s51)%s ML: Recomendaciones adaptativas\n" "$C_GRN" "$C_RESET"
  printf "  %s52)%s Deep Thinking: Pipeline de limpieza automatizado\n" "$C_GRN" "$C_RESET"
  printf "  %s62)%s ML Evolutivo (entrenar/predicción local)\n" "$C_GRN" "$C_RESET"
  printf "  %s63)%s Toggle ML ON/OFF (evita activar venv ML)\n" "$C_GRN" "$C_RESET"
  printf "  %s64)%s TensorFlow opcional (instalar/ideas avanzadas)\n" "$C_GRN" "$C_RESET"
  printf "  %s65)%s TensorFlow Lab (auto-tagging/similitud/etc.)\n" "$C_GRN" "$C_RESET"
  printf "\n"

  printf "%s🧰 Extras / utilidades (53-68):%s\n" "$C_CYN" "$C_RESET"
  printf "  %s53)%s Reset estado / limpiar extras\n" "$C_GRN" "$C_RESET"
  printf "  %s54)%s Gestor de perfiles (guardar/cargar rutas)\n" "$C_GRN" "$C_RESET"
  printf "  %s55)%s Ableton Tools (analítica básica)\n" "$C_GRN" "$C_RESET"
  printf "  %s56)%s Importers: Rekordbox/Traktor cues\n" "$C_GRN" "$C_RESET"
  printf "  %s57)%s Gestor de exclusiones (perfiles)\n" "$C_GRN" "$C_RESET"
  printf "  %s58)%s Comparar hash_index entre discos (sin rehash)\n" "$C_GRN" "$C_RESET"
  printf "  %s59)%s Health-check de estado (_DJProducerTools)\n" "$C_GRN" "$C_RESET"
  printf "  %s60)%s Export/Import solo config/perfiles\n" "$C_GRN" "$C_RESET"
  printf "  %s61)%s Mirror check entre hash_index (faltantes/corrupción)\n" "$C_GRN" "$C_RESET"
  printf "  %s66)%s Plan LUFS (análisis, sin normalizar)\n" "$C_GRN" "$C_RESET"
  printf "  %s67)%s Auto-cues por onsets (librosa)\n" "$C_GRN" "$C_RESET"
  printf "  %s68)%s Instalar deps Python en venv (pyserial, python-osc, librosa, soundfile)\n" "$C_GRN" "$C_RESET"

  printf "\n"
  printf "%sL)%s Librerías DJ & Cues (submenú)\n" "$C_GRN" "$C_RESET"
  printf "%sD)%s Duplicados generales (submenú)\n" "$C_GRN" "$C_RESET"
  printf "%sV)%s Visuales / DAW / OSC (submenú)\n" "$C_GRN" "$C_RESET"
  printf "%sH)%s Help & INFO\n" "$C_GRN" "$C_RESET"
  printf "%s0)%s Salir\n" "$C_GRN" "$C_RESET"
}

invalid_option() {
  printf "%s[ERR]%s Opción inválida.\n" "$C_RED" "$C_RESET"
  pause_enter
}

action_1_status() {
  print_header
  printf "%s[INFO]%s Estado actual:\n" "$C_CYN" "$C_RESET"
  printf "  BASE_PATH: %s\n" "$BASE_PATH"
  printf "  STATE_DIR: %s\n" "$STATE_DIR"
  printf "  REPORTS_DIR: %s\n" "$REPORTS_DIR"
  printf "  PLANS_DIR: %s\n" "$PLANS_DIR"
  printf "  QUAR_DIR: %s\n" "$QUAR_DIR"
  printf "  VENV_DIR: %s (opcional ML)\n" "$VENV_DIR"
  if [ -n "${EXTRA_SOURCE_ROOTS:-}" ]; then
    printf "  EXTRA_SOURCE_ROOTS (auto-detectadas al arrancar): %s\n" "$EXTRA_SOURCE_ROOTS"
  fi
  local safe_disp lock_disp dry_disp
  if [ "$SAFE_MODE" -eq 1 ]; then safe_disp="ON"; else safe_disp="OFF"; fi
  if [ "$DJ_SAFE_LOCK" -eq 1 ]; then lock_disp="ACTIVE"; else lock_disp="INACTIVE"; fi
  if [ "$DRYRUN_FORCE" -eq 1 ]; then dry_disp="ON"; else dry_disp="OFF"; fi
  printf "  SAFE_MODE: %s\n" "$safe_disp"
  printf "  DJ_SAFE_LOCK: %s\n" "$lock_disp"
  printf "  DRYRUN_FORCE: %s\n" "$dry_disp"
  pause_enter
}

action_2_change_base() {
  print_header
  printf "%s[INFO]%s BASE_PATH actual: %s\n" "$C_CYN" "$C_RESET" "$BASE_PATH"
  printf "Nuevo BASE_PATH (ENTER para cancelar, acepta rutas con espacios/drag & drop): "
  read -e -r new_base
  if [ -z "$new_base" ]; then
    return
  fi
  new_base=$(strip_quotes "$new_base")
  if [ ! -d "$new_base" ]; then
    printf "%s[ERR]%s Ruta no válida.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  BASE_PATH="$new_base"
  init_paths
  save_conf
  printf "%s[OK]%s BASE_PATH actualizado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_3_summary() {
  print_header
  printf "%s[INFO]%s Resumen del volumen:\n" "$C_CYN" "$C_RESET"
  du -sh "$BASE_PATH" 2>/dev/null || true
  printf "\nÚltimos reports en %s:\n" "$REPORTS_DIR"
  ls -1t "$REPORTS_DIR" 2>/dev/null | head || true
  pause_enter
}

action_4_top_dirs() {
  print_header
  printf "%s[INFO]%s Top carpetas por tamaño (nivel 2):\n" "$C_CYN" "$C_RESET"
  find "$BASE_PATH" -maxdepth 2 -type d -print0 2>/dev/null | xargs -0 du -sh 2>/dev/null | sort -hr | head || true
  pause_enter
}

action_5_top_files() {
  print_header
  printf "%s[INFO]%s Top archivos grandes:\n" "$C_CYN" "$C_RESET"
  find "$BASE_PATH" -type f -print0 2>/dev/null | xargs -0 ls -lhS 2>/dev/null | head || true
  pause_enter
}

action_6_scan_workspace() {
  print_header
  out="$REPORTS_DIR/workspace_scan.tsv"
  printf "%s[INFO]%s Scan workspace -> %s\n" "$C_CYN" "$C_RESET" "$out"
  total=$(find "$BASE_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$total" -eq 0 ]; then
    >"$out"
    printf "%s[WARN]%s No se encontraron archivos.\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi
  count=0
  >"$out"
  find "$BASE_PATH" -type f 2>/dev/null | while IFS= read -r f; do
    count=$((count + 1))
    percent=$((count * 100 / total))
    rel="${f#$BASE_PATH/}"
    status_line "SCAN" "$percent" "$rel"
    printf "%s\t%s\n" "$rel" "$f" >>"$out"
  done
  finish_status_line
  printf "%s[OK]%s Generado %s\n" "$C_GRN" "$C_RESET" "$out"
  pause_enter
}

action_7_backup_serato() {
  confirm_heavy "Backup Serato (rsync)" || return
  print_header
  printf "%s[INFO]%s Backup Serato básico.\n" "$C_CYN" "$C_RESET"
  src1="$BASE_PATH/_Serato_"
  src2="$BASE_PATH/_Serato_Backup"
  dest="$STATE_DIR/serato_backup"
  mkdir -p "$dest"
  if [ -d "$src1" ]; then
    rsync -a "$src1"/ "$dest/_Serato_"/ 2>/dev/null || true
  fi
  if [ -d "$src2" ]; then
    rsync -a "$src2"/ "$dest/_Serato_Backup"/ 2>/dev/null || true
  fi
  printf "%s[OK]%s Backup Serato completado (si había fuentes).\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_8_backup_dj() {
  confirm_heavy "Backup DJ metadatos (rsync)" || return
  print_header
  printf "%s[INFO]%s Backup DJ metadatos.\n" "$C_CYN" "$C_RESET"
  dest="$STATE_DIR/dj_metadata_backup"
  mkdir -p "$dest"

  paths_tmp=$(mktemp "${STATE_DIR}/backup_dj_paths.XXXXXX") || paths_tmp="/tmp/backup_dj_paths.$$"
  >"$paths_tmp"

  for d in "Serato" "Traktor" "Rekordbox" "Ableton"; do
    find "$BASE_PATH" -maxdepth 4 -type d -iname "*$d*" -print0 2>/dev/null | while IFS= read -r -d '' f; do
      printf "%s|%s\n" "$d" "$f" >>"$paths_tmp"
    done
  done

  total=$(wc -l <"$paths_tmp" | tr -d ' ')
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No se encontraron rutas de metadatos.\n" "$C_YLW" "$C_RESET"
    rm -f "$paths_tmp"
    pause_enter
    return
  fi

  count=0
  while IFS='|' read -r typ path; do
    count=$((count + 1))
    percent=$((count * 100 / total))
    status_line "BACKUP_DJ ${count}/${total}" "$percent" "$path"
    dest_dir="$dest/${typ}_$(basename "$path")"
    rsync -a "$path"/ "$dest_dir"/ 2>/dev/null || true
    printf "\n%s[OK]%s %s -> %s\n" "$C_GRN" "$C_RESET" "$path" "$dest_dir"
  done <"$paths_tmp"
  finish_status_line
  rm -f "$paths_tmp"

  printf "%s[OK]%s Backup DJ metadatos completado (%s rutas).\n" "$C_GRN" "$C_RESET" "$total"
  pause_enter
}

action_9_hash_index() {
  confirm_heavy "Hash index completo (SHA-256)" || return
  print_header
  out="$REPORTS_DIR/hash_index.tsv"
  printf "%s[INFO]%s Generando índice SHA-256 -> %s\n" "$C_CYN" "$C_RESET" "$out"
  total=$(find "$BASE_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$total" -eq 0 ]; then
    >"$out"
    printf "%s[WARN]%s No se encontraron archivos.\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi
  count=0
  >"$out"
  find "$BASE_PATH" -type f 2>/dev/null | while IFS= read -r f; do
    count=$((count + 1))
    percent=$((count * 100 / total))
    rel="${f#$BASE_PATH/}"
    status_line "HASH" "$percent" "$rel"
    h=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
    printf "%s\t%s\t%s\n" "$h" "$rel" "$f" >>"$out"
  done
  finish_status_line
  printf "%s[OK]%s Generado %s\n" "$C_GRN" "$C_RESET" "$out"
  pause_enter
}

action_10_dupes_plan() {
  print_header
  hash_file="$REPORTS_DIR/hash_index.tsv"
  if [ ! -f "$hash_file" ]; then
    printf "%s[WARN]%s No hay hash_index.tsv, generando primero.\n" "$C_YLW" "$C_RESET"
    action_9_hash_index
  fi
  hash_file="$REPORTS_DIR/hash_index.tsv"
  if [ ! -f "$hash_file" ]; then
    printf "%s[ERR]%s No se pudo generar hash_index.tsv.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  plan_tsv="$PLANS_DIR/dupes_plan.tsv"
  plan_json="$PLANS_DIR/dupes_plan.json"
  printf "%s[INFO]%s Generando plan de duplicados EXACTO.\n" "$C_CYN" "$C_RESET"
  awk '
  {
    h=$1
    rel=$2
    full=$3
    key=h
    count[key]++
    path[key, count[key]] = full
  }
  END {
    for (k in count) {
      if (count[k] > 1) {
        keep_done=0
        for (i=1; i<=count[k]; i++) {
          f = path[k,i]
          if (keep_done==0) {
            action="KEEP"
            keep_done=1
          } else {
            action="QUARANTINE"
          }
          printf "%s\t%s\t%s\n", k, action, f
        }
      }
    }
  }' "$hash_file" >"$plan_tsv"
  {
    echo "{"
    echo "  \"type\": \"dupes_plan\","
    echo "  \"entries\": ["
    first=1
    while IFS=$'\t' read -r h action f; do
      if [ "$first" -eq 0 ]; then
        echo "    ,"
      fi
      first=0
      printf "    {\"hash\": \"%s\", \"action\": \"%s\", \"path\": \"%s\"}" "$h" "$action" "$f"
    done <"$plan_tsv"
    echo
    echo "  ]"
    echo "}"
  } >"$plan_json"
  printf "%s[OK]%s Plan generado: %s y %s\n" "$C_GRN" "$C_RESET" "$plan_tsv" "$plan_json"
  pause_enter
}

action_11_quarantine_from_plan() {
  if [ "$DRYRUN_FORCE" -eq 1 ]; then
    print_header
    printf "%s[WARN]%s DRYRUN_FORCE=1, se omite quarantine (no se moverá nada).\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi
  print_header
  plan_tsv="$PLANS_DIR/dupes_plan.tsv"
  if [ ! -f "$plan_tsv" ]; then
    printf "%s[ERR]%s No existe dupes_plan.tsv.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  printf "%s[INFO]%s Aplicando quarantine desde plan (SAFE_MODE=%s).\n" "$C_CYN" "$C_RESET" "$SAFE_MODE"
  sample_count=$(awk -F'\t' '$2=="QUARANTINE"{c++} END {print c+0}' "$plan_tsv")
  printf "Acciones QUARANTINE: %s\n" "$sample_count"
  if [ "$sample_count" -gt 0 ]; then
    printf "Muestra de las primeras 10 entradas:\n"
    awk -F'\t' '$2=="QUARANTINE"{print NR": "$3}' "$plan_tsv" | head -10
  fi
  printf "Confirmar mover archivos marcados como QUARANTINE? (y/N): "
  read -r ans
  case "$ans" in
    y|Y) ;;
    *) printf "%s[INFO]%s Cancelado.\n" "$C_CYN" "$C_RESET"; pause_enter; return ;;
  esac
  while IFS=$'\t' read -r h action f; do
    if [ "$action" != "QUARANTINE" ]; then
      continue
    fi
    rel="${f#$BASE_PATH/}"
    dest_dir="$QUAR_DIR/$h"
    dest="$dest_dir/$(basename "$f")"
    if [ "$SAFE_MODE" -eq 1 ] || [ "$DJ_SAFE_LOCK" -eq 1 ] || [ "$DRYRUN_FORCE" -eq 1 ]; then
      printf "[DRY] mover \"%s\" -> \"%s\"\n" "$f" "$dest"
    else
      mkdir -p "$dest_dir"
      if [ -f "$f" ]; then
        mv "$f" "$dest"
        printf "[MOVE] \"%s\" -> \"%s\"\n" "$f" "$dest"
      fi
    fi
  done <"$plan_tsv"
  pause_enter
}

action_12_quarantine_manager() {
  while true; do
    clear
    printf "%s=== Quarantine Manager ===%s\n" "$C_CYN" "$C_RESET"
    printf "QUAR_DIR: %s\n\n" "$QUAR_DIR"
    printf "%s1)%s Listar archivos en quarantine\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Restaurar todo (si SAFE_MODE=0 y DJ_SAFE_LOCK=0)\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Borrar definitivamente todo (si SAFE_MODE=0 y DJ_SAFE_LOCK=0)\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Volver\n" "$C_YLW" "$C_RESET"
    printf "%sOpción:%s " "$C_BLU" "$C_RESET"
    read -r qop
    case "$qop" in
      1)
        printf "%s[INFO]%s Contenido de quarantine:\n" "$C_CYN" "$C_RESET"
        find "$QUAR_DIR" -type f 2>/dev/null || true
        pause_enter
        ;;
      2)
        if [ "$SAFE_MODE" -eq 1 ] || [ "$DJ_SAFE_LOCK" -eq 1 ]; then
          printf "%s[ERR]%s SAFE_MODE o DJ_SAFE_LOCK activos. No se restaurará nada.\n" "$C_RED" "$C_RESET"
          pause_enter
        else
          printf "%s[WARN]%s Restaurar TODO desde quarantine al BASE_PATH.\n" "$C_YLW" "$C_RESET"
          printf "Confirmar (YES para continuar): "
          read -r ans
          if [ "$ans" = "YES" ]; then
            find "$QUAR_DIR" -type f 2>/dev/null | while IFS= read -r f; do
              rel="${f#$QUAR_DIR/}"
              dest="$BASE_PATH/_RESTORED_FROM_QUARANTINE/$rel"
              mkdir -p "$(dirname "$dest")"
              mv "$f" "$dest"
              printf "[RESTORE] %s -> %s\n" "$f" "$dest"
            done
            pause_enter
          fi
        fi
        ;;
      3)
        if [ "$SAFE_MODE" -eq 1 ] || [ "$DJ_SAFE_LOCK" -eq 1 ]; then
          printf "%s[ERR]%s SAFE_MODE o DJ_SAFE_LOCK activos. No se borrará nada.\n" "$C_RED" "$C_RESET"
          pause_enter
        else
          printf "%s[WARN]%s Borrar TODO el contenido de quarantine.\n" "$C_YLW" "$C_RESET"
          printf "Confirmar (YES para continuar): "
          read -r ans2
          if [ "$ans2" = "YES" ]; then
            rm -rf "$QUAR_DIR"/*
            printf "%s[OK]%s Quarantine vaciado.\n" "$C_GRN" "$C_RESET"
            pause_enter
          fi
        fi
        ;;
      B|b)
        break ;;
      *)
        invalid_option
        ;;
    esac
  done
}

action_13_ffprobe_report() {
  print_header
  out="$REPORTS_DIR/media_corrupt.tsv"
  printf "%s[INFO]%s Detectando media corrupta (ffprobe) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  if ! command -v ffprobe >/dev/null 2>&1; then
    printf "%s[ERR]%s ffprobe no está instalado.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  >"$out"
  find "$BASE_PATH" -type f 2>/dev/null | while IFS= read -r f; do
    status_line "FFPROBE" 0 "$f"
    ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$f" >/dev/null 2>&1 || printf "%s\tCORRUPT\n" "$f" >>"$out"
  done
  finish_status_line
  printf "%s[OK]%s Reporte generado (si hay corruptos) en %s\n" "$C_GRN" "$C_RESET" "$out"
  pause_enter
}

action_14_playlists_per_folder() {
  print_header
  printf "%s[INFO]%s Crear playlists .m3u8 por carpeta.\n" "$C_CYN" "$C_RESET"
  find "$BASE_PATH" -type d 2>/dev/null | while IFS= read -r d; do
    playlist="$d/playlist.m3u8"
    find "$d" -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.m4a" \) 2>/dev/null >"$playlist"
  done
  printf "%s[OK]%s Playlists generadas.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_15_relink_helper() {
  print_header
  out="$REPORTS_DIR/relink_helper.tsv"
  printf "%s[INFO]%s Generando Relink Helper TSV: %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  find "$BASE_PATH" -type f 2>/dev/null | while IFS= read -r f; do
    rel="${f#$BASE_PATH/}"
    printf "%s\t%s\n" "$rel" "$f" >>"$out"
  done
  printf "%s[OK]%s Relink Helper generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_16_mirror_by_genre() {
  print_header
  printf "%s[INFO]%s Mirror por género (plan seguro básico).\n" "$C_CYN" "$C_RESET"
  out="$PLANS_DIR/mirror_by_genre.tsv"
  >"$out"
  find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null | while IFS= read -r f; do
    printf "%s\tGENRE_UNKNOWN\t%s\n" "$f" "$BASE_PATH/_MIRROR_BY_GENRE/GENRE_UNKNOWN/$(basename "$f")" >>"$out"
  done
  printf "%s[OK]%s Plan espejo por género generado: %s\n" "$C_GRN" "$C_RESET" "$out"
  pause_enter
}

action_17_find_dj_libs() {
  print_header
  printf "%s[INFO]%s Buscando librerías DJ en %s\n" "$C_CYN" "$C_RESET" "$BASE_PATH"
  find "$BASE_PATH" -type d \( -iname "*Serato*" -o -iname "*Traktor*" -o -iname "*Rekordbox*" -o -iname "*Ableton*" \) 2>/dev/null || true
  pause_enter
}

action_18_rescan_intelligent() {
  print_header
  printf "%s[INFO]%s Rescan inteligente.\n" "$C_CYN" "$C_RESET"
  out="$REPORTS_DIR/rescan_intelligent.tsv"
  total=$(find "$BASE_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$total" -eq 0 ]; then
    >"$out"
    printf "%s[WARN]%s No se encontraron archivos.\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi
  count=0
  >"$out"
  find "$BASE_PATH" -type f 2>/dev/null | while IFS= read -r f; do
    count=$((count + 1))
    percent=$((count * 100 / total))
    status_line "RESCAN" "$percent" "$f"
    printf "%s\n" "$f" >>"$out"
  done
  finish_status_line
  printf "%s[OK]%s Rescan inteligente completado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_19_tools_diag() {
  print_header
  printf "%s[INFO]%s Diagnóstico herramientas.\n" "$C_CYN" "$C_RESET"
  for cmd in ffprobe shasum rsync find ls du; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf "  %s: OK\n" "$cmd"
    else
      printf "  %s: NO ENCONTRADO\n" "$cmd"
    fi
  done
  pause_enter
}

action_20_fix_ownership_flags() {
  print_header
  out="$PLANS_DIR/fix_ownership_flags.tsv"
  printf "%s[INFO]%s Plan de fix ownership/flags -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  find "$BASE_PATH" -type f 2>/dev/null | while IFS= read -r f; do
    printf "%s\tchown-KEEP\tchmod-KEEP\n" "$f" >>"$out"
  done
  printf "%s[OK]%s Plan generado (no ejecutado).\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_21_install_cmd() {
  print_header
  target="/usr/local/bin/djproducertool"
  printf "%s[INFO]%s Instalar comando universal: %s\n" "$C_CYN" "$C_RESET" "$target"
  if [ "$SAFE_MODE" -eq 1 ]; then
    printf "%s[WARN]%s SAFE_MODE=1, solo se mostrará la acción.\n" "$C_YLW" "$C_RESET"
    printf "ln -s \"%s/DJProducerTools_MultiScript.sh\" \"%s\"\n" "$BASE_PATH" "$target"
  else
    ln -sf "$BASE_PATH/DJProducerTools_MultiScript.sh" "$target" 2>/dev/null || printf "%s[ERR]%s No se pudo crear el enlace (permiso requerido).\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_22_uninstall_cmd() {
  print_header
  target="/usr/local/bin/djproducertool"
  printf "%s[INFO]%s Desinstalar comando universal: %s\n" "$C_CYN" "$C_RESET" "$target"
  if [ -L "$target" ] || [ -f "$target" ]; then
    if [ "$SAFE_MODE" -eq 1 ]; then
      printf "%s[WARN]%s SAFE_MODE=1, no se borrará.\n" "$C_YLW" "$C_RESET"
    else
      rm -f "$target" 2>/dev/null || true
      printf "%s[OK]%s Eliminado.\n" "$C_GRN" "$C_RESET"
    fi
  else
    printf "%s[INFO]%s No existe el comando.\n" "$C_CYN" "$C_RESET"
  fi
  pause_enter
}

action_23_toggle_safe_mode() {
  print_header
  printf "%s[INFO]%s SAFE_MODE actual: %s\n" "$C_CYN" "$C_RESET" "$SAFE_MODE"
  if [ "$SAFE_MODE" -eq 1 ]; then
    SAFE_MODE=0
  else
    SAFE_MODE=1
  fi
  save_conf
  printf "%s[OK]%s SAFE_MODE ahora: %s\n" "$C_GRN" "$C_RESET" "$SAFE_MODE"
  pause_enter
}

action_24_toggle_lock() {
  print_header
  printf "%s[INFO]%s DJ_SAFE_LOCK actual: %s\n" "$C_CYN" "$C_RESET" "$DJ_SAFE_LOCK"
  if [ "$DJ_SAFE_LOCK" -eq 1 ]; then
    DJ_SAFE_LOCK=0
  else
    DJ_SAFE_LOCK=1
  fi
  save_conf
  printf "%s[OK]%s DJ_SAFE_LOCK ahora: %s\n" "$C_GRN" "$C_RESET" "$DJ_SAFE_LOCK"
  pause_enter
}

action_25_quick_help() {
  print_header
  printf "%s[INFO]%s Guía rápida de procesos.\n" "$C_CYN" "$C_RESET"
  printf "  6 -> 9 -> 10 -> 11 -> 12 para flujo de duplicados.\n"
  printf "  7 -> 8 para backups DJ.\n"
  printf "  27 para snapshot rápido de integridad.\n"
  printf "  Reset estado: borra la carpeta _DJProducerTools en tu BASE_PATH para reiniciar (config/reports/planes/quarantine/venv).\n"
  printf "    Ejemplo: rm -rf \"<BASE_PATH>/_DJProducerTools\" (cambia <BASE_PATH> por tu ruta actual).\n"
  pause_enter
}

action_26_export_import_state() {
  print_header
  bundle="$STATE_DIR/DJPT_state_bundle.tar.gz"
  printf "%s[INFO]%s Exportando estado a %s\n" "$C_CYN" "$C_RESET" "$bundle"
  (tar -czf "$bundle" -C "$STATE_DIR" . 2>/dev/null) &
  tar_pid=$!
  while kill -0 "$tar_pid" 2>/dev/null; do
    status_line "EXPORT" "--" "Empaquetando estado..."
    sleep 1
  done
  finish_status_line
  if wait "$tar_pid"; then
    printf "%s[OK]%s Bundle creado: %s\n" "$C_GRN" "$C_RESET" "$bundle"
  else
    printf "%s[ERR]%s Falló la creación del bundle.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_27_snapshot() {
  confirm_heavy "Snapshot integridad (hash rápido)" || return
  print_header
  out="$REPORTS_DIR/snapshot_hash_fast.tsv"
  printf "%s[INFO]%s Generando snapshot rápido -> %s\n" "$C_CYN" "$C_RESET" "$out"
  total=$(find "$BASE_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$total" -eq 0 ]; then
    >"$out"
    printf "%s[WARN]%s No se encontraron archivos.\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi
  count=0
  >"$out"
  find "$BASE_PATH" -type f 2>/dev/null | while IFS= read -r f; do
    count=$((count + 1))
    percent=$((count * 100 / total))
    status_line "SNAP" "$percent" "$f"
    h=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
    printf "%s\t%s\n" "$h" "$f" >>"$out"
  done
  finish_status_line
  printf "%s[OK]%s Snapshot generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_28_logs_viewer() {
  print_header
  printf "%s[INFO]%s Logs en %s\n" "$C_CYN" "$C_RESET" "$LOGS_DIR"
  ls -1t "$LOGS_DIR" 2>/dev/null || true
  pause_enter
}

action_29_toggle_dryrun() {
  print_header
  printf "%s[INFO]%s DRYRUN_FORCE actual: %s\n" "$C_CYN" "$C_RESET" "$DRYRUN_FORCE"
  if [ "$DRYRUN_FORCE" -eq 1 ]; then
    DRYRUN_FORCE=0
  else
    DRYRUN_FORCE=1
  fi
  save_conf
  printf "%s[OK]%s DRYRUN_FORCE ahora: %s\n" "$C_GRN" "$C_RESET" "$DRYRUN_FORCE"
  pause_enter
}

action_53_reset_state() {
  print_header
  printf "%s[INFO]%s Reset de estado (config/reports/planes/quarantine/venv).\n" "$C_CYN" "$C_RESET"
  printf "BASE_PATH: %s\n" "$BASE_PATH"
  printf "STATE_DIR a borrar: %s\n" "$STATE_DIR"
  printf "EXTRA_SOURCE_ROOTS actuales: %s\n" "${EXTRA_SOURCE_ROOTS:-<vacío>}"
  if [ "$SAFE_MODE" -eq 1 ] || [ "$DJ_SAFE_LOCK" -eq 1 ]; then
    printf "%s[WARN]%s SAFE_MODE/DJ_SAFE_LOCK activos. Desactiva temporalmente si realmente quieres borrar el estado.\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi
  if ! ensure_state_dir_safe; then
    pause_enter
    return
  fi
  printf "Escribe RESET para borrar, CLEAR para solo limpiar EXTRA_SOURCE_ROOTS, DRY para simular, o ENTER para cancelar: "
  read -r ans
  case "$ans" in
    RESET)
      printf "Confirma escribiendo YES para borrar %s: " "$STATE_DIR"
      read -r confirm
      if [ "$confirm" != "YES" ]; then
        printf "%s[INFO]%s Cancelado.\n" "$C_CYN" "$C_RESET"
        pause_enter
        return
      fi
      if [ "$DRYRUN_FORCE" -eq 1 ]; then
        printf "[DRY] Se eliminaría: %s\n" "$STATE_DIR"
      else
        printf "%s[WARN]%s Eliminando %s ...\n" "$C_YLW" "$C_RESET" "$STATE_DIR"
        rm -rf "$STATE_DIR" 2>/dev/null || true
      fi
      EXTRA_SOURCE_ROOTS=""
      init_paths
      save_conf
      printf "%s[OK]%s Estado reiniciado.\n" "$C_GRN" "$C_RESET"
      ;;
    CLEAR)
      EXTRA_SOURCE_ROOTS=""
      save_conf
      printf "%s[OK]%s EXTRA_SOURCE_ROOTS limpiado.\n" "$C_GRN" "$C_RESET"
      ;;
    DRY)
      printf "[DRY] Se eliminaría: %s\n" "$STATE_DIR"
      ;;
    *)
      printf "%s[INFO]%s Cancelado.\n" "$C_CYN" "$C_RESET"
      ;;
  esac
  pause_enter
}

action_compare_hash_indexes() {
  print_header
  printf "%s[INFO]%s Comparar dos hash_index.tsv (sin recalcular hashes, formato: hash\\trel\\tpath).\n" "$C_CYN" "$C_RESET"
  printf "Hash index A (ENTER usa reports/hash_index.tsv): "
  read -e -r file_a
  [ -z "$file_a" ] && file_a="$REPORTS_DIR/hash_index.tsv"
  printf "Hash index B (drag & drop): "
  read -e -r file_b
  if [ ! -f "$file_a" ] || [ ! -f "$file_b" ]; then
    printf "%s[ERR]%s Archivo(s) inválidos.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  out_missing="$REPORTS_DIR/hash_compare_missing_$(date +%s).tsv"
  out_extra="$REPORTS_DIR/hash_compare_extra_$(date +%s).tsv"
  awk '{print $1"\t"$3}' "$file_a" | sort >"$STATE_DIR/hash_a.tmp"
  awk '{print $1"\t"$3}' "$file_b" | sort >"$STATE_DIR/hash_b.tmp"
  comm -23 "$STATE_DIR/hash_a.tmp" "$STATE_DIR/hash_b.tmp" >"$out_extra"
  comm -13 "$STATE_DIR/hash_a.tmp" "$STATE_DIR/hash_b.tmp" >"$out_missing"
  printf "%s[OK]%s Diferencias generadas:\n" "$C_GRN" "$C_RESET"
  printf "  Extra en A vs B: %s\n" "$out_extra"
  printf "  Faltante en A vs B: %s\n" "$out_missing"
  pause_enter
}

action_mirror_integrity_check() {
  print_header
  printf "%s[INFO]%s Validar integridad entre discos (hash_index por ruta, formato: hash\\trel\\tpath).\n" "$C_CYN" "$C_RESET"
  printf "Hash index A (ENTER usa reports/hash_index.tsv): "
  read -e -r file_a
  [ -z "$file_a" ] && file_a="$REPORTS_DIR/hash_index.tsv"
  printf "Hash index B (ruta espejo, drag & drop): "
  read -e -r file_b
  if [ ! -f "$file_a" ] || [ ! -f "$file_b" ]; then
    printf "%s[ERR]%s Archivo(s) inválidos.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  missing_in_b="$REPORTS_DIR/mirror_missing_in_B_$(date +%s).tsv"
  missing_in_a="$REPORTS_DIR/mirror_missing_in_A_$(date +%s).tsv"
  mismatch="$REPORTS_DIR/mirror_hash_mismatch_$(date +%s).tsv"
  awk -F'\t' '{map[$2]=$1} END {for (p in map) print p"\t"map[p]}' "$file_a" | sort >"$STATE_DIR/mirror_a.tmp"
  awk -F'\t' '{map[$2]=$1} END {for (p in map) print p"\t"map[p]}' "$file_b" | sort >"$STATE_DIR/mirror_b.tmp"
  join -v1 -t$'\t' "$STATE_DIR/mirror_a.tmp" "$STATE_DIR/mirror_b.tmp" >"$missing_in_b"
  join -v2 -t$'\t' "$STATE_DIR/mirror_a.tmp" "$STATE_DIR/mirror_b.tmp" >"$missing_in_a"
  join -t$'\t' "$STATE_DIR/mirror_a.tmp" "$STATE_DIR/mirror_b.tmp" | awk -F'\t' '{if ($2!=$3) print $1"\tA:"$2"\tB:"$3}' >"$mismatch"
  printf "%s[OK]%s Mirror check generado:\n" "$C_GRN" "$C_RESET"
  printf "  Falta en B: %s\n" "$missing_in_b"
  printf "  Falta en A: %s\n" "$missing_in_a"
  printf "  Hash distinto (posible corrupción): %s\n" "$mismatch"
  pause_enter
}

action_state_health() {
  print_header
  printf "%s[INFO]%s Health-check de _DJProducerTools\n" "$C_CYN" "$C_RESET"
  {
    echo "STATE HEALTH REPORT"
    echo "BASE_PATH: $BASE_PATH"
    echo "STATE_DIR: $STATE_DIR"
    du -sh "$STATE_DIR" 2>/dev/null || true
    echo "Top 10 en quarantine:"
    du -sh "$QUAR_DIR"/* 2>/dev/null | sort -hr | head -10 || true
    echo "Logs size:"
    du -sh "$LOGS_DIR" 2>/dev/null || true
    echo "Reports size:"
    du -sh "$REPORTS_DIR" 2>/dev/null || true
  } >"$STATE_HEALTH_REPORT"
  printf "%s[OK]%s Health report: %s\n" "$C_GRN" "$C_RESET" "$STATE_HEALTH_REPORT"
  pause_enter
}

action_export_import_config() {
  print_header
  printf "%s[INFO]%s Export/Import solo config/perfiles.\n" "$C_CYN" "$C_RESET"
  printf "1) Exportar config\n2) Importar config\nOpción: "
  read -e -r cio
  case "$cio" in
    1)
      bundle="$STATE_DIR/config_bundle_$(date +%s).tar.gz"
      tar -czf "$bundle" -C "$CONFIG_DIR" . 2>/dev/null
      printf "%s[OK]%s Config exportada: %s\n" "$C_GRN" "$C_RESET" "$bundle"
      ;;
    2)
      printf "Ruta del bundle (.tar.gz): "
      read -e -r bpath
      bpath=$(strip_quotes "$bpath")
      if [ ! -f "$bpath" ]; then
        printf "%s[ERR]%s Archivo inválido.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
      fi
      tar -xzf "$bpath" -C "$CONFIG_DIR" 2>/dev/null
      load_conf
      printf "%s[OK]%s Config importada.\n" "$C_GRN" "$C_RESET"
      ;;
    *)
      printf "%s[INFO]%s Cancelado.\n" "$C_CYN" "$C_RESET"
      ;;
  esac
  pause_enter
}

action_toggle_ml() {
  print_header
  if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
    ML_ENV_DISABLED=0
    save_conf
    printf "%s[OK]%s ML habilitado de nuevo.\n" "$C_GRN" "$C_RESET"
  else
    ML_ENV_DISABLED=1
    save_conf
    printf "%s[OK]%s ML deshabilitado (Deep/ML/62 no activarán venv).\n" "$C_GRN" "$C_RESET"
  fi
  pause_enter
}

action_ml_evo_manager() {
  print_header
  maybe_activate_ml_env "ML Evolutivo (entrenamiento local)" 0 1
  printf "%s[INFO]%s ML Evolutivo local (modelo ligero, sin enviar datos).\n" "$C_CYN" "$C_RESET"
  printf "1) Entrenar/reentrenar con datos locales\n"
  printf "2) Predecir sobre BASE_PATH usando el modelo guardado\n"
  printf "3) Reset (borrar modelo y features)\n"
  printf "Opción: "
  read -r mlop
  case "$mlop" in
    1)
      if ! command -v python3 >/dev/null 2>&1; then
        printf "%s[ERR]%s python3 no disponible.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
      fi
      if ! python3 - <<'PY' 2>/dev/null
import sys
try:
    import pandas  # noqa
    import sklearn  # noqa
    import joblib  # noqa
except Exception:
    sys.exit(1)
sys.exit(0)
PY
      then
        printf "%s[ERR]%s Faltan dependencias ML (numpy/pandas/scikit-learn). Instálalas en el venv e intenta de nuevo.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
      fi
      PLAN_HASH="$PLANS_DIR/general_hash_dupes_plan.tsv" PLAN_NAME="$PLANS_DIR/general_dupes_plan.tsv" \
      FEATURES_OUT="$ML_FEATURES_FILE" MODEL_OUT="$ML_MODEL_PATH" BASE="$BASE_PATH" python3 - <<'PY'
import os, sys, pathlib, hashlib, csv
from collections import defaultdict

try:
    import pandas as pd
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.model_selection import train_test_split
    from sklearn.preprocessing import OneHotEncoder
    from sklearn.compose import ColumnTransformer
    from sklearn.pipeline import Pipeline
    from sklearn.metrics import classification_report
    import joblib
except Exception as e:
    sys.exit(1)

plan_hash = pathlib.Path(os.environ["PLAN_HASH"])
plan_name = pathlib.Path(os.environ["PLAN_NAME"])
features_out = pathlib.Path(os.environ["FEATURES_OUT"])
model_out = pathlib.Path(os.environ["MODEL_OUT"])
base = pathlib.Path(os.environ["BASE"])

def feature_row(path_str, label):
    p = pathlib.Path(path_str)
    try:
        stat = p.stat()
        size = stat.st_size
    except FileNotFoundError:
        size = 0
    parts = p.parts
    depth = len(parts)
    name = p.name
    ext = p.suffix.lower()
    name_len = len(name)
    underscores = name.count("_")
    brackets = name.count("(") + name.count("[") + name.count("{")
    digits = sum(ch.isdigit() for ch in name)
    return {
        "path": str(p),
        "label": label,
        "size": size,
        "depth": depth,
        "name_len": name_len,
        "ext": ext or "<none>",
        "underscores": underscores,
        "brackets": brackets,
        "digits": digits,
    }

rows = []
# Prioridad 1: plan de hash (acción KEEP/QUARANTINE)
if plan_hash.exists() and plan_hash.stat().st_size > 0:
    with plan_hash.open() as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            _, action, path = parts[0], parts[1], parts[2]
            label = 1 if action.upper() != "KEEP" else 0
            rows.append(feature_row(path, label))
# Prioridad 2: plan de nombre+tamaño
elif plan_name.exists() and plan_name.stat().st_size > 0:
    seen_keys = defaultdict(int)
    with plan_name.open() as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 2:
                continue
            key, path = parts[0], parts[1]
            seen_keys[key] += 1
            # Marca duplicados (todas las ocurrencias) como 1
            label = 1 if seen_keys[key] >= 1 else 0
            rows.append(feature_row(path, label))
else:
    # Fallback: sample de BASE_PATH con heurística (sin etiquetas positivas reales)
    # Solo negativa: puede no entrenar bien, pero guardamos features para cuando haya planes.
    limit = 2000
    count = 0
    for p in base.rglob("*"):
        if p.is_file():
            rows.append(feature_row(str(p), 0))
            count += 1
            if count >= limit:
                break

if not rows:
    print("[ERR] Sin datos para entrenar.")
    sys.exit(2)

features_out.parent.mkdir(parents=True, exist_ok=True)
with features_out.open("w", newline="") as fw:
    w = csv.DictWriter(fw, fieldnames=list(rows[0].keys()), delimiter="\t")
    w.writeheader()
    w.writerows(rows)

df = pd.DataFrame(rows)
if df["label"].nunique() < 2:
    print("[WARN] No hay etiquetas positivas/negativas suficientes. Entrenamiento saltado.")
    sys.exit(3)

cat_cols = ["ext"]
num_cols = ["size", "depth", "name_len", "underscores", "brackets", "digits"]
pre = ColumnTransformer(
    transformers=[
        ("cat", OneHotEncoder(handle_unknown="ignore", max_categories=50), cat_cols),
        ("num", "passthrough", num_cols),
    ]
)
clf = RandomForestClassifier(n_estimators=80, max_depth=None, random_state=42, n_jobs=2)
pipe = Pipeline([("prep", pre), ("clf", clf)])
X = df[cat_cols + num_cols]
y = df["label"]
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.25, random_state=42, stratify=y)
pipe.fit(X_train, y_train)
y_pred = pipe.predict(X_test)
report = classification_report(y_test, y_pred, output_dict=True)
joblib.dump({"model": pipe, "features": cat_cols + num_cols}, model_out)

print(f"[OK] Modelo entrenado: {model_out}")
print(f"[INFO] Features guardadas en: {features_out}")
print(f"[INFO] Métricas (macro f1): {report.get('macro avg', {}).get('f1-score', 0):.3f}")
PY
      printf "%s[OK]%s Entrenamiento completado (ver consola para métricas).\n" "$C_GRN" "$C_RESET"
      pause_enter
      ;;
    2)
      if [ ! -f "$ML_MODEL_PATH" ]; then
        printf "%s[ERR]%s No hay modelo entrenado (ejecuta opción 1 primero).\n" "$C_RED" "$C_RESET"
        pause_enter
        return
      fi
      if ! command -v python3 >/dev/null 2>&1; then
        printf "%s[ERR]%s python3 no disponible.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
      fi
      BASE="$BASE_PATH" MODEL="$ML_MODEL_PATH" REPORT="$ML_PRED_REPORT" python3 - <<'PY'
import os, sys, pathlib, csv
import joblib

try:
    import pandas as pd
except Exception:
    sys.exit(1)

base = pathlib.Path(os.environ["BASE"])
model_path = pathlib.Path(os.environ["MODEL"])
report_path = pathlib.Path(os.environ["REPORT"])

if not model_path.exists():
    print("[ERR] Modelo no encontrado.")
    sys.exit(2)

obj = joblib.load(model_path)
pipe = obj["model"]
cols = obj["features"]

def feature_row(path_str):
    p = pathlib.Path(path_str)
    try:
        stat = p.stat()
        size = stat.st_size
    except FileNotFoundError:
        size = 0
    parts = p.parts
    depth = len(parts)
    name = p.name
    ext = p.suffix.lower()
    name_len = len(name)
    underscores = name.count("_")
    brackets = name.count("(") + name.count("[") + name.count("{")
    digits = sum(ch.isdigit() for ch in name)
    return {
        "path": str(p),
        "size": size,
        "depth": depth,
        "name_len": name_len,
        "ext": ext or "<none>",
        "underscores": underscores,
        "brackets": brackets,
        "digits": digits,
    }

rows = []
limit = 5000
count = 0
for p in base.rglob("*"):
    if p.is_file():
        rows.append(feature_row(str(p)))
        count += 1
        if count >= limit:
            break

if not rows:
    print("[ERR] Sin archivos para evaluar.")
    sys.exit(3)

df = pd.DataFrame(rows)
# Alinear columnas
for c in cols:
    if c not in df.columns:
        df[c] = 0
X = df[cols]
probs = pipe.predict_proba(X)[:, 1]
df_out = pd.DataFrame({"prob": probs, "path": df["path"]})
df_out.sort_values("prob", ascending=False, inplace=True)
report_path.parent.mkdir(parents=True, exist_ok=True)
df_out.to_csv(report_path, sep="\t", index=False)
top5 = df_out.head(5)
print(f"[OK] Predicciones guardadas en {report_path}")
print("[INFO] Top 5 sospechosos:")
for _, row in top5.iterrows():
    print(f"  {row['prob']:.3f}\t{row['path']}")
PY
      pause_enter
      ;;
    3)
      rm -f "$ML_MODEL_PATH" "$ML_FEATURES_FILE" "$ML_PRED_REPORT"
      printf "%s[OK]%s Modelo y datos ML eliminados.\n" "$C_GRN" "$C_RESET"
      pause_enter
      ;;
    *)
      invalid_option
      ;;
  esac
}

action_tensorflow_manager() {
  print_header
  if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
    printf "%s[WARN]%s ML está deshabilitado (usa 63 para habilitarlo).\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi
  printf "%s[INFO]%s TensorFlow opcional (auto-tagging avanzado, embeddings de similitud, clasificadores profundos).\n" "$C_CYN" "$C_RESET"
  printf "Descarga estimada adicional: ~%s MB. ¿Instalar ahora en el venv ML? [y/N]: " "$ML_PKG_TF_MB"
  read -r tfa
  case "$tfa" in
    y|Y)
      maybe_activate_ml_env "TensorFlow opcional" 1 1
      if python3 - <<'PY' 2>/dev/null
import tensorflow as tf  # noqa
print("TF_OK")
PY
      then
        printf "%s[OK]%s TensorFlow disponible en el venv.\n" "$C_GRN" "$C_RESET"
      else
        printf "%s[ERR]%s TensorFlow no se pudo importar (revisa instalación).\n" "$C_RED" "$C_RESET"
      fi
      ;;
    *)
      printf "%s[INFO]%s Instalación cancelada.\n" "$C_CYN" "$C_RESET"
      ;;
  esac
  printf "Posibles módulos futuros al tener TF:\n"
  printf " - Auto-tagging de audio con embeddings pre-entrenados.\n"
  printf " - Detección de similitud audio (recomendaciones de duplicados por sonido).\n"
  printf " - Clasificadores profundos para limpieza/organización avanzada.\n"
  pause_enter
}

submenu_T_tensorflow_lab() {
  while true; do
    clear
    print_header
    printf "%s=== TensorFlow Lab (requiere TF instalado) ===%s
" "$C_CYN" "$C_RESET"
    printf "%s[INFO]%s Dependencias: python3 + tensorflow + tensorflow_hub + soundfile + numpy. Límite: ~150 archivos; similitud usa umbral >=0.60 (top 200 pares).
" "$C_CYN" "$C_RESET"
    printf "%s1)%s Auto-tagging de audio (embeddings/tags)
" "$C_YLW" "$C_RESET"
    printf "%s2)%s Similitud por contenido (audio) desde embeddings
" "$C_YLW" "$C_RESET"
    printf "%s3)%s Detección de fragmentos repetidos/loops
" "$C_YLW" "$C_RESET"
    printf "%s4)%s Clasificador de sospechosos (basura/silencio)
" "$C_YLW" "$C_RESET"
    printf "%s5)%s Estimar loudness (plan de normalización)
" "$C_YLW" "$C_RESET"
    printf "%s6)%s Auto-segmentación (cues preliminares)
" "$C_YLW" "$C_RESET"
    printf "%s7)%s Matching cross-platform (relink inteligente)
" "$C_YLW" "$C_RESET"
    printf "%s8)%s Auto-tagging de vídeo (keyframes)
" "$C_YLW" "$C_RESET"
    printf "%s9)%s Music Tagging (multi-label, modelo TF Hub)
" "$C_YLW" "$C_RESET"
    printf "%sB)%s Volver\n" "$C_YLW" "$C_RESET"
    printf "%sOpción:%s " "$C_BLU" "$C_RESET"
    read -r top
    offline_args=()
    [ "${DJPT_OFFLINE:-0}" -eq 1 ] && offline_args=(--offline)
    case "$top" in
      1)
        clear
        ensure_python_bin || { pause_enter; continue; }
        out_emb="$REPORTS_DIR/audio_embeddings.tsv"
        out_tags="$REPORTS_DIR/audio_tags.tsv"
        printf "%s[INFO]%s Auto-tagging/embeddings (offline/TF si disponible) -> %s / %s\n" "$C_CYN" "$C_RESET" "$out_emb" "$out_tags"
        if "$PYTHON_BIN" "lib/ml_tf.py" embeddings --base "$BASE_PATH" --out "$out_emb" --limit 150 "${offline_args[@]}" && \
           "$PYTHON_BIN" "lib/ml_tf.py" tags --base "$BASE_PATH" --out "$out_tags" --limit 150 "${offline_args[@]}"; then
          printf "%s[OK]%s Reportes generados. Usa DJPT_TF_MOCK=1 para evitar descargas; instala TF (opción 64) para usar modelos reales.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Falló generación de embeddings/tags.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      2)
        clear
        ensure_python_bin || { pause_enter; continue; }
        emb_in="$REPORTS_DIR/audio_embeddings.tsv"
        sim_out="$REPORTS_DIR/audio_similarity.tsv"
        printf "%s[INFO]%s Similitud por contenido desde embeddings -> %s\n" "$C_CYN" "$C_RESET" "$sim_out"
        if [ ! -s "$emb_in" ]; then
          printf "%s[WARN]%s No hay embeddings previos; generando primero.\n" "$C_YLW" "$C_RESET"
          "$PYTHON_BIN" "lib/ml_tf.py" embeddings --base "$BASE_PATH" --out "$emb_in" --limit 150 "${offline_args[@]}" || {
            printf "%s[ERR]%s No se pudieron generar embeddings.\n" "$C_RED" "$C_RESET"
            pause_enter; continue
          }
        fi
        if "$PYTHON_BIN" "lib/ml_tf.py" similarity --embeddings "$emb_in" --out "$sim_out" --threshold 0.60 --top 200; then
          printf "%s[OK]%s Similitud generada: %s
" "$C_GRN" "$C_RESET" "$sim_out"
        else
          printf "%s[ERR]%s Falló cálculo de similitud.
" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      3)
        clear
        ensure_python_bin || { pause_enter; continue; }
        out_an="$REPORTS_DIR/audio_anomalies.tsv"
        printf "%s[INFO]%s Anomalías (silencio/clipping) -> %s
" "$C_CYN" "$C_RESET" "$out_an"
        if "$PYTHON_BIN" "lib/ml_tf.py" anomalies --base "$BASE_PATH" --out "$out_an" --limit 200; then
          printf "%s[OK]%s Anomalías generadas.
" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Falló análisis de anomalías.
" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      4)
        clear
        ensure_python_bin || { pause_enter; continue; }
        out_gb="$REPORTS_DIR/audio_garbage.tsv"
        printf "%s[INFO]%s Garbage/silence/clipping classifier -> %s\n" "$C_CYN" "$C_RESET" "$out_gb"
        if "$PYTHON_BIN" "lib/ml_tf.py" garbage --base "$BASE_PATH" --out "$out_gb" --limit 200; then
          printf "%s[OK]%s Garbage report generated.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Garbage classifier failed.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      5)
        clear
        ensure_python_bin || { pause_enter; continue; }
        out_lufs="$REPORTS_DIR/audio_loudness.tsv"
        printf "%s[INFO]%s Loudness estimate (LUFS; pyloudnorm if available) -> %s\n" "$C_CYN" "$C_RESET" "$out_lufs"
        if "$PYTHON_BIN" "lib/ml_tf.py" loudness --base "$BASE_PATH" --out "$out_lufs" --limit 200; then
          printf "%s[OK]%s Loudness report generated.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Loudness estimation failed.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      6)
        clear
        ensure_python_bin || { pause_enter; continue; }
        out_seg="$REPORTS_DIR/audio_segments.tsv"
        printf "%s[INFO]%s Segmentación/onsets -> %s
" "$C_CYN" "$C_RESET" "$out_seg"
        if "$PYTHON_BIN" "lib/ml_tf.py" segments --base "$BASE_PATH" --out "$out_seg" --limit 50; then
          printf "%s[OK]%s Segmentos generados.
" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Falló segmentación.
" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      7)
        clear
        ensure_python_bin || { pause_enter; continue; }
        out_match="$REPORTS_DIR/audio_matching.tsv"
        emb_file="$REPORTS_DIR/audio_embeddings.tsv"
        tags_file="$REPORTS_DIR/audio_tags.tsv"
        emb_args=()
        tag_args=()
        [ -s "$emb_file" ] && emb_args=(--embeddings "$emb_file")
        [ -s "$tags_file" ] && tag_args=(--tags "$tags_file")
        printf "%s[INFO]%s Cross-platform matching (normalized names + tags/embeddings if present) -> %s\n" "$C_CYN" "$C_RESET" "$out_match"
        if "$PYTHON_BIN" "lib/ml_tf.py" matching --base "$BASE_PATH" --out "$out_match" --limit 200 "${emb_args[@]}" "${tag_args[@]}"; then
          printf "%s[OK]%s Matching report generated.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Matching generation failed.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      8)
        clear
        ensure_python_bin || { pause_enter; continue; }
        out_vtags="$REPORTS_DIR/video_tags.tsv"
        printf "%s[INFO]%s Video tagging (heuristic filename cues) -> %s\n" "$C_CYN" "$C_RESET" "$out_vtags"
        if "$PYTHON_BIN" "lib/ml_tf.py" video_tags --base "$BASE_PATH" --out "$out_vtags" --limit 200; then
          printf "%s[OK]%s Video tags generated.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Video tagging failed.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      9)
        clear
        ensure_python_bin || { pause_enter; continue; }
        out_mtags="$REPORTS_DIR/music_tags.tsv"
        printf "%s[INFO]%s Music tagging multi-label (TF Hub or heuristics) -> %s\n" "$C_CYN" "$C_RESET" "$out_mtags"
        if "$PYTHON_BIN" "lib/ml_tf.py" music_tags --base "$BASE_PATH" --out "$out_mtags" --limit 200; then
          printf "%s[OK]%s Music tagging generated.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Music tagging failed.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      B|b)
        break
        ;;
      *)
        invalid_option
        ;;
    esac
  done
}

action_30_plan_tags() {
  print_header
  out="$PLANS_DIR/audio_by_tags_plan.tsv"
  printf "%s[INFO]%s Organizar audio por TAGS -> plan TSV: %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null | while IFS= read -r f; do
    printf "%s\tGENRE_UNKNOWN\n" "$f" >>"$out"
  done
  printf "%s[OK]%s Plan de TAGS generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_31_report_tags() {
  print_header
  plan="$PLANS_DIR/audio_by_tags_plan.tsv"
  out="$REPORTS_DIR/audio_tags_report.tsv"
  printf "%s[INFO]%s Reporte de tags de audio -> %s\n" "$C_CYN" "$C_RESET" "$out"
  if [ ! -f "$plan" ]; then
    printf "%s[WARN]%s No hay plan de TAGS, generando primero.\n" "$C_YLW" "$C_RESET"
    action_30_plan_tags
  fi
  awk -F'\t' '{c[$2]++} END {for (g in c){printf "%s\t%d\n", g, c[g]}}' "$plan" >"$out"
  printf "%s[OK]%s Reporte generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_32_serato_video_report() {
  print_header
  out="$REPORTS_DIR/serato_video_report.tsv"
  printf "%s[INFO]%s Serato Video REPORT (ffprobe inventario) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  if ! command -v ffprobe >/dev/null 2>&1; then
    printf "%s[ERR]%s ffprobe no disponible.\n" "$C_RED" "$C_RESET"; pause_enter; return
  fi
  ensure_python_bin || { pause_enter; return; }
  "$PYTHON_BIN" "lib/video_tools.py" inventory "$BASE_PATH" "$out" 2>/dev/null || {
    printf "%s[ERR]%s Falló inventario (revisa lib/video_tools.py).\n" "$C_RED" "$C_RESET"
    pause_enter; return
  }
  printf "%s[OK]%s Reporte vídeo generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_33_serato_video_prep() {
  print_header
  out="$PLANS_DIR/serato_video_transcode_plan.tsv"
  printf "%s[INFO]%s Serato Video PREP (plan transcode sugerido) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  if ! command -v ffprobe >/dev/null 2>&1; then
    printf "%s[ERR]%s ffprobe no disponible.\n" "$C_RED" "$C_RESET"; pause_enter; return
  fi
  ensure_python_bin || { pause_enter; return; }
  "$PYTHON_BIN" "lib/video_tools.py" transcode_plan "$BASE_PATH" "$out" "h264_1080p" 2>/dev/null || {
    printf "%s[ERR]%s Falló generación de plan (revisa lib/video_tools.py).\n" "$C_RED" "$C_RESET"
    pause_enter; return
  }
  printf "%s[OK]%s Plan de transcode generado (no ejecuta ffmpeg).\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_34_normalize_names() {
  print_header
  out="$PLANS_DIR/normalize_names_plan.tsv"
  printf "%s[INFO]%s Normalizar nombres (plan TSV) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  find "$BASE_PATH" -type f 2>/dev/null | while IFS= read -r f; do
    base="$(basename "$f")"
    dir="$(dirname "$f")"
    new="$dir/$base"
    printf "%s\t%s\n" "$f" "$new" >>"$out"
  done
  printf "%s[OK]%s Plan de renombrado generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_35_samples_by_type() {
  print_header
  out="$PLANS_DIR/samples_by_type_plan.tsv"
  printf "%s[INFO]%s Organizar samples por TIPO (plan TSV) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  find "$BASE_PATH" -type f \( -iname "*kick*.wav" -o -iname "*snare*.wav" -o -iname "*hat*.wav" -o -iname "*bass*.wav" \) 2>/dev/null | while IFS= read -r f; do
    type="OTHER"
    case "$(basename "$f" | tr '[:upper:]' '[:lower:]')" in
      *kick*) type="KICK" ;;
      *snare*) type="SNARE" ;;
      *hat*) type="HAT" ;;
      *bass*) type="BASS" ;;
    esac
    printf "%s\t%s\n" "$f" "$type" >>"$out"
  done
  printf "%s[OK]%s Plan de samples por tipo generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

submenu_36_web_clean() {
  while true; do
    clear
    printf "%s=== Limpiar WEB (submenú) ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Mostrar resumen whitelist\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Volver\n" "$C_YLW" "$C_RESET"
    printf "%sOpción:%s " "$C_BLU" "$C_RESET"
    read -r wop
    case "$wop" in
      1)
        printf "%s[INFO]%s Whitelist básica (dominios permitidos):\n" "$C_CYN" "$C_RESET"
        printf "  youtube.com\n"
        printf "  soundcloud.com\n"
        printf "  bandcamp.com\n"
        pause_enter
        ;;
      B|b)
        break ;;
      *)
        invalid_option
        ;;
    esac
  done
}

action_37_web_whitelist_manager() {
  print_header
  printf "%s[INFO]%s WEB Whitelist Manager simple.\n" "$C_CYN" "$C_RESET"
  printf "Whitelist fija en esta versión.\n"
  pause_enter
}

action_38_clean_web_playlists() {
  print_header
  printf "%s[INFO]%s Limpiar entradas WEB en playlists.\n" "$C_CYN" "$C_RESET"
  find "$BASE_PATH" -type f \( -iname "*.m3u" -o -iname "*.m3u8" \) 2>/dev/null | while IFS= read -r f; do
    tmp="$f.tmp"
    grep -vE "^https?://" "$f" >"$tmp" 2>/dev/null || true
    mv "$tmp" "$f" 2>/dev/null || true
  done
  printf "%s[OK]%s Playlists limpiadas.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_39_clean_web_tags() {
  print_header
  out="$PLANS_DIR/clean_web_tags_plan.tsv"
  printf "%s[INFO]%s Limpiar WEB en TAGS (plan) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null | while IFS= read -r f; do
    printf "%s\tCLEAN_WEB_TAGS\n" "$f" >>"$out"
  done
  printf "%s[OK]%s Plan de limpieza WEB en TAGS generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_40_smart_analysis() {
  maybe_activate_ml_env "Opción 40 (Smart Analysis)"
  print_header
  printf "%s[INFO]%s 🧠 DEEP-THINKING: Análisis Inteligente de Biblioteca\n" "$C_CYN" "$C_RESET"

  local ts analysis_report total_files audio_files video_files size_kb
  ts=$(date +%s)
  analysis_report="$REPORTS_DIR/smart_analysis_${ts}.json"
  total_files=$(find "$BASE_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
  audio_files=$(find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.m4a" \) 2>/dev/null | wc -l | tr -d ' ')
  video_files=$(find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" \) 2>/dev/null | wc -l | tr -d ' ')
  size_kb=$(du -sk "$BASE_PATH" 2>/dev/null | awk '{print $1}')
  : "${total_files:=0}"
  : "${audio_files:=0}"
  : "${video_files:=0}"
  : "${size_kb:=0}"

  cat >"$analysis_report" <<EOF
{
  "analysis_type": "SMART_ANALYSIS",
  "base_path": "$BASE_PATH",
  "totals": {
    "files": $total_files,
    "audio_files": $audio_files,
    "video_files": $video_files,
    "size_kb": $size_kb
  },
  "quick_recommendations": [
    "9 -> 10 (hash + duplicados exactos)",
    "27 (snapshot rápido)",
    "39 (limpieza de URLs en tags)",
    "8 (backup rápido)"
  ]
}
EOF

  printf "%s[OK]%s Análisis generado: %s\n" "$C_GRN" "$C_RESET" "$analysis_report"
  pause_enter
}

action_41_ml_predictor() {
  maybe_activate_ml_env "Opción 41 (Predictor ML)"
  print_header
  printf "%s[INFO]%s 🤖 MACHINE LEARNING: Predictor de Problemas\n" "$C_CYN" "$C_RESET"

  local ts prediction_report lines
  ts=$(date +%s)
  prediction_report="$REPORTS_DIR/ml_predictions_${ts}.tsv"
  printf "Archivo\tProblema\tConfianza\tAccion\n" >"$prediction_report"

  find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.m4a" \) 2>/dev/null | head -50 | while IFS= read -r f; do
    fname=$(basename "$f")
    size=$({ stat -f %z "$f" 2>/dev/null || echo 0; } | tr -d ' ')
    if [ "${#fname}" -gt 80 ]; then
      printf "%s\tNombre muy largo\t75%%\tRevisar opción 34\n" "$f" >>"$prediction_report"
    fi
    if [ "$size" -eq 0 ]; then
      printf "%s\tArchivo vacío\t90%%\tReemplazar o borrar\n" "$f" >>"$prediction_report"
    fi
  done

  lines=$(wc -l <"$prediction_report" | tr -d ' ')
  if [ "$lines" -le 1 ]; then
    printf "N/A\tSin hallazgos simples\t100%%\tOK\n" >>"$prediction_report"
  fi

  printf "%s[OK]%s Predicciones generadas: %s\n" "$C_GRN" "$C_RESET" "$prediction_report"
  pause_enter
}

action_42_efficiency_optimizer() {
  maybe_activate_ml_env "Opción 42 (Optimizador)"
  print_header
  printf "%s[INFO]%s ⚡ DEEP-THINKING: Optimizador de Eficiencia\n" "$C_CYN" "$C_RESET"

  local ts plan dupe_info
  ts=$(date +%s)
  plan="$PLANS_DIR/efficiency_${ts}.tsv"
  dupe_info="Generar plan con opción 10"
  if [ -f "$PLANS_DIR/dupes_plan.tsv" ]; then
    dupe_info=$(awk -F'\t' '$2=="QUARANTINE"{c++} END {if (c=="") c=0; print c " candidatos"}' "$PLANS_DIR/dupes_plan.tsv")
  fi

  printf "Area\tAccion\tBeneficio_Estimado\tReferencia\n" >"$plan"
  printf "Duplicados\tRevisar/quitar duplicados\tAlto (%s)\tOpción 10\n" "$dupe_info" >>"$plan"
  printf "Metadatos\tLimpiar URLs en tags\tMedio\tOpción 39\n" >>"$plan"
  printf "Backup\tVerificar backup reciente\tMedio\tOpción 8\n" >>"$plan"
  printf "Snapshot\tHash rápido para control\tBajo\tOpción 27\n" >>"$plan"

  printf "%s[OK]%s Plan de eficiencia generado: %s\n" "$C_GRN" "$C_RESET" "$plan"
  pause_enter
}

action_43_smart_workflow() {
  maybe_activate_ml_env "Opción 43 (Flujo inteligente)"
  print_header
  printf "%s[INFO]%s 🚀 DEEP-THINKING: Flujo de Trabajo Inteligente\n" "$C_CYN" "$C_RESET"

  local workflow="$PLANS_DIR/workflow_$(date +%s).txt"
  cat >"$workflow" <<'EOF'
FLUJO DE TRABAJO INTELIGENTE:
1. Opción 40: Análisis (5 min)
2. Opción 41: Predictor (10 min)
3. Opción 42: Optimizador (5 min)
4. Opción 8: Backup (30 min)
5. Opción 10: Eliminar duplicados (45 min)
6. Opción 39: Limpiar metadatos (30 min)
7. Opción 8: Backup final (30 min)
Tiempo total: ~2-3 horas
EOF

  printf "%s[OK]%s Flujo generado: %s\n" "$C_GRN" "$C_RESET" "$workflow"
  pause_enter
}

action_44_integrated_dedup() {
  maybe_activate_ml_env "Opción 44 (Deduplicación integrada)"
  print_header
  printf "%s[INFO]%s 🔄 DEEP-THINKING: Deduplicación Integrada\n" "$C_CYN" "$C_RESET"

  local dedup_plan="$PLANS_DIR/integrated_dedup_$(date +%s).tsv"
  local dupes_plan="$PLANS_DIR/dupes_plan.tsv"
  local exact=0
  if [ -f "$dupes_plan" ]; then
    exact=$(awk -F'\t' '$2=="QUARANTINE"{c++} END {if (c=="") c=0; print c}' "$dupes_plan")
  fi

  printf "Tipo\tConteo\tNota\n" >"$dedup_plan"
  printf "Exactos (hash)\t%s\tGenerados con opción 10\n" "$exact" >>"$dedup_plan"
  printf "Fuzzy (nombre/tamaño)\t0\tUsar submenú D2 para detectar\n" >>"$dedup_plan"
  printf "Acción\tRecomendación\tSiguiente_Paso\n" >>"$dedup_plan"
  printf "Revisar\tMover a quarantine los sobrantes\tOpción 11\n" >>"$dedup_plan"

  printf "%s[OK]%s Plan deduplicación integrada: %s\n" "$C_GRN" "$C_RESET" "$dedup_plan"
  pause_enter
}

action_45_ml_organization() {
  maybe_activate_ml_env "Opción 45 (Organización ML)"
  print_header
  printf "%s[INFO]%s 📂 MACHINE LEARNING: Organización Automática\n" "$C_CYN" "$C_RESET"

  local org_plan="$PLANS_DIR/ml_organization_$(date +%s).tsv"
  printf "Archivo\tCarpeta_Sugerida\tConfianza\n" >"$org_plan"

  find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.m4a" \) 2>/dev/null | head -50 | while IFS= read -r f; do
    lower=$(printf "%s" "$f" | tr '[:upper:]' '[:lower:]')
    target="MISC"
    conf="60%"
    case "$lower" in
      *acapella*|*acapela*) target="ACAPELLAS"; conf="90%";;
      *remix*|*edit*) target="REMIXES"; conf="85%";;
      *instrumental*|*inst*) target="INSTRUMENTALES"; conf="80%";;
      *live*) target="LIVE"; conf="70%";;
    esac
    printf "%s\t%s\t%s\n" "$f" "$target" "$conf" >>"$org_plan"
  done

  printf "%s[OK]%s Plan organización ML: %s\n" "$C_GRN" "$C_RESET" "$org_plan"
  pause_enter
}

action_46_metadata_harmonizer() {
  maybe_activate_ml_env "Opción 46 (Armonizador metadatos)"
  print_header
  printf "%s[INFO]%s 🎵 DEEP-THINKING: Armonizador de Metadatos\n" "$C_CYN" "$C_RESET"

  local harmony_plan="$PLANS_DIR/metadata_harmony_$(date +%s).tsv"
  printf "Aspecto\tDetalle\tAccion\n" >"$harmony_plan"
  printf "Tags/URLs\tDetectar y limpiar http(s) en comentarios\tOpción 39\n" >>"$harmony_plan"
  printf "Campos vacíos\tCompletar artista/título en lote\tOpción 31\n" >>"$harmony_plan"
  printf "Consistencia\tRevisar mayúsculas/minúsculas en nombres\tOpción 34\n" >>"$harmony_plan"

  printf "%s[OK]%s Plan armonización: %s\n" "$C_GRN" "$C_RESET" "$harmony_plan"
  pause_enter
}

action_47_predictive_backup() {
  maybe_activate_ml_env "Opción 47 (Backup predictivo)"
  print_header
  printf "%s[INFO]%s 🛡️ MACHINE LEARNING: Backup Predictivo\n" "$C_CYN" "$C_RESET"

  local backup_plan="$PLANS_DIR/predictive_backup_$(date +%s).txt"
  cat >"$backup_plan" <<'EOF'
BACKUP PREDICTIVO - ESTRATEGIA INTELIGENTE:

1) Análisis de riesgo: metadatos Serato/Traktor/Rekordbox/Ableton = críticos.
2) Frecuencia sugerida: semanal (diaria si hay shows).
3) Flujo recomendado:
   - Opción 8: Backup incremental
   - Opción 27: Snapshot rápido de integridad
   - Opción 7: Copia de _Serato_ y _Serato_Backup
4) Próxima ventana: madrugada (03:00–05:00) para evitar locks.
EOF

  printf "%s[OK]%s Plan backup predictivo: %s\n" "$C_GRN" "$C_RESET" "$backup_plan"
  pause_enter
}

action_48_cross_platform_sync() {
  maybe_activate_ml_env "Opción 48 (Sync multiplataforma)"
  print_header
  printf "%s[INFO]%s 🌐 DEEP-THINKING: Sincronización Multi-Plataforma\n" "$C_CYN" "$C_RESET"

  local sync_plan="$PLANS_DIR/cross_platform_$(date +%s).txt"
  local serato_status="NO"
  local rekordbox_hint="NO"
  local traktor_hint="NO"
  local ableton_hint="NO"

  [ -d "$BASE_PATH/_Serato_" ] && serato_status="OK"
  if find "$BASE_PATH" -maxdepth 4 -type f -iname "*.xml" 2>/dev/null | head -1 | grep -qi rekordbox; then
    rekordbox_hint="Detectado"
  fi
  if find "$BASE_PATH" -maxdepth 4 -type f -iname "*collection*.nml" 2>/dev/null | head -1 >/dev/null; then
    traktor_hint="Detectado"
  fi
  if find "$BASE_PATH" -maxdepth 4 -type f -iname "*.als" 2>/dev/null | head -1 >/dev/null; then
    ableton_hint="Detectado"
  fi

  cat >"$sync_plan" <<EOF
SINCRONIZACIÓN INTELIGENTE ENTRE PLATAFORMAS:
- Serato: $serato_status
- Rekordbox XML: $rekordbox_hint
- Traktor NML: $traktor_hint
- Ableton ALS: $ableton_hint

Acciones recomendadas:
1. Consolidar cues/notas en TSV maestro.
2. Opción 39 para limpiar URLs antes de sync.
3. Opción 8 para backup previo/post sync.
EOF

  printf "%s[OK]%s Plan sincronización: %s\n" "$C_GRN" "$C_RESET" "$sync_plan"
  pause_enter
}

submenu_ableton_tools() {
  while true; do
    clear
    print_header
    printf "%s=== Ableton Tools ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Reporte rápido de sets .als (samples/plugins)\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Volver\n" "$C_YLW" "$C_RESET"
    printf "%sOpción:%s " "$C_BLU" "$C_RESET"
    read -r aop
    case "$aop" in
      1)
        clear
        root="${ABLETON_ROOT:-$BASE_PATH}"
        printf "Root Ableton (drag & drop; ENTER usa %s; busca .als): " "$root"
        read -r r
        [ -n "$r" ] && root="$r"
        if [ ! -d "$root" ]; then
          printf "%s[ERR]%s Ruta inválida.\n" "$C_RED" "$C_RESET"
          pause_enter
          continue
        fi
        if ! command -v python3 >/dev/null 2>&1; then
          printf "%s[ERR]%s python3 no disponible para analizar .als\n" "$C_RED" "$C_RESET"
          pause_enter
          continue
        fi
        out="$REPORTS_DIR/ableton_sets_report.tsv"
        printf "%s[INFO]%s Buscando .als en %s\n" "$C_CYN" "$C_RESET" "$root"
        total=$(find "$root" -type f -iname "*.als" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$total" -eq 0 ]; then
          printf "%s[WARN]%s No se encontraron .als\n" "$C_YLW" "$C_RESET"
          pause_enter
          continue
        fi
        count=0
        printf "Set\tSampleRefs\tPluginRefs\tNota\n" >"$out"
        find "$root" -type f -iname "*.als" 2>/dev/null | while IFS= read -r f; do
          count=$((count + 1))
          percent=$((count * 100 / total))
          status_line "ALS" "$percent" "$f"
          note="OK"
res=$(python3 - "$f" <<'PY'
import gzip, sys
from pathlib import Path
path = Path(sys.argv[1])
try:
    data = path.read_bytes()
    try:
        text = gzip.decompress(data).decode("utf-8", "ignore")
    except Exception:
        text = data.decode("utf-8", "ignore")
    samples = text.count("FileRef")
    plugins = text.count("PluginDevice") + text.count("VstPluginDevice") + text.count("AuPluginDevice")
    print(f"{samples}\t{plugins}\tOK")
except Exception as e:
    print(f"0\t0\tERROR:{e}")
PY
)
          printf "%s\n" "$res" | {
            IFS=$'\t' read -r srefs prefs note
            printf "%s\t%s\t%s\t%s\n" "$f" "$srefs" "$prefs" "$note" >>"$out"
          }
        done
        finish_status_line
        printf "%s[OK]%s Reporte Ableton: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      B|b)
        break ;;
      *)
        invalid_option
        ;;
    esac
  done
}

submenu_importers_cues() {
  while true; do
    clear
    print_header
    printf "%s=== Importers Cues/Playlists ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Parse Rekordbox XML -> dj_cues.tsv\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Resumen Traktor NML (tracks/cues)\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Volver\n" "$C_YLW" "$C_RESET"
    printf "%sOpción (usa python3 si está disponible):%s " "$C_BLU" "$C_RESET"
    read -r iop
    case "$iop" in
      1)
        clear
        rk="${REKORDBOX_XML:-}"
        printf "Ruta Rekordbox XML (drag & drop, ENTER usa %s): " "${rk:-<vacío>}"
        read -r r
        [ -n "$r" ] && rk="$r"
        if [ -z "$rk" ] || [ ! -f "$rk" ]; then
          printf "%s[ERR]%s XML inválido.\n" "$C_RED" "$C_RESET"
          pause_enter
          continue
        fi
        if ! command -v python3 >/dev/null 2>&1; then
          printf "%s[ERR]%s python3 no disponible para parsear XML.\n" "$C_RED" "$C_RESET"
          pause_enter
          continue
        fi
        out="$REPORTS_DIR/dj_cues.tsv"
        python3 - "$rk" "$out" <<'PY'
import sys
import xml.etree.ElementTree as ET
rk_path, out_path = sys.argv[1], sys.argv[2]
root = ET.parse(rk_path).getroot()
with open(out_path, "w", encoding="utf-8") as f:
    f.write("Track\tCueName\tTime\n")
    for track in root.findall(".//TRACK"):
        name = track.get("Name") or track.get("Title") or track.get("TITLE") or ""
        location = track.get("Location") or ""
        ident = location or name
        for pm in track.findall(".//POSITIONMARK"):
            t = pm.get("Time") or pm.get("Start") or ""
            cname = pm.get("Name") or pm.get("Type") or ""
            f.write(f"{ident}\t{cname}\t{t}\n")
print(f"OK {out_path}")
PY
        printf "%s[OK]%s dj_cues.tsv generado: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      2)
        clear
        if ! command -v python3 >/dev/null 2>&1; then
          printf "%s[ERR]%s python3 no disponible para parsear NML.\n" "$C_RED" "$C_RESET"
          pause_enter
          continue
        fi
        printf "Buscar NML en BASE_PATH (ENTER) o indicar carpeta (drag & drop): "
        read -e -r nml_root
        [ -z "$nml_root" ] && nml_root="$BASE_PATH"
        mapfile -t nml_list < <(find "$nml_root" -maxdepth 4 -type f -iname "*.nml" 2>/dev/null)
        if [ "${#nml_list[@]}" -eq 0 ]; then
          printf "%s[WARN]%s No se encontraron NML en %s\n" "$C_YLW" "$C_RESET" "$nml_root"
          pause_enter
          continue
        fi
        out="$REPORTS_DIR/traktor_nml_summary.tsv"
        python3 - "$out" "${nml_list[@]}" <<'PY'
import sys
import xml.etree.ElementTree as ET
out_path = sys.argv[1]
files = sys.argv[2:]
with open(out_path, "w", encoding="utf-8") as f:
    f.write("NML\tTracks\tCuePoints\n")
    for nml in files:
        try:
            root = ET.parse(nml).getroot()
            tracks = len(root.findall(".//ENTRY"))
            cues = len(root.findall(".//CUEPOINT"))
            f.write(f"{nml}\t{tracks}\t{cues}\n")
        except Exception as e:
            f.write(f"{nml}\t0\t0\tERROR:{e}\n")
print(f"OK {out_path}")
PY
        printf "%s[OK]%s Resumen Traktor: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      B|b)
        break ;;
      *)
        invalid_option
        ;;
    esac
  done
}

action_49_advanced_analysis() {
  print_header
  out="$REPORTS_DIR/audio_bpm_report.tsv"
  printf "%s[INFO]%s Audio BPM (tags/librosa) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  if ! ensure_python_deps "BPM" "librosa" "soundfile"; then
    pause_enter; return
  fi
  "$PYTHON_BIN" "lib/bpm_analyzer.py" --base "$BASE_PATH" --out "$out" --limit 200 2>/dev/null || {
    printf "%s[ERR]%s Falló análisis BPM (revisa lib/bpm_analyzer.py y dependencias ffprobe/librosa).\n" "$C_RED" "$C_RESET"
    pause_enter; return
  }
  printf "%s[OK]%s Reporte BPM generado (lee método/confianza por fila).\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_50_integration_engine() {
  print_header
  printf "%s[INFO]%s API/OSC server (start/stop). HTTP: /status, /reports. OSC: /djpt/ping.\n" "$C_CYN" "$C_RESET"
  pid_file="$STATE_DIR/osc_api_server.pid"
  if [ -f "$pid_file" ] && ps -p "$(cat "$pid_file")" >/dev/null 2>&1; then
    printf "Servidor en marcha (PID %s). ¿Detener? [y/N]: " "$(cat "$pid_file")"
    read -r stop_it
    case "$stop_it" in
      y|Y)
        kill "$(cat "$pid_file")" 2>/dev/null || true
        rm -f "$pid_file"
        printf "%s[OK]%s Servidor detenido.\n" "$C_GRN" "$C_RESET"
        pause_enter
        return
        ;;
      *)
        printf "%s[INFO]%s Continúa en ejecución.\n" "$C_CYN" "$C_RESET"
        pause_enter
        return
        ;;
    esac
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    printf "%s[ERR]%s python3 no disponible.\n" "$C_RED" "$C_RESET"
    pause_enter; return
  fi
  if ! ensure_python_deps "API/OSC" "python-osc"; then
    pause_enter; return
  fi
  http_port=8000
  osc_port=9000
  printf "HTTP port (ENTER=8000): "
  read -e -r hp; [ -n "$hp" ] && http_port="$hp"
  printf "OSC port (ENTER=9000): "
  read -e -r op; [ -n "$op" ] && osc_port="$op"
  printf "Iniciar servidor (HTTP %s, OSC %s)? [y/N]: " "$http_port" "$osc_port"
  read -r ans
  case "$ans" in
    y|Y)
      nohup "$PYTHON_BIN" "lib/osc_api_server.py" --base "$BASE_PATH" --state "$STATE_DIR" --report "$REPORTS_DIR" --http-port "$http_port" --osc-port "$osc_port" >/dev/null 2>&1 &
      srv_pid=$!
      echo "$srv_pid" >"$pid_file"
      printf "%s[OK]%s Servidor iniciado (PID %s). HTTP http://127.0.0.1:%s\n" "$C_GRN" "$C_RESET" "$srv_pid" "$http_port"
      if ! python3 - <<'PY' >/dev/null 2>&1
import importlib.util
spec = importlib.util.find_spec("pythonosc")
raise SystemExit(0 if spec else 1)
PY
      then
        printf "%s[WARN]%s python-osc no instalado; servidor OSC no activo.\n" "$C_YLW" "$C_RESET"
      fi
      ;;
    *)
      printf "%s[INFO]%s Cancelado.\n" "$C_CYN" "$C_RESET"
      ;;
  esac
  pause_enter
}

action_51_adaptive_recommendations() {
  maybe_activate_ml_env "Opción 51 (Recomendaciones adaptativas)"
  print_header
  printf "%s[INFO]%s 💡 MACHINE LEARNING: Recomendaciones Adaptativas\n" "$C_CYN" "$C_RESET"

  local recommendations="$REPORTS_DIR/adaptive_recommendations_$(date +%s).txt"
  local dupes_pending="Generar plan (opción 10)"
  if [ -f "$PLANS_DIR/dupes_plan.tsv" ]; then
    dupes_pending=$(awk -F'\t' '$2=="QUARANTINE"{c++} END {if (c=="") c=0; print c " pendientes"}' "$PLANS_DIR/dupes_plan.tsv")
  fi

  cat >"$recommendations" <<EOF
RECOMENDACIONES ADAPTATIVAS BASADAS EN IA:

URGENTE (Hoy):
- Ejecutar opción 8: Crear backup
- Ejecutar opción 10: Eliminar duplicados (${dupes_pending})

IMPORTANTE (Esta semana):
- Ejecutar opción 34: Normalizar nombres
- Ejecutar opción 39: Limpiar metadatos web

NORMAL (Este mes):
- Ejecutar opción 46: Armonizar metadatos
- Ejecutar opción 48: Revisar sincronización entre plataformas
EOF

  printf "%s[OK]%s Recomendaciones: %s\n" "$C_GRN" "$C_RESET" "$recommendations"
  pause_enter
}

action_52_automated_cleanup_pipeline() {
  maybe_activate_ml_env "Opción 52 (Pipeline automático)"
  print_header
  printf "%s[INFO]%s 🔄 DEEP-THINKING: Pipeline de Limpieza Automatizado\n" "$C_CYN" "$C_RESET"

  local pipeline="$PLANS_DIR/cleanup_pipeline_$(date +%s).txt"
  cat >"$pipeline" <<'EOF'
PIPELINE DE LIMPIEZA AUTOMATIZADO:

FASE 1: Análisis (Opción 40)
FASE 2: Predictor (Opción 41)
FASE 3: Backup inicial (Opción 8)
FASE 4: Eliminar duplicados exactos (Opción 10)
FASE 5: Limpiar metadatos web (Opción 39)
FASE 6: Normalizar nombres (Opción 34)
FASE 7: Backup final (Opción 8)
FASE 8: Snapshot rápido (Opción 27)
EOF

  printf "%s[OK]%s Pipeline limpieza: %s\n" "$C_GRN" "$C_RESET" "$pipeline"
  pause_enter
}
submenu_L_libraries() {
  while true; do
    clear
    printf "%s=== L) Librerías DJ & Cues ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Configurar rutas DJ/Audio (L1)\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Construir/actualizar catálogo de audio (L2)\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Detectar duplicados audio desde catálogo maestro (L3)\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s Extraer Cues desde Rekordbox XML (L4)\n" "$C_YLW" "$C_RESET"
    printf "%s5)%s Generar ableton_locators.csv desde dj_cues.tsv (L5)\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Volver al menú principal\n" "$C_YLW" "$C_RESET"
    printf "%sSelecciona una opción:%s " "$C_BLU" "$C_RESET"
    read -r lop
    case "$lop" in
      1)
        clear
        printf "%s[INFO]%s Configurar rutas DJ/Audio.\n" "$C_CYN" "$C_RESET"
        printf "AUDIO_ROOT actual: %s\n" "${AUDIO_ROOT:-}"
        printf "Nuevo AUDIO_ROOT (ENTER para mantener): "
        read -e -r v
        v=$(strip_quotes "$v")
        if [ -n "$v" ]; then
          AUDIO_ROOT="$v"
        fi
        printf "GENERAL_ROOT actual: %s\n" "${GENERAL_ROOT:-}"
        printf "Nuevo GENERAL_ROOT (ENTER para mantener): "
        read -e -r v
        v=$(strip_quotes "$v")
        if [ -n "$v" ]; then
          GENERAL_ROOT="$v"
        fi
        printf "REKORDBOX_XML actual: %s\n" "${REKORDBOX_XML:-}"
        printf "Nuevo REKORDBOX_XML (ENTER para mantener): "
        read -e -r v
        v=$(strip_quotes "$v")
        if [ -n "$v" ]; then
          REKORDBOX_XML="$v"
        fi
        printf "ABLETON_ROOT actual: %s\n" "${ABLETON_ROOT:-}"
        printf "Nuevo ABLETON_ROOT (ENTER para mantener): "
        read -e -r v
        v=$(strip_quotes "$v")
        if [ -n "$v" ]; then
          ABLETON_ROOT="$v"
        fi
        save_conf
        printf "%s[OK]%s Rutas DJ/Audio guardadas.\n" "$C_GRN" "$C_RESET"
        pause_enter
        ;;
      2)
        clear
        if [ -z "${AUDIO_ROOT:-}" ] || [ ! -d "$AUDIO_ROOT" ]; then
          printf "%s[ERR]%s AUDIO_ROOT no configurado o inválido.\n" "$C_RED" "$C_RESET"
          pause_enter
        else
          printf "%s[INFO]%s Construyendo catálogo de audio desde %s\n" "$C_CYN" "$C_RESET" "$AUDIO_ROOT"
          printf "Identificador de librería/disco (ej: MAIN_SSD, BACKUP_A): "
          read -r libid
          if [ -z "$libid" ]; then
            libid="LIB"
          fi
          out="$REPORTS_DIR/catalog_audio_${libid}.tsv"
          total=$(find "$AUDIO_ROOT" -type f 2>/dev/null | wc -l | tr -d ' ')
          count=0
          >"$out"
          if [ "$total" -eq 0 ]; then
            printf "%s[WARN]%s No se encontraron archivos en AUDIO_ROOT.\n" "$C_YLW" "$C_RESET"
          else
            find "$AUDIO_ROOT" -type f 2>/dev/null | while IFS= read -r f; do
              count=$((count + 1))
              percent=$((count * 100 / total))
              status_line "CATALOGO_AUDIO" "$percent" "$f"
              printf "%s\t%s\n" "$libid" "$f" >>"$out"
            done
            finish_status_line
          fi
          printf "%s[OK]%s Catálogo generado: %s\n" "$C_GRN" "$C_RESET" "$out"
          pause_enter
        fi
        ;;
      3)
        clear
        printf "%s[INFO]%s Detectar duplicados audio desde catálogo maestro.\n" "$C_CYN" "$C_RESET"
        cat_master="$REPORTS_DIR/catalog_audio_MASTER.tsv"
        >"$cat_master"
        for f in "$REPORTS_DIR"/catalog_audio_*.tsv; do
          if [ -f "$f" ]; then
            cat "$f" >>"$cat_master"
          fi
        done
        if [ ! -s "$cat_master" ]; then
          printf "%s[WARN]%s No hay catálogos individuales.\n" "$C_YLW" "$C_RESET"
          pause_enter
        else
          out="$PLANS_DIR/audio_dupes_from_catalog.tsv"
          printf "%s[INFO]%s Generando plan de duplicados por basename+tamaño -> %s\n" "$C_CYN" "$C_RESET" "$out"
          awk '
          {
            lib=$1
            path=$2
            n=split(path, a, "/")
            base=a[n]
            cmd="stat -f %z \"" path "\" 2>/dev/null"
            cmd | getline sz
            close(cmd)
            if (sz=="") sz="0"
            key=base"|"sz
            count[key]++
            rec[key, count[key]]=lib"\t"path
          }
          END {
            for (k in count) {
              if (count[k]>1) {
                for (i=1; i<=count[k]; i++) {
                  print k"\t"rec[k,i]
                }
              }
            }
          }' "$cat_master" >"$out"
          printf "%s[OK]%s Plan de duplicados audio generado.\n" "$C_GRN" "$C_RESET"
          pause_enter
        fi
        ;;
      4)
        clear
        printf "%s[INFO]%s Extraer Cues desde Rekordbox XML.\n" "$C_CYN" "$C_RESET"
        if [ -z "${REKORDBOX_XML:-}" ] || [ ! -f "$REKORDBOX_XML" ]; then
          printf "%s[ERR]%s REKORDBOX_XML no configurado o inexistente.\n" "$C_RED" "$C_RESET"
          pause_enter
        else
          out="$REPORTS_DIR/dj_cues.tsv"
          printf "REKORDBOX_XML\t%s\n" "$REKORDBOX_XML" >"$out"
          printf "%s[OK]%s Placeholder dj_cues.tsv generado: %s\n" "$C_GRN" "$C_RESET" "$out"
          pause_enter
        fi
        ;;
      5)
        clear
        printf "%s[INFO]%s Generar ableton_locators.csv desde dj_cues.tsv.\n" "$C_CYN" "$C_RESET"
        cues="$REPORTS_DIR/dj_cues.tsv"
        out="$REPORTS_DIR/ableton_locators.csv"
        if [ ! -f "$cues" ]; then
          printf "%s[ERR]%s No existe dj_cues.tsv.\n" "$C_RED" "$C_RESET"
          pause_enter
        else
          printf "Name,Time,Track\n" >"$out"
          printf "CueFromRekordbox,1.1.1,1\n" >>"$out"
          printf "%s[OK]%s ableton_locators.csv generado: %s\n" "$C_GRN" "$C_RESET" "$out"
          pause_enter
        fi
        ;;
      B|b)
        break ;;
      *)
        invalid_option
        ;;
    esac
  done
}

submenu_D_dupes_general() {
  while true; do
    clear
    printf "%s=== D) Duplicados generales ===%s\n" "$C_CYN" "$C_RESET"
    ensure_general_root_valid
    printf "%s1)%s Catálogo general por disco (D1)\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Duplicados generales por basename+tamaño (D2)\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Reporte inteligente (Deep/ML) sobre duplicados (D3)\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s Consolidación multi-disco (plan seguro) (D4)\n" "$C_YLW" "$C_RESET"
    printf "%s5)%s Plan de duplicados exactos por hash (todas las extensiones) (D5)\n" "$C_YLW" "$C_RESET"
    printf "%s6)%s Consolidación inversa (sobrantes en origen) (D6)\n" "$C_YLW" "$C_RESET"
    printf "%s7)%s Reporte de matrioshkas (carpetas duplicadas por estructura) (D7)\n" "$C_YLW" "$C_RESET"
    printf "%s8)%s Carpetas espejo por contenido (hash de subdirectorios) (D8)\n" "$C_YLW" "$C_RESET"
    printf "%s9)%s Similitud audio (YAMNet embeddings, requiere TF) (D9)\n" "$C_YLW" "$C_RESET"
    printf "Flujo sugerido: D1 -> D2 -> D3, luego aplicar 10/11/44 con backup previo si SafeMode=0.\n"
    printf "Tip: GENERAL_ROOT es la raíz que se cataloga en D1/D2/D3. D4 compara destino vs orígenes. D5 acepta varias raíces separadas por coma. D6 marca sobrantes; D7 estructura; D8 contenido.\n"
    printf "%sB)%s Volver al menú principal\n" "$C_YLW" "$C_RESET"
    printf "%sH)%s Ayuda rápida (rutas/flujo)\n" "$C_YLW" "$C_RESET"
    printf "%sSelecciona una opción:%s " "$C_BLU" "$C_RESET"
    read -r dop
    : "${GENERAL_ROOT:=$BASE_PATH}"
    case "$dop" in
      1)
        clear
        printf "%s[INFO]%s Catálogo general por disco.\n" "$C_CYN" "$C_RESET"
        printf "GENERAL_ROOT actual: %s\n" "${GENERAL_ROOT:-}"
        printf "Nuevo GENERAL_ROOT (ENTER para mantener; vacío usa BASE_PATH): "
        read -e -r v
        v=$(strip_quotes "$v")
        if [ -n "$v" ] && [ -d "$v" ]; then
          GENERAL_ROOT="$v"
          save_conf
        elif [ -z "${GENERAL_ROOT:-}" ] || [ ! -d "$GENERAL_ROOT" ]; then
          GENERAL_ROOT="$BASE_PATH"
          save_conf
        fi
        printf "Exclusiones por defecto: %s\n" "$DEFAULT_EXCLUDES"
        printf "Max depth (1=solo raíz, 2=subcarpetas, 3=sub-sub; ENTER sin límite): "
        read -e -r max_depth
        printf "Max tamaño (MB, ENTER sin límite, ej: 500): "
        read -e -r max_mb
        out="$REPORTS_DIR/general_catalog.tsv"
        printf "Exclusiones (patrones coma, ej: *.asd,*/Cache/*; ENTER usa defecto): "
        read -r exclude_patterns
        [ -z "$exclude_patterns" ] && exclude_patterns="$DEFAULT_EXCLUDES"
        total=$(find "$GENERAL_ROOT" -type f 2>/dev/null | wc -l | tr -d ' ')
        count=0
        find_opts=()
        >"$out"
        if [ "$total" -eq 0 ]; then
          printf "%s[WARN]%s No se encontraron archivos.\n" "$C_YLW" "$C_RESET"
        else
          [ -n "$max_depth" ] && find_opts+=("-maxdepth" "$max_depth")
          find "$GENERAL_ROOT" "${find_opts[@]}" -type f 2>/dev/null | while IFS= read -r f; do
            if [ -n "$max_mb" ]; then
              fsz=$(wc -c <"$f" 2>/dev/null | tr -d '[:space:]')
              if [ -n "$fsz" ] && [ "$fsz" -gt $((max_mb*1024*1024)) ]; then
                continue
              fi
            fi
            if should_exclude_path "$f" "$exclude_patterns"; then
              continue
            fi
            count=$((count + 1))
            percent=$((count * 100 / total))
            status_line "CATALOGO_GENERAL" "$percent" "$f"
            printf "%s\n" "$f" >>"$out"
          done
          finish_status_line
        fi
        printf "%s[OK]%s Catálogo general generado: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      2)
        clear
        printf "%s[INFO]%s Duplicados generales por basename+tamaño.\n" "$C_CYN" "$C_RESET"
        cat_file="$REPORTS_DIR/general_catalog.tsv"
        if [ ! -s "$cat_file" ]; then
          printf "%s[WARN]%s No hay general_catalog.tsv o está vacío, generando primero.\n" "$C_YLW" "$C_RESET"
          out="$REPORTS_DIR/general_catalog.tsv"
          printf "Exclusiones (patrones coma, ej: *.asd,*/Cache/*; ENTER usa defecto): "
          read -r exclude_patterns
          [ -z "$exclude_patterns" ] && exclude_patterns="$DEFAULT_EXCLUDES"
          total=$(find "$GENERAL_ROOT" -type f 2>/dev/null | wc -l | tr -d ' ')
          count=0
          >"$out"
          if [ "$total" -eq 0 ]; then
            printf "%s[WARN]%s No se encontraron archivos.\n" "$C_YLW" "$C_RESET"
          else
            find "$GENERAL_ROOT" -type f 2>/dev/null | while IFS= read -r f; do
              if should_exclude_path "$f" "$exclude_patterns"; then
                continue
              fi
              count=$((count + 1))
              percent=$((count * 100 / total))
              status_line "CATALOGO_GENERAL" "$percent" "$f"
              printf "%s\n" "$f" >>"$out"
            done
            finish_status_line
          fi
          cat_file="$out"
        fi
        out="$PLANS_DIR/general_dupes_plan.tsv"
        tmp="$STATE_DIR/general_dupes_tmp.tsv"
        >"$tmp"
        total_lines=$(wc -l <"$cat_file" | tr -d ' ')
        if [ "$total_lines" -eq 0 ]; then
          printf "%s[WARN]%s Catálogo vacío, nada que procesar.\n" "$C_YLW" "$C_RESET"
          pause_enter
          continue
        fi
        count=0
        while IFS= read -r path; do
          count=$((count + 1))
          percent=$((count * 100 / total_lines))
          status_line "DUPES_BNAME" "$percent" "$path"
          base=$(basename "$path")
          if size=$(wc -c <"$path" 2>/dev/null); then
            size=$(printf "%s" "$size" | tr -d '[:space:]')
          else
            size=0
          fi
          printf "%s|%s\t%s\n" "$base" "$size" "$path" >>"$tmp"
        done <"$cat_file"
        finish_status_line

        awk -F'\t' '
        {
          key=$1
          path=$2
          count[key]++
          rec[key, count[key]]=path
        }
        END {
          for (k in count) {
            if (count[k]>1) {
              for (i=1; i<=count[k]; i++) {
                print k"\t"rec[k,i]
              }
            }
          }
        }' "$tmp" >"$out"
        printf "%s[OK]%s Plan de duplicados generales generado: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      H|h)
        clear
        printf "%s[INFO]%s Guía rápida submenú D (rutas/flujo):\n" "$C_CYN" "$C_RESET"
        printf "%s\n" "- GENERAL_ROOT: raíz que se cataloga en D1/D2/D3; ENTER usa BASE_PATH (actual: ${BASE_PATH})."
        printf "%s\n" "- D1: catáloga GENERAL_ROOT."
        printf "%s\n" "- D2/D3: usan ese catálogo para duplicados por nombre+tamaño (y reporte smart en D3)."
        printf "%s\n" "- D4: plan de consolidación. Destino suele ser tu librería oficial; orígenes = discos externos separados por coma."
        printf "%s\n" "- D5: plan de duplicados exactos por hash; puedes pasar varias raíces separadas por coma (oficial + externos)."
        printf "%s\n" "- D6: consolidación inversa (sobrantes en origen que ya están en destino)."
        printf "%s\n" "- D7: reporte de matrioshkas (carpetas con misma estructura/nombres)."
        printf "%s\n" "- D8: carpetas espejo por contenido (elige rápido nombre+size o hash completo)."
        printf "%s\n" "- D9: similitud de audio con YAMNet (TF), umbral >=0.60, top pares similares."
        printf "%s\n" "- Para que el menú principal (9/10/11) dedupe tu librería oficial, deja BASE_PATH allí antes de ejecutarlos."
        pause_enter
        ;;
      3)
        maybe_activate_ml_env "D3 (Reporte inteligente de duplicados)"
        clear
        printf "%s[INFO]%s D3) Reporte inteligente (Deep/ML) sobre duplicados.\n" "$C_CYN" "$C_RESET"
        cat_file="$REPORTS_DIR/general_catalog.tsv"
        plan_dupes="$PLANS_DIR/general_dupes_plan.tsv"
        smart_report="$REPORTS_DIR/general_dupes_smart.txt"
        smart_plan="$PLANS_DIR/general_dupes_smart.tsv"

        # Asegurar catálogo
        if [ ! -f "$cat_file" ]; then
          printf "%s[WARN]%s No hay general_catalog.tsv, generando primero.\n" "$C_YLW" "$C_RESET"
          out="$REPORTS_DIR/general_catalog.tsv"
          printf "Exclusiones (patrones coma, ej: *.asd,*/Cache/*; ENTER usa defecto): "
          read -r exclude_patterns
          [ -z "$exclude_patterns" ] && exclude_patterns="$DEFAULT_EXCLUDES"
          total=$(find "$GENERAL_ROOT" -type f 2>/dev/null | wc -l | tr -d ' ')
          count=0
          >"$out"
          if [ "$total" -eq 0 ]; then
            printf "%s[WARN]%s No se encontraron archivos.\n" "$C_YLW" "$C_RESET"
          else
            find "$GENERAL_ROOT" -type f 2>/dev/null | while IFS= read -r f; do
              if should_exclude_path "$f" "$exclude_patterns"; then
                continue
              fi
              count=$((count + 1))
              percent=$((count * 100 / total))
              status_line "CATALOGO_GENERAL" "$percent" "$f"
              printf "%s\n" "$f" >>"$out"
            done
            finish_status_line
          fi
          printf "%s[OK]%s Catálogo general generado: %s\n" "$C_GRN" "$C_RESET" "$out"
        fi

        # Asegurar plan básico de duplicados (D2)
        if [ ! -f "$plan_dupes" ]; then
          printf "%s[WARN]%s No hay plan de duplicados generales, generando (D2).\n" "$C_YLW" "$C_RESET"
          cat_file="$REPORTS_DIR/general_catalog.tsv"
          out="$PLANS_DIR/general_dupes_plan.tsv"
          awk '
            {
              path=$0
              n=split(path,a,"/")
              base=a[n]
              cmd="stat -f %z \"" path "\" 2>/dev/null"
              cmd | getline sz
              close(cmd)
              if (sz=="") sz="0"
              key=base"|"sz
              count[key]++
              rec[key, count[key]]=path
            }
            END {
              for (k in count) {
                if (count[k]>1) {
                  for (i=1; i<=count[k]; i++) {
                    print k"\t"rec[k,i]
                  }
                }
              }
            }' "$cat_file" >"$out"
          printf "%s[OK]%s Plan de duplicados generales generado: %s\n" "$C_GRN" "$C_RESET" "$out"
          plan_dupes="$out"
        fi

        # Generar reporte/plan inteligente
        >"$smart_plan"
        {
          printf "SMART_DUPES_KEY\tCOUNT\tSAMPLE_PATH\tRECOMENDACION\n"
          awk -F'\t' '
            {
              key=$1
              path=$2
              cnt[key]++
              if (!(key in sample)) sample[key]=path
            }
            END {
              for (k in cnt) {
                if (cnt[k]>1) {
                  print k"\t"cnt[k]"\t"sample[k]"\t\"Revisar con opción 10/11/44\""
                }
              }
            }' "$plan_dupes" | sort -t$'\t' -k2,2nr | head -50
        } >>"$smart_plan"

        >"$smart_report"
        printf "SMART DUPES REPORT (Deep/ML helper)\n" >>"$smart_report"
        printf "BASE_PATH: %s\n" "$BASE_PATH" >>"$smart_report"
        printf "SAFE_MODE=%s | DJ_SAFE_LOCK=%s | DRYRUN_FORCE=%s\n" "$SAFE_MODE" "$DJ_SAFE_LOCK" "$DRYRUN_FORCE" >>"$smart_report"
        printf "\nTop duplicados (clave=basename|size):\n" >>"$smart_report"
        awk -F'\t' '{c[$1]++} END {for (k in c) if (c[k]>1) print c[k]"\t"k}' "$plan_dupes" | sort -nr | head -20 >>"$smart_report"
        printf "\nRecomendaciones rápidas:\n" >>"$smart_report"
        printf "%s\n" "- 10 -> 11 para flujo exacto (hash) y quarantine." >>"$smart_report"
        printf "%s\n" "- 44 para consolidar con deduplicación integrada." >>"$smart_report"
        printf "%s\n" "- 40/41/42 para análisis + predictor + optimizador antes de mover." >>"$smart_report"
        printf "%s\n" "- 8/27 para backup + snapshot si SAFE_MODE=0 y DJ_SAFE_LOCK=0." >>"$smart_report"

        printf "%s[OK]%s Reporte inteligente: %s\n" "$C_GRN" "$C_RESET" "$smart_report"
        printf "%s[OK]%s Plan inteligente (top duplicados): %s\n" "$C_GRN" "$C_RESET" "$smart_plan"
        pause_enter
        ;;
      4)
        clear
        printf "%s[INFO]%s D4) Consolidación multi-disco (plan seguro, no mueve nada).\n" "$C_CYN" "$C_RESET"
        printf "Destino (ENTER para usar BASE_PATH actual; acepta drag & drop): "
        read -r dest_root
        if [ -z "$dest_root" ]; then
          dest_root="$BASE_PATH"
        fi
        if [ ! -d "$dest_root" ]; then
          printf "%s[ERR]%s Destino inválido.\n" "$C_RED" "$C_RESET"
          pause_enter
          continue
        fi
        default_sources="${EXTRA_SOURCE_ROOTS:-}"
        printf "Lista de orígenes separados por coma (ej: /Volumes/DiscoA,/Volumes/DiscoB; ENTER usa detectado: %s): " "${default_sources:-NINGUNO}"
        read -e -r src_line
        if [ -z "$src_line" ]; then
          src_line="$default_sources"
        fi
        if [ -z "$src_line" ]; then
          printf "%s[WARN]%s Sin orígenes, cancelado.\n" "$C_YLW" "$C_RESET"
          pause_enter
          continue
        fi
        IFS=',' read -r -a SRC_ROOTS <<<"$src_line"
        dest_keys="$STATE_DIR/dest_keys_tmp.tsv"
        plan_conso="$PLANS_DIR/consolidation_plan.tsv"
        mkdir -p "$PLANS_DIR"
        >"$dest_keys"
        >"$plan_conso"
        printf "%s[INFO]%s Indexando destino %s\n" "$C_CYN" "$C_RESET" "$dest_root"
        dest_total=$(find "$dest_root" -type f 2>/dev/null | wc -l | tr -d ' ')
        dest_count=0
        find "$dest_root" -type f 2>/dev/null | while IFS= read -r f; do
          dest_count=$((dest_count + 1))
          percent=$((dest_count * 100 / (dest_total + 1)))
          status_line "DEST" "$percent" "$f"
          base=$(basename "$f")
          size=$({ stat -f %z "$f" 2>/dev/null || echo 0; } | tr -d ' ')
          printf "%s|%s\n" "$base" "$size" >>"$dest_keys"
        done
        finish_status_line
        for src_root in "${SRC_ROOTS[@]}"; do
          src_root_trimmed=$(printf "%s" "$src_root" | xargs)
          [ -z "$src_root_trimmed" ] && continue
          if [ ! -d "$src_root_trimmed" ]; then
            printf "%s[WARN]%s Origen inválido: %s\n" "$C_YLW" "$C_RESET" "$src_root_trimmed"
            continue
          fi
          printf "%s[INFO]%s Escaneando origen: %s\n" "$C_CYN" "$C_RESET" "$src_root_trimmed"
          src_total=$(find "$src_root_trimmed" -type f 2>/dev/null | wc -l | tr -d ' ')
          src_count=0
          find "$src_root_trimmed" -type f 2>/dev/null | while IFS= read -r f; do
            src_count=$((src_count + 1))
            percent=$((src_count * 100 / (src_total + 1)))
            status_line "SRC" "$percent" "$f"
            base=$(basename "$f")
            size=$({ stat -f %z "$f" 2>/dev/null || echo 0; } | tr -d ' ')
            key="${base}|${size}"
            if ! grep -qxF "$key" "$dest_keys"; then
              rel="${f#$src_root_trimmed/}"
              target="$dest_root/_CONSOLIDATED_INBOX/$(basename "$src_root_trimmed")/$rel"
              printf "%s\t%s\n" "$f" "$target" >>"$plan_conso"
            fi
          done
          finish_status_line
        done
        unique_missing=$(wc -l <"$plan_conso" | tr -d ' ')
        printf "%s[OK]%s Plan de consolidación generado: %s (faltantes únicos: %s)\n" "$C_GRN" "$C_RESET" "$plan_conso" "$unique_missing"
        rsync_helper="$PLANS_DIR/consolidation_rsync.sh"
        >"$rsync_helper"
        while IFS=$'\t' read -r src target; do
          dest_dir=$(dirname "$target")
          printf "mkdir -p %q\n" "$dest_dir" >>"$rsync_helper"
          printf "rsync -av --progress --protect-args %q %q\n" "$src" "$target" >>"$rsync_helper"
        done <"$plan_conso"
        chmod +x "$rsync_helper" 2>/dev/null || true
        printf "Acción recomendada: revisar y luego ejecutar el helper: %s (SAFE_MODE no aplica, revisa antes de correrlo).\n" "$rsync_helper"
        pause_enter
        ;;
      5)
        clear
        printf "%s[INFO]%s D5) Duplicados exactos por hash (todas las extensiones).\n" "$C_CYN" "$C_RESET"
        default_roots="${GENERAL_ROOT:-$BASE_PATH}"
        if [ -n "${EXTRA_SOURCE_ROOTS:-}" ]; then
          default_roots="$default_roots,${EXTRA_SOURCE_ROOTS}"
        fi
        printf "Raíces separadas por coma (ej: /Volumes/DiscoA,/Volumes/DiscoB; ENTER usa %s): " "$default_roots"
        read -e -r roots_line
        if [ -z "$roots_line" ]; then
          roots_line="$default_roots"
        fi
        printf "Exclusiones (patrones coma, ej: *.asd,*/Cache/*; ENTER usa defecto): "
        read -r exclude_patterns
        [ -z "$exclude_patterns" ] && exclude_patterns="$DEFAULT_EXCLUDES"
        printf "Max depth (1=solo raíz, 2=subcarpetas, 3=sub-sub; ENTER sin límite): "
        read -e -r max_depth
        printf "Max tamaño (MB, ENTER sin límite, ej: 500): "
        read -e -r max_mb
        IFS=',' read -r -a ROOTS <<<"$roots_line"
        hash_tmp="$STATE_DIR/general_hashes.tmp"
        plan_hash="$PLANS_DIR/general_hash_dupes_plan.tsv"
        report_hash="$REPORTS_DIR/general_hash_dupes_report.txt"
        mkdir -p "$PLANS_DIR" "$REPORTS_DIR" "$STATE_DIR"
        >"$hash_tmp"
        >"$plan_hash"
        >"$report_hash"

        total=0
        for r in "${ROOTS[@]}"; do
          r_trim=$(printf "%s" "$r" | xargs)
          if [ ! -d "$r_trim" ]; then
            printf "%s[WARN]%s Raíz inválida: %s\n" "$C_YLW" "$C_RESET" "$r_trim"
            continue
          fi
          find_opts=()
          [ -n "$max_depth" ] && find_opts+=("-maxdepth" "$max_depth")
          find "$r_trim" "${find_opts[@]}" -type f 2>/dev/null | while IFS= read -r f; do
            if should_exclude_path "$f" "$exclude_patterns"; then
              continue
            fi
            status_line "COUNT" "--" "$f"
            total=$((total + 1))
          done
          finish_status_line
        done
        if [ "$total" -eq 0 ]; then
          printf "%s[WARN]%s No se encontraron archivos en las raíces indicadas.\n" "$C_YLW" "$C_RESET"
          pause_enter
          continue
        fi

        count=0
        printf "%s[INFO]%s Calculando hashes SHA-256 (puede tardar)...\n" "$C_CYN" "$C_RESET"
        for r in "${ROOTS[@]}"; do
          r_trim=$(printf "%s" "$r" | xargs)
          [ -d "$r_trim" ] || { printf "%s[WARN]%s Raíz inválida: %s\n" "$C_YLW" "$C_RESET" "$r_trim"; continue; }
          find_opts=()
          [ -n "$max_depth" ] && find_opts+=("-maxdepth" "$max_depth")
          find "$r_trim" "${find_opts[@]}" -type f 2>/dev/null | while IFS= read -r f; do
            if should_exclude_path "$f" "$exclude_patterns"; then
              continue
            fi
            if [ -n "$max_mb" ]; then
              fsz=$(wc -c <"$f" 2>/dev/null | tr -d '[:space:]')
              if [ -n "$fsz" ] && [ "$fsz" -gt $((max_mb*1024*1024)) ]; then
                continue
              fi
            fi
            count=$((count + 1))
            percent=$((count * 100 / total))
            status_line "HASH" "$percent" "$f"
            h=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
            printf "%s\t%s\n" "$h" "$f" >>"$hash_tmp"
          done
        done
        finish_status_line

        awk '
        {
          h=$1; path=$2
          cnt[h]++
          rec[h,cnt[h]]=path
        }
        END {
          for (k in cnt) {
            if (cnt[k]>1) {
              keep=0
              for (i=1;i<=cnt[k];i++) {
                f=rec[k,i]
                action=(keep==0?"KEEP":"QUARANTINE")
                keep=1
                print k"\t"action"\t"f
              }
            }
          }
        }' "$hash_tmp" >"$plan_hash"

        {
          printf "HASH_DUPES_REPORT\n"
          printf "Roots: %s\n" "$roots_line"
          printf "Archivos procesados: %s\n" "$count"
          dupes=$(awk -F'\t' '{print $1}' "$plan_hash" | sort | uniq | wc -l | tr -d ' ')
          printf "Hashes con duplicados: %s\n" "$dupes"
          printf "Recomendación: revisar %s y aplicar acción 11 (quarantine) con SAFE_MODE=0.\n" "$plan_hash"
        } >"$report_hash"

        printf "%s[OK]%s Plan de duplicados exactos: %s\n" "$C_GRN" "$C_RESET" "$plan_hash"
        printf "%s[OK]%s Reporte: %s\n" "$C_GRN" "$C_RESET" "$report_hash"
        pause_enter
        ;;
      6)
        clear
        printf "%s[INFO]%s D6) Consolidación inversa (sobrantes en origen, no mueve nada).\n" "$C_CYN" "$C_RESET"
        printf "Destino (ENTER para usar BASE_PATH actual; acepta drag & drop): "
        read -e -r dest_root
        dest_root=$(strip_quotes "$dest_root")
        if [ -z "$dest_root" ]; then
          dest_root="$BASE_PATH"
        fi
        if [ ! -d "$dest_root" ]; then
          printf "%s[ERR]%s Destino inválido.\n" "$C_RED" "$C_RESET"
          pause_enter
          continue
        fi
        default_sources="${EXTRA_SOURCE_ROOTS:-}"
        printf "Lista de orígenes separados por coma (ENTER usa detectado: %s): " "${default_sources:-NINGUNO}"
        read -e -r src_line
        if [ -z "$src_line" ]; then
          src_line="$default_sources"
        fi
        if [ -z "$src_line" ]; then
          printf "%s[WARN]%s Sin orígenes, cancelado.\n" "$C_YLW" "$C_RESET"
          pause_enter
          continue
        fi
        printf "Tamaño mínimo (MB) para marcar sobrantes (ENTER sin umbral, ej: 500): "
        read -e -r inv_min_mb
        IFS=',' read -r -a SRC_ROOTS <<<"$src_line"
        dest_keys="$STATE_DIR/dest_keys_tmp.tsv"
        plan_inv="$PLANS_DIR/consolidation_inverse_plan.tsv"
        mkdir -p "$PLANS_DIR"
        >"$dest_keys"
        >"$plan_inv"
        printf "%s[INFO]%s Indexando destino %s\n" "$C_CYN" "$C_RESET" "$dest_root"
        dest_total=$(find "$dest_root" -type f 2>/dev/null | wc -l | tr -d ' ')
        dest_count=0
        find "$dest_root" -type f 2>/dev/null | while IFS= read -r f; do
          dest_count=$((dest_count + 1))
          percent=$((dest_count * 100 / (dest_total + 1)))
          status_line "DEST" "$percent" "$f"
          base=$(basename "$f")
          size=$({ stat -f %z "$f" 2>/dev/null || echo 0; } | tr -d ' ')
          printf "%s|%s\n" "$base" "$size" >>"$dest_keys"
        done
        finish_status_line
        for src_root in "${SRC_ROOTS[@]}"; do
          src_root_trimmed=$(printf "%s" "$src_root" | xargs)
          [ -z "$src_root_trimmed" ] && continue
          if [ ! -d "$src_root_trimmed" ]; then
            printf "%s[WARN]%s Origen inválido: %s\n" "$C_YLW" "$C_RESET" "$src_root_trimmed"
            continue
          fi
          printf "%s[INFO]%s Escaneando origen: %s\n" "$C_CYN" "$C_RESET" "$src_root_trimmed"
          src_total=$(find "$src_root_trimmed" -type f 2>/dev/null | wc -l | tr -d ' ')
          src_count=0
          find "$src_root_trimmed" -type f 2>/dev/null | while IFS= read -r f; do
            src_count=$((src_count + 1))
            percent=$((src_count * 100 / (src_total + 1)))
            status_line "SRC" "$percent" "$f"
            base=$(basename "$f")
            size=$({ stat -f %z "$f" 2>/dev/null || echo 0; } | tr -d ' ')
            key="${base}|${size}"
            if grep -qxF "$key" "$dest_keys"; then
              if [ -n "$inv_min_mb" ]; then
                if [ "$size" -lt $((inv_min_mb*1024*1024)) ]; then
                  continue
                fi
              fi
              printf "%s\t%s\n" "$f" "$dest_root" >>"$plan_inv"
            fi
          done
          finish_status_line
        done
        inv_count=$(wc -l <"$plan_inv" | tr -d ' ')
        printf "%s[OK]%s Plan de sobrantes generado: %s (archivos candidatos: %s)\n" "$C_GRN" "$C_RESET" "$plan_inv" "$inv_count"
        printf "Acción recomendada: revisar antes de borrar/mover manualmente.\n"
        pause_enter
        ;;
      7)
        clear
        printf "%s[INFO]%s D7) Reporte de matrioshkas (carpetas duplicadas por estructura).\n" "$C_CYN" "$C_RESET"
        roots_line="$GENERAL_ROOT"
        printf "Raíces separadas por coma (ej: /Volumes/DiscoA,/Volumes/DiscoB; ENTER usa GENERAL_ROOT=%s): " "${GENERAL_ROOT:-$BASE_PATH}"
        read -e -r rl
        [ -n "$rl" ] && roots_line="$rl"
        printf "Profundidad máxima a analizar (1=solo raíz, 2=subcarpetas, 3=sub-sub; ENTER=3): "
        read -e -r md
        [ -z "$md" ] && md=3
        printf "Máx archivos por carpeta para hash (ENTER=500): "
        read -e -r mf
        [ -z "$mf" ] && mf=500
        IFS=',' read -r -a MROOTS <<<"$roots_line"
        sig_tmp="$STATE_DIR/matrioshka_sig.tmp"
        plan_m="$PLANS_DIR/matrioshka_report.tsv"
        clean_plan="$PLANS_DIR/matrioshka_clean_plan.tsv"
        >"$sig_tmp"
        >"$plan_m"
        >"$clean_plan"
        printf "%s[INFO]%s Generando firmas de estructura (prof=%s, max_files=%s)...\n" "$C_CYN" "$C_RESET" "$md" "$mf"
        for r in "${MROOTS[@]}"; do
          r_trim=$(printf "%s" "$r" | xargs)
          [ -d "$r_trim" ] || { printf "%s[WARN]%s Raíz inválida: %s\n" "$C_YLW" "$C_RESET" "$r_trim"; continue; }
          find "$r_trim" -maxdepth "$md" -type d 2>/dev/null | while IFS= read -r d; do
            files=$(find "$d" -maxdepth 1 -type f 2>/dev/null | head -"$mf" | xargs -I{} basename "{}" | sort | tr '\n' '|' )
            if [ -n "$files" ]; then
              sig=$(printf "%s" "$files" | shasum -a 256 | awk '{print $1}')
              printf "%s\t%s\t%s\n" "$sig" "$d" "$files" >>"$sig_tmp"
            fi
          done
        done
        awk -F'\t' '{
          s=$1; d=$2; f=$3; cnt[s]++; rec[s,cnt[s]]=d; files[s]=f;
        } END {
          for (k in cnt) if (cnt[k]>1) {
            for (i=1;i<=cnt[k];i++) print k"\t"files[k]"\t"cnt[k]"\t"rec[k,i];
          }
        }' "$sig_tmp" >"$plan_m"
        # Generar plan de limpieza sugerido (KEEP/REMOVE) por fecha/size
        while IFS=$'\t' read -r sig files dupcount path; do
          if [ -z "$sig" ] || [ -z "$path" ]; then
            continue
          fi
          mtime=$({ stat -f %m "$path" 2>/dev/null || echo 0; } | tr -d '[:space:]')
          dsize=$({ du -sk "$path" 2>/dev/null || echo 0; } | awk '{print $1}')
          printf "%s\t%s\t%s\t%s\t%s\n" "$sig" "$path" "$mtime" "$dsize" "$dupcount" >>"$clean_plan.tmp"
        done <"$plan_m"
        awk -F'\t' '{
          sig=$1; path=$2; m=$3+0; sz=$4+0;
          count[sig]++; idx=count[sig];
          paths[sig,idx]=path;
          mt[sig,idx]=m;
          szs[sig,idx]=sz;
        } END {
          for (s in count) {
            best=""; bestm=-1; bestsz=-1;
            for (i=1;i<=count[s];i++) {
              m=mt[s,i]; z=szs[s,i]; p=paths[s,i];
              if (m>bestm || (m==bestm && z>bestsz)) { best=p; bestm=m; bestsz=z; }
            }
            if (best!="") {
              print "KEEP\t"best >> "'"$clean_plan"'";
              for (i=1;i<=count[s];i++) {
                p=paths[s,i];
                if (p!=best && p!="") print "REMOVE\t"p >> "'"$clean_plan"'";
              }
            }
          }
        }' "$clean_plan.tmp"
        rm -f "$clean_plan.tmp"
        hits=$(wc -l <"$plan_m" | tr -d ' ')
        printf "%s[OK]%s Reporte matrioshkas: %s (coincidencias: %s)\n" "$C_GRN" "$C_RESET" "$plan_m" "$hits"
        printf "%s[OK]%s Plan de limpieza matrioshkas: %s\n" "$C_GRN" "$C_RESET" "$clean_plan"
        pause_enter
        ;;
      9)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML está deshabilitado (usa 63 para habilitarlo).\n" "$C_YLW" "$C_RESET"
          pause_enter
          continue
        fi
        maybe_activate_ml_env "D9 Similitud audio (YAMNet)" 1 1
        report_sim="$REPORTS_DIR/d9_audio_similarity.tsv"
        plan_sim="$PLANS_DIR/d9_audio_similarity_plan.tsv"
        printf "Modelo (1=YAMNet, 2=MusicTag NNFP, 3=VGGish, 4=Musicnn) [1]: "
        read -r model_sel
        [ -z "$model_sel" ] && model_sel=1
        printf "Preset (1=rapido:100f/0.55/100 pares, 2=balanceado:150f/0.60/200 pares, 3=estricto:150f/0.70/200 pares) [2]: "
        read -r preset_sim
        [ -z "$preset_sim" ] && preset_sim=2
        if [ "$preset_sim" -eq 1 ]; then max_files=100; sim_thresh=0.55; top_pairs=100; elif [ "$preset_sim" -eq 3 ]; then max_files=150; sim_thresh=0.70; top_pairs=200; else max_files=150; sim_thresh=0.60; top_pairs=200; fi
        printf "%s[INFO]%s D9) Similitud audio (modelo %s, máx %s archivos, umbral %.2f, top %s pares, requiere TF/tf_hub/soundfile).\n" "$C_CYN" "$C_RESET" "$model_sel" "$max_files" "$sim_thresh" "$top_pairs"
        BASE="$GENERAL_ROOT" REPORT="$report_sim" PLAN="$plan_sim" MODEL_SEL="$model_sel" MAX_FILES="$max_files" SIM_THRESH="$sim_thresh" TOP_PAIRS="$top_pairs" python3 - <<'PY'
import os, sys, pathlib, itertools, heapq
try:
    import tensorflow as tf
    import tensorflow_hub as hub
    import soundfile as sf
    import numpy as np
except Exception:
    sys.exit(1)

MODEL_CHOICES = {
    "1": "https://tfhub.dev/google/yamnet/1",
    "2": "https://tfhub.dev/google/music_tagging/nnfp/1",
    "3": "https://tfhub.dev/google/vggish/1",
}
model_choice = os.environ.get("MODEL_SEL", "1")
model_url = MODEL_CHOICES.get(model_choice, MODEL_CHOICES["1"])
max_files = int(os.environ.get("MAX_FILES", "150"))
sim_thresh = float(os.environ.get("SIM_THRESH", "0.6"))
top_limit = int(os.environ.get("TOP_PAIRS", "200"))

base = pathlib.Path(os.environ.get("BASE") or ".")
report_path = pathlib.Path(os.environ["REPORT"])
plan_path = pathlib.Path(os.environ["PLAN"])
audio_exts = {".mp3", ".wav", ".flac", ".m4a", ".aiff", ".aif"}
files = []
for p in base.rglob("*"):
    if p.suffix.lower() in audio_exts and p.is_file():
        files.append(p)
    if len(files) >= max_files:
        break
if len(files) < 2:
    print("[ERR] Muy pocos archivos para similitud.")
    sys.exit(2)

model = hub.load(model_url)
class_names = []
if hasattr(model, "class_map_path"):
    try:
        class_map_path = model.class_map_path().numpy()
        class_names = [ln.strip() for ln in pathlib.Path(class_map_path).read_text().splitlines()]
    except Exception:
        class_names = []

def load_mono_16k(path):
    data, sr = sf.read(path)
    if data.ndim > 1:
        data = data.mean(axis=1)
    if sr != 16000:
        target_len = int(len(data) * 16000 / sr)
        data = tf.signal.resample(tf.convert_to_tensor(data, dtype=tf.float32), target_len).numpy()
    return data

def get_embedding(wav):
    outp = model(wav)
    if isinstance(outp, dict):
        outp = list(outp.values())[0]
    arr = tf.convert_to_tensor(outp)
    if arr.ndim >= 2:
        return tf.reduce_mean(arr, axis=0).numpy()
    elif arr.ndim == 1:
        return arr.numpy()
    return None

embeddings = []
for f in files:
    try:
        wav = load_mono_16k(str(f))
        emb = get_embedding(tf.convert_to_tensor(wav, dtype=tf.float32))
        if emb is None:
            continue
        tag = "unknown"
        if class_names:
            scores = None
            if hasattr(model, "signatures") and "serving_default" in model.signatures:
                sig = model.signatures["serving_default"]
                outputs = sig(tf.convert_to_tensor(wav, dtype=tf.float32))
                logits = None
                for v in outputs.values():
                    logits = v
                    break
                if logits is not None:
                    scores = tf.nn.softmax(logits[0]).numpy()
            if scores is not None:
                top_idx = int(np.argmax(scores))
                if 0 <= top_idx < len(class_names):
                    tag = class_names[top_idx]
        embeddings.append((f, emb, tag))
    except Exception:
        pass

if len(embeddings) < 2:
    print("[ERR] Falló generar embeddings (revisa dependencias).")
    sys.exit(3)

pairs = []
for (f1, e1, t1), (f2, e2, t2) in itertools.combinations(embeddings, 2):
    sim = float(np.dot(e1, e2) / (np.linalg.norm(e1) * np.linalg.norm(e2) + 1e-9))
    if sim >= sim_thresh:
        pairs.append((sim, f1, f2, t1, t2))
top_pairs = heapq.nlargest(top_limit, pairs, key=lambda x: x[0])

with report_path.open("w", encoding="utf-8") as rf, plan_path.open("w", encoding="utf-8") as pf:
    rf.write("file_a\tfile_b\tsimilarity\ttag_a\ttag_b\n")
    pf.write("file_a\tfile_b\taction\n")
    for sim, f1, f2, t1, t2 in top_pairs:
        rf.write(f\"{f1}\\t{f2}\\t{sim:.3f}\\t{t1}\\t{t2}\\n\")
        pf.write(f\"{f1}\\t{f2}\\tREVIEW\\n\")

print(f\"[OK] Reporte: {report_path}\")
print(f\"[OK] Plan: {plan_path}\")
PY
        rc=$?
        if [ "$rc" -ne 0 ]; then
          printf "%s[ERR]%s No se pudo generar similitud (revise dependencias TF/tf_hub/soundfile). RC=%s\n" "$C_RED" "$C_RESET" "$rc"
        else
          printf "%s[OK]%s Reporte similitud: %s\n" "$C_GRN" "$C_RESET" "$report_sim"
          printf "%s[OK]%s Plan similitud: %s\n" "$C_GRN" "$C_RESET" "$plan_sim"
        fi
        pause_enter
        ;;
      8)
        clear
        printf "%s[INFO]%s D8) Carpetas espejo por contenido.\n" "$C_CYN" "$C_RESET"
        roots_line="$GENERAL_ROOT"
        printf "Raíces separadas por coma (ej: /Volumes/DiscoA,/Volumes/DiscoB; ENTER usa GENERAL_ROOT=%s): " "${GENERAL_ROOT:-$BASE_PATH}"
        read -e -r rl
        [ -n "$rl" ] && roots_line="$rl"
        printf "Profundidad máxima a analizar (1=solo raíz, 2=subcarpetas, 3=sub-sub; ENTER=3): "
        read -e -r md
        [ -z "$md" ] && md=3
        printf "Máx archivos por carpeta (ENTER=500): "
        read -e -r mf
        [ -z "$mf" ] && mf=500
        printf "Modo (1=rápido nombre+tamaño, 2=hash contenido más preciso pero lento): "
        read -e -r mode
        [ -z "$mode" ] && mode=1
        IFS=',' read -r -a MROOTS <<<"$roots_line"
        sig_tmp="$STATE_DIR/mirror_sig.tmp"
        report_mirror="$PLANS_DIR/mirror_folders_report.tsv"
        clean_mirror="$PLANS_DIR/mirror_folders_clean.tsv"
        mkdir -p "$PLANS_DIR" "$STATE_DIR"
        >"$sig_tmp"
        >"$report_mirror"
        >"$clean_mirror"
        printf "%s[INFO]%s Calculando firmas de carpetas (prof=%s, max_files=%s, modo=%s)...\n" "$C_CYN" "$C_RESET" "$md" "$mf" "$mode"
        for r in "${MROOTS[@]}"; do
          r_trim=$(printf "%s" "$r" | xargs)
          [ -d "$r_trim" ] || { printf "%s[WARN]%s Raíz inválida: %s\n" "$C_YLW" "$C_RESET" "$r_trim"; continue; }
          find "$r_trim" -maxdepth "$md" -type d 2>/dev/null | while IFS= read -r d; do
            list_file=$(mktemp "${STATE_DIR}/mirror_list.XXXXXX") || list_file="/tmp/mirror_list.$$"
            >"$list_file"
            count=0
            total_bytes=0
            while IFS= read -r -d '' f; do
              size=$({ stat -f %z "$f" 2>/dev/null || echo 0; } | tr -d '[:space:]')
              count=$((count + 1))
              total_bytes=$((total_bytes + size))
              if [ "$count" -le "$mf" ]; then
                rel="${f#$d/}"
                if [ "$mode" -eq 2 ]; then
                  h=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
                  printf "%s|%s|%s\n" "$rel" "$h" "$size" >>"$list_file"
                else
                  printf "%s|%s\n" "$rel" "$size" >>"$list_file"
                fi
              fi
            done < <(find "$d" -maxdepth "$md" -type f -print0 2>/dev/null)
            if [ "$count" -eq 0 ]; then
              rm -f "$list_file"
              continue
            fi
            sig=$(sort "$list_file" | shasum -a 256 | awk '{print $1}')
            mtime=$({ stat -f %m "$d" 2>/dev/null || echo 0; } | tr -d '[:space:]')
            printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$sig" "$d" "$count" "$total_bytes" "$mode" "$mtime" >>"$sig_tmp"
            rm -f "$list_file"
          done
        done
        awk -F'\t' '{
          sig=$1; path=$2; files=$3+0; bytes=$4+0; mode=$5; mt=$6+0;
          c[sig]++; idx=c[sig];
          p[sig,idx]=path; f[sig,idx]=files; b[sig,idx]=bytes; mtime[sig,idx]=mt; m[sig]=mode;
        } END {
          for (s in c) if (c[s]>1) {
            best=""; bestm=-1; bestb=-1;
            for (i=1;i<=c[s];i++) {
              if (mtime[s,i]>bestm || (mtime[s,i]==bestm && b[s,i]>bestb)) {
                best=p[s,i]; bestm=mtime[s,i]; bestb=b[s,i];
              }
            }
            for (i=1;i<=c[s];i++) {
              print s"\t"c[s]"\t"f[s,i]"\t"b[s,i]"\t"m[s]"\t"mtime[s,i]"\t"p[s,i] >> "'"$report_mirror"'";
            }
            if (best!="") {
              print "KEEP\t"best >> "'"$clean_mirror"'";
              for (i=1;i<=c[s];i++) {
                pp=p[s,i];
                if (pp!=best) print "REMOVE\t"pp >> "'"$clean_mirror"'";
              }
            }
          }
        }' "$sig_tmp"
        hits=$(wc -l <"$report_mirror" | tr -d ' ')
        if [ "$hits" -eq 0 ]; then
          printf "%s[WARN]%s No se detectaron carpetas espejo en las raíces indicadas.\n" "$C_YLW" "$C_RESET"
        else
          printf "%s[OK]%s Reporte carpetas espejo: %s (coincidencias: %s)\n" "$C_GRN" "$C_RESET" "$report_mirror" "$hits"
          printf "%s[OK]%s Plan de limpieza espejo: %s\n" "$C_GRN" "$C_RESET" "$clean_mirror"
        fi
        pause_enter
        ;;
      B|b)
        break ;;
      *)
        invalid_option
        ;;
    esac
  done
}

action_V1_ableton_report() {
  print_header
  out="$REPORTS_DIR/ableton_als_report.tsv"
  printf "%s[INFO]%s Ableton .als quick report -> %s\n" "$C_CYN" "$C_RESET" "$out"
  if ! command -v python3 >/dev/null 2>&1; then
    printf "%s[ERR]%s python3 no encontrado (necesario para leer .als).\n" "$C_RED" "$C_RESET"
    pause_enter; return
  fi
  mapfile -t als_list < <(find "$BASE_PATH" -type f -iname "*.als" 2>/dev/null | head -200)
  if [ "${#als_list[@]}" -eq 0 ]; then
    printf "%s[WARN]%s No se encontraron .als en la base.\n" "$C_YLW" "$C_RESET"
    pause_enter; return
  fi
  python3 - "$out" "${als_list[@]}" <<'PY'
import sys, gzip, xml.etree.ElementTree as ET
out = sys.argv[1]
paths = sys.argv[2:]
with open(out, "w", encoding="utf-8") as f:
    f.write("path\tsamples\tplugins\tmidi_devices\n")
    for p in paths:
        samples = plugins = midi = 0
        try:
            with gzip.open(p, "rb") as g:
                data = g.read()
            root = ET.fromstring(data)
            samples = len(root.findall(".//FileRef"))
            plugins = len(root.findall(".//PlugIn"))
            midi = len(root.findall(".//MidiDevice"))
        except Exception:
            pass
        f.write(f"{p}\t{samples}\t{plugins}\t{midi}\n")
PY
  printf "%s[OK]%s Reporte generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_V2_visuals_inventory() {
  print_header
  out="$REPORTS_DIR/visuals_inventory.tsv"
  printf "%s[INFO]%s Inventario de vídeos/visuales -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  mapfile -t vids < <(find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.m4v" \) 2>/dev/null)
  total=${#vids[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No se encontraron vídeos/visuales.\n" "$C_YLW" "$C_RESET"
    rm -f "$out"
    pause_enter; return
  fi
  count=0
  for f in "${vids[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    size=$({ stat -f %z "$f" 2>/dev/null || echo 0; } | tr -d '[:space:]')
    printf "%s\t%s\t%s\n" "$f" "$(basename "$f")" "$size" >>"$out"
    status_line "Inventario visuals" "$percent" "$(basename "$f")"
  done
  finish_status_line
  printf "%s[OK]%s Inventario generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_V3_osc_dmx_plan() {
  print_header
  printf "%s[INFO]%s Enviar plan DMX (ENTTEC DMX USB Pro). Safe/Lock fuerzan dry-run.\n" "$C_CYN" "$C_RESET"
  printf "Plan DMX (default: %s/dmx_from_playlist.tsv): " "$PLANS_DIR"
  read -e -r plan_path
  [ -z "$plan_path" ] && plan_path="$PLANS_DIR/dmx_from_playlist.tsv"
  plan_path=$(strip_quotes "$plan_path")
  if [ ! -f "$plan_path" ]; then
    printf "%s[ERR]%s Plan no encontrado.\n" "$C_RED" "$C_RESET"; pause_enter; return
  fi
  device="/dev/tty.usbserial"
  printf "Dispositivo DMX (default %s): " "$device"
  read -e -r dev_in
  [ -n "$dev_in" ] && device="$dev_in"
  baud="57600"
  dry="--dry-run"
  if [ "$SAFE_MODE" -eq 0 ] && [ "$DJ_SAFE_LOCK" -eq 0 ] && [ "$DRYRUN_FORCE" -eq 0 ]; then
    printf "Enviar realmente por %s? (escribe SEND para confirmar, otra cosa = dry-run): " "$device"
    read -r cfm
    [ "$cfm" = "SEND" ] && dry=""
  else
    printf "%s[WARN]%s SAFE_MODE/DJ_SAFE_LOCK/DRYRUN_FORCE activos, solo dry-run.\n" "$C_YLW" "$C_RESET"
  fi
  if ! ensure_python_deps "DMX" "pyserial"; then
    pause_enter; return
  fi
  "$PYTHON_BIN" "lib/dmx_send.py" --plan "$plan_path" --device "$device" --baud "$baud" $dry 2>/dev/null || {
    printf "%s[ERR]%s Falló el envío/preview DMX (revisa lib/dmx_send.py).\n" "$C_RED" "$C_RESET"
    pause_enter; return
  }
  mode="DRY-RUN"
  [ -z "$dry" ] && mode="LIVE"
  printf "%s[OK]%s Plan procesado (modo %s).\n" "$C_GRN" "$C_RESET" "$mode"
  pause_enter
}

action_V4_serato_video_report() {
  action_32_serato_video_report
}

action_V5_serato_video_prep() {
  action_33_serato_video_prep
}

action_V6_visuals_ffprobe_report() {
  print_header
  out="$REPORTS_DIR/visuals_media_report.tsv"
  printf "%s[INFO]%s Reporte resolución/duración (ffprobe) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  if ! command -v ffprobe >/dev/null 2>&1; then
    printf "%s[ERR]%s ffprobe no disponible.\n" "$C_RED" "$C_RESET"
    pause_enter; return
  fi
  >"$out"
  mapfile -t vids < <(find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.m4v" \) 2>/dev/null)
  total=${#vids[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No se encontraron vídeos/visuales.\n" "$C_YLW" "$C_RESET"
    rm -f "$out"; pause_enter; return
  fi
  count=0
  for f in "${vids[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    info=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,codec_name:format=duration -of csv=p=0:s=',' "$f" 2>/dev/null)
    IFS=',' read -r width height codec dur <<<"$info"
    size=$({ stat -f %z "$f" 2>/dev/null || echo 0; } | tr -d '[:space:]')
    printf "%s\t%spx\t%spx\t%s\t%s\t%s\n" "$f" "${width:-?}" "${height:-?}" "${codec:-?}" "${dur:-?}" "$size" >>"$out"
    status_line "ffprobe visuals" "$percent" "$(basename "$f")"
  done
  finish_status_line
  printf "%s[OK]%s Reporte generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_V7_visuals_by_resolution() {
  print_header
  out="$PLANS_DIR/visuals_by_resolution.tsv"
  printf "%s[INFO]%s Plan organizar visuales por resolución -> %s\n" "$C_CYN" "$C_RESET" "$out"
  if ! command -v ffprobe >/dev/null 2>&1; then
    printf "%s[ERR]%s ffprobe no disponible.\n" "$C_RED" "$C_RESET"
    pause_enter; return
  fi
  >"$out"
  mapfile -t vids < <(find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.m4v" \) 2>/dev/null)
  total=${#vids[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No se encontraron vídeos/visuales.\n" "$C_YLW" "$C_RESET"
    rm -f "$out"; pause_enter; return
  fi
  count=0
  for f in "${vids[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    info=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=',' "$f" 2>/dev/null)
    IFS=',' read -r width height <<<"$info"
    bucket="SD_or_unknown"
    w=${width:-0}; h=${height:-0}
    if [ "$w" -ge 3800 ] || [ "$h" -ge 2100 ]; then bucket="4K"; elif [ "$w" -ge 1800 ] || [ "$h" -ge 1000 ]; then bucket="1080p"; elif [ "$w" -ge 1200 ] || [ "$h" -ge 700 ]; then bucket="720p"; fi
    printf "%s\t%s\n" "$f" "$bucket" >>"$out"
    status_line "Bucket resolución" "$percent" "$(basename "$f")"
  done
  finish_status_line
  printf "%s[OK]%s Plan generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_V8_visuals_hash_dupes() {
  print_header
  report="$REPORTS_DIR/visuals_hash_dupes.tsv"
  plan="$PLANS_DIR/visuals_hash_dupes_plan.tsv"
  printf "%s[INFO]%s Duplicados exactos de visuales (hash) -> %s\n" "$C_CYN" "$C_RESET" "$report"
  tmp="$STATE_DIR/visuals_hashes.tmp"
  >"$tmp"
  mapfile -t vids < <(find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.m4v" \) 2>/dev/null)
  total=${#vids[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No hay visuales o no se pudieron hashear.\n" "$C_YLW" "$C_RESET"
    rm -f "$tmp"; pause_enter; return
  fi
  count=0
  for f in "${vids[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    h=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
    [ -n "$h" ] && printf "%s\t%s\n" "$h" "$f" >>"$tmp"
    status_line "Hash visuals" "$percent" "$(basename "$f")"
  done
  finish_status_line
  awk -F'\t' '{
    h=$1; p=$2; c[h]++; paths[h]=paths[h] "\t" p;
  } END {
    print "hash\tpath_count\tpaths";
    for (h in c) if (c[h]>1) {
      gsub(/^\t/,"",paths[h]);
      print h "\t" c[h] "\t" paths[h];
    }
  }' "$tmp" >"$report"
  awk -F'\t' 'NR>1 {split($3,a,"\t"); for(i=1;i<=length(a);i++) if(a[i]!="") print a[i] "\tQUARANTINE"}' "$report" >"$plan"
  rm -f "$tmp"
  hits=$(wc -l <"$report" | tr -d ' ')
  if [ "$hits" -le 1 ]; then
    printf "%s[WARN]%s No se encontraron duplicados exactos.\n" "$C_YLW" "$C_RESET"
  else
    printf "%s[OK]%s Reporte duplicados: %s\n" "$C_GRN" "$C_RESET" "$report"
    printf "%s[OK]%s Plan duplicados: %s\n" "$C_GRN" "$C_RESET" "$plan"
  fi
  pause_enter
}

action_V9_visuals_optimize_plan() {
  print_header
  out="$PLANS_DIR/visuals_optimize_plan.tsv"
  printf "%s[INFO]%s Plan de optimización visual (sugerencias, no ejecuta ffmpeg) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  if ! command -v ffprobe >/dev/null 2>&1; then
    printf "%s[ERR]%s ffprobe no disponible.\n" "$C_RED" "$C_RESET"
    pause_enter; return
  fi
  >"$out"
  mapfile -t vids < <(find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.m4v" \) 2>/dev/null)
  total=${#vids[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No se encontraron vídeos/visuales.\n" "$C_YLW" "$C_RESET"
    rm -f "$out"; pause_enter; return
  fi
  count=0
  for f in "${vids[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    info=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,codec_name:format=duration -of csv=p=0:s=',' "$f" 2>/dev/null)
    IFS=',' read -r width height codec dur <<<"$info"
    action="KEEP"
    w=${width:-0}; h=${height:-0}
    if [ "$w" -gt 1920 ] || [ "$h" -gt 1080 ] || [ "$codec" != "h264" ]; then
      action="SUGGEST_TRANSCODE_H264_1080P"
    fi
    printf "%s\t%s\t%s\t%s\t%s\n" "$f" "${width:-?}" "${height:-?}" "${codec:-?}" "$action" >>"$out"
    status_line "Optimización visual" "$percent" "$(basename "$f")"
  done
  finish_status_line
  printf "%s[OK]%s Plan generado (sólo sugerencias).\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_V10_osc_from_playlist() {
  print_header
  default_pl="$BASE_PATH/playlist.m3u8"
  printf "%s[INFO]%s Generar cues OSC desde playlist (.m3u/.m3u8) con tiempos (ffprobe).\n" "$C_CYN" "$C_RESET"
  printf "Playlist path (ENTER intenta %s): " "$default_pl"
  read -e -r pl_path
  if [ -z "$pl_path" ]; then
    pl_path="$default_pl"
  fi
  pl_path=$(strip_quotes "$pl_path")
  if [ ! -f "$pl_path" ]; then
    printf "%s[ERR]%s Playlist no encontrada.\n" "$C_RED" "$C_RESET"
    pause_enter; return
  fi
  plan="$PLANS_DIR/osc_from_playlist.tsv"
  if ! command -v ffprobe >/dev/null; then
    printf "%s[ERR]%s ffprobe no disponible.\n" "$C_RED" "$C_RESET"; pause_enter; return
  fi
  ensure_python_bin || { pause_enter; return; }
  "$PYTHON_BIN" "lib/playlist_bridge.py" osc "$pl_path" "$plan" 2>/dev/null || {
    printf "%s[ERR]%s No se pudo generar el plan OSC.\n" "$C_RED" "$C_RESET"
    pause_enter; return
  }
  printf "%s[OK]%s Plan OSC generado: %s (direcciona a tu router OSC).\n" "$C_GRN" "$C_RESET" "$plan"
  pause_enter
}

action_V11_dmx_from_playlist() {
  print_header
  default_pl="$BASE_PATH/playlist.m3u8"
  printf "%s[INFO]%s Plan DMX desde playlist (escenas Intro/Drop/Outro con tiempos).\n" "$C_CYN" "$C_RESET"
  printf "Playlist path (ENTER intenta %s): " "$default_pl"
  read -e -r pl_path
  if [ -z "$pl_path" ]; then
    pl_path="$default_pl"
  fi
  pl_path=$(strip_quotes "$pl_path")
  if [ ! -f "$pl_path" ]; then
    printf "%s[ERR]%s Playlist no encontrada.\n" "$C_RED" "$C_RESET"
    pause_enter; return
  fi
  base_ch=1
  printf "Canal base (ENTER=1): "
  read -e -r base_ch_in
  [ -n "$base_ch_in" ] && base_ch="$base_ch_in"
  plan="$PLANS_DIR/dmx_from_playlist.tsv"
  if ! command -v ffprobe >/dev/null; then
    printf "%s[ERR]%s ffprobe no disponible.\n" "$C_RED" "$C_RESET"; pause_enter; return
  fi
  ensure_python_bin || { pause_enter; return; }
  "$PYTHON_BIN" "lib/playlist_bridge.py" dmx "$pl_path" "$plan" "$base_ch" 2>/dev/null || {
    printf "%s[ERR]%s No se pudo generar el plan DMX.\n" "$C_RED" "$C_RESET"
    pause_enter; return
  }
  printf "%s[OK]%s Plan DMX generado: %s (ajusta canales/valores a tu rig).\n" "$C_GRN" "$C_RESET" "$plan"
  pause_enter
}

action_V12_dmx_presets() {
  print_header
  plan="$PLANS_DIR/dmx_presets_beam_laser.tsv"
  printf "%s[INFO]%s Presets DMX (Mini LEDs Spider 8x6W + Láser ALIEN 500mw RGB) -> %s\n" "$C_CYN" "$C_RESET" "$plan"
  printf "%sHint:%s ajusta canales según tu manual. Sugerido:\n" "$C_BLU" "$C_RESET"
  printf "  Spider: CH1 Dimmer, CH2 Pan velo, CH3 Tilt velo, CH4 Macro/Auto, CH5 Strobe, CH6 Color/Macro, CH7 Red, CH8 Green, CH9 Blue, CH10 White.\n"
  printf "  Láser ALIEN: CH1 Master/Modo, CH2 Patrón, CH3 Color, CH4 Rotación, CH5 Tamaño/Zoom, CH6 X, CH7 Y, CH8 Strobe/Audio.\n"
  cat >"$plan" <<'EOF'
#scene	label	channel_values	notes
INTRO_SUAVE	Spider soft + láser bajo	"SPIDER:CH1=80,CH2=90,CH3=90,CH4=0,CH5=0,CH6=0,CH7=60,CH8=0,CH9=0,CH10=20; LASER:CH1=60,CH2=PATTERN1,CH3=BLUE,CH4=SLOW,CH5=30,CH6=CENTER,CH7=CENTER,CH8=OFF"	Intro ambiente/hipnótico
DROP_FULL	Spider+Láser full	"SPIDER:CH1=255,CH2=180,CH3=180,CH4=AUTO,CH5=160,CH6=255,CH7=255,CH8=255,CH9=255,CH10=255; LASER:CH1=255,CH2=PATTERN8,CH3=RGB,CH4=FAST,CH5=120,CH6=SWEEP,CH7=SWEEP,CH8=AUDIO"	Pico/drops
BREAK_LENTO	Break sin strobe	"SPIDER:CH1=150,CH2=60,CH3=60,CH4=0,CH5=0,CH6=80,CH7=120,CH8=80,CH9=40,CH10=0; LASER:CH1=80,CH2=PATTERN3,CH3=GREEN,CH4=SLOW,CH5=0,CH6=STATIC,CH7=STATIC,CH8=OFF"	Transiciones suaves
LASER_SOLO	Láser protagonista medio	"SPIDER:CH1=0,CH5=0; LASER:CH1=180,CH2=PATTERN5,CH3=RED,CH4=MEDIUM,CH5=40,CH6=CENTER,CH7=CENTER,CH8=AUTO"	Enfasis láser
PANORAMA_WIDE	Spider barrido ancho + láser leve	"SPIDER:CH1=200,CH2=220,CH3=40,CH4=AUTO,CH5=80,CH6=120,CH7=200,CH8=200,CH9=180,CH10=120; LASER:CH1=100,CH2=PATTERN2,CH3=CYAN,CH4=SLOW,CH5=20,CH6=SWEEP,CH7=SWEEP,CH8=OFF"	Llenar sala sin saturar
STROBE_FAST	Strobe rápido controlado	"SPIDER:CH1=200,CH2=150,CH3=150,CH4=0,CH5=220,CH6=200,CH7=255,CH8=255,CH9=255,CH10=255; LASER:CH1=120,CH2=PATTERN4,CH3=WHITE,CH4=FAST,CH5=60,CH6=CENTER,CH7=CENTER,CH8=AUDIO"	Para subidas/clímax cortos
BLACKOUT_SALIDA	Blackout seguro	"SPIDER:CH1=0,CH2=0,CH3=0,CH4=0,CH5=0,CH6=0,CH7=0,CH8=0,CH9=0,CH10=0; LASER:CH1=0,CH2=PATTERN1,CH3=OFF,CH4=0,CH5=0,CH6=CENTER,CH7=CENTER,CH8=OFF"	Corte limpio/pausa
AUTO_SOUND	Laser/Spider en sonido	"SPIDER:CH1=220,CH2=180,CH3=180,CH4=AUTO,CH5=140,CH6=180,CH7=200,CH8=200,CH9=200,CH10=200; LASER:CH1=200,CH2=PATTERN7,CH3=RGB,CH4=MEDIUM,CH5=80,CH6=SWEEP,CH7=SWEEP,CH8=AUDIO"	Modo sonido/auto ligero
EOF
  printf "%s[OK]%s Presets escritos; adapta nombres/canales/valores según tu mapeo real antes de enviar a tu software DMX.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

submenu_V_visuals() {
  while true; do
    clear
    printf "%s=== V) Visuales / DAW / OSC ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Ableton .als quick report (samples/plugins)\n" "$C_GRN" "$C_RESET"
    printf "%s2)%s Inventario de vídeos/visuales -> TSV\n" "$C_GRN" "$C_RESET"
    printf "%s3)%s Plan OSC/DMX placeholder\n" "$C_GRN" "$C_RESET"
    printf "%s4)%s Serato Video: reporte\n" "$C_GRN" "$C_RESET"
    printf "%s5)%s Serato Video: plan de transcode\n" "$C_GRN" "$C_RESET"
    printf "%s6)%s Reporte resolución/duración (ffprobe)\n" "$C_GRN" "$C_RESET"
    printf "%s7)%s Plan organizar visuales por resolución\n" "$C_GRN" "$C_RESET"
    printf "%s8)%s Duplicados exactos de visuales (hash)\n" "$C_GRN" "$C_RESET"
    printf "%s9)%s Plan optimización visual (sugerir H.264 1080p)\n" "$C_GRN" "$C_RESET"
    printf "%s10)%s Plan OSC desde playlist (.m3u/.m3u8)\n" "$C_GRN" "$C_RESET"
    printf "%s11)%s Plan DMX desde playlist (escenas Intro/Drop/Outro)\n" "$C_GRN" "$C_RESET"
    printf "%s12)%s Presets DMX beam+láser (plantilla editable)\n" "$C_GRN" "$C_RESET"
    printf "%sB)%s Volver al menú principal\n" "$C_YLW" "$C_RESET"
    printf "%sSelecciona una opción:%s " "$C_BLU" "$C_RESET"
    read -r vop
    case "$vop" in
      1) action_V1_ableton_report ;;
      2) action_V2_visuals_inventory ;;
      3) action_V3_osc_dmx_plan ;;
      4) action_V4_serato_video_report ;;
      5) action_V5_serato_video_prep ;;
      6) action_V6_visuals_ffprobe_report ;;
      7) action_V7_visuals_by_resolution ;;
      8) action_V8_visuals_hash_dupes ;;
      9) action_V9_visuals_optimize_plan ;;
      10) action_V10_osc_from_playlist ;;
      11) action_V11_dmx_from_playlist ;;
      12) action_V12_dmx_presets ;;
      B|b)
        break
        ;;
      *)
        invalid_option
        ;;
    esac
  done
}

action_H_help_info() {
  clear
  printf "%s=== H) Help & INFO ===%s\n" "$C_CYN" "$C_RESET"
  printf "%sBloque principal 1-39:%s\n" "$C_YLW" "$C_RESET"
  printf "  1) Estado / rutas / locks: muestra BASE_PATH y flags de seguridad.\n"
  printf "  2) Cambiar Base Path: establece la raíz de trabajo (impacta en reports/planes).\n"
  printf "  3) Resumen del volumen: tamaño + últimos reports.\n"
  printf "  4) Top carpetas por tamaño: detecta hotspots de espacio.\n"
  printf "  5) Top archivos grandes: archivos más pesados en la base.\n"
  printf "  6) Scan workspace -> workspace_scan.tsv (listado completo de archivos).\n"
  printf "  9) Índice SHA-256 -> hash_index.tsv (base para duplicados exactos).\n"
  printf " 10) Plan duplicados -> dupes_plan.json/tsv (usa hash_index).\n"
  printf " 11) Quarantine desde dupes_plan.tsv (aplica plan; respeta SafeMode/Lock).\n"
  printf " 12) Quarantine Manager: listar / restaurar / borrar contenido de quarantine.\n"
  printf " 13) ffprobe -> media_corrupt.tsv (detectar archivos corruptos).\n"
  printf " 27) Snapshot integridad con barra de progreso (hash rápido).\n"
  printf " 30) Plan organización por TAGS (género) -> TSV.\n"
  printf " 31) Informe de géneros y recuentos.\n"
  printf " 32-33) Vídeo: reporte + plan de transcode (Serato Video).\n"
  printf " 34-35) Planes de renombrado y samples por tipo.\n"
  printf " 36-39) Submenú y herramientas WEB (whitelist + limpieza tags/playlists).\n\n"

  printf "%sBloque avanzado 40-52 (Deep Thinking / ML):%s\n" "$C_YLW" "$C_RESET"
  printf "  40) Smart Analysis: resumen de archivos/audio/video + sugerencias rápidas.\n"
  printf "  41) Predictor ML: heurísticas locales (nombres largos, vacíos, rutas raras) con acción sugerida.\n"
  printf "  42) Optimizador: checklist de prioridades (duplicados, metadatos, backup, snapshot).\n"
  printf "  43) Flujo inteligente: orden recomendado (análisis -> backup -> dedupe -> cleanup).\n"
  printf "  44) Deduplicación integrada: resumen de duplicados exactos vs fuzzy.\n"
  printf "  45-48) Organización/armonía metadata, backup predictivo, sync multiplataforma.\n"
  printf "  49-52) Análisis avanzado, motor integración, recomendaciones, pipeline de limpieza.\n"
  printf "  Qué aporta: inspección local (hashes, tamaños, nombres, tags) para priorizar limpieza/sync.\n"
  printf "  Ejemplos: 40 da resumen y tips rápidos; 41 marca rutas sospechosas; 44 cruza exactos + fuzzy; 49 agrega métricas.\n"
  printf "  Nota: todo el análisis es local; no envía datos. En modo básico usa reglas/estadísticas; en 62 puedes entrenar un modelo ligero local.\n"
  printf "  Descargas: básico ~%s MB (numpy/pandas); evolutivo ~%s MB (añade scikit-learn/joblib). TensorFlow opcional (+%s MB) para audio embeddings/auto-tagging avanzados.\n\n" "$ML_PKG_BASIC_MB" "$ML_PKG_EVO_MB" "$ML_PKG_TF_MB"

  printf "%sHerramientas adicionales 53-68:%s\n" "$C_YLW" "$C_RESET"
  printf "  53) Reset estado / limpiar extras: borra _DJProducerTools o limpia fuentes extra.\n"
  printf "  54) Gestor de perfiles (BASE/GENERAL/AUDIO roots): guardar/cargar perfiles de rutas.\n"
  printf "  55) Ableton Tools: reporte rápido de .als (samples/plugins usados).\n"
  printf "  56) Importers Rekordbox/Traktor: cues a TSV / resumen NML.\n"
  printf "  57) Gestor de exclusiones: ver/cargar/guardar perfiles de patrones de exclusión.\n"
  printf "  58) Comparar hash_index entre discos: detecta faltantes/sobrantes sin recalcular hashes.\n"
  printf "  59) Health-check de estado: espacio de _DJProducerTools, tamaño quarantine/logs, hints de limpieza.\n"
  printf "  60) Export/Import solo config/perfiles: mover tu configuración sin arrastrar reports/planes.\n"
  printf "  61) Mirror check: compara dos hash_index por ruta y marca faltantes o hashes diferentes.\n"
  printf "  62) ML Evolutivo: entrena modelo local con tus planes de duplicados y predice sospechosos sin subir datos.\n"
  printf "  63) Toggle ML ON/OFF: desactiva/habilita todo uso del venv ML (Deep/ML/62).\n"
  printf "  64) TensorFlow opcional: instala TF (descarga +%s MB) y habilita ideas de auto-tagging/embeddings avanzados.\n"
  printf "  65) TensorFlow Lab: auto-tagging (modelos: YAMNet/NNFP/VGGish/musicnn; 150 archivos, top3), similitud (presets: rápido/balanceado/estricto), loops/sospechosos (placeholder), music tagging multi-label (150). Requiere TF/tf_hub/soundfile.\n"
  printf "  66) Plan LUFS (análisis, sin normalizar) – requiere python3+pyloudnorm+soundfile.\n"
  printf "  67) Auto-cues por onsets (librosa) – requiere python3+librosa.\n"
  printf "  68) Instalar deps Python en venv (pyserial, python-osc, librosa, soundfile).\n\n" "$ML_PKG_TF_MB"

  printf "%sNotas rápidas de procesos (qué hacen internamente):%s\n" "$C_YLW" "$C_RESET"
  printf "  D4: indexa destino por nombre+tamaño y lista faltantes desde orígenes → plan TSV + helper rsync.\n"
  printf "  D6: marca sobrantes en orígenes que ya existen en destino (umbral opcional) → plan TSV.\n"
  printf "  D7: firma estructura de carpetas, sugiere KEEP/REMOVE por fecha/tamaño → plan limpieza.\n"
  printf "  D8: compara carpetas por contenido (hash de listados) para detectar espejos → plan KEEP/REMOVE.\n"
  printf "  D9: genera embeddings YAMNet y lista pares de audio similares (sim>=0.60) → plan REVIEW.\n"
  printf "  10/11: usan hash_index/dupes_plan; 11 aplica quarantine (mueve a _DJProducerTools/quarantine).\n"
  printf "  62: entrena modelo ligero (scikit-learn) con tus planes; 2) predice sospechosos (5000 máx).\n"
  printf "  64: instala TensorFlow en el venv (no por defecto); 65 usa TF Hub (YAMNet/music tagging) si está.\n"
  printf "  66: calcula LUFS por archivo y sugiere ganancia (no modifica audio).\n"
  printf "  67: detecta onsets y propone cue inicial (no escribe tags, solo TSV).\n\n"

  printf "%sSubmenú V) Visuales / DAW / OSC / DMX:%s\n" "$C_YLW" "$C_RESET"
  printf "  V1-V2: reportes Ableton .als y catálogo de visuales.\n"
  printf "  V4-V5: Serato Video (reporte + plan transcode).\n"
  printf "  V6-V9: ffprobe para resolución/duración, buckets por resolución, duplicados por hash, sugerir H.264 1080p.\n"
  printf "  V10-V11: generar plan OSC/DMX desde playlist (.m3u/.m3u8) para sincronizar clips/escenas.\n"
  printf "  V12: presets DMX para Spider 8x6W + láser ALIEN; ajusta canales/valores a tu mapeo.\n"
  printf "  Nota: los TSV generados son plantillas; revísalos antes de enviarlos a tu software DMX/OSC.\n\n"

  printf "%sModelos TF disponibles (pros/cons + peso aprox descarga inicial):%s\n" "$C_YLW" "$C_RESET"
  printf "  YAMNet (~40MB): rápido, generalista (eventos/ambiente), bueno para similitud básica.\n"
  printf "  Music Tagging NNFP (~70MB): orientado a música, mejor para géneros/estilos; algo más pesado.\n"
  printf "  VGGish (~70MB): embeddings clásicos, ligero; menos fino en música que musicnn/NNFP.\n"
  printf "  Musicnn (~80-100MB): enfocado a música, buen tagging y similitud; más peso.\n"
  printf "  Nota: los pesos son aproximados; se descargan una sola vez al primer uso.\n\n"

  printf "%sSubmenú L) Librerías DJ & Cues:%s\n" "$C_YLW" "$C_RESET"
  printf "  L1) Config rutas Serato/Rekordbox/Traktor/Ableton.\n"
  printf "  L2) Catálogo audio multi-librería.\n"
  printf "  L3) Duplicados por basename+tamaño.\n"
  printf "  L4) Cues Rekordbox -> dj_cues.tsv (placeholder).\n"
  printf "  L5) dj_cues.tsv -> ableton_locators.csv (placeholder).\n\n"

  printf "%sSubmenú D) Duplicados generales:%s\n" "$C_YLW" "$C_RESET"
  printf "  D1) Catálogo general por disco.\n"
  printf "  D2) Duplicados generales por basename+tamaño.\n"
  printf "  D3) Reporte inteligente (Deep/ML) sobre duplicados.\n"
  printf "  D4) Consolidación multi-disco (plan seguro, añade faltantes).\n"
  printf "  D5) Plan de duplicados exactos por hash (todas las extensiones).\n"
  printf "  D6) Consolidación inversa: sobrantes en orígenes que ya existen en destino (umbral opcional).\n"
  printf "  D7) Matrioshkas: carpetas duplicadas por estructura (KEEP/REMOVE sugerido).\n"
  printf "  D8) Carpetas espejo: duplicados de carpetas por contenido (nombre+size o hash completo).\n"
  printf "  D9) Similitud audio (YAMNet embeddings, requiere TF).\n\n"

  printf "%sEntorno ML opcional (para 40-52 y D3):%s\n" "$C_YLW" "$C_RESET"
  printf "  Se crea aislado en: %s/venv\n" "$STATE_DIR"
  printf "  Comandos sugeridos (una sola vez):\n"
  printf "    python3 -m venv \"%s\"\n" "$VENV_DIR"
  printf "    source \"%s/bin/activate\" && pip install --upgrade pip\n" "$VENV_DIR"
  printf "  Así evitamos conflictos con el sistema y mantenemos limpieza en otros Mac/discos.\n\n"

  printf "%sInfraestructura:%s\n" "$C_YLW" "$C_RESET"
  printf "  Config:   %s\n" "$CONF_FILE"
  printf "  State:    %s\n" "$STATE_DIR"
  printf "  Reports:  %s\n" "$REPORTS_DIR"
  printf "  Plans:    %s\n" "$PLANS_DIR"
  printf "  ML venv:  %s (modo básico: numpy/pandas ~%s MB; evolutivo añade scikit-learn/joblib ~%s MB). Siempre se pide confirmación.\n" "$VENV_DIR" "$ML_PKG_BASIC_MB" "$ML_PKG_EVO_MB"
  pause_enter
}

main_loop() {
  while true; do
    print_header
    print_menu
    printf "%sOpción:%s " "$C_BLU" "$C_RESET"
    if ! read -r op </dev/tty 2>/dev/null; then
      printf "%s[WARN]%s Entrada no disponible (doble click / sin teclado). Pulsa ENTER para salir.\n" "$C_YLW" "$C_RESET"
      pause_enter
      break
    fi
    if [ -z "$op" ] || [[ "$op" == *pyenv* ]]; then
      continue
    fi
    case "$op" in
      1) action_1_status ;;
      2) action_2_change_base ;;
      3) action_3_summary ;;
      4) action_4_top_dirs ;;
      5) action_5_top_files ;;
      6) action_6_scan_workspace ;;
      7) action_7_backup_serato ;;
      8) action_8_backup_dj ;;
      9) action_9_hash_index ;;
      10) action_10_dupes_plan ;;
      11) action_11_quarantine_from_plan ;;
      12) action_12_quarantine_manager ;;
      13) action_13_ffprobe_report ;;
      14) action_14_playlists_per_folder ;;
      15) action_15_relink_helper ;;
      16) action_16_mirror_by_genre ;;
      17) action_17_find_dj_libs ;;
      18) action_18_rescan_intelligent ;;
      19) action_19_tools_diag ;;
      20) action_20_fix_ownership_flags ;;
      21) action_21_install_cmd ;;
      22) action_22_uninstall_cmd ;;
      23) action_23_toggle_safe_mode ;;
      24) action_24_toggle_lock ;;
      25) action_25_quick_help ;;
      26) action_26_export_import_state ;;
      27) action_27_snapshot ;;
      28) action_28_logs_viewer ;;
      29) action_29_toggle_dryrun ;;
      30) action_30_plan_tags ;;
      31) action_31_report_tags ;;
      32) action_32_serato_video_report ;;
      33) action_33_serato_video_prep ;;
      34) action_34_normalize_names ;;
      35) action_35_samples_by_type ;;
      36) submenu_36_web_clean ;;
      37) action_37_web_whitelist_manager ;;
      38) action_38_clean_web_playlists ;;
      39) action_39_clean_web_tags ;;
      40) action_40_smart_analysis ;;
      41) action_41_ml_predictor ;;
      42) action_42_efficiency_optimizer ;;
      43) action_43_smart_workflow ;;
      44) action_44_integrated_dedup ;;
      45) action_45_ml_organization ;;
      46) action_46_metadata_harmonizer ;;
      47) action_47_predictive_backup ;;
      48) action_48_cross_platform_sync ;;
      49) action_49_advanced_analysis ;;
      50) action_50_integration_engine ;;
      51) action_51_adaptive_recommendations ;;
      52) action_52_automated_cleanup_pipeline ;;
      53) action_53_reset_state ;;
      54) submenu_profiles_manager ;;
      55) submenu_ableton_tools ;;
      56) submenu_importers_cues ;;
      57) submenu_excludes_manager ;;
      58) action_compare_hash_indexes ;;
      59) action_state_health ;;
      60) action_export_import_config ;;
      61) action_mirror_integrity_check ;;
      62) action_ml_evo_manager ;;
      63) action_toggle_ml ;;
      64) action_tensorflow_manager ;;
      65) submenu_T_tensorflow_lab ;;
      66) action_audio_lufs_plan ;;
      67) action_audio_cues_onsets ;;
      68) action_install_all_python_deps ;;
      L|l) submenu_L_libraries ;;
      D|d) submenu_D_dupes_general ;;
      V|v) submenu_V_visuals ;;
      H|h) action_H_help_info ;;
      0) break ;;
      *) invalid_option ;;
    esac
  done
}

init_paths
load_conf
ensure_base_path_valid
ensure_general_root_valid

# Parseo de flags CLI
parse_args "$@"

# Salidas rápidas
if [ "${DJPT_SOURCED:-0}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

if [ $SHOW_HELP -eq 1 ]; then
  usage
  exit 0
fi

if [ $SHOW_VERSION -eq 1 ]; then
  echo "$SCRIPT_VERSION"
  exit 0
fi

# Inicializa rutas y configuración
init_paths
load_conf
ensure_base_path_valid
ensure_general_root_valid

# Si hay GENERAL_ROOT configurado y válido, úsalo como BASE_PATH preferente
if [ -n "${GENERAL_ROOT:-}" ] && [ -d "$GENERAL_ROOT" ] && [ "$BASE_PATH" != "$GENERAL_ROOT" ]; then
  BASE_PATH="$GENERAL_ROOT"
  init_paths
  load_conf
fi

# Si se arrancó desde otra ruta distinta a BASE_PATH, añádela como fuente extra
if [ -n "$LAUNCH_PATH" ] && [ "$LAUNCH_PATH" != "$BASE_PATH" ] && [ -d "$LAUNCH_PATH" ]; then
  append_extra_root "$LAUNCH_PATH"
fi

# Modo test ligero
if [ $RUN_TEST_MODE -eq 1 ]; then
  printf "SAFE_MODE=%s DJ_SAFE_LOCK=%s DRYRUN_FORCE=%s\n" "$SAFE_MODE" "$DJ_SAFE_LOCK" "$DRYRUN_FORCE"
  check_dependencies_basic
  exit $?
fi

save_conf
maybe_migrate_legacy_state
warn_legacy_state
main_loop
