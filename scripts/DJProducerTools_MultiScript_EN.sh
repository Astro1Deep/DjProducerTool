#!/usr/bin/env bash
set -euo pipefail

# Variable de idioma con fallback para ejecución directa
: "${DJPT_CURRENT_LANG:=EN}"

# Cargar cadenas de texto localizadas
LANG_FILE="$(dirname "${BASH_SOURCE[0]}")/lang_strings.sh"
if [ -f "$LANG_FILE" ]; then
  source "$LANG_FILE"
else
  # Fallback simple si no existe el archivo de idioma para evitar crash
  get_localized_string() { echo "$1"; }
fi

# Re-ejecuta con bash si no se lanzó con bash (doble click/otros shells)
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

guard_entrypoint_reentry() {
  local current_script
  current_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  local stack="${DJPT_ENTRYPOINT_STACK:-}"
  if [[ "$stack" == *"|$current_script|"* ]]; then
    echo "[ERR] Recursive source/exec detected for $current_script" >&2
    exit 1
  fi
  export DJPT_ENTRYPOINT_STACK="${stack}|${current_script}|"
}

is_root_volume_path() {
  local p="${1%/}"
  [ -z "$p" ] && return 1
  [ "$p" = "/" ] && return 0
  [[ "$p" =~ ^/Volumes/[^/]+$ ]] && return 0
  return 1
}

guard_entrypoint_reentry

# Early CLI flags used before full argument parsing.
for __djpt_early_arg in "$@"; do
  case "$__djpt_early_arg" in
    --no-interactive|-n)
      export DJPT_NO_INTERACTIVE=1
      ;;
  esac
done

if [[ -z "${BASE_PATH:-}" ]]; then
  script_root_hint="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  echo "ERROR: BASE_PATH environment variable is required for safety" >&2
  echo "Example: export BASE_PATH=\"$script_root_hint\"" >&2
  exit 1
fi

if is_root_volume_path "$BASE_PATH" && [[ "${ALLOW_FULL_VOLUME:-0}" != "1" ]]; then
  echo "ERROR: Full volume scan detected and blocked for safety" >&2
  echo "BASE_PATH=\"$BASE_PATH\" appears to be a root volume path" >&2
  echo "To allow full volume scans, set: export ALLOW_FULL_VOLUME=1" >&2
  exit 1
fi

if [[ ! -d "$BASE_PATH" ]]; then
  echo "ERROR: BASE_PATH directory does not exist: $BASE_PATH" >&2
  exit 1
fi
export DJPT_EXPLICIT_BASE_PATH="$BASE_PATH"

bootstrap_runtime_context() {
  local script_dir root probe abs_probe env_file
  local assets=()
  local venv_candidates=()

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  root=""

  for probe in "$script_dir/.." "$script_dir" "$PWD" "/Volumes/SeaGate2TB/_DJProducerTools"; do
    abs_probe="$(cd "$probe" 2>/dev/null && pwd || true)"
    [ -n "$abs_probe" ] || continue
    if [ -f "$abs_probe/scripts/cli.py" ]; then
      root="$abs_probe"
      break
    fi
  done

  [ -n "$root" ] || root="$(cd "$script_dir/.." && pwd)"

  export DJPT_CANONICAL_ROOT="$root"
  : "${DJPT_BASE_DIR:=$root}"
  : "${DJPT_STATE_DIR:=$root/state}"
  : "${DJPT_LIB_DIR:=$root/lib}"
  : "${DJPT_LOGS_DIR:=$root/state/logs}"
  : "${DJPT_QUARANTINE_DIR:=$root/state/quarantine}"
  export DJPT_BASE_DIR DJPT_STATE_DIR DJPT_LIB_DIR DJPT_LOGS_DIR DJPT_QUARANTINE_DIR

  env_file="$root/env"
  if [ -r "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$env_file"
    set +a
  fi

  for probe in state backups reports data archive archives_home; do
    [ -d "$root/$probe" ] && assets+=("$probe")
  done
  if [ "${#assets[@]}" -gt 0 ]; then
    DJPT_CANONICAL_ASSETS="$(IFS=,; printf "%s" "${assets[*]}")"
  else
    DJPT_CANONICAL_ASSETS="none"
  fi
  export DJPT_CANONICAL_ASSETS

  venv_candidates=(
    "$root/_DJProducerTools/djpt_venv"
    "$root/djpt_venv"
    "$root/.venv"
    "$root/venv"
    "$root/state/djpt_venv"
    "$DJPT_STATE_DIR/djpt_venv"
  )
  for probe in "${venv_candidates[@]}"; do
    [ -x "$probe/bin/python3" ] || continue
    export DJPT_VENV_DIR="$probe"
    export VIRTUAL_ENV="$probe"
    export PATH="$probe/bin:$PATH"
    : "${PYTHON_BIN:=$probe/bin/python3}"
    : "${DJPT_PYTHON_BIN:=$probe/bin/python3}"
    export PYTHON_BIN DJPT_PYTHON_BIN
    break
  done
}

bootstrap_runtime_context

# Anti-recursion protection - prevent recursive entrypoint invocation
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
if [[ "${DJPT_ENTRYPOINT_LOCK:-}" == "$SCRIPT_PATH" ]]; then
  echo "ERROR: Recursive entrypoint invocation detected ($SCRIPT_PATH)" >&2
  exit 1
fi
export DJPT_ENTRYPOINT_LOCK="$SCRIPT_PATH"

ESC=$'\033'
C_RESET="${ESC}[0m"
C_RED="${ESC}[1;31m"
C_GRN="${ESC}[1;32m"
C_YLW="${ESC}[1;33m"
C_BLU="${ESC}[1;34m"
C_CYN="${ESC}[1;35m"
C_PURP="${ESC}[1;35m"
BANNER="${ESC}[1;37;48;5;22m"  # Fondo verde estándar

# Paleta unificada verde/degradado para banners

C_GREEN1="${ESC}[38;5;22m"   # Verde oscuro
C_GREEN2="${ESC}[38;5;28m"   # Verde medio
C_GREEN3="${ESC}[38;5;46m"   # Verde estándar
C_GREEN4="${ESC}[38;5;82m"   # Verde claro
C_GREEN5="${ESC}[38;5;120m"  # Verde brillante
EN_BANNER_COLORS=("${C_GREEN1}" "${C_GREEN2}" "${C_GREEN3}" "${C_GREEN4}" "${C_GREEN5}" "${C_GREEN1}") # Degradado verde EN
ES_BANNER_COLORS=("${C_GREEN5}" "${C_GREEN4}" "${C_GREEN3}" "${C_GREEN2}" "${C_GREEN1}" "${C_GREEN5}") # Degradado verde ES

# Asegura TERM para evitar cortes raros en terminales mínimos
export TERM="${TERM:-xterm-256color}"

# Directorio del script para llamadas fiables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Directorio de librerías (corregido para consistencia)
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)"

# Limpieza de archivos temporales al salir
trap 'rm -f "${STATE_DIR:-/tmp}"/*.tmp* &>/dev/null' EXIT

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
      # Always append without explicit \n literal to avoid issues in banner
      eval "$arr_name+=(\"$esc_line\")"
    done
  }
fi

SAFE_MODE=1
DJ_SAFE_LOCK=1
DRYRUN_FORCE=0
RUN_TEST_MODE=0
SHOW_VERSION=0
SHOW_HELP=0
SCRIPT_VERSION="1.1.0"

SPIN_FRAMES=("\\" "|" "/" "-")
SPIN_IDX=0
SPIN_COLORS=("$C_GREEN1" "$C_GREEN2" "$C_GREEN3" "$C_GREEN4" "$C_GREEN5")
SPIN_COLOR_IDX=0
GHOST_COLORS=("${C_GREEN1}" "${C_GREEN5}") # verde oscuro y verde brillante
GHOST_IDX=0

BASE_DEFAULT="${BASE_PATH}"
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
PRESET_EXCLUDES_PROYECTOS="*/node_modules/*,*/.git/*,*/dist/*,*/build/*,*/.venv/*,*.log,*.tmp,*.dmg,*.iso"

append_extra_root() {
  local new="$1"
  [ -z "$new" ] && return
  [ ! -d "$new" ] && return
  local arr=()
  if [ -n "${EXTRA_SOURCE_ROOTS:-}" ]; then
    IFS=',' read -r -a arr <<<"${EXTRA_SOURCE_ROOTS}"
  fi
  # Safe check for array length avoiding unbound variable error
  if [ "${#arr[@]}" -gt 0 ]; then
    for r in "${arr[@]}"; do
      [ "$r" = "$new" ] && return
    done
  fi
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
    */_DJProducerTools/_DJProducerTools*)
      printf "%s[ERR]%s STATE_DIR parece una matrioshka (%s). Ajusta BASE_PATH a la carpeta raíz, no a _DJProducerTools.\n" "$C_RED" "$C_RESET" "$STATE_DIR"
      return 1
      ;;
  esac
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
  local marker="$CONFIG_DIR/.migration_done"
  
  if [ -f "$marker" ]; then
    return
  fi
  
  if [ ! -d "$legacy" ]; then
    return
  fi
  
  if [ "$legacy" -ef "$STATE_DIR" ]; then
    return
  fi

  # Fix for //_DJProducerTools path issue if BASE_PATH is root or empty
  if [[ "$STATE_DIR" == "//"* ]] || [[ "$STATE_DIR" == "/"* ]] && [ "${#STATE_DIR}" -lt 5 ]; then
     # Fallback to HOME if state dir seems broken for migration
     STATE_DIR="$HOME/_DJProducerTools"
     mkdir -p "$STATE_DIR" "$CONFIG_DIR"
     marker="$CONFIG_DIR/.migration_done"
  fi

  if [ -d "$STATE_DIR" ] && [ "$(ls -A "$STATE_DIR" 2>/dev/null)" ]; then
    # Already populated, mark as done
    touch "$marker"
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
      touch "$marker"
      printf "%s[OK]%s Migración completada.\n" "$C_GRN" "$C_RESET"
      ;;
    DRY)
      printf "[DRY] rsync %s -> %s\n" "$legacy" "$STATE_DIR"
      rsync -an "$legacy"/ "$STATE_DIR"/ 2>/dev/null || true
      ;;
    SKIP)
      touch "$marker"
      printf "%s[INFO]%s Saltando migración (no se volverá a preguntar).\n" "$C_CYN" "$C_RESET"
      ;;
    *)
      printf "%s[INFO]%s Saltando migración temporalmente.\n" "$C_CYN" "$C_RESET"
      ;;
  esac
}

usage() {
  cat <<EOF
DJProducerTools WAX MultiScript
Uso: $(basename "$0") [--help] [--version] [--test] [--dry-run] [--no-interactive]
  --help       Muestra esta ayuda
  --version    Imprime versión y sale
  --test       Solo chequeo ligero de dependencias (sin menú)
  --dry-run    Fuerza DRYRUN_FORCE=1 (sin escrituras)
  --no-interactive  Ejecuta en modo no interactivo (alias de --test)
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

RUN_ACTION=""

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
      --no-interactive|-n)
        export DJPT_NO_INTERACTIVE=1
        RUN_TEST_MODE=1
        shift
        ;;
      --run)
        RUN_ACTION="$2"
        shift 2
        ;;
      *)
        if [[ "$1" == --* ]]; then
          printf "Opción desconocida: %s\n" "$1"
          usage
          exit 1
        fi
        # Not an option, probably a path, break loop
        break
      ;;
    esac
  done
}

select_from_candidates() {
  local prompt="$1"
  shift
  local arr=("$@")
  if [ "${#arr[@]}" -eq 0 ]; then return 1; fi
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

maybe_reuse_file() {
  local file="$1"
  local name="$2"
  if [ -s "$file" ]; then
    printf "%s[INFO]%s Se encontró %s previo.\n" "$C_CYN" "$C_RESET" "$name"
    printf "¿Reusar? [Y/n]: "
    read -r ans
    if [ -z "$ans" ] || [[ "$ans" =~ ^[Yy]$ ]]; then return 1; fi
  fi
  return 0
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
SHARED_CORPUS_DIR=""
SAFETY_PROMPTED=0
VENV_ACTIVE=0
PYTHON_BIN="python3"
ML_ENV_DISABLED=0
ML_PKGS_BASIC="numpy pandas"
ML_PKG_BASIC_MB=300
ML_PKGS_EVO="numpy pandas scikit-learn joblib"
ML_PKG_EVO_MB=450
ML_PKGS_TF="tensorflow"
ML_PKG_TF_MB=600
DJPT_TF_THRESHOLD=0.60
DJPT_TF_TOPN=200
DJPT_TF_BATCH=150
DJPT_ONLINE_REF=0
PROFILES_DIR=""

pause_enter() {
  printf "%s%s%s" "$C_YLW" "$(get_localized_string PRESS_ENTER)" "$C_RESET"
  read -r _
}

ensure_safety_guard() {
  if [ "${SAFETY_PROMPTED:-0}" -eq 1 ]; then
    return 0
  fi
  if { [ "${SAFE_MODE:-1}" -eq 0 ] || [ "${DJ_SAFE_LOCK:-1}" -eq 0 ]; }; then
    SAFETY_PROMPTED=1
    printf "%s[WARN]%s SAFE_MODE o DJ_SAFE_LOCK están en 0. ¿Restaurar a 1/1 para proteger movimientos? [S/n]: " "$C_YLW" "$C_RESET"
    read -r restore_safe
    if [ -z "$restore_safe" ] || [[ "$restore_safe" =~ ^[sSyY]$ ]]; then
      SAFE_MODE=1
      DJ_SAFE_LOCK=1
      save_conf
      printf "%s[OK]%s SAFE_MODE y DJ_SAFE_LOCK restaurados a 1.\n" "$C_GRN" "$C_RESET"
    else
      printf "%s[INFO]%s Se mantiene el estado actual de SAFE_MODE/DJ_SAFE_LOCK (no se volverá a preguntar en esta sesión).\n" "$C_CYN" "$C_RESET"
    fi
  fi
}

check_connectivity() {
  printf "📡 Verificando conectividad a Internet...\n"
  if curl -s --head --request GET https://www.google.com | grep "200" > /dev/null; then 
      printf "✅ Conexión a Internet confirmada.\n"
      return 0
  else
      printf "❌ Error: No se detecta conexión a Internet.\n"
      return 1
  fi
}

action_install_all_python_deps() {
  print_header
  ensure_python_bin || { pause_enter; return; }
  
  check_connectivity || { pause_enter; return; }

  printf "%s[INFO]%s Iniciando gestión de dependencias...\n" "$C_CYN" "$C_RESET"

  # 1. Actualizar pip es CRÍTICO en macOS para descargar los 'wheels' correctos
  printf "🔄 Actualizando pip...\n"
  "$PYTHON_BIN" -m pip install --upgrade pip

  # 2. Definir paquetes base
  pkgs="numpy pandas soundfile librosa pyloudnorm pyserial python-osc onnxruntime tensorflow tensorflow_hub"

  # 3. Lógica condicional para TFLite (Solución al error "No matching distribution" en macOS)
  if [[ "$(uname -s)" == "Darwin" ]]; then
      printf "🍎 macOS detectado: Omitiendo 'tflite-runtime' (usando tensorflow completo).\n"
  else
      printf "🐧 Linux/Otro detectado: Añadiendo 'tflite-runtime'...\n"
      pkgs="$pkgs tflite-runtime"
  fi

  printf "%s[INFO]%s Instalando/actualizando: %s\n" "$C_CYN" "$C_RESET" "$pkgs"
  if "$PYTHON_BIN" -m pip install --upgrade $pkgs; then
    printf "%s[OK]%s Deps instaladas.\n" "$C_GRN" "$C_RESET"
  else
    printf "%s[ERR]%s Falló la instalación de deps.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

setup_tf_perf_env() {
  local cores
  cores=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
  : "${TF_NUM_INTRAOP_THREADS:=$cores}"
  : "${TF_NUM_INTEROP_THREADS:=$cores}"
  : "${OMP_NUM_THREADS:=$cores}"
  export TF_NUM_INTRAOP_THREADS TF_NUM_INTEROP_THREADS OMP_NUM_THREADS
}

ensure_dirs() {
  local existed=0
  if [ -d "$STATE_DIR" ]; then
    existed=1
    # Try to fix ownership if running as root or if writable check fails
    if [ ! -w "$STATE_DIR" ]; then
        printf "%s[WARN]%s STATE_DIR no es escribible. Intentando corregir permisos (sudo)...\n" "$C_YLW" "$C_RESET"
        # Try to change ownership to SUDO_USER if available, else current user
        local target_user="${SUDO_USER:-$(id -un)}"
        if sudo chown -R "$target_user" "$STATE_DIR"; then
           chmod -R u+rw "$STATE_DIR"
           printf "%s[OK]%s Permisos corregidos para %s.\n" "$C_GRN" "$C_RESET" "$target_user"
        else
           printf "%s[ERR]%s Falló la corrección de permisos. Es posible que falle la escritura.\n" "$C_RED" "$C_RESET"
        fi
    fi
  else
    printf "%s[INFO]%s Creando estado en %s\n" "$C_CYN" "$C_RESET" "$STATE_DIR"
  fi
  
  if ! mkdir -p "$STATE_DIR" "$CONFIG_DIR" "$REPORTS_DIR" "$PLANS_DIR" "$LOGS_DIR" "$QUAR_DIR" "$VENV_DIR" "$SHARED_CORPUS_DIR" "$SHARED_CORPUS_DIR/reports" "$SHARED_CORPUS_DIR/plans"; then
      printf "%s[ERR]%s Falló al crear directorios en: %s\nVerifica permisos o si existe un archivo con el mismo nombre.\n" "$C_RED" "$C_RESET" "$STATE_DIR"
  fi

  if [ "$existed" -eq 1 ] && [ -d "$REPORTS_DIR" ]; then
    local repc planc logc
    repc=$(find "$REPORTS_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    planc=$(find "$PLANS_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    logc=$(find "$LOGS_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    printf "%s[INFO]%s Reutilizando _DJProducerTools existente (%s reports, %s plans, %s logs).\n" "$C_CYN" "$C_RESET" "$repc" "$planc" "$logc"
  fi
}

init_paths() {
  # P0-PHASE: Check if DJPT environment variables are already set by bin/djpt
  # If set, use them directly and skip legacy detection
  if [ -n "${DJPT_BASE_DIR:-}" ] && [ -n "${DJPT_STATE_DIR:-}" ]; then
    echo "[INFO] Using DJPT environment variables from bin/djpt"
    # Respect explicit BASE_PATH if already validated by wrappers/entrypoints.
    if [ -n "${BASE_PATH:-}" ] && [ -d "$BASE_PATH" ]; then
      BASE_PATH="$(cd "$BASE_PATH" && pwd)"
    else
      BASE_PATH="$DJPT_BASE_DIR"
      # Default BASE_PATH to parent of install dir for portable scanning
      if [[ "$DJPT_BASE_DIR" == *"/Applications"* ]] || [[ "$DJPT_BASE_DIR" == *"/usr/local"* ]]; then
          BASE_PATH="$HOME"
      else
          BASE_PATH="$(dirname "$DJPT_BASE_DIR")"
      fi
    fi
    STATE_DIR="$DJPT_STATE_DIR"
    CONFIG_DIR="$DJPT_STATE_DIR/config"
    REPORTS_DIR="$DJPT_STATE_DIR/reports"
    PLANS_DIR="$DJPT_STATE_DIR/plans"
    LOGS_DIR="$DJPT_STATE_DIR/logs"
    QUAR_DIR="$DJPT_STATE_DIR/quarantine"
    VENV_DIR="$BASE_PATH/djpt_venv"
    SHARED_CORPUS_DIR="${DJPT_SHARED_CORPUS:-${SHARED_CORPUS_DIR:-$STATE_DIR/shared}}"
    export DJPT_SHARED_CORPUS="$SHARED_CORPUS_DIR"
    export DJPT_MODELS_DIR="${DJPT_MODELS_DIR:-$BASE_PATH/ai/models}"
    PROFILES_DIR="$CONFIG_DIR/profiles"
    BASE_HISTORY_FILE="$CONFIG_DIR/base_history.txt"
    GENERAL_HISTORY_FILE="$CONFIG_DIR/general_history.txt"
    AUDIO_HISTORY_FILE="$CONFIG_DIR/audio_history.txt"
    EXCLUDES_PROFILES_FILE="$CONFIG_DIR/exclude_profiles.tsv"
    STATE_HEALTH_REPORT="$REPORTS_DIR/state_health.txt"
    BANNER_FILE="$STATE_DIR/banner.txt"
    CONF_FILE="$CONFIG_DIR/djpt.conf"
    ML_MODEL_PATH="$STATE_DIR/ml_model.pkl"
    ML_FEATURES_FILE="$STATE_DIR/ml_features.tsv"
    ML_PRED_REPORT="$REPORTS_DIR/ml_predictions.tsv"
    ensure_dirs
    mkdir -p "$PROFILES_DIR"
    touch "$BASE_HISTORY_FILE" "$GENERAL_HISTORY_FILE" "$AUDIO_HISTORY_FILE"
    touch "$EXCLUDES_PROFILES_FILE"
    return
  fi

  # Legacy path detection (only if DJPT variables not set)
  echo "[INFO] DJPT environment variables not set, using legacy path detection"
  # Permite forzar HOME_OVERRIDE para no tocar librerías reales
  if [ -n "${HOME_OVERRIDE:-}" ]; then
    BASE_PATH="$HOME_OVERRIDE"
  fi
  
  # Safety fallback: if BASE_PATH is root or empty, default STATE_DIR to HOME
  if [ -z "$BASE_PATH" ] || [ "$BASE_PATH" = "/" ]; then
     STATE_DIR="$HOME/_DJProducerTools"
  else
     # Evitar anidamiento: si BASE_PATH ya termina en _DJProducerTools, úsalo como STATE_DIR
     if [[ "${BASE_PATH}" == *"_DJProducerTools" ]] || [[ "${BASE_PATH}" == *"_DJProducerTools/" ]]; then
         STATE_DIR="${BASE_PATH%/}"
     else
         STATE_DIR="$BASE_PATH/_DJProducerTools"
     fi
  fi

  CONFIG_DIR="$STATE_DIR/config"
  REPORTS_DIR="$STATE_DIR/reports"
  PLANS_DIR="$STATE_DIR/plans"
  LOGS_DIR="$STATE_DIR/logs"
  QUAR_DIR="$STATE_DIR/quarantine"
  VENV_DIR="$BASE_PATH/djpt_venv"
  SHARED_CORPUS_DIR="${DJPT_SHARED_CORPUS:-${SHARED_CORPUS_DIR:-$STATE_DIR/shared}}"
  export DJPT_SHARED_CORPUS="$SHARED_CORPUS_DIR"
  export DJPT_MODELS_DIR="$BASE_PATH/ai/models"
  PROFILES_DIR="$CONFIG_DIR/profiles"
  BASE_HISTORY_FILE="$CONFIG_DIR/base_history.txt"
  GENERAL_HISTORY_FILE="$CONFIG_DIR/general_history.txt"
  AUDIO_HISTORY_FILE="$CONFIG_DIR/audio_history.txt"
  EXCLUDES_PROFILES_FILE="$CONFIG_DIR/exclude_profiles.tsv"
  STATE_HEALTH_REPORT="$REPORTS_DIR/state_health.txt"

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
  : "${DJPT_SPOTIFY_API:=}"
  : "${DJPT_SPOTIFY_CLIENT_ID:=}"
  : "${DJPT_SPOTIFY_CLIENT_SECRET:=}"
  : "${DJPT_MUSICBRAINZ:=}"
  : "${DJPT_MUSICBRAINZ_APP:=}"
  : "${DJPT_MUSICBRAINZ_CONTACT:=}"
  : "${DJPT_MCP_ENABLED:=0}"
  : "${DJPT_MCP_TRANSPORT:=stdio}"
  : "${DJPT_MCP_SERVER_ENTRY:=}"
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
    printf 'DJPT_TF_THRESHOLD=%q\n' "$DJPT_TF_THRESHOLD"
    printf 'DJPT_TF_TOPN=%q\n' "$DJPT_TF_TOPN"
    printf 'DJPT_TF_BATCH=%q\n' "$DJPT_TF_BATCH"
    printf 'DJPT_ONLINE_REF=%q\n' "$DJPT_ONLINE_REF"
    printf 'DJPT_SPOTIFY_API=%q\n' "${DJPT_SPOTIFY_API:-}"
    printf 'DJPT_SPOTIFY_CLIENT_ID=%q\n' "${DJPT_SPOTIFY_CLIENT_ID:-}"
    printf 'DJPT_SPOTIFY_CLIENT_SECRET=%q\n' "${DJPT_SPOTIFY_CLIENT_SECRET:-}"
    printf 'DJPT_MUSICBRAINZ=%q\n' "${DJPT_MUSICBRAINZ:-}"
    printf 'DJPT_MUSICBRAINZ_APP=%q\n' "${DJPT_MUSICBRAINZ_APP:-}"
    printf 'DJPT_MUSICBRAINZ_CONTACT=%q\n' "${DJPT_MUSICBRAINZ_CONTACT:-}"
    printf 'DJPT_MCP_ENABLED=%q\n' "${DJPT_MCP_ENABLED:-0}"
    printf 'DJPT_MCP_TRANSPORT=%q\n' "${DJPT_MCP_TRANSPORT:-stdio}"
    printf 'DJPT_MCP_SERVER_ENTRY=%q\n' "${DJPT_MCP_SERVER_ENTRY:-}"
    printf 'DJPT_MPC_ENABLED=%q\n' "${DJPT_MPC_ENABLED:-}"
    printf 'DJPT_MPC_LEARNING=%q\n' "${DJPT_MPC_LEARNING:-}"
    printf 'DJPT_ADAPTIVE_UI=%q\n' "${DJPT_ADAPTIVE_UI:-}"
    printf 'DJPT_MPC_THRESHOLD=%q\n' "${DJPT_MPC_THRESHOLD:-}"
    printf 'DJPT_MPC_MODEL=%q\n' "${DJPT_MPC_MODEL:-}"
    printf 'DJPT_NEURAL_BATCH=%q\n' "${DJPT_NEURAL_BATCH:-}"
    printf 'DJPT_WORKER_NODES=%q\n' "${DJPT_WORKER_NODES:-}"
    printf 'DJPT_LOAD_BALANCING=%q\n' "${DJPT_LOAD_BALANCING:-}"
    printf 'DJPT_REALTIME_METRICS=%q\n' "${DJPT_REALTIME_METRICS:-}"
    printf 'DJPT_AUTO_ALERTS=%q\n' "${DJPT_AUTO_ALERTS:-}"
    printf 'DJPT_AUTO_HEALING=%q\n' "${DJPT_AUTO_HEALING:-}"
    printf 'DJPT_ROLLBACK=%q\n' "${DJPT_ROLLBACK:-}"
    printf 'DJPT_USER_PROFILES=%q\n' "${DJPT_USER_PROFILES:-}"
    printf 'DJPT_CONTEXT_CONFIG=%q\n' "${DJPT_CONTEXT_CONFIG:-}"
    printf 'SHARED_CORPUS_DIR=%q\n' "${SHARED_CORPUS_DIR:-}"
    printf 'DJPT_CURRENT_LANG=%q\n' "${DJPT_CURRENT_LANG:-ES}"
  } >"$CONF_FILE"
}

load_conf() {
  if [ -f "$CONF_FILE" ]; then
    set +u
    if ! source "$CONF_FILE" 2>/dev/null; then
      printf "%s[WARN]%s Could not load %s, it will be regenerated.\n" "$C_YLW" "$C_RESET" "$CONF_FILE" # Cannot localize here
    fi
  fi
  if [ -f "$CONFIG_DIR/mcp.env" ]; then
    set +u
    if ! source "$CONFIG_DIR/mcp.env" 2>/dev/null; then
      printf "%s[WARN]%s Could not load %s\n" "$C_YLW" "$C_RESET" "$CONFIG_DIR/mcp.env"
    fi
  fi
  set -u
}

mcp_management_menu() {
  local mcp_mgr="$SCRIPT_DIR/mcp_env_manager.py"
  if [ ! -f "$mcp_mgr" ]; then
    printf "%s[ERR]%s Missing MCP manager: %s\n" "$C_RED" "$C_RESET" "$mcp_mgr"
    pause_enter
    return 1
  fi

  while true; do
    clear
    printf "%s=== MCP) Setup & Pairing ===%s\n" "$BANNER" "$C_RESET"
    printf "Current status:\n"
    printf -- "- MCP enabled: %s\n" "${DJPT_MCP_ENABLED:-0}"
    printf -- "- Transport: %s\n" "${DJPT_MCP_TRANSPORT:-stdio}"
    printf -- "- Server entry: %s\n" "${DJPT_MCP_SERVER_ENTRY:-$SCRIPT_DIR/../mcp_server_fixed.py}"
    printf "\nOptions:\n"
    printf "  1) MCP status\n"
    printf "  2) Install MCP dependency (pip)\n"
    printf "  3) Pair MCP with this environment\n"
    printf "  4) MCP smoke test\n"
    printf "  5) Toggle MCP enabled/disabled\n"
    printf "  B) Back\n"
    printf "Option: "
    if ! read -r mcp_opt; then
      break
    fi
    mcp_opt="$(echo "$mcp_opt" | xargs)"
    [ -z "$mcp_opt" ] && continue

    case "$mcp_opt" in
      1)
        "$PYTHON_BIN" "$mcp_mgr" status --json || true
        pause_enter
        ;;
      2)
        printf "%s[INFO]%s Installing MCP with %s\n" "$C_CYN" "$C_RESET" "$PYTHON_BIN"
        "$PYTHON_BIN" "$mcp_mgr" install --json || true
        pause_enter
        ;;
      3)
        "$PYTHON_BIN" "$mcp_mgr" pair --write-env "$CONFIG_DIR/mcp.env" --json || true
        DJPT_MCP_ENABLED=1
        DJPT_MCP_TRANSPORT="${DJPT_MCP_TRANSPORT:-stdio}"
        DJPT_MCP_SERVER_ENTRY="${DJPT_MCP_SERVER_ENTRY:-$SCRIPT_DIR/../mcp_server_fixed.py}"
        save_conf
        printf "%s[OK]%s MCP pairing saved.\n" "$C_GRN" "$C_RESET"
        pause_enter
        ;;
      4)
        "$PYTHON_BIN" "$mcp_mgr" smoke --json || true
        pause_enter
        ;;
      5)
        if [ "${DJPT_MCP_ENABLED:-0}" = "1" ]; then
          DJPT_MCP_ENABLED=0
        else
          DJPT_MCP_ENABLED=1
        fi
        save_conf
        printf "%s[OK]%s DJPT_MCP_ENABLED=%s\n" "$C_GRN" "$C_RESET" "${DJPT_MCP_ENABLED:-0}"
        pause_enter
        ;;
      B|b|0)
        break
        ;;
      *)
        printf "%s[WARN]%s Invalid option.\n" "$C_YLW" "$C_RESET"
        pause_enter
        ;;
    esac
  done
}

submenu_I_integrations() {
  local integration_checks_py="$SCRIPT_DIR/integration_checks.py"
  while true; do
    clear
    local local_serato_root="${SERATO_ROOT:-$BASE_PATH/_Serato_}"
    local serato_parser_status="Not available"
    local serato_tools_status="Not available"
    if "$PYTHON_BIN" - <<'PY' >/dev/null 2>&1
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec("serato_crate") else 1)
PY
    then
      serato_parser_status="Available"
    fi
    if "$PYTHON_BIN" - <<'PY' >/dev/null 2>&1
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec("serato_tools") else 1)
PY
    then
      serato_tools_status="Available"
    fi
    local spotify_client_id="${DJPT_SPOTIFY_CLIENT_ID:-${DJPT_SPOTIFY_API:-}}"
    local spotify_client_secret="${DJPT_SPOTIFY_CLIENT_SECRET:-}"
    local musicbrainz_app="${DJPT_MUSICBRAINZ_APP:-DJProducerTools}"
    local musicbrainz_contact="${DJPT_MUSICBRAINZ_CONTACT:-${DJPT_MUSICBRAINZ:-}}"
    local spotify_status="Not configured"
    [ -n "$spotify_client_id" ] && [ -n "$spotify_client_secret" ] && spotify_status="Credentials configured"
    local musicbrainz_status="$musicbrainz_app"
    [ -n "$musicbrainz_contact" ] && musicbrainz_status="$musicbrainz_status ($musicbrainz_contact)"

    printf "%s=== Integration Stack (Local/Web) ===%s\n" "$BANNER" "$C_RESET"
    printf "Current status:\n"
    printf -- "- Serato (local filesystem): %s\n" "$local_serato_root"
    printf -- "- Crate parser (serato-crate): %s\n" "$serato_parser_status"
    printf -- "- Serato tools (serato-tools): %s\n" "$serato_tools_status"
    printf -- "- Spotify (OAuth Client Credentials): %s\n" "$spotify_status"
    printf -- "- MusicBrainz (User-Agent): %s\n" "$musicbrainz_status"
    if [ -f "$integration_checks_py" ]; then
      printf -- "- Integration checker: %s\n" "$integration_checks_py"
    else
      printf -- "- Integration checker: %sMissing%s\n" "$C_YLW" "$C_RESET"
    fi
    printf "\nOptions:\n"
    printf "  1) Configure local Serato root\n"
    printf "  2) Configure Spotify (Client ID / Client Secret)\n"
    printf "  3) Configure MusicBrainz (App / Contact)\n"
    printf "  4) Full integration diagnostics\n"
    printf "  5) Configure local MCP\n"
    printf "  6) Test Spotify OAuth now\n"
    printf "  7) Test MusicBrainz now\n"
    printf "  8) Install Serato deps (serato-crate + serato-tools)\n"
    printf "  9) ShazamIO: Acoustic audio identification (MPC/Serato/Production)\n"
    printf "  B) Back\n"
    printf "Option: "
    if ! read -r api_opt; then
      break
    fi
    api_opt="$(echo "$api_opt" | xargs)"
    [ -z "$api_opt" ] && continue

    case "$api_opt" in
      1)
        printf "Local Serato root (ENTER keeps: %s): " "${SERATO_ROOT:-$BASE_PATH/_Serato_}"
        read -r serato_root_input
        serato_root_input="$(echo "$serato_root_input" | xargs)"
        if [ -n "$serato_root_input" ]; then
          SERATO_ROOT="$serato_root_input"
          save_conf
        fi
        if [ -d "${SERATO_ROOT:-$BASE_PATH/_Serato_}" ]; then
          printf "%s[OK]%s Serato root set: %s\n" "$C_GRN" "$C_RESET" "${SERATO_ROOT:-$BASE_PATH/_Serato_}"
        else
          printf "%s[WARN]%s Serato root not found: %s\n" "$C_YLW" "$C_RESET" "${SERATO_ROOT:-$BASE_PATH/_Serato_}"
        fi
        pause_enter
        ;;
      2)
        printf "Spotify Client ID (ENTER keeps): "
        read -r spotify_client_id_input
        spotify_client_id_input="$(echo "$spotify_client_id_input" | xargs)"
        printf "Spotify Client Secret (ENTER keeps): "
        read -r spotify_client_secret_input
        spotify_client_secret_input="$(echo "$spotify_client_secret_input" | xargs)"
        if [ -n "$spotify_client_id_input" ]; then
          DJPT_SPOTIFY_CLIENT_ID="$spotify_client_id_input"
          DJPT_SPOTIFY_API="$spotify_client_id_input"
        fi
        if [ -n "$spotify_client_secret_input" ]; then
          DJPT_SPOTIFY_CLIENT_SECRET="$spotify_client_secret_input"
        fi
        save_conf
        printf "%s[OK]%s Spotify OAuth config updated.\n" "$C_GRN" "$C_RESET"
        pause_enter
        ;;
      3)
        printf "MusicBrainz App Name (ENTER keeps: %s): " "${DJPT_MUSICBRAINZ_APP:-DJProducerTools}"
        read -r mb_app_input
        mb_app_input="$(echo "$mb_app_input" | xargs)"
        printf "MusicBrainz Contact Email/URL (ENTER keeps): "
        read -r mb_contact_input
        mb_contact_input="$(echo "$mb_contact_input" | xargs)"
        if [ -n "$mb_app_input" ]; then
          DJPT_MUSICBRAINZ_APP="$mb_app_input"
        fi
        if [ -n "$mb_contact_input" ]; then
          DJPT_MUSICBRAINZ_CONTACT="$mb_contact_input"
          DJPT_MUSICBRAINZ="$mb_contact_input"
        fi
        save_conf
        printf "%s[OK]%s MusicBrainz config updated.\n" "$C_GRN" "$C_RESET"
        pause_enter
        ;;
      4)
        if [ -f "$integration_checks_py" ]; then
          "$PYTHON_BIN" "$integration_checks_py" all \
            --serato-root "${SERATO_ROOT:-$BASE_PATH/_Serato_}" \
            --spotify-client-id "${DJPT_SPOTIFY_CLIENT_ID:-${DJPT_SPOTIFY_API:-}}" \
            --spotify-client-secret "${DJPT_SPOTIFY_CLIENT_SECRET:-}" \
            --musicbrainz-app "${DJPT_MUSICBRAINZ_APP:-DJProducerTools}" \
            --musicbrainz-contact "${DJPT_MUSICBRAINZ_CONTACT:-${DJPT_MUSICBRAINZ:-}}" \
            --json || true
        else
          printf "%s[ERR]%s Missing %s\n" "$C_RED" "$C_RESET" "$integration_checks_py"
        fi
        pause_enter
        ;;
      5)
        mcp_management_menu
        ;;
      6)
        if [ -f "$integration_checks_py" ]; then
          "$PYTHON_BIN" "$integration_checks_py" spotify \
            --spotify-client-id "${DJPT_SPOTIFY_CLIENT_ID:-${DJPT_SPOTIFY_API:-}}" \
            --spotify-client-secret "${DJPT_SPOTIFY_CLIENT_SECRET:-}" \
            --json || true
        else
          printf "%s[ERR]%s Missing %s\n" "$C_RED" "$C_RESET" "$integration_checks_py"
        fi
        pause_enter
        ;;
      7)
        if [ -f "$integration_checks_py" ]; then
          "$PYTHON_BIN" "$integration_checks_py" musicbrainz \
            --musicbrainz-app "${DJPT_MUSICBRAINZ_APP:-DJProducerTools}" \
            --musicbrainz-contact "${DJPT_MUSICBRAINZ_CONTACT:-${DJPT_MUSICBRAINZ:-}}" \
            --json || true
        else
          printf "%s[ERR]%s Missing %s\n" "$C_RED" "$C_RESET" "$integration_checks_py"
        fi
        pause_enter
        ;;
      8)
        printf "Install optional Serato Python packages?\n"
        printf "  - serato-crate\n"
        printf "  - serato-tools\n"
        printf "Continue? [y/N]: "
        read -r install_serato_opt
        install_serato_opt="$(echo "$install_serato_opt" | xargs)"
        case "$install_serato_opt" in
          y|Y|yes|YES)
            if "$PYTHON_BIN" -m pip install --disable-pip-version-check serato-crate serato-tools; then
              printf "%s[OK]%s Serato packages installed.\n" "$C_GRN" "$C_RESET"
            else
              printf "%s[ERR]%s Failed installing Serato packages.\n" "$C_RED" "$C_RESET"
            fi
            if [ -f "$integration_checks_py" ]; then
              "$PYTHON_BIN" "$integration_checks_py" serato --serato-root "${SERATO_ROOT:-$BASE_PATH/_Serato_}" --json || true
            fi
            ;;
          *)
            printf "%s[INFO]%s Installation canceled.\n" "$C_CYN" "$C_RESET"
            ;;
        esac
        pause_enter
        ;;
      9)
        printf "%s[INFO]%s ShazamIO Acoustic Recognition (Resilient Engine + Fallback)...\n" "$C_CYN" "$C_RESET"
        local shazam_py="$LIB_DIR/shazam_resilient_engine.py"
        if [ -f "$shazam_py" ]; then
          printf "Select target to recognize:\n"
          printf "  1) Akai MPC Sample (/Volumes/MPCSMPL)\n"
          printf "  2) Serato DJ Pro (/Volumes/SanDisk SSD/00_SERATO_MUSICA)\n"
          printf "  3) Production & Ableton (/Volumes/samsung PSSDT7)\n"
          printf "  4) Current / Custom directory\n"
          printf "Option [1-4]: "
          read -r shz_target_opt
          local shz_path=""
          case "$shz_target_opt" in
            1) shz_path="/Volumes/MPCSMPL" ;;
            2) shz_path="/Volumes/SanDisk SSD/00_SERATO_MUSICA" ;;
            3) shz_path="/Volumes/samsung PSSDT7" ;;
            4)
              printf "Scan path: "
              read -r user_shz_path
              shz_path="${user_shz_path:-$BASE_PATH}"
              ;;
            *) shz_path="$BASE_PATH" ;;
          esac

          printf "Max candidates to process (ENTER for 25): "
          read -r shz_limit
          shz_limit="${shz_limit:-25}"

          local shz_out="$BASE_PATH/_DJProducerTools/reports/shazam_matches.tsv"
          printf "%s[RUN]%s Processing candidates in %s...\n" "$C_CYN" "$C_RESET" "$shz_path"
          if command -v uv &>/dev/null; then
            uv run --no-project --with shazamio python3 "$shazam_py" --base "$shz_path" --out "$shz_out" --limit "$shz_limit"
          else
            "$PYTHON_BIN" "$shazam_py" --base "$shz_path" --out "$shz_out" --limit "$shz_limit"
          fi
          printf "%s[OK]%s Report saved to: %s\n" "$C_GRN" "$C_RESET" "$shz_out"
        else
          printf "%s[ERR]%s Missing %s\n" "$C_RED" "$C_RESET" "$shazam_py"
        fi
        pause_enter
        ;;
      B|b|0)
        break
        ;;
      *)
        printf "%s[WARN]%s Invalid option.\n" "$C_YLW" "$C_RESET"
        pause_enter
        ;;
    esac
  done
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
  
  # Check if venv seems valid
  if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/python3" ] && [ -f "$VENV_DIR/bin/activate" ]; then
    # Try to verify if deps are there
    if [ "$want_tf" -eq 1 ]; then
        if "$VENV_DIR/bin/python3" -c "import tensorflow" >/dev/null 2>&1; then
           # shellcheck disable=SC1090
           . "$VENV_DIR/bin/activate"
           VENV_ACTIVE=1
           return
        fi
    else
        # Basic check
        if "$VENV_DIR/bin/python3" -c "import numpy" >/dev/null 2>&1; then
           # shellcheck disable=SC1090
           . "$VENV_DIR/bin/activate"
           VENV_ACTIVE=1
           return
        fi
    fi
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
      check_connectivity || { printf "%s[ERR]%s Sin conexión a Internet.\n" "$C_RED" "$C_RESET"; ML_ENV_DISABLED=1; return; }
      if ! command -v python3 >/dev/null 2>&1; then
        printf "%s[ERR]%s python3 no encontrado. Instálalo e inténtalo de nuevo.\n" "$C_RED" "$C_RESET"
        ML_ENV_DISABLED=1
        return
      fi
      # If venv exists but broken, warn/recreate
      if [ -d "$VENV_DIR" ]; then
         printf "%s[WARN]%s Recreando venv existente en %s...\n" "$C_YLW" "$C_RESET" "$VENV_DIR"
         rm -rf "$VENV_DIR"
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
        printf "Actualizando pip...\n"
        "$VENV_DIR/bin/pip" install --upgrade pip || printf "%s[WARN]%s Falló update pip.\n" "$C_YLW" "$C_RESET"
        printf "Instalando paquetes ML (%s)...\n" "${pkgs_arr[*]}"
        if ! "$VENV_DIR/bin/pip" install "${pkgs_arr[@]}"; then
             printf "%s[ERR]%s Falló la instalación de paquetes ML. Revisa tu conexión.\n" "$C_RED" "$C_RESET"
        fi
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
      check_connectivity || return 1
      printf "Actualizando pip...\n"
      "$PYTHON_BIN" -m pip install --upgrade pip || printf "%s[WARN]%s Falló update pip.\n" "$C_YLW" "$C_RESET"
      printf "Instalando módulos (%s)...\n" "${modules[*]}"
      "$PYTHON_BIN" -m pip install "${modules[@]}" || {
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
    while IFS= read -r line; do
      printf "%s%s%s\n" "$C_PURP" "$line" "$C_RESET"
    done < "$BANNER_FILE"
  else
    local banner_colors
    case "$DJPT_CURRENT_LANG" in
      en) banner_colors=("${EN_BANNER_COLORS[@]}") ;;
      *)  banner_colors=("${ES_BANNER_COLORS[@]}") ;; # Default to Spanish colors
    esac

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
      local color="${banner_colors[$((idx % ${#banner_colors[@]}))]}"
      printf "%s%s%s\n" "$color" "${banner_lines[$idx]}" "$C_RESET"
    done
  fi
  printf "%s⚡ Por Astro One Deep 🎵%s\n\n" "$C_PURP" "$C_RESET"

  printf "%sWAX SPACESHIP  DJProducerTools%s\n" "$C_CYN" "$C_RESET"
  printf "%sBase:%s %s\n" "$C_YLW" "$C_RESET" "$BASE_PATH"
  local ml_status_str
  if [ "${DJPT_OFFLINE:-0}" -eq 1 ]; then
    ml_status_str="${C_RED}Offline ${C_PURP}ML${C_RESET}"
  else
    ml_status_str="${C_GRN}Online ${C_PURP}ML${C_RESET}"
  fi
  printf "%s\n" "$ml_status_str"

  local safemode_str
  local lock_str
  local dryrun_str

  if [ "$SAFE_MODE" -eq 1 ]; then
    safemode_str="${C_GRN}ON${C_RESET}"
  else
    safemode_str="${C_RED}OFF${C_RESET}"
  fi

  if [ "$DJ_SAFE_LOCK" -eq 1 ]; then
    lock_str="${C_GRN}ACTIVO${C_RESET}"
  else
    lock_str="${C_RED}INACTIVO${C_RESET}"
  fi

  if [ "$DRYRUN_FORCE" -eq 1 ]; then
    dryrun_str="${C_GRN}ON${C_RESET}"
  else
    dryrun_str="${C_RED}OFF${C_RESET}"
  fi

  printf "%sAsistente:%s %sON%s | %sAutoTools:%s %sON%s | %sSafeMode:%s %s | %sDJ_SAFE_LOCK:%s %s | %sDryRunForce:%s %s\n" \
    "$C_BLU" "$C_RESET" "$C_GRN" "$C_RESET" \
    "$C_BLU" "$C_RESET" "$C_GRN" "$C_RESET" \
    "$C_BLU" "$C_RESET" "$safemode_str" \
    "$C_BLU" "$C_RESET" "$lock_str" \
    "$C_BLU" "$C_RESET" "$dryrun_str"

  printf "────────────────────────────────────────────────────────────\n"
}

print_menu() {
  printf "%s%s%s\n" "$C_GRN" "$(get_localized_string MENU_TITLE)" "$C_RESET"
  printf "%s%s%s\n" "$C_CYN" "$(get_localized_string MENU_INTERFACE)" "$C_RESET"
  printf "  %sC)%s %s%s%s\n" "$C_GRN" "$C_RESET" "$C_PURP" "$(get_localized_string MENU_C_CHAT)" "$C_RESET"
  printf "\n"
  printf "%s%s%s\n" "$C_CYN" "$(get_localized_string MENU_CORE)" "$C_RESET"
  printf "  %s1)%s %s\n" "$C_GRN" "$C_RESET" "$(get_localized_string MENU_1_STATUS)"
  printf "  %s2)%s %s\n" "$C_GRN" "$C_RESET" "$(get_localized_string MENU_2_CHANGE_BASE)"
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

  printf "%s%s%s\n" "$C_CYN" "$(get_localized_string MENU_MEDIA)" "$C_RESET"
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

  printf "%s%s%s\n" "$C_CYN" "$(get_localized_string MENU_CLEANUP)" "$C_RESET"
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
  printf "  %sAI)%s AI STATUS (MLX/Ollama/Embeddings)\n" "$C_GRN" "$C_RESET"
  printf "  %s36)%s Limpiar WEB (submenú)\n" "$C_GRN" "$C_RESET"
  printf "  %s37)%s WEB: Whitelist Manager (dominios permitidos)\n" "$C_GRN" "$C_RESET"
  printf "  %s38)%s Limpiar WEB en Playlists (.m3u/.m3u8)\n" "$C_GRN" "$C_RESET"
  printf "  %s39)%s Limpiar WEB en TAGS (mutagen) (plan)\n" "$C_GRN" "$C_RESET"
  printf "\n"

  printf "%s%s%s\n" "$C_CYN" "$(get_localized_string MENU_DEEP_ML)" "$C_RESET"
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

  printf "%s%s%s\n" "$C_CYN" "$(get_localized_string MENU_EXTRAS)" "$C_RESET"
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
  printf "  %s69)%s Sincronizar corpus compartido (hashes/ML entre discos)\n" "$C_GRN" "$C_RESET"
  printf "\n"

  printf "%s🤖 AI / Chat / Config (70-90)%s\n" "$C_CYN" "$C_RESET"
  printf "  %s70)%s Estado IA (MLX/Ollama/Embeddings)\n" "$C_GRN" "$C_RESET"
  printf "  %s71)%s Gestor de backends IA (multi-backend)\n" "$C_GRN" "$C_RESET"
  printf "  %s72)%s Instalar deps IA (stack)\n" "$C_GRN" "$C_RESET"
  printf "  %s73)%s Chat IA (CLI)\n" "$C_GRN" "$C_RESET"
  printf "  %s74)%s Config avanzada IA (ai_model_params.toml)\n" "$C_GRN" "$C_RESET"
  printf "  %s75)%s Entrenar modelos IA\n" "$C_GRN" "$C_RESET"
  printf "  %s76)%s Base de conocimiento IA\n" "$C_GRN" "$C_RESET"
  printf "  %s77)%s Config UI IA\n" "$C_GRN" "$C_RESET"
  printf "  %s78)%s Escaneo inteligente (IA)\n" "$C_GRN" "$C_RESET"
  printf "  %s79)%s Recuperación / diagnóstico IA\n" "$C_GRN" "$C_RESET"
  printf "  %s80)%s Menú IA avanzado\n" "$C_GRN" "$C_RESET"
  printf "  %s81)%s IA Lab (experimentos)\n" "$C_GRN" "$C_RESET"
  printf "  %s82)%s Optimización IA\n" "$C_GRN" "$C_RESET"
  printf "  %s83)%s Config global IA\n" "$C_GRN" "$C_RESET"
  printf "  %s84)%s Sistema de aprendizaje IA\n" "$C_GRN" "$C_RESET"
  printf "  %s85)%s Educador IA\n" "$C_GRN" "$C_RESET"
  printf "  %s86)%s Análisis de documentos IA\n" "$C_GRN" "$C_RESET"
  printf "  %s87)%s Install Local Models\n" "$C_GRN" "$C_RESET"
  printf "  %s88)%s Local Models Manager\n" "$C_GRN" "$C_RESET"
  printf "  %s89)%s Enhanced Chat CLI\n" "$C_GRN" "$C_RESET"
  printf "  %s90)%s Launch SERATO Organizer\n" "$C_GRN" "$C_RESET"

  printf "\n"
  printf "%sL)%s %s\n" "$C_GRN" "$C_RESET" "$(get_localized_string MENU_L_LIBS)"
  printf "%sI)%s Integration Stack (Serato/Spotify/MusicBrainz/MCP)\n" "$C_GRN" "$C_RESET"
  printf "%sD)%s %s\n" "$C_GRN" "$C_RESET" "$(get_localized_string MENU_D_DUPES)"
  printf "%sV)%s %s\n" "$C_GRN" "$C_RESET" "$(get_localized_string MENU_V_VISUALS)"
  printf "%sH)%s %s\n" "$C_GRN" "$C_RESET" "$(get_localized_string MENU_H_HELP)"
  printf "%s0)%s %s\n" "$C_GRN" "$C_RESET" "$(get_localized_string MENU_0_EXIT)"
}

invalid_option() {
  printf "%s[ERR]%s %s\n" "$C_RED" "$C_RESET" "$(get_localized_string INVALID_OPTION)"
  pause_enter
}

action_chat_cli() {
  print_header
  if ! command -v python3 >/dev/null 2>&1; then
    printf "%s[ERR]%s Se requiere Python3 para el Chat CLI.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  
  chat_script="$ROOT_DIR/scripts/djpt_chat_cli.py"
  if [ ! -f "$chat_script" ]; then
    chat_script="$LIB_DIR/djpt_chat_cli.py"
  fi
  if [ ! -f "$chat_script" ]; then
    chat_script="$(dirname "$0")/djpt_chat_cli.py"
  fi
  
  if [ ! -f "$chat_script" ]; then
    printf "%s[ERR]%s Script de Chat CLI no encontrado en %s\n" "$C_RED" "$C_RESET" "$chat_script"
    pause_enter; return
  fi

  printf "%s[INFO]%s Iniciando DJPT Chat CLI...\n" "$C_CYN" "$C_RESET"
  BASE_PATH="$BASE_PATH" VENV_DIR="$VENV_DIR" SCRIPT_DIR="$SCRIPT_DIR" python3 "$chat_script"
  
  printf "\n%s[INFO]%s Regreso desde Chat CLI.\n" "$C_CYN" "$C_RESET"
  pause_enter
}

action_1_status() {
  print_header
  printf "%s[INFO]%s Obteniendo estado desde el módulo Python...\n" "$C_CYN" "$C_RESET"
  
  local system_actions_script="$LIB_DIR/system_actions.py"
  if [ ! -f "$system_actions_script" ]; then
    printf "%s[ERR]%s No se encuentra el script de acciones del sistema: %s\n" "$C_RED" "$C_RESET" "$system_actions_script"
    pause_enter
    return
  fi

  "$PYTHON_BIN" "$system_actions_script" status \
    --base-path "$BASE_PATH" \
    --state-dir "$STATE_DIR" \
    --reports-dir "$REPORTS_DIR" \
    --plans-dir "$PLANS_DIR" \
    --quar-dir "$QUAR_DIR" \
    --venv-dir "$VENV_DIR" \
    --shared-corpus-dir "$SHARED_CORPUS_DIR" \
    --extra-source-roots "${EXTRA_SOURCE_ROOTS:-}" \
    --safe-mode "$SAFE_MODE" \
    --dj-safe-lock "$DJ_SAFE_LOCK" \
    --dryrun-force "$DRYRUN_FORCE"

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
  if [ -s "$out" ]; then
    printf "%s[INFO]%s Se encontró un scan previo (%s).\n" "$C_CYN" "$C_RESET" "$out"
    printf "¿Deseas REUSAR el archivo existente? [Y/n] (n = regenerar): "
    read -r reuse
    if [ -z "$reuse" ] || [[ "$reuse" =~ ^[Yy]$ ]]; then
      printf "%s[OK]%s Reusando workspace_scan.tsv existente.\n" "$C_GRN" "$C_RESET"
      pause_enter
      return
    fi
  fi

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
  
  # Verify backup integrity
  verify_backup_integrity "$dest" "serato"
  
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
  
  # Verify backup integrity
  verify_backup_integrity "$dest" "dj_metadata"
  
  pause_enter
}

verify_backup_integrity() {
  local backup_dir="$1"
  local backup_name="$2"
  
  if [ ! -d "$backup_dir" ]; then
    printf "%s[ERR]%s Directorio de backup no encontrado: %s\n" "$C_RED" "$C_RESET" "$backup_dir"
    return 1
  fi
  
  printf "%s[INFO]%s Verificando integridad del backup %s...\n" "$C_CYN" "$C_RESET" "$backup_name"
  
  # Count files and directories
  local file_count=$(find "$backup_dir" -type f | wc -l | tr -d ' ')
  local dir_count=$(find "$backup_dir" -type d | wc -l | tr -d ' ')
  local total_size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1)
  
  # Check for empty files (potential corruption indicators)
  local empty_files=$(find "$backup_dir" -type f -size 0 | wc -l | tr -d ' ')
  
  # Check for recent modifications (might indicate incomplete backup)
  local recent_files=$(find "$backup_dir" -type f -mtime -1 2>/dev/null | wc -l | tr -d ' ')
  
  printf "%s[INFO]%s Estadísticas del backup:\n" "$C_CYN" "$C_RESET"
  printf "  - Archivos: %s\n" "$file_count"
  printf "  - Directorios: %s\n" "$dir_count"
  printf "  - Tamaño total: %s\n" "$total_size"
  printf "  - Archivos vacíos: %s\n" "$empty_files"
  printf "  - Archivos modificados recientemente (últimas 24h): %s\n" "$recent_files"
  
  # Basic integrity checks
  local issues=0
  
  if [ "$file_count" -eq 0 ]; then
    printf "%s[WARN]%s No se encontraron archivos en el backup.\n" "$C_YLW" "$C_RESET"
    issues=$((issues + 1))
  fi
  
  if [ "$empty_files" -gt 10 ]; then
    printf "%s[WARN]%s Se encontraron %s archivos vacíos (posible corrupción).\n" "$C_YLW" "$C_RESET" "$empty_files"
    issues=$((issues + 1))
  fi
  
  if [ "$recent_files" -gt "$((file_count / 10))" ]; then
    printf "%s[WARN]%s Muchos archivos modificados recientemente (backup posiblemente incompleto).\n" "$C_YLW" "$C_RESET"
    issues=$((issues + 1))
  fi
  
  # Generate integrity report
  local integrity_report="$REPORTS_DIR/backup_integrity_${backup_name}_$(date +%s).tsv"
  mkdir -p "$REPORTS_DIR"
  
  {
    echo "metric\tvalue"
    echo "backup_name\t$backup_name"
    echo "backup_path\t$backup_dir"
    echo "file_count\t$file_count"
    echo "directory_count\t$dir_count"
    echo "total_size\t$total_size"
    echo "empty_files\t$empty_files"
    echo "recent_files\t$recent_files"
    echo "issues_found\t$issues"
    echo "timestamp\t$(date -Iseconds)"
  } > "$integrity_report"
  
  if [ "$issues" -eq 0 ]; then
    printf "%s[OK]%s Integridad del backup verificada sin problemas.\n" "$C_GRN" "$C_RESET"
    printf "%s[INFO]%s Reporte guardado en: %s\n" "$C_CYN" "$C_RESET" "$integrity_report"
    return 0
  else
    printf "%s[WARN]%s Se encontraron %s posibles problemas en el backup.\n" "$C_YLW" "$C_RESET" "$issues"
    printf "%s[INFO]%s Reporte guardado en: %s\n" "$C_CYN" "$C_RESET" "$integrity_report"
    return 1
  fi
}

action_9_hash_index() {
  out="$REPORTS_DIR/hash_index.tsv"
  if [ -s "$out" ]; then
    printf "%s[INFO]%s Se encontró un índice previo (%s).\n" "$C_CYN" "$C_RESET" "$out"
    printf "¿Deseas REUSAR el archivo existente? [Y/n] (n = regenerar): "
    read -r reuse
    if [ -z "$reuse" ] || [[ "$reuse" =~ ^[Yy]$ ]]; then
      printf "%s[OK]%s Reusando hash_index.tsv existente.\n" "$C_GRN" "$C_RESET"
      pause_enter
      return
    fi
  fi

  confirm_heavy "Hash index completo (SHA-256)" || return
  print_header
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
  dupes_builder_script="$LIB_DIR/dupes_plan_builder.py"

  printf "%s[INFO]%s Generando plan de duplicados EXACTO vía script Python...\n" "$C_CYN" "$C_RESET"
  
  if ! ensure_python_bin; then
      printf "%s[ERR]%s Se necesita Python para generar el plan de duplicados.\n" "$C_RED" "$C_RESET"
      pause_enter
      return
  fi

  if [ ! -f "$dupes_builder_script" ]; then
      printf "%s[ERR]%s No se encuentra el script constructor: %s\n" "$C_RED" "$C_RESET" "$dupes_builder_script"
      pause_enter
      return
  fi

  if "$PYTHON_BIN" "$dupes_builder_script" \
      --input "$hash_file" \
      --out-tsv "$plan_tsv" \
      --out-json "$plan_json"; then
    printf "%s[OK]%s Plan generado: %s y %s\n" "$C_GRN" "$C_RESET" "$plan_tsv" "$plan_json"
  else
    printf "%s[ERR]%s Falló la generación del plan de duplicados.\n" "$C_RED" "$C_RESET"
  fi
  
  pause_enter
}

action_11_quarantine_from_plan() {
    ensure_safety_guard
    print_header
    local plan_tsv="$PLANS_DIR/dupes_plan.tsv"
    local executor_script="$LIB_DIR/quarantine_executor.py"

    if [ ! -f "$plan_tsv" ]; then
        printf "%s[ERR]%s No existe dupes_plan.tsv. Ejecuta la opción 10 primero.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
    fi

    if ! ensure_python_bin; then
        printf "%s[ERR]%s Se necesita Python para ejecutar el plan de cuarentena.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
    fi

    printf "%s[INFO]%s Aplicando quarantine desde plan (SAFE_MODE=%s, DRYRUN_FORCE=%s).\n" "$C_CYN" "$C_RESET" "$SAFE_MODE" "$DRYRUN_FORCE"
    local sample_count
    sample_count=$(awk -F'\t' '$2=="QUARANTINE"{c++} END {print c+0}' "$plan_tsv")
    printf "Acciones QUARANTINE a ejecutar: %s\n" "$sample_count"

    if [ "$sample_count" -gt 0 ]; then
        printf "Muestra de las primeras 5 entradas a poner en cuarentena:\n"
        awk -F'\t' '$2=="QUARANTINE"{print "  - " $3}' "$plan_tsv" | head -5
    fi

    local dry_run_flag=""
    if [ "$SAFE_MODE" -eq 1 ] || [ "$DJ_SAFE_LOCK" -eq 1 ] || [ "$DRYRUN_FORCE" -eq 1 ]; then
        printf "\n%s[WARN]%s SAFE_MODE/DJ_SAFE_LOCK/DRYRUN_FORCE activos. Se ejecutará en modo simulación (dry-run).\n" "$C_YLW" "$C_RESET"
        dry_run_flag="--dry-run"
    else
        printf "\n%s[WARN]%s Estás a punto de MOVER %s archivos a la cuarentena. Esta acción es reversible desde el menú 12.\n" "$C_RED" "$C_RESET" "$sample_count"
        printf "%s[CRITICAL]%s ¡ESTA ACCIÓN AFECTARÁ TUS ARCHIVOS! Los archivos serán movidos a %s\n" "$C_RED" "$C_RESET" "$QUAR_DIR"
        printf "Para confirmar, escribe EXACTAMENTE 'YES' en mayúsculas: "
        read -r ans
        if [ "$ans" != "YES" ]; then
            printf "%s[INFO]%s Cancelado. Respuesta: '%s' (se requería 'YES')\n" "$C_CYN" "$C_RESET" "$ans"
            pause_enter
            return
        fi
        printf "%s[OK]%s Confirmación recibida. Procediendo con la cuarentena...\n" "$C_GRN" "$C_RESET"
    fi

    "$PYTHON_BIN" "$executor_script" --plan "$plan_tsv" --quar-dir "$QUAR_DIR" ${dry_run_flag}

    pause_enter
}

action_12_quarantine_manager() {
  local manager_script="$LIB_DIR/quarantine_manager.py"

  while true; do
    clear
    printf "%s=== Quarantine Manager ===%s\n" "$C_CYN" "$C_RESET"
    printf "QUAR_DIR: %s\n\n" "$QUAR_DIR"
    printf "%s1)%s Listar archivos en quarantine\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Restaurar todo\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Borrar definitivamente todo\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Volver\n" "$C_YLW" "$C_RESET"
    printf "%sOpción:%s " "$C_BLU" "$C_RESET"
    read -r qop
    case "$qop" in
      1)
        if ensure_python_bin; then
            "$PYTHON_BIN" "$manager_script" list --quar-dir "$QUAR_DIR"
        else
            printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      2)
        ensure_safety_guard
        local dry_run_flag=""
        if [ "$SAFE_MODE" -eq 1 ] || [ "$DJ_SAFE_LOCK" -eq 1 ] || [ "$DRYRUN_FORCE" -eq 1 ]; then
            printf "%s[WARN]%s SAFE_MODE/DJ_SAFE_LOCK/DRYRUN_FORCE activos. Se ejecutará en modo simulación (dry-run).\n" "$C_YLW" "$C_RESET"
            dry_run_flag="--dry-run"
        else
            printf "%s[WARN]%s Restaurar TODO desde quarantine a %s/_RESTORED_FROM_QUARANTINE/.\n" "$C_YLW" "$C_RESET" "$BASE_PATH"
            printf "Confirmar (escribe YES para continuar): "
            read -r ans
            if [ "$ans" != "YES" ]; then
                printf "%s[INFO]%s Cancelado.\n" "$C_CYN" "$C_RESET"; pause_enter; continue
            fi
        fi
        if ensure_python_bin; then
            "$PYTHON_BIN" "$manager_script" restore --quar-dir "$QUAR_DIR" --base-path "$BASE_PATH" ${dry_run_flag}
        fi
        pause_enter
        ;;
      3)
        ensure_safety_guard
        local dry_run_flag_purge=""
        if [ "$SAFE_MODE" -eq 1 ] || [ "$DJ_SAFE_LOCK" -eq 1 ] || [ "$DRYRUN_FORCE" -eq 1 ]; then
            printf "%s[WARN]%s SAFE_MODE/DJ_SAFE_LOCK/DRYRUN_FORCE activos. Se ejecutará en modo simulación (dry-run).\n" "$C_YLW" "$C_RESET"
            dry_run_flag_purge="--dry-run"
        else
            printf "%s[WARN]%s Borrar TODO el contenido de quarantine. ¡ESTA ACCIÓN NO SE PUEDE DESHACER!\n" "$C_RED" "$C_RESET"
            printf "Confirmar (escribe YES para continuar): "
            read -r ans2
            if [ "$ans2" != "YES" ]; then
                printf "%s[INFO]%s Cancelado.\n" "$C_CYN" "$C_RESET"; pause_enter; continue
            fi
        fi
        if ensure_python_bin; then
            "$PYTHON_BIN" "$manager_script" purge --quar-dir "$QUAR_DIR" ${dry_run_flag_purge}
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

action_13_ffprobe_report() {
    print_header
    local out="$REPORTS_DIR/media_corrupt.tsv"
    if [ -s "$out" ]; then
        printf "%s[INFO]%s Se encontró un reporte previo (%s).\n" "$C_CYN" "$C_RESET" "$out"
        printf "¿Deseas REUSAR el archivo existente? [Y/n] (n = regenerar): "
        read -r reuse
        if [ -z "$reuse" ] || [[ "$reuse" =~ ^[Yy]$ ]]; then
            printf "%s[OK]%s Reusando media_corrupt.tsv existente.\n" "$C_GRN" "$C_RESET"
            pause_enter
            return
        fi
    fi

    local validator_script="$LIB_DIR/media_validator.py"

    if ! ensure_python_bin; then
        printf "%s[ERR]%s Se necesita Python para ejecutar el validador de medios.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
    fi

    printf "%s[INFO]%s Detectando media corrupta (ffprobe) vía script Python -> %s\n" "$C_CYN" "$C_RESET" "$out"
    if ! "$PYTHON_BIN" "$validator_script" --base "$BASE_PATH" --out "$out"; then
        printf "%s[ERR]%s Falló la validación de medios. Revisa si 'ffprobe' está instalado.\n" "$C_RED" "$C_RESET"
    fi
    
    pause_enter
}

action_14_playlists_per_folder() {
    print_header
    printf "%s[INFO]%s Crear playlists .m3u8 por carpeta (vía script Python).\n" "$C_CYN" "$C_RESET"
    
    local playlist_builder_script="$LIB_DIR/playlist_builder.py"

    if ! ensure_python_bin; then
        printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
    fi

    if ! "$PYTHON_BIN" "$playlist_builder_script" --base "$BASE_PATH"; then
        printf "%s[ERR]%s Falló la generación de playlists.\n" "$C_RED" "$C_RESET"
    fi

    pause_enter
}

action_15_relink_helper() {
    print_header
    local out="$REPORTS_DIR/relink_helper.tsv"
    printf "%s[INFO]%s Generando Relink Helper TSV (vía script Python): %s\n" "$C_CYN" "$C_RESET" "$out"

    local relink_builder_script="$LIB_DIR/relink_helper_builder.py"

    if ! ensure_python_bin; then
        printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
    fi

    if ! "$PYTHON_BIN" "$relink_builder_script" --base "$BASE_PATH" --out "$out"; then
        printf "%s[ERR]%s Falló la generación del Relink Helper.\n" "$C_RED" "$C_RESET"
    fi

    pause_enter
}

action_16_mirror_by_genre() {
  print_header
  printf "%s[INFO]%s Mirror por género (plan seguro básico).\n" "$C_CYN" "$C_RESET"
  out="$PLANS_DIR/mirror_by_genre.tsv"
  if ! maybe_reuse_file "$out" "mirror_by_genre.tsv"; then return; fi
  >"$out"
  printf "Indexando colección de audio...\r"
  mapfile -t files < <(find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null)
  total=${#files[@]}
  count=0
  for f in "${files[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    status_line "MIRROR_GENRE" "$percent" "$(basename "$f")"
    printf "%s\tGENRE_UNKNOWN\t%s\n" "$f" "$BASE_PATH/_MIRROR_BY_GENRE/GENRE_UNKNOWN/$(basename "$f")" >>"$out"
  done
  finish_status_line
  printf "%s[OK]%s Plan espejo por género generado: %s\n" "$C_GRN" "$C_RESET" "$out"
  pause_enter
}

action_17_find_dj_libs() {
    print_header
    local finder_script="$LIB_DIR/dj_lib_finder.py"

    if ! ensure_python_bin; then
        printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
    fi

    if [ ! -f "$finder_script" ]; then
        printf "%s[ERR]%s No se encuentra el script de búsqueda: %s\n" "$C_RED" "$C_RESET" "$finder_script"
        pause_enter
        return
    fi

    "$PYTHON_BIN" "$finder_script" --base "$BASE_PATH"

    pause_enter
}

action_18_rescan_intelligent() {
    print_header
    printf "%s[INFO]%s Rescan inteligente (vía script Python).\n" "$C_CYN" "$C_RESET"
    local out="$REPORTS_DIR/rescan_intelligent.tsv"
    local scanner_script="$LIB_DIR/intelligent_scanner.py"

    if ! ensure_python_bin; then
        printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
    fi

    if [ ! -f "$scanner_script" ]; then
        printf "%s[ERR]%s No se encuentra el script de escaneo: %s\n" "$C_RED" "$C_RESET" "$scanner_script"
        pause_enter
        return
    fi

    "$PYTHON_BIN" "$scanner_script" --base "$BASE_PATH" --out "$out"
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
  
  print_header
  printf "%s[INFO]%s Diagnóstico de herramientas (vía script Python).\n" "$C_CYN" "$C_RESET"
  
  local diag_script="$LIB_DIR/tools_diagnostics.py"

  if ! ensure_python_bin; then
    printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi

  if [ ! -f "$diag_script" ]; then
    printf "%s[ERR]%s No se encuentra el script de diagnóstico: %s\n" "$C_RED" "$C_RESET" "$diag_script"
    pause_enter
    return
  fi

  "$PYTHON_BIN" "$diag_script"
  pause_enter
}

action_20_fix_ownership_flags() {
  print_header
  out="$PLANS_DIR/fix_ownership_flags.tsv"
  printf "%s[INFO]%s Plan de fix ownership/flags -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  printf "Analizando estructura de archivos...\r"
  mapfile -t files < <(find "$BASE_PATH" -type f 2>/dev/null)
  total=${#files[@]}
  count=0
  for f in "${files[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    status_line "FIX_OWNER" "$percent" "$(basename "$f")"
    printf "%s\tchown-KEEP\tchmod-KEEP\n" "$f" >>"$out"
  done
  finish_status_line
  printf "%s[OK]%s Plan generado (no ejecutado).\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_21_install_cmd() {
  print_header
  target="/usr/local/bin/djproducertool"
  
  # Determine the best source script to link
  # Use the current script path
  src_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

  printf "%s[INFO]%s Instalar comando universal: %s -> %s\n" "$C_CYN" "$C_RESET" "$src_script" "$target"
  
  if [ "$SAFE_MODE" -eq 1 ]; then
    printf "%s[WARN]%s SAFE_MODE=1, solo se mostrará la acción.\n" "$C_YLW" "$C_RESET"
    printf "ln -s \"%s\" \"%s\"\n" "$src_script" "$target"
  else
    if ln -sf "$src_script" "$target" 2>/dev/null; then
        printf "%s[OK]%s Enlace creado exitosamente.\n" "$C_GRN" "$C_RESET"
    else
        printf "%s[WARN]%s Falló el enlace directo (permiso denegado).\n" "$C_YLW" "$C_RESET"
        printf "¿Intentar con sudo? [Y/n]: "
        read -r ans
        if [ -z "$ans" ] || [[ "$ans" =~ ^[Yy]$ ]]; then
            if sudo ln -sf "$src_script" "$target"; then
                printf "%s[OK]%s Enlace creado con sudo.\n" "$C_GRN" "$C_RESET"
            else
                printf "%s[ERR]%s Falló incluso con sudo.\n" "$C_RED" "$C_RESET"
            fi
        else
            printf "%s[INFO]%s Omitido.\n" "$C_CYN" "$C_RESET"
        fi
    fi
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
      if rm -f "$target" 2>/dev/null; then
        printf "%s[OK]%s Eliminado exitosamente.\n" "$C_GRN" "$C_RESET"
      else
        printf "%s[WARN]%s Falló el borrado (permiso denegado).\n" "$C_YLW" "$C_RESET"
        printf "¿Intentar con sudo? [Y/n]: "
        read -r ans
        if [ -z "$ans" ] || [[ "$ans" =~ ^[Yy]$ ]]; then
            if sudo rm -f "$target"; then
                printf "%s[OK]%s Eliminado con sudo.\n" "$C_GRN" "$C_RESET"
            else
                printf "%s[ERR]%s Falló incluso con sudo.\n" "$C_RED" "$C_RESET"
            fi
        else
            printf "%s[INFO]%s Omitido.\n" "$C_CYN" "$C_RESET"
        fi
      fi
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
    local out="$REPORTS_DIR/snapshot_hash_fast.tsv"
    if [ -s "$out" ]; then
        printf "%s[INFO]%s Se encontró un snapshot previo (%s).\n" "$C_CYN" "$C_RESET" "$out"
        printf "¿Deseas REUSAR el archivo existente? [Y/n] (n = regenerar): "
        read -r reuse
        if [ -z "$reuse" ] || [[ "$reuse" =~ ^[Yy]$ ]]; then
            printf "%s[OK]%s Reusando snapshot_hash_fast.tsv existente.\n" "$C_GRN" "$C_RESET"
            pause_enter
            return
        fi
    fi

    confirm_heavy "Snapshot integridad (hash rápido)" || return
    print_header
    
    local builder_script="$LIB_DIR/snapshot_builder.py"

    if ! ensure_python_bin; then
        printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
    fi

    printf "%s[INFO]%s Generando snapshot rápido (vía script Python) -> %s\n" "$C_CYN" "$C_RESET" "$out"
    if ! "$PYTHON_BIN" "$builder_script" --base "$BASE_PATH" --out "$out"; then
        printf "%s[ERR]%s Falló la generación del snapshot.\n" "$C_RED" "$C_RESET"
    fi

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
  ensure_safety_guard
  if [ "$SAFE_MODE" -eq 1 ] || [ "$DJ_SAFE_LOCK" -eq 1 ]; then
    printf "%s[WARN]%s SAFE_MODE/DJ_SAFE_LOCK activos. Desactiva temporalmente si realmente quieres borrar el estado.\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi
  if ! ensure_state_dir_safe; then
    pause_enter
    return
  fi
  printf "%s[CRITICAL]%s ¡ESTA ACCIÓN ELIMINARÁ TODO EL ESTADO DEL SISTEMA!\n" "$C_RED" "$C_RESET"
  printf "Directorios a eliminar: %s\n" "$STATE_DIR"
  printf "Esto incluye: configuración, reportes, planes, cuarentena, logs, base de datos\n"
  printf "Escribe RESET para borrar, CLEAR para solo limpiar EXTRA_SOURCE_ROOTS, DRY para simular, o ENTER para cancelar: "
  read -r ans
  case "$ans" in
    RESET)
      printf "%s[CRITICAL]%s ¡PELIGRO! Esta acción es IRREVERSIBLE y eliminará: %s\n" "$C_RED" "$C_RESET" "$STATE_DIR"
      printf "Para confirmar la eliminación IRREVERSIBLE, escribe EXACTAMENTE 'YES' en mayúsculas: "
      read -r confirm
      if [ "$confirm" != "YES" ]; then
        printf "%s[INFO]%s Cancelado. Respuesta: '%s' (se requería 'YES')\n" "$C_CYN" "$C_RESET" "$confirm"
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

shared_corpus_copy() {
  # $1: origen, $2: destino
  local src="$1" dest="$2"
  mkdir -p "$dest"
  rsync -av --include='*.tsv' --include='*.json' --include='*.txt' --exclude='*' "$src"/ "$dest"/ >/dev/null 2>&1 || true
}

action_69_shared_corpus() {
  print_header
  printf "%s[INFO]%s Sincronizar corpus compartido (hashes/ML/planes) entre discos.\n" "$C_CYN" "$C_RESET"
  printf "Ruta actual del corpus compartido: %s\n" "$SHARED_CORPUS_DIR"
  printf "Nueva ruta (ENTER para mantener): "
  read -e -r new_shared
  new_shared=$(strip_quotes "$new_shared")
  if [ -n "$new_shared" ]; then
    SHARED_CORPUS_DIR="$new_shared"
    mkdir -p "$SHARED_CORPUS_DIR" "$SHARED_CORPUS_DIR/reports" "$SHARED_CORPUS_DIR/plans"
    save_conf
  fi
  mkdir -p "$SHARED_CORPUS_DIR/reports" "$SHARED_CORPUS_DIR/plans"
  printf "1) Exportar reports/planes actuales al corpus compartido\n"
  printf "2) Importar desde el corpus compartido (solo si faltan)\n"
  printf "3) Solo mostrar contenido\n"
  printf "Opción: "
  read -e -r sc_opt
  case "$sc_opt" in
    1)
      shared_corpus_copy "$REPORTS_DIR" "$SHARED_CORPUS_DIR/reports"
      shared_corpus_copy "$PLANS_DIR" "$SHARED_CORPUS_DIR/plans"
      printf "%s[OK]%s Exportado a %s (reports/plans).\n" "$C_GRN" "$C_RESET" "$SHARED_CORPUS_DIR"
      ;;
    2)
      shared_corpus_copy "$SHARED_CORPUS_DIR/reports" "$REPORTS_DIR"
      shared_corpus_copy "$SHARED_CORPUS_DIR/plans" "$PLANS_DIR"
      printf "%s[OK]%s Importado desde %s hacia el estado actual (solo copia lectura).\n" "$C_GRN" "$C_RESET" "$SHARED_CORPUS_DIR"
      ;;
    3)
      printf "%s[INFO]%s Contenido compartido:\n" "$C_CYN" "$C_RESET"
      printf "Reports:\n"
      ls -1 "$SHARED_CORPUS_DIR/reports" 2>/dev/null | head || true
      printf "Plans:\n"
      ls -1 "$SHARED_CORPUS_DIR/plans" 2>/dev/null | head || true
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
      if ! ensure_python_deps "ML" "pandas" "sklearn" "joblib"; then
        pause_enter
        return
      fi
      
      PLAN_HASH="$PLANS_DIR/general_hash_dupes_plan.tsv"
      PLAN_NAME="$PLANS_DIR/general_dupes_plan.tsv"
      
      printf "%s[INFO]%s Entrenando modelo...\n" "$C_CYN" "$C_RESET"
      "$PYTHON_BIN" "$SCRIPT_DIR/ml_evolutionary.py" train \
        --base "$BASE_PATH" \
        --plan-hash "$PLAN_HASH" \
        --plan-name "$PLAN_NAME" \
        --features-out "$ML_FEATURES_FILE" \
        --model-out "$ML_MODEL_PATH"
        
      if [ $? -eq 0 ]; then
        printf "%s[OK]%s Entrenamiento completado.\n" "$C_GRN" "$C_RESET"
      else
        printf "%s[ERR]%s Falló el entrenamiento.\n" "$C_RED" "$C_RESET"
      fi
      pause_enter
      ;;
    2)
      if [ ! -f "$ML_MODEL_PATH" ]; then
        printf "%s[ERR]%s No hay modelo entrenado (ejecuta opción 1 primero).\n" "$C_RED" "$C_RESET"
        pause_enter
        return
      fi
      
      printf "%s[INFO]%s Prediciendo sospechosos...\n" "$C_CYN" "$C_RESET"
      "$PYTHON_BIN" "$SCRIPT_DIR/ml_evolutionary.py" predict \
        --base "$BASE_PATH" \
        --model-in "$ML_MODEL_PATH" \
        --report-out "$ML_PRED_REPORT"
        
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

  # Check if TF is already installed in the venv
  local tf_installed=0
  if [ -f "$VENV_DIR/bin/python3" ]; then
      if "$VENV_DIR/bin/python3" -c "import tensorflow" >/dev/null 2>&1; then
          tf_installed=1
      fi
  fi

  if [ "$tf_installed" -eq 1 ]; then
      printf "%s[OK]%s TensorFlow ya está instalado y detectado en %s\n" "$C_GRN" "$C_RESET" "$VENV_DIR"
      printf "¿Deseas REINSTALAR/RESET? (y/N): "
      read -r reset_tf
      if [[ ! "$reset_tf" =~ ^[yY] ]]; then
          printf "%s[INFO]%s Manteniendo instalación actual.\n" "$C_CYN" "$C_RESET"
          pause_enter
          return
      fi
      printf "%s[WARN]%s Reinstalando TensorFlow...\n" "$C_YLW" "$C_RESET"
  fi

  printf "%s[INFO]%s TensorFlow opcional (auto-tagging avanzado, embeddings de similitud, clasificadores profundos).\n" "$C_CYN" "$C_RESET"
  printf "Descarga estimada adicional: ~%s MB. ¿Instalar ahora en el venv ML? [y/N]: " "$ML_PKG_TF_MB"
  read -r tfa
  case "$tfa" in
    y|Y)
      check_connectivity || { pause_enter; return; }
      maybe_activate_ml_env "TensorFlow opcional" 1 1
      if "$PYTHON_BIN" -c "import tensorflow as tf; print('TF_OK')" >/dev/null 2>&1; then
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
  setup_tf_perf_env
  while true; do
    clear
    print_header
    printf "%s=== TensorFlow Lab (requiere TF instalado) ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s[INFO]%s Dependencias: python3 + tensorflow + tensorflow_hub + soundfile + numpy. Límite: ~150 archivos; similitud usa umbral >=0.60 (top 200 pares).\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Auto-tagging de audio (embeddings/tags)\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Similitud por contenido (audio) desde embeddings\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Detección de fragmentos repetidos/loops\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s Clasificador de sospechosos (basura/silencio)\n" "$C_YLW" "$C_RESET"
    printf "%s5)%s Estimar loudness (plan de normalización) [target env DJPT_LUFS_TARGET]\n" "$C_YLW" "$C_RESET"
    printf "%s6)%s Auto-segmentación (cues preliminares)\n" "$C_YLW" "$C_RESET"
    printf "%s7)%s Matching cross-platform (relink inteligente)\n" "$C_YLW" "$C_RESET"
    printf "%s8)%s Auto-tagging de vídeo (keyframes)\n" "$C_YLW" "$C_RESET"
    printf "%s9)%s Music Tagging (multi-label, modelo TF Hub)\n" "$C_YLW" "$C_RESET"
    printf "%s10)%s Mastering check (LUFS/crest/DR plan)\n" "$C_YLW" "$C_RESET"
    printf "%s11)%s Descargar modelo opcional (onnx/tflite cache)\n" "$C_YLW" "$C_RESET"
    printf "%s0)%s Toggle offline (DJPT_OFFLINE=%s)\n" "$C_YLW" "$C_RESET" "${DJPT_OFFLINE:-0}"
    printf "%sB)%s Volver\n" "$C_YLW" "$C_RESET"
    printf "%sOpción:%s " "$C_BLU" "$C_RESET"
    if ! read -e -r top </dev/tty 2>/dev/null; then
      printf "\n%s[WARN]%s Entrada no disponible, saliendo del submenú.\n" "$C_YLW" "$C_RESET"
      break
    fi
    offline_args=()
    [ "${DJPT_OFFLINE:-0}" -eq 1 ] && offline_args=(--offline)
    case "$top" in
      0)
        if [ "${DJPT_OFFLINE:-0}" -eq 1 ]; then
          DJPT_OFFLINE=0
          printf "%s[INFO]%s Offline desactivado.\n" "$C_CYN" "$C_RESET"
        else
          DJPT_OFFLINE=1
          printf "%s[INFO]%s Offline activado (forzará heurísticos/mocks).\n" "$C_CYN" "$C_RESET"
        fi
        export DJPT_OFFLINE
        pause_enter
        ;;
      1)
        clear
        ensure_python_bin || { pause_enter; continue; }
        check_connectivity || { pause_enter; continue; }
        out_emb="$REPORTS_DIR/audio_embeddings.tsv"
        out_tags="$REPORTS_DIR/audio_tags.tsv"
        printf "%s[INFO]%s Auto-tagging/embeddings (offline/TF si disponible) -> %s / %s\n" "$C_CYN" "$C_RESET" "$out_emb" "$out_tags"
        printf "Modelo (yamnet/musicnn/musictag/clap_onnx/clip_vitb16_onnx/musicgen_tflite/sentence_t5_tflite) [por defecto %s]: " "${DJPT_ML_MODEL:-yamnet}"
        read -e -r mdl_choice
        mdl_choice=$(strip_quotes "$mdl_choice")
        mdl_choice=${mdl_choice:-${DJPT_ML_MODEL:-yamnet}}
        case "$mdl_choice" in
          clap_onnx|clip_vitb16_onnx|sentence_t5_tflite)
            ensure_python_deps "onnxruntime (para $mdl_choice)" onnxruntime || {
              printf "%s[WARN]%s Sin onnxruntime; se usará fallback/mock.\n" "$C_YLW" "$C_RESET"
            }
            ;;
        esac
        if "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" embeddings --base "$BASE_PATH" --out "$out_emb" --limit "$DJPT_TF_BATCH" --model "$mdl_choice" "${offline_args[@]}" &&\
           "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" tags --base "$BASE_PATH" --out "$out_tags" --limit "$DJPT_TF_BATCH" --model "$mdl_choice" "${offline_args[@]}"; then
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
          "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" embeddings --base "$BASE_PATH" --out "$emb_in" --limit "$DJPT_TF_BATCH" "${offline_args[@]}" || {
            printf "%s[ERR]%s No se pudieron generar embeddings.\n" "$C_RED" "$C_RESET"
            pause_enter; continue
          }
        fi
        if "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" similarity --embeddings "$emb_in" --out "$sim_out" --threshold "$DJPT_TF_THRESHOLD" --top "$DJPT_TF_TOPN" "${offline_args[@]}"; then
          printf "%s[OK]%s Similitud generada: %s\n" "$C_GRN" "$C_RESET" "$sim_out"
        else
          printf "%s[ERR]%s Falló cálculo de similitud.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      3)
        clear
        ensure_python_bin || { pause_enter; continue; }
        out_an="$REPORTS_DIR/audio_anomalies.tsv"
        printf "%s[INFO]%s Anomalías (silencio/clipping) -> %s\n" "$C_CYN" "$C_RESET" "$out_an"
        if "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" anomalies --base "$BASE_PATH" --out "$out_an" --limit "$DJPT_TF_BATCH" "${offline_args[@]}"; then
          printf "%s[OK]%s Anomalías generadas.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Falló análisis de anomalías.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      4)
        clear
        ensure_python_bin || { pause_enter; continue; }
        out_gb="$REPORTS_DIR/audio_garbage.tsv"
        printf "%s[INFO]%s Clasificador basura/silencio/clipping -> %s\n" "$C_CYN" "$C_RESET" "$out_gb"
        if "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" garbage --base "$BASE_PATH" --out "$out_gb" --limit "$DJPT_TF_BATCH" "${offline_args[@]}"; then
          printf "%s[OK]%s Reporte de sospechosos generado.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Falló el clasificador de sospechosos.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      5)
        clear
        ensure_python_bin || { pause_enter; continue; }
        out_lufs="$REPORTS_DIR/audio_loudness.tsv"
        printf "Objetivo LUFS (default %s): " "${DJPT_LUFS_TARGET:- -14.0}"
        read -e -r target
        target=$(strip_quotes "$target")
        target=${target:-${DJPT_LUFS_TARGET:- -14.0}}
        printf "Tolerancia BOOST/CUT dB (default %s): " "${DJPT_GAIN_TOL:-1.5}"
        read -e -r tol
        tol=$(strip_quotes "$tol")
        tol=${tol:-${DJPT_GAIN_TOL:-1.5}}
        printf "%s[INFO]%s Estimación de loudness (objetivo %s LUFS, tolerancia %s dB; usa pyloudnorm si está) -> %s\n" "$C_CYN" "$C_RESET" "$target" "$tol" "$out_lufs"
        if DJPT_GAIN_TOL="$tol" "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" loudness --base "$BASE_PATH" --out "$out_lufs" --limit "$DJPT_TF_BATCH" --target "$target" --tolerance "$tol" "${offline_args[@]}"; then
          printf "%s[OK]%s Reporte de loudness generado.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Falló la estimación de loudness.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      6)
        clear
        ensure_python_bin || { pause_enter; continue; }
        out_seg="$REPORTS_DIR/audio_segments.tsv"
        printf "%s[INFO]%s Segmentación/onsets -> %s\n" "$C_CYN" "$C_RESET" "$out_seg"
        if "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" segments --base "$BASE_PATH" --out "$out_seg" --limit "$DJPT_TF_BATCH" "${offline_args[@]}"; then
          printf "%s[OK]%s Segmentos generados.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Falló segmentación.\n" "$C_RED" "$C_RESET"
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
        printf "%s[INFO]%s Matching cross-platform (nombres normalizados + tags/embeddings si existen) -> %s\n" "$C_CYN" "$C_RESET" "$out_match"
        if "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" matching --base "$BASE_PATH" --out "$out_match" --limit "$DJPT_TF_BATCH" "${emb_args[@]}" "${tag_args[@]}" "${offline_args[@]}"; then
          printf "%s[OK]%s Matching generado.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Falló el matching.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      8)
        clear
        ensure_python_bin || { pause_enter; continue; }
        out_vtags="$REPORTS_DIR/video_tags.tsv"
        printf "%s[INFO]%s Auto-tagging de vídeo (heurístico por nombre) -> %s\n" "$C_CYN" "$C_RESET" "$out_vtags"
        if "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" video_tags --base "$BASE_PATH" --out "$out_vtags" --limit "$DJPT_TF_BATCH" "${offline_args[@]}"; then
          printf "%s[OK]%s Tags de vídeo generados.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Falló el tagging de vídeo.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      9)
        clear
        ensure_python_bin || { pause_enter; continue; }
        out_mtags="$REPORTS_DIR/music_tags.tsv"
        printf "%s[INFO]%s Music tagging multi-label (TF Hub o heurístico) -> %s\n" "$C_CYN" "$C_RESET" "$out_mtags"
        if "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" music_tags --base "$BASE_PATH" --out "$out_mtags" --limit "$DJPT_TF_BATCH" "${offline_args[@]}"; then
          printf "%s[OK]%s Music tagging generado.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Falló music tagging.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      10)
        clear
        ensure_python_bin || { pause_enter; continue; }
        out_master="$REPORTS_DIR/audio_mastering.tsv"
        printf "%s[INFO]%s Mastering check (LUFS/crest/DR) -> %s\n" "$C_CYN" "$C_RESET" "$out_master"
        if "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" mastering --base "$BASE_PATH" --out "$out_master" --limit "$DJPT_TF_BATCH" --target -14.0 --crest-min 6.0 --dr-min 5.0 "${offline_args[@]}"; then
          printf "%s[OK]%s Plan de mastering generado.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Falló el chequeo de mastering.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      11)
        clear
        ensure_python_bin || { pause_enter; continue; }
        check_connectivity || { pause_enter; continue; }
        printf "%s[INFO]%s Descargar modelo opcional (onnx/tflite) a .venv/models\n" "$C_CYN" "$C_RESET"
        printf "Opciones: clap_onnx, clip_vitb16_onnx, musicgen_tflite, sentence_t5_tflite\nNombre: "
        read -e -r mdl
        mdl=$(strip_quotes "$mdl")
        if [ -z "$mdl" ]; then
          printf "%s[WARN]%s Sin nombre, cancelado.\n" "$C_YLW" "$C_RESET"
        else
          if "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" download_model --name "$mdl" "${offline_args[@]}"; then
            printf "%s[OK]%s Modelo %s cacheado.\n" "$C_GRN" "$C_RESET" "$mdl"
          else
            printf "%s[ERR]%s Descarga falló (revisa red/URL).\n" "$C_RED" "$C_RESET"
          fi
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
    local out="$PLANS_DIR/audio_by_tags_plan.tsv"
    if [ -s "$out" ]; then
        printf "%s[INFO]%s Se encontró un plan de tags previo (%s).\n" "$C_CYN" "$C_RESET" "$out"
        printf "¿Deseas REUSAR el archivo existente? [Y/n] (n = regenerar): "
        read -r reuse
        if [ -z "$reuse" ] || [[ "$reuse" =~ ^[Yy]$ ]]; then
            printf "%s[OK]%s Reusando plan de tags existente.\n" "$C_GRN" "$C_RESET"
            pause_enter
            return
        fi
    fi

    printf "%s[INFO]%s Organizar audio por TAGS (vía script Python) -> plan TSV: %s\n" "$C_CYN" "$C_RESET" "$out"
    local builder_script="$LIB_DIR/tags_plan_builder.py"

    if ! ensure_python_bin; then
        printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
    fi

    if ! "$PYTHON_BIN" "$builder_script" --base "$BASE_PATH" --out "$out"; then
        printf "%s[ERR]%s Falló la generación del plan de tags.\n" "$C_RED" "$C_RESET"
    fi
    pause_enter
}

action_31_report_tags() {
    print_header
    local plan="$PLANS_DIR/audio_by_tags_plan.tsv"
    local out="$REPORTS_DIR/audio_tags_report.tsv"
    
    printf "%s[INFO]%s Reporte de tags de audio (vía script Python) -> %s\n" "$C_CYN" "$C_RESET" "$out"

    if [ ! -s "$plan" ]; then
        printf "%s[WARN]%s No hay plan de TAGS, generando primero.\n" "$C_YLW" "$C_RESET"
        action_30_plan_tags
        if [ ! -s "$plan" ]; then
            printf "%s[ERR]%s No se pudo generar el plan de tags. Abortando.\n" "$C_RED" "$C_RESET"
            pause_enter
            return
        fi
    fi

    local report_builder_script="$LIB_DIR/tags_report_builder.py"

    if ! ensure_python_bin; then
        printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
    fi

    if ! "$PYTHON_BIN" "$report_builder_script" --plan "$plan" --out "$out"; then
        printf "%s[ERR]%s Falló la generación del reporte de tags.\n" "$C_RED" "$C_RESET"
    fi
    pause_enter
}

action_32_serato_video_report() {
    print_header
    local out="$REPORTS_DIR/serato_video_report.tsv"
    printf "%s[INFO]%s Serato Video REPORT (vía script Python) -> %s\n" "$C_CYN" "$C_RESET" "$out"

    local reporter_script="$LIB_DIR/serato_video_reporter.py"

    if ! ensure_python_bin; then
        printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
    fi

    if [ ! -f "$reporter_script" ]; then
        printf "%s[ERR]%s No se encuentra el script de reporte: %s\n" "$C_RED" "$C_RESET" "$reporter_script"
        pause_enter
        return
    fi

    if ! "$PYTHON_BIN" "$reporter_script" --base "$BASE_PATH" --out "$out"; then
        printf "%s[ERR]%s Falló la generación del reporte de video. Revisa si 'ffprobe' está instalado.\n" "$C_RED" "$C_RESET"
    fi
    pause_enter
}

action_33_serato_video_prep() {
    print_header
    local out="$PLANS_DIR/serato_video_transcode_plan.tsv"
    printf "%s[INFO]%s Serato Video PREP (plan de transcode sugerido) -> %s\n" "$C_CYN" "$C_RESET" "$out"

    if ! command -v ffprobe >/dev/null 2>&1; then
        printf "%s[ERR]%s ffprobe no disponible.\n" "$C_RED" "$C_RESET"; pause_enter; return
    fi
    ensure_python_bin || { pause_enter; return; }

    printf "Codec a usar (auto/videotoolbox/nvenc/libx264) [auto]: "
    read -r vid_codec
    vid_codec=${vid_codec:-auto}

    if ! "$PYTHON_BIN" "$LIB_DIR/video_tools.py" transcode_plan "$BASE_PATH" "$out" "h264_1080p" "$vid_codec"; then
        printf "%s[ERR]%s Falló la generación del plan (revisa lib/video_tools.py).\n" "$C_RED" "$C_RESET"
        pause_enter; return
    fi

    printf "%s[OK]%s Plan de transcode generado.\n" "$C_GRN" "$C_RESET"
    printf "¿Ejecutar transcodificación con ffmpeg ahora? [y/N]: "
    read -r run_ff
    [[ "$run_ff" =~ ^[yY]$ ]] || { pause_enter; return; }

    if ! command -v ffmpeg >/dev/null 2>&1; then
        printf "%s[ERR]%s ffmpeg no disponible.\n" "$C_RED" "$C_RESET"; pause_enter; return
    fi

    local dry_run_flag=""
    if [ "$SAFE_MODE" -eq 1 ] || [ "$DJ_SAFE_LOCK" -eq 1 ] || [ "$DRYRUN_FORCE" -eq 1 ]; then
        printf "%s[WARN]%s SAFE_MODE/DJ_SAFE_LOCK/DRYRUN_FORCE activos. Se ejecutará en modo simulación (dry-run).\n" "$C_YLW" "$C_RESET"
        dry_run_flag="--dry-run"
    else
        confirm_heavy "Transcodificación ffmpeg (puede tardar mucho)" || { pause_enter; return; }
    fi

    local executor_script="$LIB_DIR/transcode_executor.py"
    "$PYTHON_BIN" "$executor_script" --plan "$out" ${dry_run_flag}

    pause_enter
}

action_34_normalize_names() {
    print_header
    local out="$PLANS_DIR/normalize_names_plan.tsv"
    printf "%s[INFO]%s Normalizar nombres (plan TSV, vía script Python) -> %s\n" "$C_CYN" "$C_RESET" "$out"

    local normalizer_script="$LIB_DIR/name_normalizer.py"

    if ! ensure_python_bin; then
        printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
    fi

    if [ ! -f "$normalizer_script" ]; then
        printf "%s[ERR]%s No se encuentra el script de normalización: %s\n" "$C_RED" "$C_RESET" "$normalizer_script"
        pause_enter
        return
    fi

    "$PYTHON_BIN" "$normalizer_script" --base "$BASE_PATH" --out "$out"

    pause_enter
}

action_ai_status() {
    print_header
    printf "%s[INFO]%s 🧠 AI STATUS: Reporte completo del entorno IA\n" "$C_CYN" "$C_RESET"
    
    local ai_status_script="$SCRIPT_DIR/ai_status.py"
    local models_dir="$BASE_PATH/ai/models"
    
    if ! ensure_python_bin; then
        printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
    fi
    
    if [ ! -f "$ai_status_script" ]; then
        printf "%s[ERR]%s No se encuentra el script de AI status: %s\n" "$C_RED" "$C_RESET" "$ai_status_script"
        pause_enter
        return
    fi
    
    # Use enhanced AI status script if available, fallback to basic
    local enhanced_script="$SCRIPT_DIR/ai_status_enhanced.py"
    local basic_script="$SCRIPT_DIR/ai_status.py"
  
    if [ -f "$enhanced_script" ]; then
        printf "%s[INFO]%s Usando script mejorado de AI status.\n" "$C_CYN" "$C_RESET"
        "$PYTHON_BIN" "$enhanced_script" --models-dir "$DJPT_MODELS_DIR" --format text --lang "${DJPT_CURRENT_LANG:-ES}"
    elif [ -f "$basic_script" ]; then
        printf "%s[INFO]%s Usando script básico de AI status.\n" "$C_CYN" "$C_RESET"
        "$PYTHON_BIN" "$basic_script" --models-dir "$DJPT_MODELS_DIR" --format text --lang "${DJPT_CURRENT_LANG:-ES}"
    else
        printf "%s[ERR]%s No se encontró script de AI status.\n" "$C_RED" "$C_RESET"
    fi
    
    pause_enter
}

action_35_samples_by_type() {
    print_header
    local out="$PLANS_DIR/samples_by_type_plan.tsv"
    printf "%s[INFO]%s Organizar samples por TIPO (vía script Python) -> %s\n" "$C_CYN" "$C_RESET" "$out"

    local classifier_script="$LIB_DIR/sample_classifier.py"

    if ! ensure_python_bin; then
        printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
    fi

    if [ ! -f "$classifier_script" ]; then
        printf "%s[ERR]%s No se encuentra el script clasificador: %s\n" "$C_RED" "$C_RESET" "$classifier_script"
        pause_enter
        return
    fi

    "$PYTHON_BIN" "$classifier_script" --base "$BASE_PATH" --out "$out"
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
  printf "Buscando playlists (.m3u/.m3u8)...\r"
  mapfile -t files < <(find "$BASE_PATH" -type f \( -iname "*.m3u" -o -iname "*.m3u8" \) 2>/dev/null)
  total=${#files[@]}
  count=0
  for f in "${files[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    status_line "WEB_CLEAN" "$percent" "$(basename "$f")"
    tmp="$f.tmp"
    grep -vE "^https?://" "$f" >"$tmp" 2>/dev/null || true
    mv "$tmp" "$f" 2>/dev/null || true
  done
  finish_status_line
  printf "%s[OK]%s Playlists limpiadas.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_39_clean_web_tags() {
  print_header
  out="$PLANS_DIR/clean_web_tags_plan.tsv"
  printf "%s[INFO]%s Limpiar WEB en TAGS (plan) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  printf "Analizando audio para limpieza web...\r"
  mapfile -t files < <(find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null)
  total=${#files[@]}
  count=0
  for f in "${files[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    status_line "WEB_CLEAN_TAGS" "$percent" "$(basename "$f")"
    printf "%s\tCLEAN_WEB_TAGS\n" "$f" >>"$out"
  done
  finish_status_line
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

action_40_smart_analysis() {
  maybe_activate_ml_env "Opción 40 (Análisis inteligente)"
  print_header
  printf "%s[INFO]%s 🧠 DEEP-THINKING: Análisis Inteligente de Biblioteca\n" "$C_CYN" "$C_RESET"

  local ts report analyzer_script candidate
  ts="$(date +%Y%m%d-%H%M%S)"
  report="$REPORTS_DIR/smart_analysis_${ts}.json"
  analyzer_script=""
  mkdir -p "$REPORTS_DIR"

  for candidate in "$LIB_DIR/smart_analyzer.py" "$SCRIPT_DIR/smart_analyzer.py" "${ROOT_DIR:-}/lib/smart_analyzer.py"; do
    if [ -f "$candidate" ]; then
      analyzer_script="$candidate"
      break
    fi
  done

  if [ -z "$analyzer_script" ]; then
    printf "%s[ERR]%s smart_analyzer.py no encontrado (rutas probadas: lib/, ../lib/).\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi

  if ! ensure_python_bin; then
    pause_enter
    return
  fi

  if "$PYTHON_BIN" "$analyzer_script" --base "$BASE_PATH" --out "$report"; then
    printf "%s[OK]%s Análisis inteligente generado: %s\n" "$C_GRN" "$C_RESET" "$report"
    "$PYTHON_BIN" - "$report" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    by_type = data.get("by_type") or {}
    print(
        "Resumen: files={files} audio={audio} video={video} project={project}"
        .format(
            files=data.get("files_count", 0),
            audio=by_type.get("audio", 0),
            video=by_type.get("video", 0),
            project=by_type.get("project", 0),
        )
    )
except Exception:
    pass
PY
  else
    printf "%s[ERR]%s Falló el análisis inteligente.\n" "$C_RED" "$C_RESET"
  fi

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
 
  local ts plan optimizer_script
  ts=$(date +%s)
  plan="$PLANS_DIR/efficiency_${ts}.tsv"
  optimizer_script="$LIB_DIR/efficiency_optimizer.py"

  if ! ensure_python_bin; then
    printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi

  if [ ! -f "$optimizer_script" ]; then
    printf "%s[ERR]%s No se encuentra el script optimizador: %s\n" "$C_RED" "$C_RESET" "$optimizer_script"
    pause_enter
    return
  fi

  if "$PYTHON_BIN" "$optimizer_script" --plans-dir "$PLANS_DIR" --out "$plan" --lang es; then
    printf "%s[OK]%s Plan de eficiencia generado: %s\n" "$C_GRN" "$C_RESET" "$plan"
  else
    printf "%s[ERR]%s Falló el optimizador de eficiencia.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_43_smart_workflow() {
  maybe_activate_ml_env "Opción 43 (Flujo inteligente)"
  print_header
  printf "%s[INFO]%s 🚀 DEEP-THINKING: Flujo de Trabajo Inteligente\n" "$C_CYN" "$C_RESET"
 
  local workflow_file workflow_script
  workflow_file="$PLANS_DIR/workflow_$(date +%s).txt"
  workflow_script="$LIB_DIR/smart_workflow_generator.py"

  if ! ensure_python_bin; then
    printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi

  if [ ! -f "$workflow_script" ]; then
    printf "%s[ERR]%s No se encuentra el script generador de flujo: %s\n" "$C_RED" "$C_RESET" "$workflow_script"
    pause_enter
    return
  fi

  if "$PYTHON_BIN" "$workflow_script" --out "$workflow_file" --lang es; then
    printf "%s[OK]%s Flujo de trabajo generado: %s\n" "$C_GRN" "$C_RESET" "$workflow_file"
  else
    printf "%s[ERR]%s Falló la generación del flujo de trabajo.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_44_integrated_dedup() {
  maybe_activate_ml_env "Opción 44 (Deduplicación integrada)"
  print_header
  printf "%s[INFO]%s 🔄 DEEP-THINKING: Deduplicación Integrada\n" "$C_CYN" "$C_RESET"

  local dedup_plan analyzer_script
  dedup_plan="$PLANS_DIR/integrated_dedup_$(date +%s).tsv"
  analyzer_script="$SCRIPT_DIR/integrated_dedup_analyzer.py"

  if ! ensure_python_bin; then
    printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi

  if [ ! -f "$analyzer_script" ]; then
    printf "%s[ERR]%s No se encuentra el script de análisis: %s\n" "$C_RED" "$C_RESET" "$analyzer_script"
    pause_enter
    return
  fi

  if "$PYTHON_BIN" "$analyzer_script" --plans-dir "$PLANS_DIR" --out "$dedup_plan" --lang es; then
    printf "%s[OK]%s Plan de deduplicación integrada generado: %s\n" "$C_GRN" "$C_RESET" "$dedup_plan"
  else
    printf "%s[ERR]%s Falló el análisis de deduplicación integrada.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_45_ml_organization() {
    maybe_activate_ml_env "Opción 45 (Organización ML)"
    print_header
    printf "%s[INFO]%s 📂 MACHINE LEARNING: Organización Automática (vía script Python)\n" "$C_CYN" "$C_RESET"

    local ts
    ts=$(date +%s)
    local org_plan="$PLANS_DIR/ml_organization_${ts}.tsv"
    local planner_script="$LIB_DIR/ml_organization_planner.py"

    if ! ensure_python_bin; then
        printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
        pause_enter
        return
    fi

    if [ ! -f "$planner_script" ]; then
        printf "%s[ERR]%s No se encuentra el script de organización: %s\n" "$C_RED" "$C_RESET" "$planner_script"
        pause_enter
        return
    fi

    "$PYTHON_BIN" "$planner_script" --base "$BASE_PATH" --out "$org_plan" --limit 50 --lang es
    pause_enter
}

action_46_metadata_harmonizer() {
  maybe_activate_ml_env "Opción 46 (Armonizador metadatos)"
  print_header
  printf "%s[INFO]%s 🎵 DEEP-THINKING: Armonizador de Metadatos\n" "$C_CYN" "$C_RESET"

  local harmony_plan="$PLANS_DIR/metadata_harmony_$(date +%s).tsv"
  local harmonizer_script="$LIB_DIR/metadata_harmonizer.py"

  if ! ensure_python_bin; then
      printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
      pause_enter
      return
  fi

  if [ ! -f "$harmonizer_script" ]; then
      printf "%s[ERR]%s No se encuentra el script armonizador: %s\n" "$C_RED" "$C_RESET" "$harmonizer_script"
      pause_enter
      return
  fi

  if ! "$PYTHON_BIN" "$harmonizer_script" --out "$harmony_plan" --lang "${DJPT_CURRENT_LANG:-es}"; then
      printf "%s[ERR]%s Falló la generación del plan de armonización.\n" "$C_RED" "$C_RESET"
  fi
  
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
  "$PYTHON_BIN" "$LIB_DIR/bpm_analyzer.py" --base "$BASE_PATH" --out "$out" --limit 200 2>/dev/null || {
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
  printf "Bearer token (ENTER = sin token): "
  read -r api_token
  printf "Iniciar servidor (HTTP %s, OSC %s)? [y/N]: " "$http_port" "$osc_port"
  read -r ans
  case "$ans" in
    y|Y)
      args=(--base "$BASE_PATH" --state "$STATE_DIR" --report "$REPORTS_DIR" --http-port "$http_port" --osc-port "$osc_port")
      [ -n "$api_token" ] && args+=(--auth-token "$api_token")
      nohup "$PYTHON_BIN" "$LIB_DIR/osc_api_server.py" "${args[@]}" >/dev/null 2>&1 &
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
          printf "%s[OK]%s %s\n" "$C_GRN" "$C_RESET" "$(get_localized_string SUB_L_DUPES_PLAN_DONE)"
          pause_enter
        fi
        ;;
      4)
        clear
        printf "%s[INFO]%s %s\n" "$C_CYN" "$C_RESET" "$(get_localized_string CUES_HEADER_RB)"
        if [ -z "${REKORDBOX_XML:-}" ] || [ ! -f "$REKORDBOX_XML" ]; then
          printf "%s[ERR]%s %s\n" "$C_RED" "$C_RESET" "$(get_localized_string NO_REKORDBOX_XML)"
          pause_enter
        else
          out="$REPORTS_DIR/dj_cues.tsv"
          if ! ensure_python_bin; then
            pause_enter
            break
          fi
          bridge="${ROOT_DIR:-}/lib/rekordbox_cues_bridge.py"
          if [ ! -f "$bridge" ]; then
            bridge="$LIB_DIR/rekordbox_cues_bridge.py"
          fi
          if [ ! -f "$bridge" ]; then
            printf "%s[ERR]%s No se encuentra rekordbox_cues_bridge.py\n" "$C_RED" "$C_RESET"
            pause_enter
            break
          fi
          if "$PYTHON_BIN" "$bridge" extract --xml "$REKORDBOX_XML" --out "$out"; then
            printf "%s[OK]%s %s\n" "$C_GRN" "$C_RESET" "$(get_localized_string CUES_RB_DONE "$out")"
          else
            printf "%s[ERR]%s Fallo al extraer cues desde Rekordbox XML.\n" "$C_RED" "$C_RESET"
          fi
          pause_enter
        fi
        ;;
      5)
        clear
        printf "%s[INFO]%s %s\n" "$C_CYN" "$C_RESET" "$(get_localized_string CUES_HEADER_ABLETON)"
        cues="$REPORTS_DIR/dj_cues.tsv"
        out="$REPORTS_DIR/ableton_locators.csv"
        if [ ! -f "$cues" ]; then
          printf "%s[ERR]%s %s\n" "$C_RED" "$C_RESET" "$(get_localized_string NO_DJ_CUES)"
          pause_enter
        else
          if ! ensure_python_bin; then
            pause_enter
            break
          fi
          bridge="${ROOT_DIR:-}/lib/rekordbox_cues_bridge.py"
          if [ ! -f "$bridge" ]; then
            bridge="$LIB_DIR/rekordbox_cues_bridge.py"
          fi
          if [ ! -f "$bridge" ]; then
            printf "%s[ERR]%s No se encuentra rekordbox_cues_bridge.py\n" "$C_RED" "$C_RESET"
            pause_enter
            break
          fi
          if "$PYTHON_BIN" "$bridge" to-ableton --cues "$cues" --out "$out" --default-bpm 120; then
            printf "%s[OK]%s %s\n" "$C_GRN" "$C_RESET" "$(get_localized_string LOCATORS_DONE "$out")"
          else
            printf "%s[ERR]%s Fallo al convertir dj_cues.tsv a ableton_locators.csv.\n" "$C_RED" "$C_RESET"
          fi
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
    printf "%s10)%s Helpers rsync por lotes desde consolidation_plan (D10)\n" "$C_YLW" "$C_RESET"
    printf "Flujo sugerido: D1 -> D2 -> D3, luego aplicar 10/11/44 con backup previo si SafeMode=0.\n"
    printf "Tip: GENERAL_ROOT es la raíz que se cataloga en D1/D2/D3. D4 compara destino vs orígenes. D5 acepta varias raíces separadas por coma. D6 marca sobrantes; D7 estructura; D8 contenido; D10 crea helpers de rsync en lotes desde el plan de consolidación.\n"
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
        if [ ! -s "$cat_file" ]; then
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
          printf "rsync -av --progress %q %q\n" "$src" "$target" >>"$rsync_helper"
        done <"$plan_conso"
        chmod +x "$rsync_helper" 2>/dev/null || true
        printf "Acción recomendada: revisar y luego ejecutar el helper: %s (SAFE_MODE no aplica, revisa antes de correrlo).\n" "$rsync_helper"
        pause_enter
        ;;
      10)
        clear
        printf "%s[INFO]%s D10) Helpers rsync por lotes desde consolidation_plan.tsv (solo genera scripts, no mueve nada).\n" "$C_CYN" "$C_RESET"
        default_plan="$PLANS_DIR/consolidation_plan.tsv"
        printf "Ruta del plan (ENTER usa %s): " "$default_plan"
        read -e -r plan_path
        plan_path=$(strip_quotes "$plan_path")
        [ -z "$plan_path" ] && plan_path="$default_plan"
        if [ ! -f "$plan_path" ]; then
          printf "%s[ERR]%s No existe el plan: %s\n" "$C_RED" "$C_RESET" "$plan_path"
          pause_enter
          continue
        fi
        printf "Tamaño de lote en GB (ENTER=50): "
        read -r batch_gb
        if [ -z "$batch_gb" ]; then
          batch_gb=50
        elif ! printf "%s" "$batch_gb" | grep -Eq '^[0-9]+$'; then
          printf "%s[WARN]%s Valor inválido, usando 50 GB.\n" "$C_YLW" "$C_RESET"
          batch_gb=50
        fi
        printf "Mínimo de GB libres antes de cada batch (ENTER=20): "
        read -r min_free_gb
        if [ -z "$min_free_gb" ]; then
          min_free_gb=20
        elif ! printf "%s" "$min_free_gb" | grep -Eq '^[0-9]+$'; then
          printf "%s[WARN]%s Valor inválido, usando 20 GB.\n" "$C_YLW" "$C_RESET"
          min_free_gb=20
        fi
        printf "¿Añadir --remove-source-files tras copiar? (liberar origen) [s/N]: "
        read -r rm_src_ans
        case "$rm_src_ans" in
          [sSyY]* ) remove_src=1 ;;
          * ) remove_src=0 ;;
        esac
        batch_bytes=$((batch_gb * 1024 * 1024 * 1024))
        [ "$batch_bytes" -le 0 ] && batch_bytes=$((50 * 1024 * 1024 * 1024)) && batch_gb=50
        mkdir -p "$PLANS_DIR"
        rm -f "$PLANS_DIR"/consolidation_rsync_batch*.sh
        batch_idx=1
        batch_files=0
        batch_size=0
        total_batches=0
        total_files=0
        total_bytes=0
        missing=0
        batch_summary=""
        current_batch=""
        new_batch() {
          current_batch=$(printf "%s/consolidation_rsync_batch%02d.sh" "$PLANS_DIR" "$batch_idx")
          {
            printf "#!/usr/bin/env bash\n"
            printf "set -euo pipefail\n"
            printf "MIN_FREE_GB=%q\n" "$min_free_gb"
            printf "BATCH_SIZE_GB=%q\n" "$batch_gb"
            printf "REMOVE_SRC=%q\n" "$remove_src"
            printf "LOG_DIR=%q\n" "$LOG_DIR"
            printf "RSYNC_BIN=${RSYNC_BIN:-rsync}\n"
            printf "BATCH_NAME=%q\n" "$(basename "$current_batch")"
            cat <<'EOSCRIPT'
log_file="${LOG_DIR}/${BATCH_NAME%.sh}.log"
mkdir -p "$(dirname "$log_file")"
touch "$log_file" 2>/dev/null || true
exec > >(tee -a "$log_file") 2>&1
min_free_bytes=$((MIN_FREE_GB * 1024 * 1024 * 1024))
copied=0; copied_bytes=0; missing=0; failed=0
supports_protect_args=0
if "$RSYNC_BIN" --protect-args --version >/dev/null 2>&1; then
  supports_protect_args=1
fi
RSYNC_ARGS=(-av --info=progress2)
[ "$supports_protect_args" -eq 1 ] && RSYNC_ARGS+=(--protect-args)
[ "$REMOVE_SRC" -eq 1 ] && RSYNC_ARGS+=(--remove-source-files)
fmt_gb() { awk -v b="$1" 'BEGIN{printf "%.2f", b/1024/1024/1024}'; }
check_space() {
  dir="$1"; needed="${2:-0}"
  free_kb=$(df -Pk "$dir" 2>/dev/null | awk 'NR==2{print $4}')
  if [ -z "$free_kb" ]; then
    printf "[WARN] No se pudo obtener espacio libre para %s (continuando).\n" "$dir"
    return 0
  fi
  free_bytes=$((free_kb * 1024))
  if [ "$free_bytes" -lt $((min_free_bytes + needed)) ]; then
    printf "[ERR] Espacio insuficiente en %s: libre %.2f GB, requerido >= %.2f GB. Deteniendo batch.\n" "$dir" "$(fmt_gb "$free_bytes")" "$(fmt_gb $((min_free_bytes + needed)))"
    return 1
  fi
  return 0
}
process() {
  src="$1"; dst="$2"; size="$3"
  if [ ! -f "$src" ]; then
    printf "[WARN] Faltante: %s\n" "$src"
    missing=$((missing + 1))
    return
  fi
  dest_dir=$(dirname "$dst")
  mkdir -p "$dest_dir" || { printf "[ERR] No se pudo crear %s\n" "$dest_dir"; failed=$((failed + 1)); return; }
  if ! check_space "$dest_dir" "$size"; then
    exit 3
  fi
  "$RSYNC_BIN" "${RSYNC_ARGS[@]}" "$src" "$dst"
  st=$?
  if [ "$st" -ne 0 ]; then
    printf "[ERR] rsync falló (%s -> %s)\n" "$src" "$dst"
    failed=$((failed + 1))
    return
  fi
  copied=$((copied + 1))
  copied_bytes=$((copied_bytes + size))
}
EOSCRIPT
          } >"$current_batch"
          chmod +x "$current_batch" 2>/dev/null || true
          batch_files=0
          batch_size=0
        }
        close_batch() {
          if [ "$batch_files" -gt 0 ] && [ -n "$current_batch" ]; then
            total_batches=$((total_batches + 1))
            size_gb=$(awk -v b="$batch_size" 'BEGIN{printf "%.2f", b/1024/1024/1024}')
            batch_summary="${batch_summary}Batch ${batch_idx}: ${batch_files} archivos, ${size_gb} GB -> $(basename "$current_batch")\n"
            {
              cat <<'EOSUM'
fmt_gb() { awk -v b="$1" 'BEGIN{printf "%.2f", b/1024/1024/1024}'; }
printf "[INFO] Resumen batch %s: copiados=%s (%.2f GB) | faltantes=%s | fallidos=%s | log=%s\n" "$BATCH_NAME" "$copied" "$(fmt_gb "$copied_bytes")" "$missing" "$failed" "$log_file"
EOSUM
            } >>"$current_batch"
          fi
        }
        while IFS=$'\t' read -r src target; do
          [ -z "$src" ] && continue
          if [ ! -f "$src" ]; then
            printf "%s[WARN]%s Faltante en origen: %s\n" "$C_YLW" "$C_RESET" "$src"
            missing=$((missing + 1))
            continue
          fi
          size=$({ stat -f %z "$src" 2>/dev/null || echo 0; } | tr -d ' ')
          [ -z "$size" ] && size=0
          if [ -z "$current_batch" ]; then
            new_batch
          elif [ "$batch_files" -gt 0 ] && [ $((batch_size + size)) -gt "$batch_bytes" ]; then
            close_batch
            batch_idx=$((batch_idx + 1))
            new_batch
          fi
          printf "process %q %q %s\n" "$src" "$target" "$size" >>"$current_batch"
          batch_files=$((batch_files + 1))
          batch_size=$((batch_size + size))
          total_files=$((total_files + 1))
          total_bytes=$((total_bytes + size))
        done <"$plan_path"
        close_batch
        if [ "$total_batches" -eq 0 ]; then
          printf "%s[WARN]%s No se creó ningún batch (plan vacío o sin archivos válidos).\n" "$C_YLW" "$C_RESET"
          pause_enter
          continue
        fi
        total_gb=$(awk -v b="$total_bytes" 'BEGIN{printf "%.2f", b/1024/1024/1024}')
        printf "%s[OK]%s Batches creados: %s | Archivos: %s | Tamaño total: %s GB | Faltantes: %s | Min espacio: %s GB | remove-source: %s\n" "$C_GRN" "$C_RESET" "$total_batches" "$total_files" "$total_gb" "$missing" "$min_free_gb" "$remove_src"
        printf "Helpers en: %s (consolidation_rsync_batchXX.sh) con logs en %s\n" "$PLANS_DIR" "$LOG_DIR"
        printf "Resumen por batch:\n%s" "$batch_summary"
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
        
        # Map numeric model selection to names used by ml_tf.py
        case "$model_sel" in
          1) model_name="yamnet" ;;
          2) model_name="musictag" ;;
          3) model_name="vggish" ;;
          4) model_name="musicnn" ;;
          *) model_name="yamnet" ;;
        esac
        
        emb_file="$REPORTS_DIR/d9_embeddings.tsv"
        
        # Step 1: Generate Embeddings
        if "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" embeddings \
            --base "$GENERAL_ROOT" \
            --out "$emb_file" \
            --limit "$max_files" \
            --model "$model_name"; then
            
            # Step 2: Calculate Similarity
            if "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" similarity \
                --embeddings "$emb_file" \
                --out "$report_sim" \
                --threshold "$sim_thresh" \
                --top "$top_pairs"; then
                
                # Step 3: Create Plan (simple mapping from report)
                awk -F'\t' 'NR>1 {print $1"\t"$2"\tREVIEW"}' "$report_sim" > "$plan_sim"
                
                printf "%s[OK]%s Reporte similitud: %s\n" "$C_GRN" "$C_RESET" "$report_sim"
                printf "%s[OK]%s Plan similitud: %s\n" "$C_GRN" "$C_RESET" "$plan_sim"
            else
                printf "%s[ERR]%s Falló el cálculo de similitud.\n" "$C_RED" "$C_RESET"
            fi
        else
            printf "%s[ERR]%s Falló la generación de Embeddings.\n" "$C_RED" "$C_RESET"
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
  "$PYTHON_BIN" "$LIB_DIR/playlist_bridge.py" dmx "$pl_path" "$plan" "$base_ch" 2>/dev/null || {
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
    printf "%s3)%s Plan OSC/DMX desde playlist\n" "$C_GRN" "$C_RESET"
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

submenu_profiles_manager() {
  while true; do
    clear
    print_header
    printf "%s=== Gestor de Perfiles ===%s\n" "$C_CYN" "$C_RESET"
    printf "Perfil Actual: BASE=%s | AUDIO=%s | GENERAL=%s\n" "$BASE_PATH" "${AUDIO_ROOT:-}" "${GENERAL_ROOT:-}"
    printf "%s1)%s Guardar rutas actuales en un perfil\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Cargar perfil\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Listar perfiles\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Volver\n" "$C_YLW" "$C_RESET"
    printf "%sOpción:%s " "$C_BLU" "$C_RESET"
    read -r pop
    case "$pop" in
      1)
        printf "Nombre del perfil (ej. EstudioA): "
        read -r pname
        pname=$(strip_quotes "$pname")
        if [ -n "$pname" ]; then
          mkdir -p "$PROFILES_DIR"
          pfile="$PROFILES_DIR/${pname}.conf"
          {
            printf "BASE_PATH=%q\n" "$BASE_PATH"
            printf "AUDIO_ROOT=%q\n" "${AUDIO_ROOT:-}"
            printf "GENERAL_ROOT=%q\n" "${GENERAL_ROOT:-}"
          } > "$pfile"
          printf "%s[OK]%s Guardado en %s\n" "$C_GRN" "$C_RESET" "$pfile"
        fi
        pause_enter
        ;;
      2)
        printf "Perfiles en %s:\n" "$PROFILES_DIR"
        ls -1 "$PROFILES_DIR"/*.conf 2>/dev/null | xargs -n 1 basename .conf 2>/dev/null
        printf "Nombre del perfil a cargar: "
        read -r pname
        pname=$(strip_quotes "$pname")
        pfile="$PROFILES_DIR/${pname}.conf"
        if [ -f "$pfile" ]; then
          # shellcheck disable=SC1090
          . "$pfile"
          save_conf
          printf "%s[OK]%s Cargado.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s No encontrado.\n" "$C_RED" "$C_RESET"
        fi
        pause_enter
        ;;
      3)
        ls -1 "$PROFILES_DIR"/*.conf 2>/dev/null
        pause_enter
        ;;
      B|b) break ;;
      *) invalid_option ;;
    esac
  done
}

action_audio_lufs_plan() {
  print_header
  out="$PLANS_DIR/audio_lufs_plan.tsv"
  printf "%s[INFO]%s Plan de Análisis LUFS -> %s\n" "$C_CYN" "$C_RESET" "$out"
  ensure_python_bin || { pause_enter; return; }
  
  if ! "$PYTHON_BIN" -c "import pyloudnorm" >/dev/null 2>&1; then
      printf "%s[WARN]%s pyloudnorm no encontrado. Instala con la Opción 68 o 'pip install pyloudnorm'.\n" "$C_YLW" "$C_RESET"
      printf "¿Instalar ahora en el venv? [S/n]: "
      read -r ans
      if [[ "$ans" =~ ^[SsYy] ]]; then
         check_connectivity || { pause_enter; return; }
         maybe_activate_ml_env "LUFS" 0 0
         "$PYTHON_BIN" -m pip install pyloudnorm soundfile
      else
         pause_enter; return
      fi
  fi
  
  if "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" loudness --base "$BASE_PATH" --out "$out" --limit "$DJPT_TF_BATCH" --target -14.0 --tolerance 1.0; then
      printf "%s[OK]%s Plan generado.\n" "$C_GRN" "$C_RESET"
  else
      printf "%s[ERR]%s Falló.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_audio_cues_onsets() {
  print_header
  out="$PLANS_DIR/audio_onsets_cues.tsv"
  printf "%s[INFO]%s Auto-Cues (Onsets) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  ensure_python_bin || { pause_enter; return; }

  if ! "$PYTHON_BIN" -c "import librosa" >/dev/null 2>&1; then
       printf "%s[WARN]%s librosa no encontrado.\n" "$C_YLW" "$C_RESET"
       pause_enter; return
  fi

  if "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" segments --base "$BASE_PATH" --out "$out" --limit "$DJPT_TF_BATCH"; then
      printf "%s[OK]%s Cues generados.\n" "$C_GRN" "$C_RESET"
  else
      printf "%s[ERR]%s Falló.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
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

  printf "%sHerramientas adicionales 53-67:%s\n" "$C_YLW" "$C_RESET"
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
  printf "  65) TensorFlow Lab: auto-tagging (modelos: YAMNet/NNFP/VGGish/musicnn; 150 archivos, top3), similitud (presets: rápido/balanceado/estricto), detección de loops/sospechosos (heurística), music tagging multi-label (150). Requiere TF/tf_hub/soundfile.\n"
  printf "  66) Plan LUFS (análisis, sin normalizar) – requiere python3+pyloudnorm+soundfile.\n"
  printf "  67) Auto-cues por onsets (librosa) – requiere python3+librosa.\n\n" "$ML_PKG_TF_MB"
  printf "  68) Instalar deps Python en venv (pyserial, python-osc, librosa, soundfile).\n\n"

  printf "%sNotas rápidas de procesos (qué hacen internamente):%s\n" "$C_YLW" "$C_RESET"
  printf "  D4: indexa destino por nombre+tamaño y lista faltantes desde orígenes → plan TSV + helper rsync.\n"
   printf "  D10: crea helpers de rsync en lotes (50 GB por defecto) desde consolidation_plan.tsv sin mover archivos.\n"
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
  printf "  L4) Cues Rekordbox XML -> dj_cues.tsv.\n"
  printf "  L5) dj_cues.tsv -> ableton_locators.csv.\n\n"

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

action_run_tests() {
  print_header
  printf "%s[INFO]%s Ejecutando suite de pruebas completa...\n" "$C_CYN" "$C_RESET"
  
  local test_runner_script="$SCRIPT_DIR/../tests/run_all_tests.sh"
  
  if [ -f "$test_runner_script" ]; then
    # Dar permisos por si acaso y ejecutar
    chmod +x "$test_runner_script"
    if bash "$test_runner_script"; then
      printf "\n%s[OK]%s Todos los tests se completaron con éxito.\n" "$C_GRN" "$C_RESET"
    else
      printf "\n%s[ERR]%s Algunos tests fallaron. Revisa la salida para más detalles.\n" "$C_RED" "$C_RESET"
    fi
  else
    printf "%s[ERR]%s No se encuentra el script de tests principal: %s\n" "$C_RED" "$C_RESET" "$test_runner_script"
  fi
  
  pause_enter
}

# Shared AI actions + compatibility wrappers (ES/EN numeric parity)
ROOT_DIR="${DJPT_BASE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
if [ -f "$SCRIPT_DIR/ai_actions.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/ai_actions.sh"
fi
if [ -f "$SCRIPT_DIR/ai/enhanced_chat_functions.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/ai/enhanced_chat_functions.sh"
fi

# Numeric parity wrappers for menu contract v1 (ES dispatch as source of truth)
action_55_ableton_tools() {
  submenu_ableton_tools
}
action_56_importers() {
  submenu_importers_cues
}
action_57_submenu_excludes() {
  submenu_excludes_manager
}
action_58_hash_compare() {
  action_compare_hash_indexes
}
action_59_health_check() {
  action_state_health
}
action_60_export_import_config() {
  action_export_import_config
}
action_61_mirror_check() {
  action_mirror_integrity_check
}
action_80_ai_advanced_menu() {
  action_ai_advanced_menu
}
action_81_ai_lab() {
  action_ai_lab
}
action_82_ai_optimization() {
  action_ai_optimization
}
action_83_ai_global_config() {
  action_ai_global_config
}
action_84_ai_learning_system() {
  action_ai_learning_system
}
action_85_ai_educator() {
  action_ai_educator
}
action_86_ai_document_analysis() {
  action_ai_document_analysis
}
action_87_install_local_models() {
  action_install_local_models
}
action_local_models_manager() {
  action_install_local_models
}
submenu_C_chat() {
  action_chat_cli
}
submenu_H_help() {
  action_H_help_info
}
submenu_R_repair_system() {
  action_error_recovery
}

delegate_to_canonical_es_action() {
  local action_number="$1"
  shift || true
  local target="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"
  if [ ! -x "$target" ]; then
    printf "%s[ERR]%s Canonical ES script not found: %s\n" "$C_RED" "$C_RESET" "$target"
    return 1
  fi
  BASE_PATH="${BASE_PATH:-$ROOT_DIR}" bash "$target" --run "$action_number" "$@"
}

if ! declare -f action_ai_backends_manager >/dev/null 2>&1; then
  action_ai_backends_manager() { delegate_to_canonical_es_action 71 "$@"; }
fi
if ! declare -f action_install_ai_deps >/dev/null 2>&1; then
  action_install_ai_deps() { delegate_to_canonical_es_action 72 "$@"; }
fi
if ! declare -f action_ai_advanced_config >/dev/null 2>&1; then
  action_ai_advanced_config() { delegate_to_canonical_es_action 74 "$@"; }
fi
if ! declare -f action_ai_train_models >/dev/null 2>&1; then
  action_ai_train_models() { delegate_to_canonical_es_action 75 "$@"; }
fi
if ! declare -f action_ai_knowledge_base >/dev/null 2>&1; then
  action_ai_knowledge_base() { delegate_to_canonical_es_action 76 "$@"; }
fi
if ! declare -f action_ui_config >/dev/null 2>&1; then
  action_ui_config() { delegate_to_canonical_es_action 77 "$@"; }
fi
if ! declare -f action_smart_scan >/dev/null 2>&1; then
  action_smart_scan() { delegate_to_canonical_es_action 78 "$@"; }
fi
if ! declare -f action_error_recovery >/dev/null 2>&1; then
  action_error_recovery() { delegate_to_canonical_es_action 79 "$@"; }
fi
if ! declare -f action_enhanced_chat_cli >/dev/null 2>&1; then
  action_enhanced_chat_cli() { delegate_to_canonical_es_action 89 "$@"; }
fi
if ! declare -f action_launch_serato_organizer >/dev/null 2>&1; then
  action_launch_serato_organizer() {
    print_header
    printf "%s[INFO]%s Launching SERATO Organizer...\n" "$C_CYN" "$C_RESET"
    local serato_script=""
    for cand in \
      "$ROOT_DIR/../_SeratOrganizer/SeratOrganizer.sh" \
      "/Volumes/SeaGate2TB/_SeratOrganizer/SeratOrganizer.sh" \
      "$ROOT_DIR/../_SERATORGANIZER/SERATO_ORGANIZER.sh" \
      "/Volumes/SeaGate2TB/_SERATORGANIZER/SERATO_ORGANIZER.sh"; do
      if [ -f "$cand" ]; then
        serato_script="$cand"
        break
      fi
    done
    if [ -z "$serato_script" ]; then
      printf "%s[ERR]%s Serato Organizer script not found.\n" "$C_RED" "$C_RESET"
      pause_enter
      return
    fi
    bash "$serato_script" || true
    pause_enter
  }
fi

# Chat->menu action policy: block destructive numeric actions unless explicitly allowed.
BLOCKED_DESTRUCTIVE_ACTIONS="11 12"
run_numeric_action_safe() {
  local action="$1"
  case " $BLOCKED_DESTRUCTIVE_ACTIONS " in
    *" $action "*)
      if [ "${DJPT_ALLOW_DESTRUCTIVE:-0}" != "1" ]; then
        printf "%s[BLOCKED]%s Action %s is destructive. Set DJPT_ALLOW_DESTRUCTIVE=1 to allow.\n" "$C_RED" "$C_RESET" "$action"
        return 1
      fi
      ;;
  esac
  case "$action" in
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
    55) action_55_ableton_tools ;;
    56) action_56_importers ;;
    57) action_57_submenu_excludes ;;
    58) action_58_hash_compare ;;
    59) action_59_health_check ;;
    60) action_60_export_import_config ;;
    61) action_61_mirror_check ;;
    62) action_ml_evo_manager ;;
    63) action_toggle_ml ;;
    64) action_tensorflow_manager ;;
    65) submenu_T_tensorflow_lab ;;
    66) action_audio_lufs_plan ;;
    67) action_audio_cues_onsets ;;
    68) action_install_all_python_deps ;;
    69) action_69_shared_corpus ;;
    70) action_ai_status ;;
    71) action_ai_backends_manager ;;
    72) action_install_ai_deps ;;
    73) action_chat_cli ;;
    74) action_ai_advanced_config ;;
    75) action_ai_train_models ;;
    76) action_ai_knowledge_base ;;
    77) action_ui_config ;;
    78) action_smart_scan ;;
    79) action_error_recovery ;;
    80) action_80_ai_advanced_menu ;;
    81) action_81_ai_lab ;;
    82) action_82_ai_optimization ;;
    83) action_83_ai_global_config ;;
    84) action_84_ai_learning_system ;;
    85) action_85_ai_educator ;;
    86) action_86_ai_document_analysis ;;
    87) action_87_install_local_models ;;
    88) action_local_models_manager ;;
    89) action_enhanced_chat_cli ;;
    90) action_launch_serato_organizer ;;
    *)
      printf "%s[ERR]%s Unknown numeric action: %s\n" "$C_RED" "$C_RESET" "$action"
      return 1
      ;;
  esac
}

main_loop() {
  while true; do
    print_header
    print_menu
    printf "%s%s%s " "$C_BLU" "$(get_localized_string PROMPT_OPTION)" "$C_RESET"
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
      AI) action_ai_status ;;
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
      55) action_55_ableton_tools ;;
      56) action_56_importers ;;
      57) action_57_submenu_excludes ;;
      58) action_58_hash_compare ;;
      59) action_59_health_check ;;
      60) action_60_export_import_config ;;
      61) action_61_mirror_check ;;
      62) action_ml_evo_manager ;;
      63) action_toggle_ml ;;
      64) action_tensorflow_manager ;;
      65) submenu_T_tensorflow_lab ;;
      66) action_audio_lufs_plan ;;
      67) action_audio_cues_onsets ;;
      68) action_install_all_python_deps ;;
      69) action_69_shared_corpus ;;
      70) action_ai_status ;;
      71) action_ai_backends_manager ;;
      72) action_install_ai_deps ;;
      73) action_chat_cli ;;
      74) action_ai_advanced_config ;;
      75) action_ai_train_models ;;
      76) action_ai_knowledge_base ;;
      77) action_ui_config ;;
      78) action_smart_scan ;;
      79) action_error_recovery ;;
      80) action_80_ai_advanced_menu ;;
      81) action_81_ai_lab ;;
      82) action_82_ai_optimization ;;
      83) action_83_ai_global_config ;;
      84) action_84_ai_learning_system ;;
      85) action_85_ai_educator ;;
      86) action_86_ai_document_analysis ;;
      87) action_87_install_local_models ;;
      88) action_local_models_manager ;;
      89) action_enhanced_chat_cli ;;
      90) action_launch_serato_organizer ;;
      C|c) submenu_C_chat ;;
      # La opción de cambiar idioma ahora se gestiona en main.sh al inicio
      L|l) submenu_L_libraries ;;
      I|i) submenu_I_integrations ;;
      D|d) submenu_D_dupes_general ;;
      V|v) submenu_V_visuals ;;
      T|t) submenu_T_tensorflow_lab ;;
      B|b) break ;;
      R|r|DR|dr) submenu_R_repair_system ;;
      H|h) submenu_H_help ;;
      0) break ;;
      *) invalid_option ;;
    esac
  done
}

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
if [ -n "${DJPT_EXPLICIT_BASE_PATH:-}" ] && [ -d "${DJPT_EXPLICIT_BASE_PATH}" ]; then
  BASE_PATH="$DJPT_EXPLICIT_BASE_PATH"
fi
ensure_base_path_valid
ensure_general_root_valid

# Si hay GENERAL_ROOT configurado y válido, úsalo como BASE_PATH preferente
if [ -z "${DJPT_EXPLICIT_BASE_PATH:-}" ] && [ -n "${GENERAL_ROOT:-}" ] && [ -d "$GENERAL_ROOT" ] && [ "$BASE_PATH" != "$GENERAL_ROOT" ]; then
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

if [ -n "$RUN_ACTION" ]; then
  # Map keywords to actions or numbers
  case "$RUN_ACTION" in
    status) action_1_status ;;
    scan) action_6_scan_workspace ;;
    backup) action_7_backup_serato; action_8_backup_dj ;;
    hash) action_9_hash_index ;;
    dupes) action_10_dupes_plan ;;
    smart) action_40_smart_analysis ;;
    predict) action_41_ml_predictor ;;
    optimize) action_42_efficiency_optimizer ;;
    workflow) action_43_smart_workflow ;;
    tensorflow) action_tensorflow_manager ;;
    mlx) action_mlx_test ;;
    deps) action_install_all_python_deps ;;
    ml_evo) action_ml_evo_manager ;;
    integrated_dedup) action_44_integrated_dedup ;;
    ai_status) action_ai_status ;;
    ai_backends) action_ai_backends_manager ;;
    ai_chat|chat) action_chat_cli ;;
    ai_health|repair) action_error_recovery ;;
    *) 
      if [[ "$RUN_ACTION" =~ ^[0-9]+$ ]]; then
         run_numeric_action_safe "$RUN_ACTION" || exit 1
      else
         printf "[ERR] Acción desconocida: %s\n" "$RUN_ACTION"
         exit 1
      fi
      ;;
  esac
  exit 0
fi

main_loop
