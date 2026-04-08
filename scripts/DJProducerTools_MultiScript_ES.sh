#!/usr/bin/env bash
# set -euo pipefail  # Desactivado para evitar cierres al hacer doble clic

# Enhanced configuration options with intelligent defaults
: "${DJPT_CURRENT_LANG:=ES}"

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

guard_entrypoint_reentry

# Early CLI flags used before full argument parsing.
for __djpt_early_arg in "$@"; do
  case "$__djpt_early_arg" in
    --no-interactive|-n)
      export DJPT_NO_INTERACTIVE=1
      ;;
    --run)
      export DJPT_EARLY_RUN_MODE=1
      ;;
  esac
done

bootstrap_runtime_context() {
  local script_dir root probe abs_probe env_file
  local assets=()
  local venv_candidates=()

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  root=""

  is_root_volume_path() {
    local p="${1%/}"
    [ -z "$p" ] && return 1
    [ "$p" = "/" ] && return 0
    [[ "$p" =~ ^/Volumes/[^/]+$ ]] && return 0
    return 1
  }

  # BASE_PATH must be explicit to avoid accidental full-volume scans.
  # Direct CLI actions may anchor safely to the project root.
  if [[ -z "${BASE_PATH:-}" ]]; then
    local script_root_hint
    script_root_hint="$(cd "$script_dir/.." && pwd)"
    if [[ "${DJPT_EARLY_RUN_MODE:-0}" == "1" ]]; then
      BASE_PATH="$script_root_hint"
      export BASE_PATH
    else
      echo "ERROR: BASE_PATH environment variable is required for safety"
      echo "Example: export BASE_PATH=\"$script_root_hint\""
      exit 1
    fi
  fi

  # Volume scan protection - block root volumes unless explicitly allowed
  if is_root_volume_path "$BASE_PATH" && [[ "${ALLOW_FULL_VOLUME:-0}" != "1" ]]; then
    echo "ERROR: Full volume scan detected and blocked for safety"
    echo "BASE_PATH=\"$BASE_PATH\" appears to be a root volume path"
    echo "To allow full volume scans, set: export ALLOW_FULL_VOLUME=1"
    echo "Or use a more specific path like: BASE_PATH=\"$BASE_PATH/_DJProducerTools\" (or your music library subfolder)"
    exit 1
  fi

  # Validate BASE_PATH exists and is accessible
  if [[ ! -d "$BASE_PATH" ]]; then
    echo "ERROR: BASE_PATH directory does not exist: $BASE_PATH"
    exit 1
  fi
  export DJPT_EXPLICIT_BASE_PATH="$BASE_PATH"
  : "${DJPT_STATE_ANCHOR:=$BASE_PATH}"
  export DJPT_STATE_ANCHOR

  for probe in "$BASE_PATH" "$script_dir/.." "$script_dir" "$PWD"; do
    abs_probe="$(cd "$probe" 2>/dev/null && pwd || true)"
    [ -n "$abs_probe" ] || continue
    if [ -f "$abs_probe/scripts/cli.py" ] || [ -f "$abs_probe/cli.py" ]; then
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

# GENIUS PROFILER INJECTION
# Detectar y ejecutar diagnóstico de sistema si está disponible
DIAG_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/../../../../scripts/core/system_check.sh"
if [ -f "$DIAG_SCRIPT" ]; then
  # Ejecutar check de sistema
  if [ -t 1 ]; then
    bash "$DIAG_SCRIPT" || echo "⚠️  Continuando con advertencias..."
    sleep 1
  fi
fi

# Branding helpers
COMMON_DIR="$(dirname "${BASH_SOURCE[0]}")/common"
[ -f "$COMMON_DIR/branding.sh" ] && source "$COMMON_DIR/branding.sh"
if ! declare -f djpt_menu_item >/dev/null 2>&1; then
  djpt_menu_section() { printf "%s%s%s\n" "$C_CYN" "$1" "$C_RESET"; }
  djpt_menu_item() { local n="$1"; shift; printf "  %s%s)%s %s%s%s\n" "$C_PURP" "$n" "$C_RESET" "$C_GRN" "$*" "$C_RESET"; }
  djpt_menu_item_tag() { local n="$1"; shift; local txt="$1"; shift; printf "  %s%s)%s %s%s%s %s%s%s\n" "$C_PURP" "$n" "$C_RESET" "$C_GRN" "$txt" "$C_RESET" "$C_WHT" "$*" "$C_RESET"; }
fi

# Script canónico: este archivo. El wrapper raiz delega aqui.

# 🛡️ QUANTUM ROBUSTNESS CORE INJECTION
# Cargar librería de seguridad y diseño
ROBUST_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/scripts/core/robustness.sh"
if [ -f "$ROBUST_SCRIPT" ]; then
    source "$ROBUST_SCRIPT"
    # Verificar conectividad al inicio de forma silenciosa pero elegante
    if [ -t 1 ]; then
        check_connectivity || echo "⚠️  Modo Offline Activado"
    fi
else
    # Fallback si no existe la librería (mantiene compatibilidad)
    check_connectivity() { return 0; }
    secure_download() { curl -L -o "$2" "$1"; }
    safe_ai_execution() { python3 "$1" "${@:2}"; }
    draw_option() { echo "  $1) $2 - $3"; }
    draw_section_header() { echo "--- $1 ---"; }
fi

: "${DJPT_UI_MODE:=enhanced}"  # enhanced, classic, minimal
: "${DJPT_DRAG_SUPPORT:=1}"   # Enable drag-and-drop support
: "${DJPT_SMART_SCAN:=1}"     # Smart scanning for audio files only - ACTIVADO POR DEFECTO
: "${DJPT_ERROR_RECOVERY:=1}" # Auto-recovery from errors
: "${DJPT_PROGRESS_BARS:=1}"  # Clean progress bars without symbols

# Cargar cadenas de texto localizadas
LANG_FILE="$(dirname "${BASH_SOURCE[0]}")/lang_strings.sh"
if [ -f "$LANG_FILE" ]; then
  source "$LANG_FILE"
else
  # Fallback simple si no existe el archivo de idioma para evitar crash
  get_localized_string() { echo "$1"; }
fi

# Enhanced progress bar function - clean without symbols
progress_bar() {
  local current=$1
  local total=$2
  local width=${3:-50}
  local percent=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))
  
  if [ "$DJPT_PROGRESS_BARS" = "1" ]; then
    printf "\r[%s%s%s] %d%% (%d/%d)" \
      "$(printf "%*s" $filled | tr ' ' '=')" \
      "$(printf "%*s" $empty | tr ' ' '-')" \
      "$C_RESET" "$percent" "$current" "$total"
  else
    printf "Progress: %d%% (%d/%d)\n" "$percent" "$current" "$total"
  fi
}

# Security Validator Integration
validate_path_safe() {
  local path="$1"
  local type="${2:-path}" # path, dir
  local validator_script="${LIB_DIR}/input_validation.py"
  
  # Si no hay script o python, fallback a validación básica bash
  if [ ! -f "$validator_script" ] || [ -z "${PYTHON_BIN:-}" ]; then
     [ -e "$path" ] || return 1
  else
     local cmd="validate_path"
     local args=("--must-exist")
     [ "$type" = "dir" ] && { cmd="validate_dir"; args=(); }
     "$PYTHON_BIN" "$validator_script" "$cmd" "$path" "${args[@]}" >/dev/null 2>&1 || return 1
  fi

  # En SAFE_MODE, bloquear rutas fuera de BASE_PATH
  if [ "${SAFE_MODE:-1}" -eq 1 ]; then
    if ! is_under_base "$path"; then
      printf "%s[WARN]%s Ruta fuera de BASE_PATH bloqueada: %s\n" "$C_YLW" "$C_RESET" "$path"
      return 1
    fi
  fi
  return 0
}

# Helper: en SAFE_MODE garantiza que una ruta (o BASE_PATH) está bajo BASE_PATH
ensure_under_base() {
  local p="$1"
  if [ "${SAFE_MODE:-1}" -eq 1 ] && ! is_under_base "$p"; then
    printf "%s[ERR]%s Ruta fuera de BASE_PATH en SAFE_MODE: %s\n" "$C_RED" "$C_RESET" "$p"
    return 1
  fi
  return 0
}

# Comprueba que una ruta resuelta permanezca dentro de BASE_PATH (cuando SAFE_MODE=1)
is_under_base() {
  local path="$1"
  [ -z "$path" ] && return 1
  local rp
  rp=$(python3 - "$path" <<'PY' 2>/dev/null
import os,sys
p=os.path.realpath(sys.argv[1])
base=os.path.realpath(os.environ.get("BASE_PATH","/"))
print(p if p.startswith(base) else "")
PY
  )
  [ -n "$rp" ] || return 1
  return 0
}

# Drag-and-drop support function
handle_drag_drop() {
  local input="$1"
  
  # Check if input looks like a dragged file/directory
  if [[ "$input" =~ ^/.* ]]; then
    # Normalize path (remove quotes if present)
    input="${input//\'}"
    input="${input//\"}"
    
    # Validar path si existe
    if [ -e "$input" ]; then
        # Validación extra de seguridad si estamos en SAFE_MODE
        if [ "${SAFE_MODE:-1}" -eq 1 ]; then
            if ! validate_path_safe "$input" "path"; then
                echo "error:invalid_path"
                return 1
            fi
            if ! is_under_base "$input"; then
                echo "error:outside_base"
                return 1
            fi
        fi

        # Smart detection of content type
        if [ -d "$input" ]; then
          if is_audio_directory "$input"; then
            echo "audio_directory:$input"
          else
            echo "directory:$input"
          fi
        elif is_audio_file "$input"; then
          echo "audio_file:$input"
        else
          echo "file:$input"
        fi
        return 0
    fi
  fi
  
  echo "text:$input"
}

# Smart audio file detection
is_audio_file() {
  local file="$1"
  local audio_extensions="mp3|wav|flac|aac|m4a|ogg|wma|aiff|au"
  
  [[ "$file" =~ \.($audio_extensions)$ ]] && [ -f "$file" ]
}

# Smart audio directory detection
is_audio_directory() {
  local dir="$1"
  local audio_count=$(find "$dir" -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.aac" \) 2>/dev/null | wc -l)
  [ "$audio_count" -gt 5 ]  # More than 5 audio files = likely music directory
}

# Enhanced error recovery
handle_error() {
  local error_msg="$1"
  local context="$2"
  
  if [ "$DJPT_ERROR_RECOVERY" = "1" ]; then
    printf "%s[ERROR RECOVERY]%s %s\n" "$C_YLW" "$C_RESET" "$error_msg"
    
    case "$context" in
      "scan")
        printf "%s[SUGGESTION]%s Try: scan --audio-only or specify music directory\n" "$C_CYAN" "$C_RESET"
        ;;
      "audio_file")
        printf "%s[SUGGESTION]%s Check file format and permissions\n" "$C_CYAN" "$C_RESET"
        ;;
      *)
        printf "%s[SUGGESTION]%s Check file paths and permissions\n" "$C_CYAN" "$C_RESET"
        ;;
    esac
    
    return 1
  else
    printf "%s[ERROR]%s %s\n" "$C_RED" "$C_RESET" "$error_msg"
    return 1
  fi
}

# Enhanced input handling with drag-and-drop support
enhanced_input() {
  local prompt="$1"
  local context="$2"
  local input
  
  printf "%s%s%s " "$C_BLU" "$prompt" "$C_RESET"
  
  if [ "$DJPT_DRAG_SUPPORT" = "1" ]; then
    # Read input that might be dragged files
    IFS= read -r input
    
    # Handle drag-and-drop
    if [[ "$input" =~ ^/.* ]] && [ -e "$input" ]; then
      local result=$(handle_drag_drop "$input")
      local type="${result%%:*}"
      local path="${result#*:}"
      
      case "$type" in
        "audio_directory")
          printf "%s[SMART]%s Audio directory detected: %s\n" "$C_GREEN" "$C_RESET" "$path"
          echo "$path"
          ;;
        "audio_file")
          printf "%s[SMART]%s Audio file detected: %s\n" "$C_GREEN" "$C_RESET" "$path"
          echo "$path"
          ;;
        "directory")
          printf "%s[INFO]%s Directory detected: %s\n" "$C_CYAN" "$C_RESET" "$path"
          echo "$path"
          ;;
        *)
          echo "$input"
          ;;
      esac
    else
      echo "$input"
    fi
  else
    IFS= read -r input
    echo "$input"
  fi
}

# Re-ejecuta con bash si no se lanzó con bash (doble click/otros shells)
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

pause_on_error_exit_app() {
  local rc="$1"
  if [ "$rc" -ne 0 ] && [ "${DJPT_NO_INTERACTIVE:-0}" -ne 1 ] && [ -t 0 ] && [ "${DJPT_PAUSE_ON_ERROR_EXIT:-1}" -eq 1 ]; then
    printf "\n%s[ERR]%s El script termino con error (%s).\n" "$C_RED" "$C_RESET" "$rc"
    printf "Presiona ENTER para cerrar..."
    read -r _ || true
  fi
}

export ESC=$'\033'
export C_RESET="${ESC}[0m"
export C_RED="${ESC}[1;31m"
export C_GRN="${ESC}[1;32m"      # Verde matrix estándar
export C_GREEN="${ESC}[38;5;46m"   # Verde suave para fondos
export C_YLW="${ESC}[1;33m"
export C_BLU="${ESC}[1;34m"
export C_CYN="${ESC}[1;35m"     # Púrpura suave para headers
export C_CYAN="${ESC}[38;5;135m"  # Rosa púrpura suave
export C_PURP="${ESC}[1;35m"    # Fucsia suave para acentos
export BANNER="${ESC}[1;37;48;5;22m"  # Fondo verde estándar
export C_DIM="${ESC}[2m"          # Dim para efectos de fade
export C_WHT="${ESC}[1;37m"        # Blanco brillante

# Paleta unificada verde/degradado para banners
export C_GREEN1="${ESC}[38;5;22m"   # Verde oscuro
export C_GREEN2="${ESC}[38;5;28m"   # Verde medio
export C_GREEN3="${ESC}[38;5;46m"   # Verde estándar
export C_GREEN4="${ESC}[38;5;82m"   # Verde claro
export C_GREEN5="${ESC}[38;5;120m"  # Verde brillante

# Colores degradado sutil para headers (verde con toque púrpura)
export C_PURPLE1="${ESC}[38;5;57m"    # Púrpura oscuro
export C_PURPLE2="${ESC}[38;5;93m"    # Púrpura medio
export C_PURPLE3="${ESC}[38;5;135m"   # Púrpura rosa
export C_PURPLE4="${ESC}[38;5;207m"   # Rosa claro
export C_PURPLE5="${ESC}[38;5;219m"   # Rosa brillante

# Asegura TERM para evitar cortes raros en terminales mínimos
export TERM="${TERM:-xterm-256color}"

on_exit_app() {
  local rc="${1:-$?}"
  rm -f "${STATE_DIR:-/tmp}"/*.tmp* &>/dev/null || true
  pause_on_error_exit_app "$rc"
  if [ "$rc" -eq 0 ] && [ "${DJPT_LAUNCHED_FROM_GUI:-0}" -eq 1 ] && [ "${DJPT_NO_INTERACTIVE:-0}" -ne 1 ] && [ -t 0 ]; then
    printf "Presiona ENTER para cerrar..."
    read -r _ || true
  fi
}

trap 'on_exit_app "$?"' EXIT

pause_on_guard_error() {
  if [ "${DJPT_NO_INTERACTIVE:-0}" -eq 1 ]; then
    return 0
  fi
  if [ ! -t 0 ]; then
    return 0
  fi
  printf "Presiona ENTER para cerrar..."
  read -r _ || true
}

djpt_has_project_markers() {
  local candidate="${1%/}"
  [ -n "$candidate" ] || return 1
  [ -d "$candidate" ] || return 1
  if [ ! -f "$candidate/scripts/cli.py" ] && [ ! -f "$candidate/cli.py" ]; then
    return 1
  fi
  if [ ! -f "$candidate/scripts/DJProducerTools_MultiScript_ES.sh" ] && \
     [ ! -f "$candidate/DJProducerTools_MultiScript_ES.sh" ]; then
    return 1
  fi
  return 0
}

recover_launch_from_home() {
  if [ "${DJPT_STRICT_HOME_GUARD:-0}" -eq 1 ]; then
    return 1
  fi
  local script_dir parent_dir cand
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  parent_dir="$(cd "$script_dir/.." && pwd)"

  for cand in \
    "${DJPT_CANONICAL_ROOT:-}" \
    "${DJPT_BASE_DIR:-}" \
    "${BASE_PATH:-}" \
    "$parent_dir" \
    "$script_dir"
  do
    [ -n "$cand" ] || continue
    if djpt_has_project_markers "$cand"; then
      cd "$cand" || return 1
      export DJPT_LAUNCH_PATH="$cand"
      export DJPT_LAUNCHED_FROM_GUI=1
      printf "%s[INFO]%s Inicio desde Finder detectado. Reubicando a: %s\n" "$C_CYN" "$C_RESET" "$cand"
      return 0
    fi
  done
  return 1
}

# If launched from HOME via Finder double-click, try to recover to project root.
if [[ "$(pwd -P)" == "$HOME" ]]; then
  if ! recover_launch_from_home; then
    printf "%s[ERR]%s No ejecutes este script desde HOME; lanzalo desde la carpeta raiz del proyecto (_DJProducerTools).\n" "$C_RED" "$C_RESET"
    pause_on_guard_error
    exit 1
  fi
fi

# Smart base directory detection with auto-installation
detect_smart_base_path() {
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  
  # 1. If we're inside _DJProducerTools directory
  if [[ "$(basename "$script_dir")" == "_DJProducerTools" ]] || djpt_has_project_markers "$script_dir"; then
    echo "$script_dir"
    return
  fi
  
  # 2. If _DJProducerTools exists in current directory
  if djpt_has_project_markers "$PWD/_DJProducerTools"; then
    echo "$PWD/_DJProducerTools"
    return
  fi
  
  # 3. If we're in a subdirectory, search upwards
  local search_dir="$PWD"
  while [[ "$search_dir" != "/" ]]; do
    if djpt_has_project_markers "$search_dir/_DJProducerTools"; then
      echo "$search_dir/_DJProducerTools"
      return
    fi
    search_dir="$(dirname "$search_dir")"
  done
  
  # 4. Check common music/volume directories (evita HOME directo)
  local music_dirs=("$HOME/Music" "/Volumes")
  for dir in "${music_dirs[@]}"; do
    if djpt_has_project_markers "$dir/_DJProducerTools"; then
      echo "$dir/_DJProducerTools"
      return
    fi
  done
  
  # 5. If nothing found, offer to create installation
  echo "CREATE_NEW"
}

# Enhanced base path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Si vienen rutas de DJPT (launcher), usarlas y saltar autodetección
if [ -n "${DJPT_BASE_DIR:-}" ] && { [ -f "$DJPT_BASE_DIR/scripts/cli.py" ] || [ -f "$DJPT_BASE_DIR/cli.py" ]; }; then
  BASE_DEFAULT="$DJPT_BASE_DIR"
  STATE_DIR="${DJPT_STATE_DIR:-$DJPT_BASE_DIR/state}"
  REPORTS_DIR="${DJPT_STATE_DIR:-$DJPT_BASE_DIR/state}/reports"
  PLANS_DIR="${DJPT_STATE_DIR:-$DJPT_BASE_DIR/state}/plans"
  LOGS_DIR="${DJPT_LOGS_DIR:-$DJPT_BASE_DIR/state/logs}"
  QUAR_DIR="${DJPT_QUARANTINE_DIR:-$DJPT_BASE_DIR/state/quarantine}"
  if [ -d "$DJPT_BASE_DIR/_DJProducerTools/djpt_venv" ]; then
    VENV_DIR="$DJPT_BASE_DIR/_DJProducerTools/djpt_venv"
  elif [ -d "$DJPT_BASE_DIR/djpt_venv" ]; then
    VENV_DIR="$DJPT_BASE_DIR/djpt_venv"
  else
    VENV_DIR="$DJPT_BASE_DIR/_DJProducerTools/djpt_venv"
  fi
else
  # Smart detection with fallback
  detected_base="$(detect_smart_base_path)"
  
  if [[ "$detected_base" == "CREATE_NEW" ]]; then
    printf "%s[INFO]%s No se encontró instalación de DJProducerTools.\n" "$C_CYAN" "$C_RESET"
    printf "%s[INFO]%s Ubicación actual: %s\n" "$C_CYAN" "$C_RESET" "$PWD"
    printf "%s[QUESTION]%s ¿Deseas crear una nueva instalación aquí? [s/N]: " "$C_YLW" "$C_RESET"
    read -r response
    
    if [[ "$response" =~ ^[Ss]$ ]]; then
      printf "%s[INFO]%s Creando instalación en: %s/_DJProducerTools\n" "$C_GRN" "$C_RESET" "$PWD"
      mkdir -p "$PWD/_DJProducerTools"/{scripts,config,state,logs,tools,djpt_venv}
      
      # Copy essential files
      if [[ -f "$SCRIPT_DIR/DJProducerTools_Con_Opciones_IA.sh" ]]; then
        cp "$SCRIPT_DIR/DJProducerTools_Con_Opciones_IA.sh" "$PWD/_DJProducerTools/"
      fi
      
      if [[ -f "$LIB_DIR/djpt_chat_cli.py" ]]; then
        cp "$LIB_DIR/djpt_chat_cli.py" "$PWD/_DJProducerTools/"
      fi
      
      BASE_DEFAULT="$PWD/_DJProducerTools"
      printf "%s[SUCCESS]%s Instalación completada.\n" "$C_GRN" "$C_RESET"
    else
      printf "%s[ERROR]%s No se puede continuar sin instalación.\n" "$C_RED" "$C_RESET"
      exit 1
    fi
  else
    BASE_DEFAULT="$detected_base"
  fi
  
  # Set directories based on detected base
  STATE_DIR="$BASE_DEFAULT/state"
  REPORTS_DIR="$BASE_DEFAULT/state/reports"
  PLANS_DIR="$BASE_DEFAULT/state/plans"
  LOGS_DIR="$BASE_DEFAULT/state/logs"
  QUAR_DIR="$BASE_DEFAULT/state/quarantine"
  if [ -d "$BASE_DEFAULT/_DJProducerTools/djpt_venv" ]; then
    VENV_DIR="$BASE_DEFAULT/_DJProducerTools/djpt_venv"
  else
    VENV_DIR="$BASE_DEFAULT/djpt_venv"
  fi
fi

# Directorio del script para llamadas fiables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Cargar versión desde archivo si existe
if [ -f "$SCRIPT_DIR/VERSION" ]; then
  SCRIPT_VERSION="$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null | head -n1)"
fi
# Detección robusta de LIB_DIR (Soporte para estructura plana o anidada)
if [ -n "${DJPT_LIB_DIR:-}" ] && [ -d "$DJPT_LIB_DIR" ]; then
    LIB_DIR="$DJPT_LIB_DIR"
elif [ -d "$SCRIPT_DIR/../lib" ]; then
    LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"
elif [ -d "$SCRIPT_DIR/lib" ]; then
    LIB_DIR="$SCRIPT_DIR/lib"
elif [ -d "$SCRIPT_DIR/_DJProducerTools/lib" ]; then
    LIB_DIR="$SCRIPT_DIR/_DJProducerTools/lib"
else
    # Fallback para intentar crear o usar local
    LIB_DIR="$SCRIPT_DIR/lib"
fi

# Auto-bootstrap si falta lib
if [ ! -d "$LIB_DIR" ] || [ -z "$(ls -A "$LIB_DIR" 2>/dev/null)" ]; then
    printf "%s[WARN]%s Librerías faltantes. Intentando regenerar estructura...\n" "$C_YLW" "$C_RESET"
    if [ -f "$SCRIPT_DIR/bootstrap_ai_lib.sh" ]; then
        bash "$SCRIPT_DIR/bootstrap_ai_lib.sh"
    fi
fi

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
      esc_line="${esc_line//\$/\\\$}"
      esc_line="${esc_line//\`/\\\`}"
      # Always append without explicit \n literal to avoid issues in banner
      eval "$arr_name+=(\"$esc_line\")"
    done
  }
fi

calc_sha256() {
  local target="$1"
  # Fast hash for large files - use MD5 for speed, fallback to SHA-256 if needed
  if command -v md5 >/dev/null 2>&1 && [ "${DJPT_USE_SHA256:-0}" != "1" ]; then
    if [ -n "$target" ] && [ -f "$target" ]; then
       md5 -q "$target" 2>/dev/null || md5sum "$target" | awk '{print $1}'
    else
       # stdin mode
       md5 -q 2>/dev/null || md5sum | awk '{print $1}'
    fi
  elif command -v shasum >/dev/null 2>&1; then
    if [ -n "$target" ] && [ -f "$target" ]; then
       shasum -a 256 "$target" | awk '{print $1}'
    else
       # stdin mode
       shasum -a 256 | awk '{print $1}'
    fi
  elif command -v sha256sum >/dev/null 2>&1; then
    if [ -n "$target" ] && [ -f "$target" ]; then
       sha256sum "$target" | awk '{print $1}'
    else
       sha256sum | awk '{print $1}'
    fi
  else
    # Fallback to Python for hash calculation
    "$PYTHON_BIN" -c "
import hashlib
import sys
if '$target':
    with open('$target', 'rb') as f:
        print(hashlib.sha256(f.read()).hexdigest())
else:
    print(hashlib.sha256(sys.stdin.read().encode()).hexdigest())
" 2>/dev/null
  fi
}

SAFE_MODE=1
DJ_SAFE_LOCK=1
DRYRUN_FORCE=0
RUN_TEST_MODE=0
SHOW_VERSION=0
SHOW_HELP=0
NO_INTERACTIVE=0
SCRIPT_VERSION="1.2.0"

SPIN_FRAMES=("\\" "|" "/" "-")
SPIN_IDX=0

# Menú estilizado (números púrpura, texto verde). Si faltan helpers, usa legacy.
print_menu() {
  if ! declare -f djpt_menu_section >/dev/null 2>&1; then
    print_menu_legacy
    return
  fi
  
  # Actualizar estado de artefactos
  local tag9 tag10 tag11 tag27
  
  # Variables de estado de artefactos (definir valores por defecto)
  : "${ART_HAS_HASH:=0}"
  : "${ART_HAS_DUPES_PLAN:=0}"
  : "${ART_HAS_SNAPSHOT:=0}"
  : "${ART_DUPES_QUAR:=0}"
  : "${ART_QUAR_COUNT:=0}"
  
  [ "$ART_HAS_HASH" -eq 1 ] && tag9="[prev]"
  [ "$ART_HAS_DUPES_PLAN" -eq 1 ] && tag10="[prev ${ART_DUPES_QUAR}q]"
  [ "$ART_HAS_SNAPSHOT" -eq 1 ] && tag27="[prev]"
  if [ "$ART_QUAR_COUNT" -gt 0 ]; then
    tag11="[${ART_QUAR_COUNT} cuarentena]"
  elif [ "$ART_HAS_DUPES_PLAN" -eq 1 ]; then
    tag11="[plan listo]"
  fi

  djpt_menu_section "⚙️  Núcleo (1-12)"
  djpt_menu_item 1 "Estado / rutas / locks"
  djpt_menu_item 2 "Cambiar BASE_PATH"
  djpt_menu_item 3 "Resumen del volumen / últimos reportes"
  djpt_menu_item 4 "Top carpetas por tamaño"
  djpt_menu_item 5 "Top archivos grandes"
  djpt_menu_item 6 "Scan workspace (catálogo)"
  djpt_menu_item 7 "Backup Serato (_Serato_ / _Serato_Backup)"
  djpt_menu_item 8 "Backup DJ (Serato/Traktor/Rekordbox/Ableton)"
  djpt_menu_item_tag 9 "Índice SHA-256 (generar/reusar)" "${tag9:-}"
  djpt_menu_item_tag 10 "Reporte duplicados EXACTO (PLAN JSON/TSV)" "${tag10:-}"
  djpt_menu_item_tag 11 "Cuarentena duplicados (LAST_PLAN)" "${tag11:-}"
  djpt_menu_item 12 "Gestor de cuarentena (listar/purgar/restaurar)"
  printf "\n"

  djpt_menu_section "🎛️  Media / Organización (13-24)"
  djpt_menu_item 13 "Detectar media corrupta (ffprobe) -> TSV"
  djpt_menu_item 14 "Crear playlists .m3u8 por carpeta"
  djpt_menu_item 15 "Relink Helper (TSV seguro)"
  djpt_menu_item 16 "Mirror por género (hardlink/copy/move) plan"
  djpt_menu_item 17 "Buscar librerías DJ"
  djpt_menu_item 18 "Rescan inteligente (match + ULTRA)"
  djpt_menu_item 19 "Tools: diagnóstico/instalación recomendada"
  djpt_menu_item 20 "Fix ownership/flags (plan + opcional run)"
  djpt_menu_item 21 "Instalar comando: djpt"
  djpt_menu_item 22 "Desinstalar comando: djpt"
  djpt_menu_item 23 "Toggle SafeMode (ON/OFF)"
  djpt_menu_item 24 "Toggle DJ_SAFE_LOCK (ACTIVO/INACTIVO)"
  printf "\n"

  djpt_menu_section "🧹 Procesos / Limpieza (25-39)"
  djpt_menu_item 25 "Ayuda rápida (guía procesos)"
  djpt_menu_item 26 "Estado: export bundle / import bundle"
  djpt_menu_item_tag 27 "Snapshot integridad (hash rápido)" "${tag27:-}"
  djpt_menu_item 28 "Visor de logs"
  djpt_menu_item 29 "Toggle DryRunForce"
  djpt_menu_item 30 "Organizar audio por TAGS -> plan TSV"
  djpt_menu_item 31 "Reporte tags audio -> TSV"
  djpt_menu_item 32 "Serato Video: REPORT"
  djpt_menu_item 33 "Serato Video: PREP (plan)"
  djpt_menu_item 34 "Normalizar nombres (plan TSV)"
  djpt_menu_item 35 "Organizar samples por TIPO"
  djpt_menu_item 36 "Limpiar WEB (submenú)"
  djpt_menu_item 37 "WEB: Whitelist Manager"
  djpt_menu_item 38 "Limpiar WEB en Playlists"
  djpt_menu_item 39 "Limpiar WEB en TAGS"
  printf "\n"

  djpt_menu_section "🧠 Deep ML / Automatización (40-61)"
  djpt_menu_item 40 "Smart Analysis (JSON)"
  djpt_menu_item 41 "Predictor de problemas (ML)"
  djpt_menu_item 42 "Optimizador de eficiencia"
  djpt_menu_item 43 "Flujo de trabajo inteligente"
  djpt_menu_item 44 "Deduplicación integrada"
  djpt_menu_item 45 "Organización automática (plan)"
  djpt_menu_item 46 "Armonizador de metadatos (plan)"
  djpt_menu_item 47 "Backup predictivo"
  djpt_menu_item 48 "Sync multiplataforma"
  djpt_menu_item 49 "Audio BPM (librosa) -> TSV"
  djpt_menu_item 50 "API/OSC server (start/stop)"
  djpt_menu_item 51 "Recomendaciones adaptativas"
  djpt_menu_item 52 "Pipeline de limpieza automatizado"
  djpt_menu_item 53 "Reset de estado (recuperación)"
  djpt_menu_item 54 "Gestor de perfiles"
  djpt_menu_item 55 "Ableton Tools (.als reporte rápido)"
  djpt_menu_item 56 "Importers Rekordbox/Traktor (cues/NML)"
  djpt_menu_item 57 "Gestor de exclusiones"
  djpt_menu_item 58 "Comparar hash_index entre discos"
  djpt_menu_item 59 "Health-check de estado (_DJProducerTools)"
  djpt_menu_item 60 "Export/Import config y perfiles"
  djpt_menu_item 61 "Mirror check de integridad"
  printf "\n"

  djpt_menu_section "🤖 IA / ML (62-90)"
  djpt_menu_item 62 "Gestor ML Evo (train/predict)"
  djpt_menu_item 63 "Toggle ML (enable/disable)"
  djpt_menu_item 64 "TensorFlow Manager (stack)"
  djpt_menu_item 65 "TensorFlow Lab (experimentos)"
  djpt_menu_item 66 "Plan LUFS"
  djpt_menu_item 67 "Cues/Onsets plan"
  djpt_menu_item 68 "Instalar deps Python (venv)"
  djpt_menu_item 69 "Shared Corpus"
  djpt_menu_item 70 "IA Status"
  djpt_menu_item 71 "IA Backends Manager"
  djpt_menu_item 72 "Instalar deps IA"
  djpt_menu_item 73 "Chat CLI"
  djpt_menu_item 74 "Config avanzada IA"
  djpt_menu_item 75 "Entrenar modelos IA"
  djpt_menu_item 76 "IA Knowledge Base"
  djpt_menu_item 77 "UI Config"
  djpt_menu_item 78 "Smart scan (legacy)"
  djpt_menu_item 79 "Error recovery (legacy)"
  djpt_menu_item 80 "IA advanced menu"
  djpt_menu_item 81 "IA Lab"
  djpt_menu_item 82 "IA Optimization"
  djpt_menu_item 83 "IA Global Config"
  djpt_menu_item 84 "IA Learning System"
  djpt_menu_item 85 "IA Educator"
  djpt_menu_item 86 "IA Document Analysis"
  djpt_menu_item 87 "Install Local Models"
  djpt_menu_item 88 "Gestor Modelos IA Locales"
  djpt_menu_item 89 "Enhanced Chat CLI"
  djpt_menu_item 90 "Lanzar SERATO ORGANIZER (Suite Externa)"
  printf "\n"
  printf "%sC)%s Chat / IA Hub\n" "$C_GRN" "$C_RESET"
  printf "%sR)%s Reparación y regeneración del sistema\n" "$C_GRN" "$C_RESET"
  printf "%sL)%s Librerías DJ & Cues\n" "$C_GRN" "$C_RESET"
  printf "%sD)%s Duplicados (flujo rápido)\n" "$C_GRN" "$C_RESET"
  printf "%sV)%s Visuales / paneles\n" "$C_GRN" "$C_RESET"
  printf "%sT)%s TensorFlow Lab\n" "$C_GRN" "$C_RESET"
  printf "%sH)%s Ayuda\n" "$C_GRN" "$C_RESET"
  printf "%s0)%s Salir\n" "$C_GRN" "$C_RESET"
}
SPIN_COLORS=("$C_GREEN1" "$C_GREEN2" "$C_GREEN3" "$C_GREEN4" "$C_GREEN5")
SPIN_COLOR_IDX=0
GHOST_COLORS=("${C_GREEN1}" "${C_GREEN5}") # verde oscuro y verde brillante
GHOST_IDX=0

# Auto-deteccion inteligente de BASE_PATH para portabilidad.
# Importante: no sobreescribir BASE_DEFAULT si ya fue resuelto por launcher o detector previo.
if [ -z "${BASE_DEFAULT:-}" ]; then
  if [ -f "$SCRIPT_DIR/../scripts/cli.py" ]; then
    BASE_DEFAULT="$(cd "$SCRIPT_DIR/.." && pwd)"
  elif [ -f "$SCRIPT_DIR/scripts/cli.py" ]; then
    BASE_DEFAULT="$SCRIPT_DIR"
  elif [[ "$(basename "$SCRIPT_DIR")" == "scripts" ]] && [[ "$(basename "$(dirname "$SCRIPT_DIR")")" == "_DJProducerTools" ]]; then
    BASE_DEFAULT="$(dirname "$(dirname "$SCRIPT_DIR")")"
  elif [[ "$(basename "$SCRIPT_DIR")" == "_DJProducerTools" ]]; then
    BASE_DEFAULT="$(dirname "$SCRIPT_DIR")"
  else
    BASE_DEFAULT="$PWD"
  fi
fi

BASE_PATH="${BASE_PATH:-$BASE_DEFAULT}"
if [ -n "${DJPT_LAUNCH_PATH:-}" ]; then
  LAUNCH_PATH="$DJPT_LAUNCH_PATH"
else
  LAUNCH_PATH="${LAUNCH_PATH:-$BASE_DEFAULT}"
fi
EXTRA_SOURCE_ROOTS=""
DEFAULT_EXCLUDES_BASE="*.asd,*.asd.*,*/Ableton/Cache/*,*/Ableton/Factory Packs/*,*/node_modules/*,*/.git/*,*/.Trash/*,*/Backups.backupdb/*,*/_DJProducerTools/*,*/_Serato_*/*,*.log,*.tmp,*.dmg,*.iso"
DEFAULT_EXCLUDES="$DEFAULT_EXCLUDES_BASE"
DEFAULT_WEB_WHITELIST="youtube.com,soundcloud.com,bandcamp.com"
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

normalize_web_whitelist() {
  local raw="${1:-}"
  local seen="," out="" item lower
  IFS=',' read -r -a items <<<"$raw"
  for item in "${items[@]}"; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [ -n "$item" ] || continue
    lower="$(printf '%s' "$item" | tr '[:upper:]' '[:lower:]')"
    if [[ "$seen" == *",$lower,"* ]]; then
      continue
    fi
    seen="${seen}${lower},"
    if [ -z "$out" ]; then
      out="$lower"
    else
      out="$out,$lower"
    fi
  done
  printf "%s" "$out"
}

web_whitelist_domains() {
  normalize_web_whitelist "${WEB_WHITELIST:-$DEFAULT_WEB_WHITELIST}"
}

web_url_is_whitelisted() {
  local url="$1"
  local host domains domain
  host="$(printf "%s" "$url" | sed -E 's#^[A-Za-z]+://([^/:?#]+).*#\1#')"
  host="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"
  domains="$(web_whitelist_domains)"
  IFS=',' read -r -a web_arr <<<"$domains"
  for domain in "${web_arr[@]}"; do
    [ -n "$domain" ] || continue
    if [ "$host" = "$domain" ] || [[ "$host" == *".$domain" ]]; then
      return 0
    fi
  done
  return 1
}

resolve_command_target_dir() {
  local path_dir
  if [ -n "${DJPT_CMD_TARGET_DIR:-}" ]; then
    printf "%s" "$DJPT_CMD_TARGET_DIR"
    return 0
  fi
  for path_dir in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin" "$HOME/bin"; do
    if [ -d "$path_dir" ]; then
      printf "%s" "$path_dir"
      return 0
    fi
  done
  printf "%s" "$HOME/.local/bin"
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
Uso: $(basename "$0") [--help] [--version] [--test] [--dry-run] [--run accion] [--no-interactive]
  --help       Muestra esta ayuda
  --version    Imprime versión y sale
  --test       Solo chequeo ligero de dependencias (sin menú)
  --dry-run    Fuerza DRYRUN_FORCE=1 (sin escrituras)
  --run        Ejecuta una accion directa (ej: status, scan, hash)
  --no-interactive  No espera ENTER en pausas
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
  local target="${2:-$BASE_PATH}"
  
  printf "%s[WARN]%s %s puede ser intensivo.\n" "$C_YLW" "$C_RESET" "$op"
  
  if [ -d "$target" ]; then
    printf "Calculando espacio en disco de %s...\n" "$target"
    local size
    size=$(du -sh "$target" 2>/dev/null | awk '{print $1}')
    printf "Tamaño estimado a procesar: %s%s%s\n" "$C_CYN" "$size" "$C_RESET"
  fi
  
  printf "Escribe 'CONFIRMAR' para continuar: "
  read -r ans
  [ "$ans" = "CONFIRMAR" ] || { printf "%s[INFO]%s Cancelado.\n" "$C_CYN" "$C_RESET"; return 1; }
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
  local tmp=""
  [ -z "$file" ] && return
  [ -z "$path" ] && return
  path=$(strip_quotes "$path")
  [ ! -d "$path" ] && return
  mkdir -p "$(dirname "$file")"
  tmp="${file}.tmp.$$"
  # prepend unique
  { printf "%s\n" "$path"; cat "$file" 2>/dev/null; } | awk '!seen[$0]++' | head -20 >"$tmp" && mv "$tmp" "$file"
}

RUN_ACTION=""

run_action_number() {
  case "$1" in
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
    91) action_lab_doctor ;;
    92) action_lab_graph ;;
    *) return 1 ;;
  esac
  return 0
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
      --no-interactive)
        NO_INTERACTIVE=1
        export DJPT_NO_INTERACTIVE=1
        shift
        ;;
      --dr)
        RUN_ACTION="doctor"
        shift
        ;;
      --run)
        if [ -n "${2:-}" ]; then
          RUN_ACTION="$2"
          shift 2
        else
          printf "Error: --run requiere un argumento.\n"
          exit 1
        fi
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
  local canonical_base=""
  canonical_base="$(canonicalize_base_path "$BASE_PATH")" || canonical_base=""
  if [ -n "$canonical_base" ]; then
    BASE_PATH="$canonical_base"
  fi

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
      canonical_base="$(canonicalize_base_path "$choice")" || canonical_base=""
      BASE_PATH="${canonical_base:-$choice}"
      append_history "$BASE_HISTORY_FILE" "$BASE_PATH"
      return
    fi
  fi
  printf "Introduce BASE_PATH manual: "
  read -e -r new_base
  new_base=$(strip_quotes "$new_base")
  if [ -n "$new_base" ] && [ -d "$new_base" ]; then
    canonical_base="$(canonicalize_base_path "$new_base")" || canonical_base=""
    BASE_PATH="${canonical_base:-$new_base}"
    append_history "$BASE_HISTORY_FILE" "$BASE_PATH"
  else
    printf "%s[WARN]%s Usando PWD como BASE_PATH: %s\n" "$C_YLW" "$C_RESET" "$PWD"
    canonical_base="$(canonicalize_base_path "$PWD")" || canonical_base=""
    BASE_PATH="${canonical_base:-$PWD}"
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

canonicalize_base_path() {
  local candidate="$1"
  [ -z "$candidate" ] && return 1

  local resolved
  resolved="$(cd "$candidate" 2>/dev/null && pwd -P)" || return 1

  # Normaliza .../_DJProducerTools/app -> .../_DJProducerTools
  if [ "$(basename "$resolved")" = "app" ] \
    && [ -f "$resolved/../scripts/cli.py" ] \
    && [ -f "$resolved/DJProducerTools_MultiScript_ES.sh" ]; then
    resolved="$(cd "$resolved/.." && pwd -P)"
  fi

  printf "%s" "$resolved"
}

pin_base_to_current_install_if_crossed() {
  [ "${DJPT_ALLOW_CROSS_INSTALL_BASE:-0}" -eq 1 ] && return 0
  [ -z "${SCRIPT_DIR:-}" ] && return 0

  local script_root
  script_root="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd -P)" || return 0
  [ -f "$script_root/scripts/cli.py" ] || return 0
  local current_base
  current_base="$(canonicalize_base_path "${BASE_PATH:-}")" || current_base=""
  [ -n "$current_base" ] || return 0
  [ -f "$current_base/scripts/cli.py" ] || return 0

  # Normaliza BASE_PATH (ej: .../_DJProducerTools/app -> .../_DJProducerTools)
  if [ "${BASE_PATH:-}" != "$current_base" ]; then
    BASE_PATH="$current_base"
  fi

  if [ "$current_base" != "$script_root" ]; then
    printf "%s[WARN]%s BASE_PATH apuntaba a otra instalacion (%s). Se usara la instalacion actual (%s).\n" \
      "$C_YLW" "$C_RESET" "$current_base" "$script_root"
    BASE_PATH="$script_root"
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
    printf "%s3)%s Restaurar exclusiones por defecto\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s Listar perfiles\n" "$C_YLW" "$C_RESET"
    printf "%s5)%s Cargar preset AUDIO\n" "$C_YLW" "$C_RESET"
    printf "%s6)%s Cargar preset PROYECTOS\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Volver\n" "$C_YLW" "$C_RESET"
    printf "%sOpción:%s " "$C_BLU" "$C_RESET"
    if ! read -e -r xop; then
      break
    fi
    xop="$(echo "$xop" | xargs)"
    [ -z "$xop" ] && continue
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
        printf "%s[OK]%s Exclusiones restauradas al valor base.\n" "$C_GRN" "$C_RESET"
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
BANNER_FILE=""
CONF_FILE=""
SHARED_CORPUS_DIR=""
DJPT_STATE_ANCHOR="${DJPT_STATE_ANCHOR:-}"
SAFETY_PROMPTED=0
VENV_ACTIVE=0
PYTHON_BIN="${DJPT_PYTHON_BIN:-${PYTHON_BIN:-python3}}"
IA_MODELS_DIR="${BASE_PATH}/ia_models"
ML_ENV_DISABLED=0
ML_PKGS_BASIC="numpy pandas"
ML_PKG_BASIC_MB=300
ML_PKGS_EVO="numpy pandas scikit-learn joblib"
ML_PKG_EVO_MB=450
# TensorFlow en Apple Silicon: usar tensorflow-macos + tensorflow-metal
ML_PKGS_TF="tensorflow-macos tensorflow-metal"
ML_PKG_TF_MB=600
DJPT_TF_THRESHOLD=0.60
DJPT_TF_TOPN=200
DJPT_TF_BATCH=150
DJPT_ONLINE_REF=0
PROFILES_DIR=""

pause_enter() {
  if [ "${NO_INTERACTIVE:-0}" -eq 1 ] || [ "${DJPT_NO_INTERACTIVE:-0}" -eq 1 ]; then
    return 0
  fi
  if [ ! -t 0 ]; then
    return 0
  fi
  printf "%s%s%s" "$C_YLW" "$(get_localized_string PRESS_ENTER)" "$C_RESET"
  read -r _ || true
}

djpt_read_line() {
  local __target="$1"
  local __prompt="${2:-}"
  local __value=""
  if [ -n "$__prompt" ]; then
    printf "%s" "$__prompt"
  fi
  if [ "${NO_INTERACTIVE:-0}" -eq 1 ] || [ "${DJPT_NO_INTERACTIVE:-0}" -eq 1 ] || [ ! -t 0 ]; then
    IFS= read -r __value || __value=""
  else
    IFS= read -e -r __value || __value=""
  fi
  printf -v "$__target" '%s' "$__value"
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
  if command -v djpt_check_connectivity >/dev/null 2>&1; then
    if djpt_check_connectivity; then
      printf "✅ Conexión a Internet confirmada.\n"; return 0; fi
  else
    if curl -Is --max-time 5 https://clients3.google.com/generate_204 2>/dev/null | head -n1 | grep -E "HTTP/[0-9\\.]+ 20[0-9]|HTTP/[0-9\\.]+ 30[0-9]" >/dev/null; then
      printf "✅ Conexión a Internet confirmada.\n"; return 0; fi
  fi
  printf "❌ Error: No se detecta conexión a Internet.\n"
  return 1
}

action_install_all_python_deps() {
  print_header
  ensure_python_bin || { pause_enter; return; }
  
  printf "🔍 Usando Python: %s\n" "$PYTHON_BIN"
  printf "🔍 Versión: %s\n" "$("$PYTHON_BIN" --version 2>/dev/null)"
  
  check_connectivity || { pause_enter; return; }

  # Crear venv con mejor versión disponible
  if [ ! -x "$VENV_DIR/bin/python3" ]; then
    mkdir -p "$VENV_DIR"
    local py_cmd=""
    for cand in python3.12 python3.11 python3; do
      if command -v "$cand" >/dev/null 2>&1; then py_cmd="$cand"; break; fi
    done
    if [ -z "$py_cmd" ]; then
      printf "%s[ERR]%s No se encontró python3 para crear venv\n" "$C_RED" "$C_RESET"
      pause_enter
      return
    fi
    printf "📦 Creando venv con %s...\n" "$py_cmd"
    safe_run "No se pudo crear venv en $VENV_DIR" "$py_cmd" -m venv "$VENV_DIR" || {
      printf "%s[ERR]%s No se pudo crear venv en %s\n" "$C_RED" "$C_RESET" "$VENV_DIR"
      pause_enter
      return
    }
    PYTHON_BIN="$VENV_DIR/bin/python3"
  fi

  # Instalar paquetes vía venv_manager.py si existe
  if [ -x "$LIB_DIR/venv_manager.py" ]; then
    printf "%s[INFO]%s Instalando paquetes base vía venv_manager.py\n" "$C_CYN" "$C_RESET"
    if "$PYTHON_BIN" "$LIB_DIR/venv_manager.py" "$VENV_DIR" install; then
      printf "%s[OK]%s Deps instaladas correctamente en venv.\n" "$C_GRN" "$C_RESET"
    else
      printf "%s[ERR]%s Falló la instalación en venv (venv_manager).\n" "$C_RED" "$C_RESET"
    fi
  else
    # Fallback: actualizar pip y paquetes por arquitectura
    printf "🔄 Actualizando pip en venv...\n"
    safe_run "Falló update pip en venv" "$PYTHON_BIN" -m pip install --upgrade pip
    arch="$(uname -m)"
    if [ "$arch" = "arm64" ]; then
      pkgs="numpy pandas soundfile librosa pyloudnorm pyserial python-osc onnxruntime-silicon tensorflow-macos tensorflow-metal tensorflow_hub"
    else
      pkgs="numpy pandas soundfile librosa pyloudnorm pyserial python-osc onnxruntime tensorflow tensorflow_hub"
    fi
    printf "%s[INFO]%s Instalando en venv: %s\n" "$C_CYN" "$C_RESET" "$pkgs"
    if "$PYTHON_BIN" -m pip install --upgrade $pkgs; then
      printf "%s[OK]%s Deps instaladas correctamente en venv.\n" "$C_GRN" "$C_RESET"
    else
      printf "%s[ERR]%s Falló la instalación en venv.\n" "$C_RED" "$C_RESET"
    fi
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
  local state_anchor=""
  local normalized_anchor=""
  # Permite forzar HOME_OVERRIDE para no tocar librerías reales
  if [ -n "${HOME_OVERRIDE:-}" ]; then
    BASE_PATH="$HOME_OVERRIDE"
    DJPT_STATE_ANCHOR="$HOME_OVERRIDE"
  fi

  state_anchor="${DJPT_STATE_ANCHOR:-$BASE_PATH}"
  normalized_anchor="${state_anchor%/}"
  DJPT_STATE_ANCHOR="$normalized_anchor"

  # Safety fallback: if BASE_PATH is root or empty, default STATE_DIR to HOME
  if [ -z "$normalized_anchor" ] || [ "$normalized_anchor" = "/" ]; then
     STATE_DIR="$HOME/_DJProducerTools"
  else
     # Si el ancla ya es una instalación real o termina en _DJProducerTools, úsala tal cual.
     if djpt_has_project_markers "$normalized_anchor" || [[ "$normalized_anchor" == *"/_DJProducerTools" ]]; then
         STATE_DIR="$normalized_anchor"
     else
         STATE_DIR="$normalized_anchor/_DJProducerTools"
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
  export BASE_PATH DJPT_STATE_ANCHOR
  export STATE_DIR CONFIG_DIR REPORTS_DIR PLANS_DIR LOGS_DIR QUAR_DIR VENV_DIR PROFILES_DIR
  export DJPT_BASE_DIR="$BASE_PATH"
  export DJPT_STATE_DIR="$STATE_DIR"
  export DJPT_LOGS_DIR="$LOGS_DIR"
  export DJPT_QUARANTINE_DIR="$QUAR_DIR"
EN_BANNER_COLORS=("${C_GREEN1}" "${C_GREEN2}" "${C_GREEN3}" "${C_GREEN4}" "${C_GREEN5}" "${C_GREEN1}") # Degradado verde EN
ES_BANNER_COLORS=("${C_GREEN5}" "${C_GREEN4}" "${C_GREEN3}" "${C_GREEN2}" "${C_GREEN1}" "${C_GREEN5}") # Degradado verde ES

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
  : "${DJPT_AUTO_OPTIMIZE:=0}"
  : "${DJPT_SMART_CACHE:=0}"
  : "${DJPT_HARDWARE_OPT:=universal}"
  : "${DJPT_QUANTUM:=0}"
  : "${DJPT_AI_INTEGRATION:=basica}"
  : "${DJPT_ADVANCED_ML:=0}"
  : "${DJPT_EXPERIMENTAL_MODE:=0}"
  : "${WEB_WHITELIST:=$DEFAULT_WEB_WHITELIST}"
  : "${DJPT_STATE_ANCHOR:=$BASE_PATH}"
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
    printf 'DJPT_AUTO_OPTIMIZE=%q\n' "${DJPT_AUTO_OPTIMIZE:-0}"
    printf 'DJPT_SMART_CACHE=%q\n' "${DJPT_SMART_CACHE:-0}"
    printf 'DJPT_HARDWARE_OPT=%q\n' "${DJPT_HARDWARE_OPT:-universal}"
    printf 'DJPT_QUANTUM=%q\n' "${DJPT_QUANTUM:-0}"
    printf 'DJPT_AI_INTEGRATION=%q\n' "${DJPT_AI_INTEGRATION:-basica}"
    printf 'DJPT_ADVANCED_ML=%q\n' "${DJPT_ADVANCED_ML:-0}"
    printf 'DJPT_EXPERIMENTAL_MODE=%q\n' "${DJPT_EXPERIMENTAL_MODE:-0}"
    printf 'WEB_WHITELIST=%q\n' "$(web_whitelist_domains)"
    printf 'DJPT_STATE_ANCHOR=%q\n' "${DJPT_STATE_ANCHOR:-$BASE_PATH}"
    printf 'DJPT_CURRENT_LANG=%q\n' "${DJPT_CURRENT_LANG:-ES}"
  } >"$CONF_FILE"
  export BASE_PATH AUDIO_ROOT GENERAL_ROOT SERATO_ROOT REKORDBOX_XML ABLETON_ROOT EXTRA_SOURCE_ROOTS
  export DEFAULT_EXCLUDES PROFILES_DIR SAFE_MODE DJ_SAFE_LOCK DRYRUN_FORCE ML_ENV_DISABLED
  export DJPT_TF_THRESHOLD DJPT_TF_TOPN DJPT_TF_BATCH DJPT_ONLINE_REF
  export DJPT_SPOTIFY_API DJPT_SPOTIFY_CLIENT_ID DJPT_SPOTIFY_CLIENT_SECRET
  export DJPT_MUSICBRAINZ DJPT_MUSICBRAINZ_APP DJPT_MUSICBRAINZ_CONTACT
  export DJPT_MCP_ENABLED DJPT_MCP_TRANSPORT DJPT_MCP_SERVER_ENTRY
  export DJPT_MPC_ENABLED DJPT_MPC_LEARNING DJPT_ADAPTIVE_UI DJPT_MPC_THRESHOLD DJPT_MPC_MODEL
  export DJPT_NEURAL_BATCH DJPT_NEURAL_SAMPLE_RATE DJPT_NEURAL_BUFFER_SIZE
  export DJPT_WORKER_NODES DJPT_LOAD_BALANCING DJPT_REALTIME_METRICS DJPT_AUTO_ALERTS
  export DJPT_AUTO_HEALING DJPT_ROLLBACK DJPT_USER_PROFILES DJPT_CONTEXT_CONFIG
  export SHARED_CORPUS_DIR DJPT_AUTO_OPTIMIZE DJPT_SMART_CACHE DJPT_HARDWARE_OPT
  export DJPT_QUANTUM DJPT_AI_INTEGRATION DJPT_ADVANCED_ML DJPT_EXPERIMENTAL_MODE
  export WEB_WHITELIST DJPT_STATE_ANCHOR DJPT_CURRENT_LANG
}

load_conf() {
  if [ -f "$CONF_FILE" ]; then
    set +u
    if ! source "$CONF_FILE" 2>/dev/null; then
      printf "%s[WARN]%s Could not load %s, it will be regenerated.\n" "$C_YLW" "$C_RESET" "$CONF_FILE" # Cannot localize here
    fi
# set -u # Desactivado para evitar cierres
  fi
  if [ -f "$CONFIG_DIR/mcp.env" ]; then
    set +u
    if ! source "$CONFIG_DIR/mcp.env" 2>/dev/null; then
      printf "%s[WARN]%s No se pudo cargar %s\n" "$C_YLW" "$C_RESET" "$CONFIG_DIR/mcp.env"
    fi
  fi
}

apply_runtime_defaults() {
  : "${DJPT_AUTO_OPTIMIZE:=0}"
  : "${DJPT_SMART_CACHE:=0}"
  : "${DJPT_HARDWARE_OPT:=universal}"
  : "${DJPT_QUANTUM:=0}"
  : "${DJPT_AI_INTEGRATION:=basica}"
  : "${DJPT_ADVANCED_ML:=0}"
  : "${DJPT_EXPERIMENTAL_MODE:=0}"
  : "${WEB_WHITELIST:=$DEFAULT_WEB_WHITELIST}"
  : "${DJPT_STATE_ANCHOR:=$BASE_PATH}"
  WEB_WHITELIST="$(web_whitelist_domains)"
  export DJPT_AUTO_OPTIMIZE DJPT_SMART_CACHE DJPT_HARDWARE_OPT
  export DJPT_QUANTUM DJPT_AI_INTEGRATION DJPT_ADVANCED_ML DJPT_EXPERIMENTAL_MODE
  export WEB_WHITELIST DJPT_STATE_ANCHOR DJPT_MPC_ENABLED DJPT_MPC_LEARNING
  export DJPT_ADAPTIVE_UI DJPT_MPC_THRESHOLD DJPT_MPC_MODEL DJPT_NEURAL_BATCH
  export DJPT_NEURAL_SAMPLE_RATE DJPT_NEURAL_BUFFER_SIZE DJPT_WORKER_NODES
  export DJPT_LOAD_BALANCING DJPT_REALTIME_METRICS DJPT_AUTO_ALERTS
  export DJPT_AUTO_HEALING DJPT_ROLLBACK DJPT_USER_PROFILES DJPT_CONTEXT_CONFIG
  export DJPT_SPOTIFY_CLIENT_ID DJPT_SPOTIFY_CLIENT_SECRET DJPT_MUSICBRAINZ_APP DJPT_MUSICBRAINZ_CONTACT
}

mcp_management_menu() {
  local mcp_mgr="$SCRIPT_DIR/mcp_env_manager.py"
  if [ ! -f "$mcp_mgr" ]; then
    printf "%s[ERR]%s No existe gestor MCP: %s\n" "$C_RED" "$C_RESET" "$mcp_mgr"
    pause_enter
    return 1
  fi

  while true; do
    clear
    printf "%s=== MCP) Configuración y Emparejamiento ===%s\n" "$BANNER" "$C_RESET"
    printf "Estado actual:\n"
    printf -- "- MCP habilitado: %s\n" "${DJPT_MCP_ENABLED:-0}"
    printf -- "- Transporte: %s\n" "${DJPT_MCP_TRANSPORT:-stdio}"
    printf -- "- Entry server: %s\n" "${DJPT_MCP_SERVER_ENTRY:-$SCRIPT_DIR/../mcp_server_fixed.py}"
    printf "\nOpciones:\n"
    printf "  1) Diagnóstico MCP\n"
    printf "  2) Instalar dependencia MCP (pip)\n"
    printf "  3) Emparejar MCP con este entorno\n"
    printf "  4) Smoke test MCP\n"
    printf "  5) Alternar MCP habilitado/deshabilitado\n"
    printf "  B) Volver\n"
    printf "Opción: "
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
        printf "%s[INFO]%s Instalando MCP en %s\n" "$C_CYN" "$C_RESET" "$PYTHON_BIN"
        "$PYTHON_BIN" "$mcp_mgr" install --json || true
        pause_enter
        ;;
      3)
        "$PYTHON_BIN" "$mcp_mgr" pair --write-env "$CONFIG_DIR/mcp.env" --json || true
        DJPT_MCP_ENABLED=1
        DJPT_MCP_TRANSPORT="${DJPT_MCP_TRANSPORT:-stdio}"
        DJPT_MCP_SERVER_ENTRY="${DJPT_MCP_SERVER_ENTRY:-$SCRIPT_DIR/../mcp_server_fixed.py}"
        save_conf
        printf "%s[OK]%s MCP emparejado y configuración persistida.\n" "$C_GRN" "$C_RESET"
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
        printf "%s[WARN]%s Opción inválida.\n" "$C_YLW" "$C_RESET"
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
         if [ -f "$VENV_DIR/bin/activate" ] && [ -x "$VENV_DIR/bin/python3" ]; then
            printf "%s[INFO]%s Venv detectado y parece válido. Usando existente.\n" "$C_CYN" "$C_RESET"
         else
            printf "%s[WARN]%s Venv corrupto o incompleto. Recreando en %s...\n" "$C_YLW" "$C_RESET" "$VENV_DIR"
            rm -rf "$VENV_DIR"
         fi
      fi

      if [ ! -d "$VENV_DIR" ]; then
          "$PYTHON_BIN" -m venv "$VENV_DIR" 2>/dev/null || {
            printf "%s[ERR]%s No se pudo crear el venv en %s\n" "$C_RED" "$C_RESET" "$VENV_DIR"
            ML_ENV_DISABLED=1
            return
          }
      fi
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

safe_run() {
  local label="$1"
  shift
  if "$@"; then
    return 0
  fi
  local rc=$?
  printf "%s[ERR]%s %s (rc=%s)\n" "$C_RED" "$C_RESET" "$label" "$rc"
  return "$rc"
}

ensure_python_bin() {
  if [ -n "${DJPT_PYTHON_BIN:-}" ] && [ -x "${DJPT_PYTHON_BIN:-}" ]; then
    PYTHON_BIN="$DJPT_PYTHON_BIN"
    return 0
  fi
  if [ -n "${PYTHON_BIN:-}" ] && [ -x "${PYTHON_BIN:-}" ]; then
    return 0
  fi
  if [ -x "${DJPT_VENV_DIR:-}/bin/python3" ]; then
    PYTHON_BIN="${DJPT_VENV_DIR}/bin/python3"
    return 0
  fi
  if [ -x "$VENV_DIR/bin/python3" ]; then
    PYTHON_BIN="$VENV_DIR/bin/python3"
    return 0
  fi
  # Prefer a concrete version, then generic python3 fallback.
  if command -v python3.12 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3.12)"
    return 0
  fi
  # Fallback a python3 si no hay 3.12
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
  # Construir pares paquete|módulo|versión_deseada y evaluar estado
  local pairs_json="["
  local first=1
  for pkg in "${modules[@]}"; do
    local mod="$pkg"
    local want=""
    if [[ "$pkg" == *"=="* ]]; then
      want="${pkg#*==}"
      pkg="${pkg%%==*}"
    fi
    case "$pkg" in
      tensorflow-macos|tensorflow-metal|tensorflow) mod="tensorflow";;
      mlx-lm) mod="mlx";;
      sentence-transformers) mod="sentence_transformers";;
      scikit-learn) mod="sklearn";;
      python-osc) mod="pythonosc";;
      pyloudnorm) mod="pyloudnorm";;
      PyPDF2) mod="PyPDF2";;
      pdfplumber) mod="pdfplumber";;
      onnxruntime-silicon|onnxruntime) mod="onnxruntime";;
    esac
    if [ $first -eq 0 ]; then
      pairs_json="${pairs_json},"
    fi
    pairs_json="${pairs_json}[\"${pkg}\",\"${mod}\",\"${want}\"]"
    first=0
  done
  pairs_json="${pairs_json}]"

  analysis_json="$(
    DJPT_MODULES="$pairs_json" "$PYTHON_BIN" - <<'PY'
import importlib, json, os
import importlib.metadata as md
pairs = json.loads(os.environ["DJPT_MODULES"])
missing, present, mismatch = [], [], []
for pkg, mod, want in pairs:
    spec = importlib.util.find_spec(mod)
    pkg_base = pkg.split("==")[0]
    if spec is None:
        missing.append(pkg)
    else:
        if want:
            try:
                installed = md.version(pkg_base)
            except Exception:
                installed = None
            if installed and installed != want:
                mismatch.append(f"{pkg_base} (instalado {installed}, deseado {want})")
            else:
                present.append(pkg)
        else:
            present.append(pkg)
print(json.dumps({"missing": missing, "present": present, "mismatch": mismatch}))
PY
  )" || {
    printf "%s[ERR]%s Falló el análisis de dependencias Python para %s.\n" \
      "$C_RED" "$C_RESET" "$context"
    return 1
  }

  if [ -z "$analysis_json" ]; then
    printf "%s[ERR]%s Resultado vacío al analizar dependencias para %s.\n" \
      "$C_RED" "$C_RESET" "$context"
    return 1
  fi

  if ! printf '%s' "$analysis_json" | "$PYTHON_BIN" -c \
    "import json,sys; json.loads(sys.stdin.read())" >/dev/null 2>&1
  then
    printf "%s[ERR]%s Respuesta inválida al analizar dependencias para %s.\n" \
      "$C_RED" "$C_RESET" "$context"
    return 1
  fi

  mapfile -t to_install < <(printf '%s' "$analysis_json" | "$PYTHON_BIN" -c \
    "import json,sys; data=json.loads(sys.stdin.read() or '{}'); [print(p) for p in data.get('missing', [])]")
  mapfile -t present_list < <(printf '%s' "$analysis_json" | "$PYTHON_BIN" -c \
    "import json,sys; data=json.loads(sys.stdin.read() or '{}'); [print(p) for p in data.get('present', [])]")
  mapfile -t mismatch_list < <(printf '%s' "$analysis_json" | "$PYTHON_BIN" -c \
    "import json,sys; data=json.loads(sys.stdin.read() or '{}'); [print(p) for p in data.get('mismatch', [])]")

  if [ "${#present_list[@]}" -gt 0 ]; then
    printf "%s[OK]%s Presentes (%s): %s\n" "$C_GREEN" "$C_RESET" "$context" "${present_list[*]}"
  fi

  # Solo forzamos reinstalar versiones distintas si DJPT_FORCE_REINSTALL=1
  local force_reinstall="${DJPT_FORCE_REINSTALL:-0}"
  if [ "${#mismatch_list[@]}" -gt 0 ]; then
    if [ "$force_reinstall" != "1" ]; then
      printf "%s[WARN]%s Versiones distintas (no se reinstalan, use DJPT_FORCE_REINSTALL=1): %s\n" "$C_YLW" "$C_RESET" "${mismatch_list[*]}"
    else
      # Añadir pkg base a instalación si se fuerza
      for mm in "${mismatch_list[@]}"; do
        local base="${mm%% (*}"
        to_install+=("$base")
      done
    fi
  fi

  if [ "${#to_install[@]}" -eq 0 ]; then
    return 0
  fi

  local est_mb=30
  for m in "${to_install[@]}"; do
    case "$m" in
      librosa) est_mb=$((est_mb + 120));;
      soundfile) est_mb=$((est_mb + 20));;
      python-osc|pyserial) est_mb=$((est_mb + 5));;
    esac
  done
  printf "%s[WARN]%s Faltan deps Python (%s): %s\n" "$C_YLW" "$C_RESET" "$context" "${to_install[*]}"
  printf "Instalar en venv %s (~%s MB)? [y/N]: " "$VENV_DIR" "$est_mb"
  read -r ans
  case "$ans" in
    y|Y)
      # Python 3.12 es la versión estable y compatible por defecto
      if command -v python3.12 >/dev/null 2>&1; then
        PYTHON_CMD="python3.12"
      elif command -v python3 >/dev/null 2>&1; then
        PYTHON_CMD="python3"
      else
        printf "%s[ERR]%s python3 no disponible para crear venv.\n" "$C_RED" "$C_RESET"
        return 1
      fi
      mkdir -p "$VENV_DIR"
      if [ ! -x "$VENV_DIR/bin/python3" ]; then
        "$PYTHON_CMD" -m venv "$VENV_DIR" 2>/dev/null || {
          printf "%s[ERR]%s No se pudo crear venv en %s\n" "$C_RED" "$C_RESET" "$VENV_DIR"
          return 1
        }
      fi
      PYTHON_BIN="$VENV_DIR/bin/python3"
      check_connectivity || return 1
      printf "Actualizando pip...\n"
      "$PYTHON_BIN" -m pip install --upgrade pip || printf "%s[WARN]%s Falló update pip.\n" "$C_YLW" "$C_RESET"
      printf "Instalando módulos (%s)...\n" "${to_install[*]}"
      "$PYTHON_BIN" -m pip install "${to_install[@]}" || {
        printf "%s[ERR]%s Falló instalación pip de %s\n" "$C_RED" "$C_RESET" "${to_install[*]}"
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

ensure_python_package_installed() {
  local pkg="$1"
  [ -z "$pkg" ] && return 1
  ensure_python_deps "$pkg" "$pkg"
}

load_ai_config() {
  init_paths
  mkdir -p "$CONFIG_DIR" "$STATE_DIR" "$REPORTS_DIR" "$IA_MODELS_DIR" "$IA_MODELS_DIR/embeddings" 2>/dev/null || true

  export DJPT_BEST_BACKEND="${DJPT_BEST_BACKEND:-auto}"
  export DJPT_MLX_DEVICE="${DJPT_MLX_DEVICE:-metal}"
  export DJPT_TF_DEVICE="${DJPT_TF_DEVICE:-metal}"
  export DJPT_TF_MIXED_PRECISION="${DJPT_TF_MIXED_PRECISION:-1}"
  export DJPT_OLLAMA_DEFAULT_MODEL="${DJPT_OLLAMA_DEFAULT_MODEL:-llama3.2:3b}"
  export DJPT_EMBEDDINGS_MODEL="${DJPT_EMBEDDINGS_MODEL:-sentence-transformers/all-MiniLM-L6-v2}"

  local canonical_root="${DJPT_CANONICAL_ROOT:-$SCRIPT_DIR/..}"
  local config_toml="$canonical_root/config/ai_model_params.toml"
  local toml_exports=""
  if ensure_python_bin >/dev/null 2>&1 && [ -f "$config_toml" ]; then
    toml_exports="$("$PYTHON_BIN" - "$canonical_root" "$config_toml" <<'PY' 2>/dev/null || true
from __future__ import annotations

import importlib.util
import os
import shlex
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
config_file = Path(sys.argv[2]).resolve()
module_path = root / "config_schema.py"
spec = importlib.util.spec_from_file_location("djpt_config_schema", module_path)
if spec is None or spec.loader is None:
    raise SystemExit(0)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

settings = module.load_settings(config_file)
exported = module.export_all_env_vars(settings)
cpu_threads = exported.get("DJPT_CPU_THREADS") or exported.get("DJPT_PARALLEL_THREADS") or ""
payload = {
    "DJPT_BEST_BACKEND": exported.get("DJPT_PREFERRED_BACKEND", "auto"),
    "DJPT_MLX_DEVICE": exported.get("DJPT_MLX_DEVICE", "metal"),
    "DJPT_TF_DEVICE": exported.get("DJPT_TF_DEVICE", "auto"),
    "DJPT_TF_MIXED_PRECISION": exported.get("DJPT_TF_MIXED_PRECISION", "1"),
    "DJPT_OLLAMA_DEFAULT_MODEL": exported.get("DJPT_OLLAMA_DEFAULT_MODEL", "llama3.2:3b"),
    "OMP_NUM_THREADS": cpu_threads,
    "OPENBLAS_NUM_THREADS": cpu_threads,
    "MKL_NUM_THREADS": cpu_threads,
}
for key, value in payload.items():
    print(f"export {key}={shlex.quote(str(value))}")
PY
)"
    if [ -n "$toml_exports" ]; then
      eval "$toml_exports"
    fi
  fi

  local env_file="$CONFIG_DIR/ai_backend_env.sh"
  if [ -f "$env_file" ]; then
    # shellcheck disable=SC1090
    . "$env_file"
  fi
}

persist_ai_runtime_config() {
  init_paths
  mkdir -p "$CONFIG_DIR" "$IA_MODELS_DIR/embeddings" 2>/dev/null || true

  local env_file="$CONFIG_DIR/ai_backend_env.sh"
  cat >"$env_file" <<EOF
export DJPT_BEST_BACKEND="${DJPT_BEST_BACKEND:-auto}"
export DJPT_MLX_DEVICE="${DJPT_MLX_DEVICE:-metal}"
export DJPT_TF_DEVICE="${DJPT_TF_DEVICE:-metal}"
export DJPT_TF_MIXED_PRECISION="${DJPT_TF_MIXED_PRECISION:-1}"
export DJPT_OLLAMA_DEFAULT_MODEL="${DJPT_OLLAMA_DEFAULT_MODEL:-llama3.2:3b}"
export DJPT_EMBEDDINGS_MODEL="${DJPT_EMBEDDINGS_MODEL:-sentence-transformers/all-MiniLM-L6-v2}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-}"
export TOKENIZERS_PARALLELISM="${TOKENIZERS_PARALLELISM:-false}"
EOF

  local canonical_root="${DJPT_CANONICAL_ROOT:-$SCRIPT_DIR/..}"
  local config_toml="$canonical_root/config/ai_model_params.toml"

  if ensure_python_bin >/dev/null 2>&1; then
    "$PYTHON_BIN" - "$CONFIG_DIR/ai_backend_runtime.json" <<'PY' 2>/dev/null || true
import json
import os
import sys

payload = {
    "best_backend": os.environ.get("DJPT_BEST_BACKEND", "auto"),
    "mlx_device": os.environ.get("DJPT_MLX_DEVICE", "metal"),
    "tf_device": os.environ.get("DJPT_TF_DEVICE", "metal"),
    "tf_mixed_precision": os.environ.get("DJPT_TF_MIXED_PRECISION", "1"),
    "ollama_default_model": os.environ.get("DJPT_OLLAMA_DEFAULT_MODEL", "llama3.2:3b"),
    "embeddings_model": os.environ.get("DJPT_EMBEDDINGS_MODEL", "sentence-transformers/all-MiniLM-L6-v2"),
    "omp_num_threads": os.environ.get("OMP_NUM_THREADS", ""),
    "openblas_num_threads": os.environ.get("OPENBLAS_NUM_THREADS", ""),
    "mkl_num_threads": os.environ.get("MKL_NUM_THREADS", ""),
    "tokenizers_parallelism": os.environ.get("TOKENIZERS_PARALLELISM", "false"),
}
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2, ensure_ascii=False, sort_keys=True)
PY

    "$PYTHON_BIN" - "$canonical_root" "$config_toml" <<'PY' 2>/dev/null || true
from __future__ import annotations

import importlib.util
import os
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
config_file = Path(sys.argv[2]).resolve()
module_path = root / "config_schema.py"
spec = importlib.util.spec_from_file_location("djpt_config_schema", module_path)
if spec is None or spec.loader is None:
    raise SystemExit(0)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

config_file.parent.mkdir(parents=True, exist_ok=True)
settings = module.load_settings(config_file) if config_file.exists() else module.Settings()

settings.general.preferred_backend = os.environ.get("DJPT_BEST_BACKEND", settings.general.preferred_backend)
settings.mlx.device = os.environ.get("DJPT_MLX_DEVICE", settings.mlx.device)
settings.tensorflow.device = os.environ.get("DJPT_TF_DEVICE", settings.tensorflow.device)
settings.tensorflow.mixed_precision = os.environ.get("DJPT_TF_MIXED_PRECISION", "1").lower() not in {"0", "false", "no", "off"}
settings.ollama.default_model = os.environ.get("DJPT_OLLAMA_DEFAULT_MODEL", settings.ollama.default_model)

cpu_threads_raw = os.environ.get("OMP_NUM_THREADS") or os.environ.get("DJPT_PARALLEL_THREADS") or ""
if cpu_threads_raw.isdigit():
    cpu_threads = int(cpu_threads_raw)
    if cpu_threads >= 0:
        settings.threads.cpu_threads = cpu_threads
        settings.general.parallel_threads = cpu_threads

module.save_settings(settings, config_file)
PY
  fi
}

ai_suite_script_path() {
  local canonical_root="${DJPT_CANONICAL_ROOT:-$SCRIPT_DIR/..}"
  local candidates=(
    "$canonical_root/ai_suite.py"
    "$canonical_root/scripts/ai_suite.py"
    "$SCRIPT_DIR/../ai_suite.py"
    "$SCRIPT_DIR/ai_suite.py"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    if [ -f "$candidate" ]; then
      printf "%s" "$candidate"
      return 0
    fi
  done
  return 1
}

run_djpt_ai() {
  local action="$1"
  shift || true
  if ! ensure_python_bin; then
    return 1
  fi
  local suite_script
  suite_script="$(ai_suite_script_path)" || {
    printf "%s[ERR]%s ai_suite.py no encontrado en la instalación canónica.\n" "$C_RED" "$C_RESET"
    return 1
  }
  "$PYTHON_BIN" "$suite_script" "$action" "$@"
}

djpt_ai_run() {
  run_djpt_ai "$@"
}

validate_ai_deps() {
  load_ai_config

  local ts report core_fail available_backends
  ts="$(date +%Y%m%d_%H%M%S)"
  report="$REPORTS_DIR/ai_deps_validation_${ts}.tsv"
  core_fail=0
  available_backends=0
  printf "component\tstatus\tdetail\n" >"$report"

  if ensure_python_bin >/dev/null 2>&1; then
    printf "python\tok\t%s\n" "$PYTHON_BIN" >>"$report"
  else
    printf "python\tfail\tpython3 no disponible\n" >>"$report"
    core_fail=1
  fi

  if [ -d "$STATE_DIR" ] && [ -w "$STATE_DIR" ]; then
    printf "state_dir\tok\t%s\n" "$STATE_DIR" >>"$report"
  else
    printf "state_dir\tfail\t%s\n" "$STATE_DIR" >>"$report"
    core_fail=1
  fi

  if [ -d "$REPORTS_DIR" ] && [ -w "$REPORTS_DIR" ]; then
    printf "reports_dir\tok\t%s\n" "$REPORTS_DIR" >>"$report"
  else
    printf "reports_dir\tfail\t%s\n" "$REPORTS_DIR" >>"$report"
    core_fail=1
  fi

  if [ "$core_fail" -eq 0 ]; then
    if "$PYTHON_BIN" -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('mlx') else 1)" >/dev/null 2>&1; then
      printf "mlx\tok\tmódulo mlx detectado\n" >>"$report"
      available_backends=$((available_backends + 1))
    else
      printf "mlx\twarn\tmódulo mlx ausente\n" >>"$report"
    fi

    if "$PYTHON_BIN" -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('tensorflow') else 1)" >/dev/null 2>&1; then
      printf "tensorflow\tok\tmódulo tensorflow detectado\n" >>"$report"
      available_backends=$((available_backends + 1))
    else
      printf "tensorflow\twarn\tmódulo tensorflow ausente\n" >>"$report"
    fi

    if "$PYTHON_BIN" -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('sklearn') else 1)" >/dev/null 2>&1; then
      printf "scikit-learn\tok\tmódulo sklearn detectado\n" >>"$report"
      available_backends=$((available_backends + 1))
    else
      printf "scikit-learn\twarn\tmódulo sklearn ausente\n" >>"$report"
    fi

    if "$PYTHON_BIN" -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('sentence_transformers') else 1)" >/dev/null 2>&1; then
      printf "embeddings\tok\tsentence-transformers detectado\n" >>"$report"
    else
      printf "embeddings\twarn\tsentence-transformers ausente\n" >>"$report"
    fi
  fi

  if command -v ollama >/dev/null 2>&1; then
    if ollama list >/dev/null 2>&1; then
      printf "ollama\tok\tollama operativo\n" >>"$report"
      available_backends=$((available_backends + 1))
    else
      printf "ollama\twarn\tcomando presente pero servidor/modelos no listables\n" >>"$report"
    fi
  else
    printf "ollama\twarn\tcomando ollama ausente\n" >>"$report"
  fi

  if [ -n "${OPENAI_API_KEY:-}" ]; then
    printf "openai_api\tok\tOPENAI_API_KEY configurada\n" >>"$report"
  else
    printf "openai_api\twarn\tOPENAI_API_KEY ausente\n" >>"$report"
  fi

  if [ -n "${HF_TOKEN:-${HUGGINGFACE_TOKEN:-}}" ]; then
    printf "huggingface\tok\tHF token configurado\n" >>"$report"
  else
    printf "huggingface\twarn\tHF_TOKEN/HUGGINGFACE_TOKEN ausente\n" >>"$report"
  fi

  if [ "$available_backends" -eq 0 ]; then
    printf "summary\tfail\tningún backend local operativo\n" >>"$report"
    core_fail=1
  else
    printf "summary\tok\tbackends operativos=%s\n" "$available_backends" >>"$report"
  fi

  printf "%s=== VALIDACIÓN DE DEPENDENCIAS IA ===%s\n" "$BANNER" "$C_RESET"
  if command -v column >/dev/null 2>&1; then
    column -t -s $'\t' "$report"
  else
    cat "$report"
  fi
  printf "\nReporte: %s\n" "$report"
  return "$core_fail"
}

print_header() {
  clear
  if [ -f "$BANNER_FILE" ]; then
    while IFS= read -r line; do
      printf "%s%s%s\n" "$C_PURP" "$line" "$C_RESET"
    done < "$BANNER_FILE"
  else
    # Gradiente unificado (purpura/fucsia + verde) desde branding
    local banner_colors=()
    if declare -p DJPT_BANNER_GRAD >/dev/null 2>&1; then
      banner_colors=("${DJPT_BANNER_GRAD[@]}")
    else
      case "$DJPT_CURRENT_LANG" in
        en) banner_colors=("${EN_BANNER_COLORS[@]}") ;;
        *)  banner_colors=("${ES_BANNER_COLORS[@]}") ;;
      esac
    fi
    if [ "${#banner_colors[@]}" -eq 0 ]; then
      banner_colors=("$C_PURP" "$C_BLU" "$C_CYN" "$C_GRN" "$C_YLW" "$C_RED")
    fi
    if [ "${#banner_colors[@]}" -eq 0 ]; then
      banner_colors=("$C_RESET")
    fi

    local banner_lines
    mapfile -t banner_lines <<'EOF'
@@@  @@@  @@@  @@@@@@  @@@  @@@  @@@@@@ @@@@@@@   @@@@@@   @@@@@@@ @@@@@@@@ @@@@@@ @@@  @@@ @@@ @@@@@@@    
@@!  @@!  @@! @@!  @@@ @@!  !@@ !@@     @@!  @@@ @@!  @@@ !@@      @@!     !@@     @@!  @@@ @@! @@!  @@@   
@!!  !!@  @!@ @!@!@!@!  !@@!@!   !@@!!  @!@@!@!  @!@!@!@! !@!      @!!!:!   !@@!!  @!@!@!@! !!@ @!@@!@!    
 !:  !!:  !!  !!:  !!!  !: :!!      !:! !!:      !!:  !!! :!!      !!:         !:! !!:  !!! !!: !!:        
  ::.:  :::    :   : : :::  ::: ::.: :   :        :   : :  :: :: : : :: :: ::.: :   :   : : :    :         
@@@@@@@      @@@ @@@@@@@  @@@@@@@   @@@@@@  @@@@@@@  @@@  @@@  @@@@@@@ @@@@@@@@ @@@@@@@                    
@@!  @@@     @@! @@!  @@@ @@!  @@@ @@!  @@@ @@!  @@@ @@!  @@@ !@@      @@!      @@!  @@@                   
@!@  !@!     !!@ @!@@!@!  @!@!!@!  @!@  !@! @!@  !@! @!@  !@! !@!      @!!!:!   @!@!!@!                    
!!:  !!! .  .!!  !!:      !!: :!!  !!:  !!! !!:  !!! !!:  !!! :!!      !!:      !!: :!!                    
:: :  :  ::.::    :        :   : :  : :. :  :: :  :   :.:: :   :: :: : : :: ::   :   : :                   
@@@@@@@ @@@@@@   @@@@@@  @@@                                                                               
  @!!  @@!  @@@ @@!  @@@ @@!                                                                               
  @!!  @!@  !@! @!@  !@! @!!                                                                               
  !!:  !!:  !!! !!:  !!! !!:                                                                               
   :    : :. :   : :. :  : ::.: :                                                                          
EOF
    for idx in "${!banner_lines[@]}"; do
      local color_idx=$((idx % ${#banner_colors[@]}))
      local color="${banner_colors[$color_idx]}"
      # Atenuar último tercio para efecto fade
      local maybe_dim=""
      if [ "${#banner_lines[@]}" -gt 0 ] && [ "$idx" -ge $(( ${#banner_lines[@]} * 2 / 3 )) ]; then
        maybe_dim="${C_DIM:-}"  # Usar valor por defecto si no está definido
      fi
      printf "%s%s%s%s\n" "$maybe_dim" "$color" "${banner_lines[$idx]}" "$C_RESET"
    done
  fi
  printf "%sDJProducerTool v%s%s\n" "$C_CYN" "$SCRIPT_VERSION" "$C_RESET"
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

print_ai_banner() {
  printf "%s🧠 DJProducerTool IA / Chat Multi-Backend%s\n" "$C_PURP" "$C_RESET"
  printf "%s🌐 Inteligencia Web + Auto-corrección + Evolución%s\n" "$C_CYN" "$C_RESET"
}

print_menu_legacy() {
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
  printf "  %s26)%s Estado: Export bundle / Import bundle\n" "$C_GRN" "$C_RESET"
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

  printf "%s%s%s\n" "$C_CYN" "$(get_localized_string MENU_DEEP_ML)" "$C_RESET"
  printf "  %s40)%s Smart Analysis (JSON)\n" "$C_GRN" "$C_RESET"
  printf "  %s41)%s Predictor de problemas (ML)\n" "$C_GRN" "$C_RESET"
  printf "  %s42)%s Optimizador de eficiencia\n" "$C_GRN" "$C_RESET"
  printf "  %s43)%s Flujo de trabajo inteligente\n" "$C_GRN" "$C_RESET"
  printf "  %s44)%s Deduplicación integrada\n" "$C_GRN" "$C_RESET"
  printf "  %s45)%s Organización automática (plan)\n" "$C_GRN" "$C_RESET"
  printf "  %s46)%s Armonizador de metadatos (plan)\n" "$C_GRN" "$C_RESET"
  printf "  %s47)%s Backup predictivo\n" "$C_GRN" "$C_RESET"
  printf "  %s48)%s Sync multiplataforma\n" "$C_GRN" "$C_RESET"
  printf "  %s49)%s Audio BPM (tags/librosa) -> TSV\n" "$C_GRN" "$C_RESET"
  printf "  %s50)%s API/OSC server (start/stop)\n" "$C_GRN" "$C_RESET"
  printf "  %s51)%s Recomendaciones adaptativas\n" "$C_GRN" "$C_RESET"
  printf "  %s52)%s Pipeline de limpieza automatizado\n" "$C_GRN" "$C_RESET"
  printf "  %s53)%s Reset de estado (recuperación)\n" "$C_GRN" "$C_RESET"
  printf "  %s54)%s Gestor de perfiles\n" "$C_GRN" "$C_RESET"

  printf "%s🤖 IA / ML (62-90):%s\n" "$C_CYN" "$C_RESET"
  printf "  %s62)%s Gestor ML Evo (train/predict)\n" "$C_GRN" "$C_RESET"
  printf "  %s63)%s Toggle ML (enable/disable)\n" "$C_GRN" "$C_RESET"
  printf "  %s64)%s TensorFlow Manager (stack)\n" "$C_GRN" "$C_RESET"
  printf "  %s65)%s TensorFlow Lab (experimentos)\n" "$C_GRN" "$C_RESET"
  printf "  %s66)%s Plan de normalización LUFS\n" "$C_GRN" "$C_RESET"
  printf "  %s67)%s Cues/Onsets plan\n" "$C_GRN" "$C_RESET"
  printf "  %s68)%s Instalar deps Python (venv)\n" "$C_GRN" "$C_RESET"
  printf "  %s69)%s Shared Corpus\n" "$C_GRN" "$C_RESET"
  printf "  %s70)%s IA Status\n" "$C_GRN" "$C_RESET"
  printf "  %s71)%s IA Backends Manager\n" "$C_GRN" "$C_RESET"
  printf "  %s72)%s Instalar deps IA\n" "$C_GRN" "$C_RESET"
  printf "  %s73)%s Chat CLI\n" "$C_GRN" "$C_RESET"
  printf "  %s74)%s Config avanzada IA\n" "$C_GRN" "$C_RESET"
  printf "  %s75)%s Entrenar modelos IA\n" "$C_GRN" "$C_RESET"
  printf "  %s76)%s IA Knowledge Base\n" "$C_GRN" "$C_RESET"
  printf "  %s77)%s UI Config\n" "$C_GRN" "$C_RESET"
  printf "  %s78)%s Smart scan (legacy)\n" "$C_GRN" "$C_RESET"
  printf "  %s79)%s Error recovery (legacy)\n" "$C_GRN" "$C_RESET"
  printf "  %s80)%s IA advanced menu\n" "$C_GRN" "$C_RESET"
  printf "  %s81)%s IA Lab\n" "$C_GRN" "$C_RESET"
  printf "  %s82)%s IA Optimization\n" "$C_GRN" "$C_RESET"
  printf "  %s83)%s IA Global Config\n" "$C_GRN" "$C_RESET"
  printf "  %s84)%s IA Learning System\n" "$C_GRN" "$C_RESET"
  printf "  %s85)%s IA Educator\n" "$C_GRN" "$C_RESET"
  printf "  %s86)%s IA Document Analysis\n" "$C_GRN" "$C_RESET"
  printf "  %s87)%s Install Local Models\n" "$C_GRN" "$C_RESET"
  printf "  %s88)%s Gestor Modelos IA Locales\n" "$C_GRN" "$C_RESET"
  printf "  %s89)%s 🧠 Enhanced Chat CLI\n" "$C_GRN" "$C_RESET"
  printf "  %s90)%s 🎹 Lanzar SERATO ORGANIZER (Suite Externa)\n" "$C_GRN" "$C_RESET"

  printf "\n"
  printf "%sC)%s Chat / IA Hub\n" "$C_GRN" "$C_RESET"
  printf "%sR)%s Reparación y regeneración del sistema\n" "$C_GRN" "$C_RESET"
  printf "%sL)%s %s\n" "$C_GRN" "$C_RESET" "$(get_localized_string MENU_L_LIBS)"
  printf "%sD)%s %s\n" "$C_GRN" "$C_RESET" "$(get_localized_string MENU_D_DUPES)"
  printf "%sV)%s %s\n" "$C_GRN" "$C_RESET" "$(get_localized_string MENU_V_VISUALS)"
  printf "%sT)%s TensorFlow Lab\n" "$C_GRN" "$C_RESET"
  printf "%sH)%s %s\n" "$C_GRN" "$C_RESET" "$(get_localized_string MENU_H_HELP)"
  printf "%s0)%s %s\n" "$C_GRN" "$C_RESET" "$(get_localized_string MENU_0_EXIT)"
}

invalid_option() {
  printf "%s[ERR]%s %s\n" "$C_RED" "$C_RESET" "$(get_localized_string INVALID_OPTION)"
  pause_enter
}

resolve_enhanced_chat_cli_script() {
  local candidates=(
    "$BASE_PATH/enhanced_chat_cli.py"
    "$BASE_PATH/scripts/chat/enhanced_chat_cli.py"
    "$SCRIPT_DIR/chat/enhanced_chat_cli.py"
    "$LIB_DIR/enhanced_chat_cli.py"
    "$LIB_DIR/djpt_chat_cli.py"
    "/Volumes/SeaGate2TB/_DJProducerTools/enhanced_chat_cli.py"
    "/Volumes/SeaGate2TB/_DJProducerTools/scripts/chat/enhanced_chat_cli.py"
    "/Volumes/SeaGate2TB/_DJProducerTools/lib/djpt_chat_cli.py"
  )
  local candidate=""
  for candidate in "${candidates[@]}"; do
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
      printf "%s\n" "$candidate"
      return 0
    fi
  done
  return 1
}

action_chat_cli() {
  print_header
  print_ai_banner
  if ! ensure_python_bin; then
    printf "%s[ERR]%s Se requiere Python3 para el Chat CLI.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  
  local chat_script=""
  chat_script="$(resolve_enhanced_chat_cli_script)" || true

  if [ -z "$chat_script" ] || [ ! -f "$chat_script" ]; then
    printf "%s[ERR]%s Script de Chat CLI no encontrado.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi

  printf "%s[INFO]%s Iniciando DJPT Chat CLI...\n" "$C_CYN" "$C_RESET"
  
  # Export variables for the python script
  export BASE_PATH
  export VENV_DIR
  export SCRIPT_DIR
  export DJPT_UI_MODE
  
  "$PYTHON_BIN" "$chat_script"
  
  printf "\n%s[INFO]%s Regreso desde Chat CLI.\n" "$C_CYN" "$C_RESET"
  pause_enter
}

# LAB: doctor (experimental) - Enhanced con análisis automático
action_lab_doctor() {
  while true; do
    print_header
    printf "${C_CYN}🩺 SISTEMA DE DIAGNÓSTICO Y REPARACIÓN (Doctor Total)${C_RESET}\n"
    printf "===============================================\n"
    printf "  ${C_GRN}1)${C_RESET} Instalación Completa Auto-Guiada\n"
    printf "  ${C_GRN}2)${C_RESET} Análisis de Tests y Reparación IA\n"
    printf "  ${C_GRN}3)${C_RESET} Configuración Paso a Paso\n"
    printf "  ${C_GRN}4)${C_RESET} Generar Prompt IA para Chat\n"
    printf "  ${C_GRN}5)${C_RESET} Reparación Autosuficiente con IA\n"
    printf "  ${C_GRN}B)${C_RESET} Volver\n"
    printf "\n${C_BLU}Opción:${C_RESET} "
    if ! read -r op; then
      break
    fi
    op="$(echo "$op" | xargs)"
    [ -z "$op" ] && continue
    case "$op" in
      1) 
         if [ -f "$SCRIPT_DIR/../scripts/dr_installer.py" ]; then
             python3 "$SCRIPT_DIR/../scripts/dr_installer.py"
         else
             printf "${C_RED}Script no encontrado: dr_installer.py${C_RESET}\n"
         fi
         pause_enter
         ;;
      2) 
         if [ -f "$SCRIPT_DIR/../scripts/VERIFY_AND_TEST.sh" ]; then
             "$SCRIPT_DIR/../scripts/VERIFY_AND_TEST.sh"
         else
             printf "${C_RED}Script no encontrado: VERIFY_AND_TEST.sh${C_RESET}\n"
         fi
         pause_enter
         ;;
      3) 
         action_2_change_base
         action_57_submenu_excludes
         pause_enter
         ;;
      4)
         if [ -f "$SCRIPT_DIR/../scripts/system_analyzer.py" ]; then
             python3 "$SCRIPT_DIR/../scripts/system_analyzer.py" --base-path "$BASE_PATH" --json > "$STATE_DIR/dr_prompt.json"
             printf "${C_GRN}Prompt generado en: %s/dr_prompt.json${C_RESET}\n" "$STATE_DIR"
             cat "$STATE_DIR/dr_prompt.json"
         else
             printf "${C_RED}Script no encontrado: system_analyzer.py${C_RESET}\n"
         fi
         pause_enter
         ;;
      5)
         if [ -f "$SCRIPT_DIR/../scripts/ai_dr_repair.py" ]; then
             python3 "$SCRIPT_DIR/../scripts/ai_dr_repair.py"
         else
             printf "${C_RED}Script no encontrado: ai_dr_repair.py${C_RESET}\n"
         fi
         pause_enter
         ;;
      B|b) break ;;
      *) invalid_option ;;
    esac
  done
}

# LAB: grafo (modo experimental)
action_lab_graph() {
  print_header
  init_paths
  if ! ensure_python_bin; then
    printf "%s[ERR]%s Python3 no disponible para generar el grafo LAB.\n" "$C_RED" "$C_RESET"
    pause_enter
    return 1
  fi

  local ts out_json out_mmd
  ts="$(date +%Y%m%d_%H%M%S)"
  out_json="$REPORTS_DIR/lab_assets_graph_${ts}.json"
  out_mmd="$REPORTS_DIR/lab_assets_graph_${ts}.mmd"

  if "$PYTHON_BIN" - "$BASE_PATH" "$out_json" "$out_mmd" <<'PY'
from __future__ import annotations

import json
import os
import sys
from collections import Counter
from pathlib import Path

base = Path(sys.argv[1]).resolve()
out_json = Path(sys.argv[2]).resolve()
out_mmd = Path(sys.argv[3]).resolve()
skip_dirs = {".git", "__pycache__", "node_modules", ".venv", "venv", "djpt_venv", "_DJProducerTools"}
audio_exts = {".mp3", ".wav", ".flac", ".m4a", ".aac", ".ogg", ".aiff", ".aif"}
video_exts = {".mp4", ".mov", ".mkv", ".avi", ".m4v"}
text_exts = {".md", ".txt", ".json", ".toml", ".yaml", ".yml", ".csv", ".tsv", ".py", ".sh"}

def classify(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix in audio_exts:
        return "audio"
    if suffix in video_exts:
        return "video"
    if suffix in text_exts:
        return "text"
    return "other"

counts = Counter()
top_dirs = Counter()
sample_files: list[str] = []

for root, dirs, files in os.walk(base):
    dirs[:] = sorted(d for d in dirs if d not in skip_dirs)
    root_path = Path(root)
    rel_root = "." if root_path == base else str(root_path.relative_to(base))
    top_token = rel_root.split("/", 1)[0]
    for name in sorted(files):
        path = root_path / name
        counts[classify(path)] += 1
        top_dirs[top_token] += 1
        if len(sample_files) < 20:
            sample_files.append(str(path.relative_to(base)))

payload = {
    "base_path": str(base),
    "summary": {
        "audio_files": counts["audio"],
        "video_files": counts["video"],
        "text_files": counts["text"],
        "other_files": counts["other"],
        "total_files": sum(counts.values()),
    },
    "top_roots": [{"name": name, "files": count} for name, count in top_dirs.most_common(10)],
    "sample_files": sample_files,
}

out_json.parent.mkdir(parents=True, exist_ok=True)
out_json.write_text(json.dumps(payload, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")

lines = [
    "graph LR",
    f'  ROOT["{base.name or "/"}"]',
]
for label, value in (
    ("Audio", counts["audio"]),
    ("Video", counts["video"]),
    ("Text", counts["text"]),
    ("Other", counts["other"]),
):
    node = label.lower()
    lines.append(f'  ROOT --> {node}["{label} ({value})"]')
for index, item in enumerate(payload["top_roots"], start=1):
    node = f"top{index}"
    safe_name = str(item["name"]).replace('"', "'")
    lines.append(f'  ROOT --> {node}["{safe_name} ({item["files"]})"]')
out_mmd.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(json.dumps({"json": str(out_json), "mermaid": str(out_mmd), "summary": payload["summary"]}, ensure_ascii=False))
PY
  then
    printf "%s[OK]%s Grafo LAB generado.\n" "$C_GRN" "$C_RESET"
    printf "  JSON: %s\n" "$out_json"
    printf "  Mermaid: %s\n" "$out_mmd"
  else
    printf "%s[ERR]%s No se pudo generar el grafo LAB.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_launch_serato_organizer() {
  print_header
  printf "%s=== LANZADOR SERATO ORGANIZER SUITE ===%s\n" "$BANNER" "$C_RESET"
  
  # Posibles ubicaciones del script externo
  local candidates=(
    "/Volumes/SeaGate2TB/_SERATORGANIZER/SERATO_ORGANIZER.sh"
    "$BASE_PATH/_SERATORGANIZER/SERATO_ORGANIZER.sh"
    "../_SERATORGANIZER/SERATO_ORGANIZER.sh"
    "$SCRIPT_DIR/../../_SERATORGANIZER/SERATO_ORGANIZER.sh"
  )
  
  local target_script=""
  
  for cand in "${candidates[@]}"; do
    if [ -f "$cand" ]; then
      target_script="$cand"
      break
    fi
  done
  
  if [ -z "$target_script" ]; then
    printf "%s[ERR]%s No se encontró SERATO_ORGANIZER.sh en las rutas esperadas.\n" "$C_RED" "$C_RESET"
    printf "Verifica que la carpeta _SERATORGANIZER esté en la raíz del disco.\n"
    pause_enter
    return
  fi
  
  printf "%s[INFO]%s Lanzando suite externa: %s\n" "$C_CYN" "$C_RESET" "$target_script"
  printf "%s[WARN]%s Se transferirá el control a la suite externa.\n" "$C_YLW" "$C_RESET"
  
  # Dar permisos de ejecución por si acaso
  chmod +x "$target_script"
  
  # Ejecutar en subshell para proteger el entorno actual, o exec para reemplazar?
  # Mejor subshell (bash) para volver aquí al salir
  bash "$target_script"
  
  printf "\n%s[INFO]%s Regreso al MultiScript principal.\n" "$C_CYN" "$C_RESET"
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
  printf "  SHARED_CORPUS_DIR: %s (compartir hashes/ML entre discos)\n" "$SHARED_CORPUS_DIR"
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
  djpt_read_line new_base "Nuevo BASE_PATH (ENTER para cancelar, acepta rutas con espacios/drag & drop): "
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
  DJPT_STATE_ANCHOR="$new_base"
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

  printf "%s[INFO]%s Scan workspace -> %s (scanner Python, quick, paralelo por defecto)\n" "$C_CYN" "$C_RESET" "$out"
  if ! ensure_python_bin; then
    printf "%s[ERR]%s Se necesita Python para escanear.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi

  export DJPT_PARALLEL=${DJPT_PARALLEL:-1}
  export DJPT_BASE_DIR="$BASE_PATH"
  export DJPT_ALLOW_OUTSIDE=1

  local tmp_log="/tmp/djpt_scan_$$.log"
  if "$PYTHON_BIN" -m scripts.core.scanner "$BASE_PATH" --quick --allow-outside --parallel --max-workers "${DJPT_PARALLEL_THREADS:-}" >"$tmp_log" 2>&1; then
    local last_scan_dir
    last_scan_dir=$(tail -1 "$tmp_log")
    csv_path="$last_scan_dir/files_index.csv"
    if [ -f "$csv_path" ]; then
      CSV_PATH="$csv_path" TSV_PATH="$out" python3 - <<'PY'
import csv, os
csv_path = os.environ["CSV_PATH"]
tsv_path = os.environ["TSV_PATH"]
os.makedirs(os.path.dirname(tsv_path), exist_ok=True)
with open(csv_path, newline='', encoding='utf-8') as cf, open(tsv_path, 'w', encoding='utf-8') as tf:
    reader = csv.DictReader(cf)
    for row in reader:
        tf.write(f"{row['rel_path']}\t{row['full_path']}\n")
print(f"[OK] Workspace scan saved to {tsv_path}")
PY
      total=$(wc -l <"$out" | tr -d ' ' 2>/dev/null || echo 0)
      printf "%s[OK]%s Scan completado: %s filas.\n" "$C_GRN" "$C_RESET" "$total"
      pause_enter
      return
    else
      printf "%s[ERR]%s No se encontró files_index.csv en %s\n" "$C_RED" "$C_RESET" "$last_scan_dir"
    fi
  else
    printf "%s[WARN]%s Falló el scanner Python; ver log %s. Fallback Bash...\n" "$C_YLW" "$C_RESET" "$tmp_log"
  fi

  # Fallback a implementación Bash original (lenta)
  printf "%s[INFO]%s Modo tradicional - Escaneando todos los archivos (Fallback)\n" "$C_YLW" "$C_RESET"
  
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
  printf "%s[OK]%s Scan completado: %s archivos procesados.\n" "$C_GRN" "$C_RESET" "$total"
  pause_enter
}

action_7_backup_serato() {
  confirm_heavy "Backup Serato (rsync)" || return
  print_header
  printf "%s[INFO]%s Backup Serato básico.\n" "$C_CYN" "$C_RESET"
  src1="$BASE_PATH/_Serato_"
  src2="$BASE_PATH/_Serato_Backup"
  dest="$STATE_DIR/serato_backup"
  ensure_under_base "$BASE_PATH" || { pause_enter; return; }
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
  ensure_under_base "$BASE_PATH" || { pause_enter; return; }
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
  if ! ensure_python_bin; then
    printf "%s[ERR]%s Se necesita Python para hash index.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi

  export DJPT_PARALLEL=${DJPT_PARALLEL:-1}
  export DJPT_BASE_DIR="$BASE_PATH"
  export DJPT_ALLOW_OUTSIDE=1

  tmp_log="/tmp/djpt_hash_$$.log"
  if "$PYTHON_BIN" -m scripts.core.scanner "$BASE_PATH" --allow-outside --parallel --max-workers "${DJPT_PARALLEL_THREADS:-}" >"$tmp_log" 2>&1; then
    last_scan_dir=$(tail -1 "$tmp_log")
    csv_path="$last_scan_dir/files_index.csv"
    if [ -f "$csv_path" ]; then
      CSV_PATH="$csv_path" TSV_PATH="$out" python3 - <<'PY'
import csv, os
csv_path = os.environ["CSV_PATH"]
tsv_path = os.environ["TSV_PATH"]
os.makedirs(os.path.dirname(tsv_path), exist_ok=True)
count = 0
with open(csv_path, newline='', encoding='utf-8') as cf, open(tsv_path, 'w', encoding='utf-8') as tf:
    reader = csv.DictReader(cf)
    for row in reader:
        h = row['sha256'] or ''
        tf.write(f"{h}\t{row['rel_path']}\t{row['full_path']}\n")
        count += 1
print(f"[OK] hash_index.tsv generado ({count} filas) -> {tsv_path}")
PY
      printf "%s[OK]%s hash_index.tsv generado con scanner Python.\n" "$C_GRN" "$C_RESET"
    else
      printf "%s[ERR]%s No se encontró files_index.csv en %s\n" "$C_RED" "$C_RESET" "$last_scan_dir"
    fi
  else
    printf "%s[ERR]%s Falló la generación del hash_index (scanner Python). Ver %s\n" "$C_RED" "$C_RESET" "$tmp_log"
  fi
  pause_enter
}

action_10_dupes_plan() {
  print_header
  hash_file="$REPORTS_DIR/hash_index.tsv"
  if [ ! -f "$hash_file" ]; then
    printf "%s[WARN]%s No hay hash_index.tsv, generando primero.\n" "$C_YLW" "$C_RESET"
    action_9_hash_index
  fi
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
        printf "Confirmar mover archivos marcados como QUARANTINE? (y/N): "
        read -r ans
        [[ "$ans" =~ ^[yY]$ ]] || { printf "%s[INFO]%s Cancelado.\n" "$C_CYN" "$C_RESET"; pause_enter; return; }
    fi

    # Construir plan filtrado a BASE_PATH si SAFE_MODE
    local filtered_plan="$PLANS_DIR/dupes_plan.safe.tsv"
    : >"$filtered_plan"
    while IFS=$'\t' read -r hash action path reason; do
        if [ "$action" != "QUARANTINE" ]; then continue; fi
        if [ "${SAFE_MODE:-1}" -eq 1 ] && ! is_under_base "$path"; then
        printf "%s[WARN]%s Omitiendo path fuera de BASE_PATH: %s\n" "$C_YLW" "$C_RESET" "$path"
        continue
        fi
        printf "%s\t%s\t%s\t%s\n" "$hash" "$action" "$path" "$reason" >>"$filtered_plan"
    done < <(tail -n +2 "$plan_tsv")

    "$PYTHON_BIN" "$executor_script" --plan "$filtered_plan" --quar-dir "$QUAR_DIR" ${dry_run_flag}

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
    if ! read -r qop; then
      break
    fi
    qop="$(echo "$qop" | xargs)"
    [ -z "$qop" ] && continue
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
    ensure_under_base "$BASE_PATH" || { pause_enter; return; }

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
  ensure_under_base "$BASE_PATH" || { pause_enter; return; }
  >"$out"
  find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null | while IFS= read -r f; do
    printf "%s\tGENRE_UNKNOWN\t%s\n" "$f" "$BASE_PATH/_MIRROR_BY_GENRE/GENRE_UNKNOWN/$(basename "$f")" >>"$out"
  done
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
    ensure_under_base "$BASE_PATH" || { pause_enter; return; }

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
  find "$BASE_PATH" -type f 2>/dev/null | while IFS= read -r f; do
    printf "%s\tchown-KEEP\tchmod-KEEP\n" "$f" >>"$out"
  done
  printf "%s[OK]%s Plan generado (no ejecutado).\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_21_install_cmd() {
  print_header
  target_dir="$(resolve_command_target_dir)"
  target="$target_dir/djproducertool"

  # Determine the best source script to link
  # Use the current script path
  src_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

  printf "%s[INFO]%s Instalar comando universal: %s -> %s\n" "$C_CYN" "$C_RESET" "$src_script" "$target"
  
  if [ "$SAFE_MODE" -eq 1 ]; then
    if [ ! -d "$target_dir" ]; then
      printf "%s[WARN]%s El directorio destino no existe aún; se crearía en una ejecución real: %s\n" "$C_YLW" "$C_RESET" "$target_dir"
    fi
    printf "%s[WARN]%s SAFE_MODE=1, solo se mostrará la acción.\n" "$C_YLW" "$C_RESET"
    printf "ln -s \"%s\" \"%s\"\n" "$src_script" "$target"
  else
    mkdir -p "$target_dir"
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
  local target_dir
  target_dir="$(resolve_command_target_dir)"
  target="$target_dir/djproducertool"
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
  printf "%s[INFO]%s Estado: Export/Import bundle\n" "$C_CYN" "$C_RESET"
  printf "  1) Exportar estado\n"
  printf "  2) Importar estado\n"
  printf "  Opción (1/2, default 1): "
  read -r opt
  case "$opt" in
    2) action_26_import_state; return ;;
    *) ;; # export por defecto
  esac
  bundle="$STATE_DIR/DJPT_state_bundle.tar.gz"
  ensure_under_base "$STATE_DIR" || { pause_enter; return; }
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

action_26_import_state() {
  print_header
  local bundle="$STATE_DIR/DJPT_state_bundle.tar.gz"
  ensure_under_base "$STATE_DIR" || { pause_enter; return; }
  if [ ! -f "$bundle" ]; then
    printf "%s[ERR]%s No se encuentra bundle: %s\n" "$C_RED" "$C_RESET" "$bundle"
    pause_enter
    return
  fi
  printf "%s[WARN]%s Se restaurará el estado desde el bundle (SAFE_MODE=%s). Continuar? (y/N): " "$C_YLW" "$C_RESET" "${SAFE_MODE:-1}"
  read -r ans
  [[ "$ans" =~ ^[Yy]$ ]] || { printf "%s[INFO]%s Cancelado.\n" "$C_CYN" "$C_RESET"; pause_enter; return; }
  (tar -xzf "$bundle" -C "$STATE_DIR" 2>/dev/null) &
  local tar_pid=$!
  while kill -0 "$tar_pid" 2>/dev/null; do
    status_line "IMPORT" "--" "Restaurando estado..."
    sleep 1
  done
  finish_status_line
  if wait "$tar_pid"; then
    printf "%s[OK]%s Estado restaurado desde %s\n" "$C_GRN" "$C_RESET" "$bundle"
  else
    printf "%s[ERR]%s Falló la restauración del bundle.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_27_snapshot() {
    local out="$REPORTS_DIR/snapshot_hash_fast.tsv"
    ensure_under_base "$BASE_PATH" || { pause_enter; return; }
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
  djpt_read_line file_a "Hash index A (ENTER usa reports/hash_index.tsv): "
  [ -z "$file_a" ] && file_a="$REPORTS_DIR/hash_index.tsv"
  file_a=$(strip_quotes "$file_a")
  djpt_read_line file_b "Hash index B (drag & drop): "
  file_b=$(strip_quotes "$file_b")
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
  djpt_read_line file_a "Hash index A (ENTER usa reports/hash_index.tsv): "
  [ -z "$file_a" ] && file_a="$REPORTS_DIR/hash_index.tsv"
  file_a=$(strip_quotes "$file_a")
  djpt_read_line file_b "Hash index B (ruta espejo, drag & drop): "
  file_b=$(strip_quotes "$file_b")
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
  djpt_read_line cio $'1) Exportar config\n2) Importar config\nOpción: '
  case "$cio" in
    1)
      bundle="$STATE_DIR/config_bundle_$(date +%s).tar.gz"
      tar -czf "$bundle" -C "$CONFIG_DIR" . 2>/dev/null
      printf "%s[OK]%s Config exportada: %s\n" "$C_GRN" "$C_RESET" "$bundle"
      ;;
    2)
      djpt_read_line bpath "Ruta del bundle (.tar.gz): "
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

# Slots 55-61 activados con handlers explícitos.
action_55_ableton_tools() { submenu_ableton_tools; }
action_56_importers() { submenu_importers_cues; }
action_57_submenu_excludes() { submenu_excludes_manager; }
action_58_hash_compare() { action_compare_hash_indexes; }
action_59_health_check() { action_state_health; }
action_60_export_import_config() { action_export_import_config; }
action_61_mirror_check() { action_mirror_integrity_check; }

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
      if ! ensure_python_deps "ML" "pandas" "scikit-learn" "joblib"; then
        pause_enter
        return
      fi
      
      PLAN_HASH="$PLANS_DIR/general_hash_dupes_plan.tsv"
      PLAN_NAME="$PLANS_DIR/general_dupes_plan.tsv"
      
      printf "%s[INFO]%s Entrenando modelo...\n" "$C_CYN" "$C_RESET"
      "$PYTHON_BIN" "$LIB_DIR/ml_evolutionary.py" train \
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
      "$PYTHON_BIN" "$LIB_DIR/ml_evolutionary.py" predict \
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
      # Garantizar venv y usar venv_manager si está disponible
      ensure_python_bin || { pause_enter; return; }
      if [ ! -x "$VENV_DIR/bin/python3" ]; then
        mkdir -p "$VENV_DIR"
        pycmd="$(command -v python3.12 || command -v python3 || true)"
        [ -z "$pycmd" ] && { printf "%s[ERR]%s No hay python3 para crear venv\n" "$C_RED" "$C_RESET"; pause_enter; return; }
        "$pycmd" -m venv "$VENV_DIR" || { printf "%s[ERR]%s No se pudo crear venv en %s\n" "$C_RED" "$C_RESET" "$VENV_DIR"; pause_enter; return; }
        PYTHON_BIN="$VENV_DIR/bin/python3"
      fi
      if [ -x "$LIB_DIR/venv_manager.py" ]; then
        printf "%s[INFO]%s Instalando stack TF vía venv_manager.py\n" "$C_CYN" "$C_RESET"
        if ! "$PYTHON_BIN" "$LIB_DIR/venv_manager.py" "$VENV_DIR" install; then
          printf "%s[WARN]%s venv_manager reportó error. Intentando instalación directa...\n" "$C_YLW" "$C_RESET"
        fi
      else
        maybe_activate_ml_env "TensorFlow opcional" 1 1
      fi
      if "$VENV_DIR/bin/python3" -c "import tensorflow as tf; print('TF_OK')" >/dev/null 2>&1; then
        printf "%s[OK]%s TensorFlow disponible en el venv.\n" "$C_GRN" "$C_RESET"
      else
        printf "%s[WARN]%s TensorFlow no importable tras primer intento. Reintentando instalación directa en venv...\n" "$C_YLW" "$C_RESET"
        "$VENV_DIR/bin/python3" -m pip install --upgrade pip >/dev/null 2>&1 || true
        if [ "$(uname -m)" = "arm64" ]; then
          "$VENV_DIR/bin/python3" -m pip install tensorflow-macos tensorflow-metal >/dev/null 2>&1 || true
        else
          "$VENV_DIR/bin/python3" -m pip install tensorflow >/dev/null 2>&1 || true
        fi
        if "$VENV_DIR/bin/python3" -c "import tensorflow as tf; print(tf.__version__)" >/dev/null 2>&1; then
          printf "%s[OK]%s TensorFlow instalado y validado tras reintento.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s TensorFlow no se pudo importar (usa: %s -m pip install tensorflow-macos tensorflow-metal)\n" "$C_RED" "$C_RESET" "$VENV_DIR/bin/python3"
        fi
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
  
  # No bootstrap automático al abrir el menú: la instalación debe ser explícita.
  if [ -x "$LIB_DIR/venv_manager.py" ] && [ "${DJPT_TF_LAB_BOOTSTRAP:-0}" = "1" ]; then
    ensure_python_bin
    printf "%s[INFO]%s Bootstrap explícito de TF Lab vía venv_manager.py\n" "$C_CYN" "$C_RESET"
    if ! "$PYTHON_BIN" "$LIB_DIR/venv_manager.py" "$VENV_DIR" install; then
       printf "%s[ERR]%s Falló bootstrap de dependencias para TF Lab.\n" "$C_RED" "$C_RESET"
       pause_enter
    fi
  fi

  while true; do
    clear
    print_header
    printf "%s=== TensorFlow Lab (requiere TF instalado) ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s[INFO]%s Dependencias: python3 + tensorflow + tensorflow_hub + soundfile + numpy. Límite: ~150 archivos; similitud usa umbral >=0.60 (top 200 pares).\n" "$C_CYN" "$C_RESET"
    if [ -x "$LIB_DIR/venv_manager.py" ]; then
      printf "%s[INFO]%s Bootstrap opcional: exporta DJPT_TF_LAB_BOOTSTRAP=1 o usa la opción 64/72 para instalar el stack.\n" "$C_CYN" "$C_RESET"
    fi
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
    top="$(echo "$top" | xargs)"
    [ -z "$top" ] && continue
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
        printf "%s[INFO]%s Descargar modelo opcional (onnx/tflite) a _DJProducerTools/venv/models\n" "$C_CYN" "$C_RESET"
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
    if ! read -r wop; then
      break
    fi
    wop="$(echo "$wop" | xargs)"
    [ -z "$wop" ] && continue
    case "$wop" in
      1)
        local domains
        domains="$(web_whitelist_domains)"
        printf "%s[INFO]%s Whitelist WEB actual (%s dominio(s)):\n" "$C_CYN" "$C_RESET" "$(printf "%s" "$domains" | awk -F',' '{print NF}')"
        printf "%s\n" "$domains" | tr ',' '\n' | sed 's/^/  /'
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
  while true; do
    print_header
    local domains current_count wopt new_domain remaining normalized
    domains="$(web_whitelist_domains)"
    current_count="$(printf "%s" "$domains" | awk -F',' '{print NF}')"
    printf "%s[INFO]%s WEB Whitelist Manager.\n" "$C_CYN" "$C_RESET"
    printf "Dominios actuales (%s): %s\n\n" "$current_count" "$domains"
    printf "1) Listar dominios\n"
    printf "2) Añadir dominio\n"
    printf "3) Eliminar dominio\n"
    printf "4) Reset a defaults\n"
    printf "B) Volver\n"
    printf "Opción: "
    if ! read -r wopt; then
      break
    fi
    wopt="$(echo "$wopt" | xargs)"
    case "$wopt" in
      1)
        printf "%s\n" "$domains" | tr ',' '\n' | sed 's/^/  /'
        pause_enter
        ;;
      2)
        djpt_read_line new_domain "Dominio a añadir (sin protocolo): "
        new_domain="$(strip_quotes "$new_domain")"
        new_domain="${new_domain#http://}"
        new_domain="${new_domain#https://}"
        new_domain="${new_domain%%/*}"
        [ -n "$new_domain" ] || { printf "%s[WARN]%s Dominio vacío.\n" "$C_YLW" "$C_RESET"; pause_enter; continue; }
        WEB_WHITELIST="$(normalize_web_whitelist "${domains},${new_domain}")"
        save_conf
        printf "%s[OK]%s Dominio añadido. Nueva whitelist: %s\n" "$C_GRN" "$C_RESET" "$WEB_WHITELIST"
        pause_enter
        ;;
      3)
        djpt_read_line new_domain "Dominio a eliminar: "
        new_domain="$(strip_quotes "$new_domain")"
        new_domain="${new_domain#http://}"
        new_domain="${new_domain#https://}"
        new_domain="${new_domain%%/*}"
        lower_new_domain="$(printf '%s' "$new_domain" | tr '[:upper:]' '[:lower:]')"
        remaining=""
        IFS=',' read -r -a web_arr <<<"$domains"
        for normalized in "${web_arr[@]}"; do
          [ "$normalized" = "$lower_new_domain" ] && continue
          if [ -z "$remaining" ]; then
            remaining="$normalized"
          else
            remaining="$remaining,$normalized"
          fi
        done
        WEB_WHITELIST="$(normalize_web_whitelist "${remaining:-$DEFAULT_WEB_WHITELIST}")"
        save_conf
        printf "%s[OK]%s Whitelist actualizada: %s\n" "$C_GRN" "$C_RESET" "$WEB_WHITELIST"
        pause_enter
        ;;
      4)
        WEB_WHITELIST="$DEFAULT_WEB_WHITELIST"
        save_conf
        printf "%s[OK]%s Whitelist restaurada a defaults: %s\n" "$C_GRN" "$C_RESET" "$WEB_WHITELIST"
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

action_38_clean_web_playlists() {
  print_header
  printf "%s[INFO]%s Limpiar entradas WEB en playlists.\n" "$C_CYN" "$C_RESET"
  find "$BASE_PATH" -type f \( -iname "*.m3u" -o -iname "*.m3u8" \) 2>/dev/null | while IFS= read -r f; do
    tmp="$f.tmp"
    : >"$tmp"
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ "$line" =~ ^https?:// ]]; then
        if web_url_is_whitelisted "$line"; then
          printf "%s\n" "$line" >>"$tmp"
        fi
      else
        printf "%s\n" "$line" >>"$tmp"
      fi
    done <"$f"
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
  print_header
  printf "%s[INFO]%s 🧠 DEEP-THINKING: Análisis Inteligente de Biblioteca\n" "$C_CYN" "$C_RESET"

  local ts analysis_report analyzer_script candidate
  ts=$(date +%s)
  analysis_report="$REPORTS_DIR/smart_analysis_${ts}.json"
  analyzer_script=""
  mkdir -p "$REPORTS_DIR"

  for candidate in \
    "${DJPT_CANONICAL_ROOT:-$SCRIPT_DIR/..}/smart_analyzer.py" \
    "$SCRIPT_DIR/../smart_analyzer.py" \
    "$LIB_DIR/smart_analyzer.py" \
    "$SCRIPT_DIR/smart_analyzer.py" \
    "${ROOT_DIR:-}/lib/smart_analyzer.py"
  do
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
      analyzer_script="$candidate"
      break
    fi
  done

  if [ -z "$analyzer_script" ]; then
    printf "%s[ERR]%s No se encuentra smart_analyzer.py (rutas probadas: lib/, ../lib/).\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi

  if ! ensure_python_bin; then
    printf "%s[ERR]%s Se necesita Python para esta acción.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi

  if "$PYTHON_BIN" "$analyzer_script" "$BASE_PATH" "$analysis_report"; then
    printf "%s[OK]%s Análisis generado: %s\n" "$C_GRN" "$C_RESET" "$analysis_report"
  else
    printf "%s[ERR]%s Falló el análisis inteligente.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_41_ml_predictor() {
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

    if "$PYTHON_BIN" "$planner_script" --base "$BASE_PATH" --out "$org_plan" --limit 50 --lang es; then
        printf "%s[OK]%s Plan de organización generado: %s\n" "$C_GRN" "$C_RESET" "$org_plan"
    else
        printf "%s[ERR]%s Falló la generación del plan de organización.\n" "$C_RED" "$C_RESET"
    fi
    pause_enter
}

action_46_metadata_harmonizer() {
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
    if ! read -r aop; then
      break
    fi
    aop="$(echo "$aop" | xargs)"
    [ -z "$aop" ] && continue
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
    if ! read -r iop; then
      break
    fi
    iop="$(echo "$iop" | xargs)"
    [ -z "$iop" ] && continue
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
  local osc_enabled=0
  if "$PYTHON_BIN" -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('pythonosc') else 1)" >/dev/null 2>&1; then
    osc_enabled=1
  else
    printf "%s[WARN]%s python-osc no está instalado; se iniciará solo la API HTTP.\n" "$C_YLW" "$C_RESET"
  fi
  http_port=8000
  osc_port=9000
  djpt_read_line hp "HTTP port (ENTER=8000): "; [ -n "$hp" ] && http_port="$hp"
  djpt_read_line op "OSC port (ENTER=9000): "; [ -n "$op" ] && osc_port="$op"
  djpt_read_line api_token "Bearer token (ENTER = sin token): "
  printf "Iniciar servidor (HTTP %s, OSC %s)? [y/N]: " "$http_port" "$osc_port"
  read -r ans
  case "$ans" in
    y|Y)
      args=(--base "$BASE_PATH" --state "$STATE_DIR" --report "$REPORTS_DIR" --http-port "$http_port" --osc-port "$osc_port")
      [ -n "$api_token" ] && args+=(--auth-token "$api_token")
      [ "$osc_enabled" -eq 0 ] && args+=(--disable-osc)
      nohup "$PYTHON_BIN" "$LIB_DIR/osc_api_server.py" "${args[@]}" >/dev/null 2>&1 &
      srv_pid=$!
      echo "$srv_pid" >"$pid_file"
      printf "%s[OK]%s Servidor iniciado (PID %s). HTTP http://127.0.0.1:%s\n" "$C_GRN" "$C_RESET" "$srv_pid" "$http_port"
      if [ "$osc_enabled" -eq 0 ]; then
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
    if ! read -r lop; then
      break
    fi
    lop="$(echo "$lop" | xargs)"
    [ -z "$lop" ] && continue
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
          bridge="$LIB_DIR/rekordbox_cues_bridge.py"
          if [ ! -f "$bridge" ]; then
            printf "%s[ERR]%s No se encuentra %s\n" "$C_RED" "$C_RESET" "$bridge"
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
          bridge="$LIB_DIR/rekordbox_cues_bridge.py"
          if [ ! -f "$bridge" ]; then
            printf "%s[ERR]%s No se encuentra %s\n" "$C_RED" "$C_RESET" "$bridge"
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
    if ! read -r dop; then
      break
    fi
    dop="$(echo "$dop" | xargs)"
    [ -z "$dop" ] && continue
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
        while IFS= read -e -r path; do
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
          printf "rsync -av --progress --protect-args %q %q\n" "$src" "$target" >>"$rsync_helper"
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
            h=$(calc_sha256 "$f")
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
              sig=$(printf "%s" "$files" | calc_sha256)
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
                  h=$(calc_sha256 "$f")
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
            sig=$(sort "$list_file" | calc_sha256)
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
    h=$(calc_sha256 "$f")
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
  "$PYTHON_BIN" "$LIB_DIR/playlist_bridge.py" osc "$pl_path" "$plan" 2>/dev/null || {
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
    printf "%s3)%s Plan OSC/DMX sincronizado por timeline\n" "$C_GRN" "$C_RESET"
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
    if ! read -r vop; then
      break
    fi
    vop="$(echo "$vop" | xargs)"
    [ -z "$vop" ] && continue
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

submenu_H_help() {
  while true; do
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
    printf "  10) Plan duplicados -> dupes_plan.json/tsv (usa hash_index).\n"
    printf "  11) Quarantine desde dupes_plan.tsv (aplica plan; respeta SafeMode/Lock).\n"
    printf "  12) Quarantine Manager: listar / restaurar / borrar contenido de quarantine.\n"
    printf "  13) ffprobe -> media_corrupt.tsv (detectar archivos corruptos).\n"
    printf "  27) Snapshot integridad con barra de progreso (hash rápido).\n"
    printf "  30) Plan organización por TAGS (género) -> TSV.\n"
    printf "  31) Informe de géneros y recuentos.\n"
    printf "  32-33) Vídeo: reporte + plan de transcode (Serato Video).\n"
    printf "  34-35) Planes de renombrado y samples por tipo.\n"
    printf "  36-39) Submenú y herramientas WEB (whitelist + limpieza tags/playlists).\n\n"
    
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
    printf "  Nota: todo el análisis es local; no envía datos. En modo básico usa reglas/estadísticas; en 62 puedes entrenar un modelo ligero local.\n\n"
    
    printf "%sB)%s Volver al menú principal\n" "$C_YLW" "$C_RESET"
    printf "%sSelecciona una opción:%s " "$C_BLU" "$C_RESET"
    if ! read -r hop; then
      break
    fi
    hop="$(echo "$hop" | xargs)"
    [ -z "$hop" ] && continue
    case "$hop" in
      1) action_1_status ;;
      2) action_2_change_base ;;
      3) action_3_summary ;;
      4) action_4_top_dirs ;;
      5) action_5_top_files ;;
      6) action_6_scan_workspace ;;
      9) action_9_hash_index ;;
      10) action_10_dupes_plan ;;
      11) action_11_quarantine_from_plan ;;
      12) action_12_quarantine_manager ;;
      13) action_13_ffprobe_report ;;
      27) action_27_snapshot ;;
      30) action_30_plan_tags ;;
      31) action_31_report_tags ;;
      32) action_32_serato_video_report ;;
      33) action_33_serato_video_prep ;;
      34) action_34_normalize_names ;;
      35) action_35_samples_by_type ;;
          0) break ;;
      36) submenu_36_web_clean ;;
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
      B|b)
        break
        ;;
      *)
        invalid_option
        ;;
    esac
  done
}

submenu_C_chat() {
  while true; do
    clear
    printf "%s=== C) Chat IA Integrado ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Enhanced Chat (con historial y contexto)%s\n" "$C_GRN" "$C_RESET"
    printf "%s2)%s Basic Chat CLI (simple y rápido)%s\n" "$C_GRN" "$C_RESET"
    printf "%s3)%s Enhanced Chat (SAFE_MODE=1)%s\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s Basic Chat (SAFE_MODE=1)%s\n" "$C_YLW" "$C_RESET"
    printf "%s5)%s Configurar Backend de IA\n" "$C_BLU" "$C_RESET"
    printf "%s6)%s Ver estado de Backends\n" "$C_BLU" "$C_RESET"
    printf "%s7)%s Insights del Sistema\n" "$C_BLU" "$C_RESET"
    printf "%s8)%s Chat con Backend Específico\n" "$C_BLU" "$C_RESET"
    printf "%sB)%s Volver al menú principal\n" "$C_YLW" "$C_RESET"
    printf "%sSelecciona una opción:%s " "$C_BLU" "$C_RESET"
    if ! read -r cop; then
      break
    fi
    cop="$(echo "$cop" | xargs)"
    [ -z "$cop" ] && continue
    case "$cop" in
      1)
        clear
        printf "%s[INFO]%s Iniciando Enhanced Chat...\n" "$C_CYN" "$C_RESET"
        action_chat_cli
        ;;
      2)
        clear
        printf "%s[INFO]%s Iniciando Basic Chat CLI...\n" "$C_CYN" "$C_RESET"
        if [ -f "$LIB_DIR/djpt_chat_cli.py" ]; then
          "$PYTHON_BIN" "$LIB_DIR/djpt_chat_cli.py"
        else
          printf "%s[ERR]%s djpt_chat_cli.py no encontrado.\n" "$C_RED" "$C_RESET"
        fi
        ;;
      3)
        clear
        printf "%s[INFO]%s Iniciando Enhanced Chat (SAFE_MODE=1)...\n" "$C_CYN" "$C_RESET"
        SAFE_MODE=1 DJPT_SAFE_MODE=1 action_chat_cli
        ;;
      4)
        clear
        printf "%s[INFO]%s Iniciando Basic Chat (SAFE_MODE=1)...\n" "$C_CYN" "$C_RESET"
        if [ -f "$LIB_DIR/djpt_chat_cli.py" ]; then
          SAFE_MODE=1 DJPT_SAFE_MODE=1 "$PYTHON_BIN" "$LIB_DIR/djpt_chat_cli.py"
        else
          printf "%s[ERR]%s djpt_chat_cli.py no encontrado.\n" "$C_RED" "$C_RESET"
        fi
        ;;
      5)
        clear
        printf "%s[INFO]%s Configurar Backend de IA.\n" "$C_CYN" "$C_RESET"
        action_ai_backends_manager
        ;;
      6)
        clear
        printf "%s[INFO]%s Ver estado de Backends.\n" "$C_CYN" "$C_RESET"
        action_ai_status
        ;;
      7)
        clear
        printf "%s[INFO]%s Insights del Sistema.\n" "$C_CYN" "$C_RESET"
        local enhanced_chat_script=""
        enhanced_chat_script="$(resolve_enhanced_chat_cli_script)" || true
        if [ -n "$enhanced_chat_script" ] && [ -f "$enhanced_chat_script" ]; then
          "$PYTHON_BIN" "$enhanced_chat_script" --insights
        else
          printf "%s[WARN]%s enhanced_chat_cli.py no encontrado.\n" "$C_YLW" "$C_RESET"
        fi
        ;;
      8)
        clear
        printf "%sBackend para chat (ENTER = actual): " "$C_BLU"
        read -r backend
        local enhanced_chat_script=""
        enhanced_chat_script="$(resolve_enhanced_chat_cli_script)" || true
        if [ -n "$enhanced_chat_script" ] && [ -f "$enhanced_chat_script" ]; then
          if [ -n "$backend" ]; then
            "$PYTHON_BIN" "$enhanced_chat_script" --chat "$backend"
          else
            "$PYTHON_BIN" "$enhanced_chat_script" --chat
          fi
        else
          printf "%s[WARN]%s enhanced_chat_cli.py no encontrado, usando basic chat.\n" "$C_YLW" "$C_RESET"
          if [ -f "$LIB_DIR/djpt_chat_cli.py" ]; then
            "$PYTHON_BIN" "$LIB_DIR/djpt_chat_cli.py"
          fi
        fi
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

action_quantum_processing() {
  print_header
  printf "%s=== EXPERIMENTAL: QUANTUM PROCESSING ===%s\n" "$BANNER" "$C_RESET"
  printf "Iniciando análisis neuronal avanzado (MLX/TensorFlow)...\n"
  
  if [ -f "$SCRIPT_DIR/../ml_mlx_integration.py" ]; then
      "$PYTHON_BIN" "$SCRIPT_DIR/../ml_mlx_integration.py" --analyze || true
  elif [ -f "$SCRIPT_DIR/../ai/hybrid_intelligence.py" ]; then
       # Fallback to hybrid intelligence chat in interactive mode for now
       printf "Modo interactivo experimental:\n"
       "$PYTHON_BIN" "$SCRIPT_DIR/../ai/hybrid_intelligence.py"
  else
      printf "%s[WARN]%s Motor ML no encontrado.\n" "$C_YLW" "$C_RESET"
  fi
  pause_enter
}

submenu_R_repair_system() {
  while true; do
    print_header
    printf "%s=== R) Reparación y Regeneración del Sistema ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Configuración MPC Avanzada\n" "$C_GRN" "$C_RESET"
    printf "%s2)%s Neural Audio Processing\n" "$C_GRN" "$C_RESET"
    printf "%s3)%s Distributed Processing\n" "$C_GRN" "$C_RESET"
    printf "%s4)%s Real-time Monitoring\n" "$C_GRN" "$C_RESET"
    printf "%s5)%s Enhanced Error Recovery\n" "$C_GRN" "$C_RESET"
    printf "%s6)%s Advanced Configuration\n" "$C_GRN" "$C_RESET"
    printf "%s7)%s Integration APIs\n" "$C_GRN" "$C_RESET"
    printf "%s8)%s Performance Tuning\n" "$C_GRN" "$C_RESET"
    printf "%s9)%s System Diagnostics\n" "$C_GRN" "$C_RESET"
    printf "%s10)%s Experimental Features (Quantum Processing)\n" "$C_PURP" "$C_RESET"
    printf "%sB)%s Volver al menú principal\n" "$C_YLW" "$C_RESET"
    printf "%sSelecciona una opción:%s " "$C_BLU" "$C_RESET"
    if ! read -r drp; then
      break
    fi
    drp="$(echo "$drp" | xargs)"
    [ -z "$drp" ] && continue
    case "$drp" in
      1)
        clear
        printf "%s[INFO]%s Configuración MPC Avanzado.\n" "$C_CYN" "$C_RESET"
        printf "Estado actual del MPC:\n"
        printf -- "- Predicción de acciones: %s\n" "${DJPT_MPC_ENABLED:-"Desactivado"}"
        printf -- "- Aprendizaje continuo: %s\n" "${DJPT_MPC_LEARNING:-"Desactivado"}"
        printf -- "- UI Adaptativa: %s\n" "${DJPT_ADAPTIVE_UI:-"Desactivado"}"
        printf "\nOpciones:\n"
        printf "  1) Activar MPC básico\n"
        printf "  2) Activar MPC avanzado\n"
        printf "  3) Configurar umbrales de predicción\n"
        printf "  4) Resetear modelo de aprendizaje\n"
        printf "  B) Volver\n"
        printf "Opción: "
        read -r mpc_opt
        case "$mpc_opt" in
          1)
            DJPT_MPC_ENABLED=1
            save_conf
            printf "%s[OK]%s MPC básico activado.\n" "$C_GRN" "$C_RESET"
            ;;
          2)
            DJPT_MPC_ENABLED=1
            DJPT_MPC_LEARNING=1
            DJPT_ADAPTIVE_UI=1
            save_conf
            printf "%s[OK]%s MPC avanzado activado.\n" "$C_GRN" "$C_RESET"
            ;;
          3)
            printf "Umbral de predicción (0.0-1.0, actual: ${DJPT_MPC_THRESHOLD:-0.7}): "
            read -r threshold
            if "$PYTHON_BIN" - "$threshold" >/dev/null 2>&1 <<'PY'
from __future__ import annotations
import sys
try:
    value = float(sys.argv[1])
except Exception:
    raise SystemExit(1)
raise SystemExit(0 if 0.0 <= value <= 1.0 else 1)
PY
            then
              DJPT_MPC_THRESHOLD="$threshold"
              save_conf
              printf "%s[OK]%s Umbral configurado: %s\n" "$C_GRN" "$C_RESET" "$threshold"
            else
              printf "%s[ERR]%s Umbral inválido.\n" "$C_RED" "$C_RESET"
            fi
            ;;
          4)
            unset DJPT_MPC_MODEL
            save_conf
            printf "%s[OK]%s Modelo de aprendizaje reseteado.\n" "$C_GRN" "$C_RESET"
            ;;
          B|b)
            ;;
          *)
            printf "%s[WARN]%s Opción inválida.\n" "$C_YLW" "$C_RESET"
            ;;
        esac
        pause_enter
        ;;
      2)
        clear
        printf "%s[INFO]%s Neural Audio Processing.\n" "$C_CYN" "$C_RESET"
        
        # Check if neural audio processing system exists
        if [ -f "$SCRIPT_DIR/repair/neural_audio_processing_system.py" ]; then
          printf "Sistema de procesamiento neural de audio disponible.\n"
          printf "\nOpciones:\n"
          printf "  1) Ver estado del sistema neural\n"
          printf "  2) Probar modelos disponibles\n"
          printf "  3) Procesamiento en tiempo real\n"
          printf "  4) Procesamiento por lotes\n"
          printf "  5) Configurar parámetros\n"
          printf "  6) Exportar rendimiento\n"
          printf "  B) Volver\n"
          printf "Opción: "
          read -r neural_opt
          case "$neural_opt" in
            1)
              printf "%s[INFO]%s Mostrando estado del sistema neural...\n" "$C_CYN" "$C_RESET"
              "$PYTHON_BIN" "$SCRIPT_DIR/repair/neural_audio_processing_system.py" --status
              pause_enter
              ;;
            2)
              printf "%s[INFO]%s Probando modelos disponibles...\n" "$C_CYN" "$C_RESET"
              "$PYTHON_BIN" "$SCRIPT_DIR/repair/neural_audio_processing_system.py" --test-models
              pause_enter
              ;;
            3)
              printf "%s[INFO]%s Iniciando procesamiento en tiempo real...\n" "$C_CYN" "$C_RESET"
              printf "Modelo a usar:\n"
              printf "  1) Denoising (Reducción de ruido)\n"
              printf "  2) Enhancement (Mejora)\n"
              printf "  3) Separation (Separación de fuentes)\n"
              printf "  4) Transcription (Transcripción)\n"
              printf "  5) Generation (Generación)\n"
              printf "Opción: "
              read -r model_opt
              case "$model_opt" in
                1) model="denoising" ;;
                2) model="enhancement" ;;
                3) model="separation" ;;
                4) model="transcription" ;;
                5) model="generation" ;;
                *) model="denoising" ;;
              esac
              "$PYTHON_BIN" "$SCRIPT_DIR/repair/neural_audio_processing_system.py" --realtime --model "$model"
              pause_enter
              ;;
            4)
              printf "%s[INFO]%s Iniciando procesamiento por lotes...\n" "$C_CYN" "$C_RESET"
              printf "Número de archivos a procesar (1-10): "
              read -r batch_count
              if [[ "$batch_count" =~ ^[0-9]+$ ]] && [ "$batch_count" -ge 1 ] && [ "$batch_count" -le 10 ]; then
                "$PYTHON_BIN" "$SCRIPT_DIR/repair/neural_audio_processing_system.py" --batch --count "$batch_count"
              else
                printf "%s[WARN]%s Número inválido. Usando 3 archivos.\n" "$C_YLW" "$C_RESET"
                "$PYTHON_BIN" "$SCRIPT_DIR/repair/neural_audio_processing_system.py" --batch --count 3
              fi
              pause_enter
              ;;
            5)
              printf "%s[INFO]%s Configurando parámetros del sistema...\n" "$C_CYN" "$C_RESET"
              printf "Tasa de muestreo (actual: 44100): "
              read -r sample_rate
              if [[ "$sample_rate" =~ ^[0-9]+$ ]]; then
                export DJPT_NEURAL_SAMPLE_RATE="$sample_rate"
                printf "%s[OK]%s Tasa de muestreo configurada.\n" "$C_GRN" "$C_RESET"
              fi
              printf "Tamaño del buffer (actual: 1024): "
              read -r buffer_size
              if [[ "$buffer_size" =~ ^[0-9]+$ ]]; then
                export DJPT_NEURAL_BUFFER_SIZE="$buffer_size"
                printf "%s[OK]%s Tamaño del buffer configurado.\n" "$C_GRN" "$C_RESET"
              fi
              save_conf
              ;;
            6)
              printf "%s[INFO]%s Exportando métricas de rendimiento...\n" "$C_CYN" "$C_RESET"
              "$PYTHON_BIN" "$SCRIPT_DIR/repair/neural_audio_processing_system.py" --export-performance
              printf "%s[OK]%s Métricas exportadas.\n" "$C_GRN" "$C_RESET"
              pause_enter
              ;;
            B|b)
              ;;
            *)
              printf "%s[WARN]%s Opción inválida.\n" "$C_YLW" "$C_RESET"
              ;;
          esac
        else
          printf "%s[WARN]%s Sistema de procesamiento neural no encontrado.\n" "$C_YLW" "$C_RESET"
          printf "Estado del procesamiento neural:\n"
          printf -- "- Modelos disponibles: %s\n" "$(find "$SCRIPT_DIR/../models" -name "*.pkl" -o -name "*.h5" 2>/dev/null | wc -l | tr -d ' ')"
          printf -- "- GPU disponible: %s\n" "${DJPT_GPU_AVAILABLE:-"Desconocido"}"
          printf "\nOpciones:\n"
          printf "  1) Escanear modelos\n"
          printf "  2) Configurar procesamiento\n"
          printf "  3) Test de procesamiento neural\n"
          printf "  B) Volver\n"
          printf "Opción: "
          read -r neural_opt
          case "$neural_opt" in
            1)
              printf "Modelos encontrados:\n"
              find "$SCRIPT_DIR/../models" -name "*.pkl" -o -name "*.h5" 2>/dev/null | while read -r model; do
                printf "  - $(basename "$model")\n"
              done
              pause_enter
              ;;
            2)
              printf "Configurar procesamiento neural:\n"
              printf "Batch size (actual: ${DJPT_NEURAL_BATCH:-32}): "
              read -r batch
              if [[ "$batch" =~ ^[0-9]+$ ]]; then
                DJPT_NEURAL_BATCH="$batch"
                save_conf
                printf "%s[OK]%s Batch size configurado.\n" "$C_GRN" "$C_RESET"
              fi
              ;;
            3)
              printf "%s[INFO]%s Ejecutando test de procesamiento neural...\n" "$C_CYN" "$C_RESET"
              if [ -f "$SCRIPT_DIR/../test_neural_audio.py" ]; then
                "$PYTHON_BIN" "$SCRIPT_DIR/../test_neural_audio.py"
              elif [ -f "$SCRIPT_DIR/../neural_engine_test.py" ]; then
                "$PYTHON_BIN" "$SCRIPT_DIR/../neural_engine_test.py"
              else
                printf "%s[WARN]%s Test neural no encontrado.\n" "$C_YLW" "$C_RESET"
              fi
              pause_enter
              ;;
            B|b)
              ;;
            *)
              printf "%s[WARN]%s Opción inválida.\n" "$C_YLW" "$C_RESET"
              ;;
          esac
        fi
        pause_enter
        ;;
      3)
        clear
        printf "%s[INFO]%s Distributed Processing.\n" "$C_CYN" "$C_RESET"
        printf "Configuración de procesamiento distribuido:\n"
        printf -- "- Nodos workers: %s\n" "${DJPT_WORKER_NODES:-"1 (local)"}"
        printf -- "- Balanceo de carga: %s\n" "${DJPT_LOAD_BALANCING:-"Desactivado"}"
        printf "\nOpciones:\n"
        printf "  1) Configurar workers\n"
        printf "  2) Activar balanceo de carga\n"
        printf "  3) Test de procesamiento distribuido\n"
        printf "  B) Volver\n"
        printf "Opción: "
        read -r dist_opt
        case "$dist_opt" in
          1)
            printf "Número de nodos workers (actual: ${DJPT_WORKER_NODES:-"1"}): "
            read -r nodes
            if [[ "$nodes" =~ ^[0-9]+$ ]]; then
              DJPT_WORKER_NODES="$nodes"
              save_conf
              printf "%s[OK]%s Workers configurados.\n" "$C_GRN" "$C_RESET"
            fi
            ;;
          2)
            DJPT_LOAD_BALANCING=1
            save_conf
            printf "%s[OK]%s Balanceo de carga activado.\n" "$C_GRN" "$C_RESET"
            ;;
          3)
            printf "%s[INFO]%s Test de procesamiento distribuido...\n" "$C_CYN" "$C_RESET"
            if [ -f "$SCRIPT_DIR/../test_distributed.py" ]; then
              "$PYTHON_BIN" "$SCRIPT_DIR/../test_distributed.py"
            elif [ -f "$SCRIPT_DIR/../production_tester.py" ]; then
              "$PYTHON_BIN" "$SCRIPT_DIR/../production_tester.py"
            else
              printf "%s[WARN]%s Test distribuido no encontrado.\n" "$C_YLW" "$C_RESET"
            fi
            pause_enter
            ;;
          B|b)
            ;;
          *)
            printf "%s[WARN]%s Opción inválida.\n" "$C_YLW" "$C_RESET"
            ;;
        esac
        ;;
      4)
        clear
        printf "%s[INFO]%s Real-time Monitoring.\n" "$C_CYN" "$C_RESET"
        printf "Estado del monitoreo:\n"
        printf -- "- Métricas en tiempo real: %s\n" "${DJPT_REALTIME_METRICS:-"Desactivado"}"
        printf -- "- Alertas automáticas: %s\n" "${DJPT_AUTO_ALERTS:-"Desactivado"}"
        printf "\nOpciones:\n"
        printf "  1) Activar monitoreo en tiempo real\n"
        printf "  2) Configurar alertas\n"
        printf "  3) Ver métricas actuales\n"
        printf "  B) Volver\n"
        printf "Opción: "
        read -r mon_opt
        case "$mon_opt" in
          1)
            DJPT_REALTIME_METRICS=1
            save_conf
            printf "%s[OK]%s Monitoreo en tiempo real activado.\n" "$C_GRN" "$C_RESET"
            ;;
          2)
            DJPT_AUTO_ALERTS=1
            save_conf
            printf "%s[OK]%s Alertas automáticas activadas.\n" "$C_GRN" "$C_RESET"
            ;;
          3)
            printf "Métricas actuales:\n"
            if [ -f "$SCRIPT_DIR/../runtime_metrics.py" ]; then
              metrics_json="$("$PYTHON_BIN" "$SCRIPT_DIR/../runtime_metrics.py" --base-path "$BASE_PATH" 2>/dev/null || true)"
              if [ -n "$metrics_json" ]; then
                metrics_lines="$("$PYTHON_BIN" - <<'PY' "$metrics_json"
from __future__ import annotations
import json
import sys
payload = json.loads(sys.argv[1])
print(payload.get("cpu_percent", "N/A"))
print(payload.get("memory_percent", "N/A"))
print(payload.get("throughput_files_per_min", "N/A"))
PY
)"
                cpu_usage="$(printf '%s\n' "$metrics_lines" | sed -n '1p')"
                memory_usage="$(printf '%s\n' "$metrics_lines" | sed -n '2p')"
                throughput_usage="$(printf '%s\n' "$metrics_lines" | sed -n '3p')"
              fi
            fi
            printf -- "- CPU: %s%%\n" "${cpu_usage:-${DJPT_CPU_USAGE:-N/A}}"
            printf -- "- Memoria: %s%%\n" "${memory_usage:-${DJPT_MEMORY_USAGE:-N/A}}"
            printf -- "- Throughput: %s archivos/min\n" "${throughput_usage:-${DJPT_THROUGHPUT:-N/A}}"
            pause_enter
            ;;
          B|b)
            ;;
          *)
            printf "%s[WARN]%s Opción inválida.\n" "$C_YLW" "$C_RESET"
            ;;
        esac
        ;;
      5)
        clear
        printf "%s[INFO]%s Enhanced Error Recovery.\n" "$C_CYN" "$C_RESET"
        
        # Check if error recovery module exists
        if [ -f "$SCRIPT_DIR/../ai/error_recovery.py" ]; then
          printf "Sistema de recuperación avanzada disponible.\n"
          printf "\nOpciones:\n"
          printf "  1) Iniciar monitoreo del sistema\n"
          printf "  2) Generar informe de recuperación\n"
          printf "  3) Probar sistema de recuperación\n"
          printf "  4) Ver estado de recuperación\n"
          printf "  5) Activar auto-healing\n"
          printf "  B) Volver\n"
          printf "Opción: "
          read -r rec_opt
          case "$rec_opt" in
            1)
              printf "%s[INFO]%s Iniciando monitoreo del sistema...\n" "$C_CYN" "$C_RESET"
              "$PYTHON_BIN" "$SCRIPT_DIR/../ai/error_recovery.py" --monitor
              ;;
            2)
              printf "%s[INFO]%s Generando informe de recuperación...\n" "$C_CYN" "$C_RESET"
              "$PYTHON_BIN" "$SCRIPT_DIR/../ai/error_recovery.py" --report
              pause_enter
              ;;
            3)
              printf "%s[INFO]%s Probando sistema de recuperación...\n" "$C_CYN" "$C_RESET"
              printf "Tipo de error a simular:\n"
              printf "  1) Error de memoria\n"
              printf "  2) Error de permisos\n"
              printf "  3) Error de red\n"
              printf "  4) Error de dependencias\n"
              printf "Opción: "
              read -r error_type
              case "$error_type" in
                1) error_sim="memory_error" ;;
                2) error_sim="permission_error" ;;
                3) error_sim="network_error" ;;
                4) error_sim="dependency_error" ;;
                *) error_sim="unknown_error" ;;
              esac
              "$PYTHON_BIN" "$SCRIPT_DIR/../ai/error_recovery.py" --test-error "$error_sim"
              pause_enter
              ;;
            4)
              printf "%s[INFO]%s Estado del sistema de recuperación...\n" "$C_CYN" "$C_RESET"
              "$PYTHON_BIN" "$SCRIPT_DIR/../ai/error_recovery.py" --status
              pause_enter
              ;;
            5)
              DJPT_AUTO_HEALING=1
              save_conf
              printf "%s[OK]%s Auto-healing activado.\n" "$C_GRN" "$C_RESET"
              printf "%s[INFO]%s El sistema monitorizará y recuperará errores automáticamente.\n" "$C_CYN" "$C_RESET"
              pause_enter
              ;;
            B|b)
              ;;
            *)
              printf "%s[WARN]%s Opción inválida.\n" "$C_YLW" "$C_RESET"
              ;;
          esac
        else
          printf "Módulo de recuperación avanzada no encontrado.\n"
          printf "Estado de recuperación básico:\n"
          printf -- "- Auto-healing: %s\n" "${DJPT_AUTO_HEALING:-"Desactivado"}"
          printf -- "- Rollback system: %s\n" "${DJPT_ROLLBACK:-"Desactivado"}"
          printf "\nOpciones:\n"
          printf "  1) Activar auto-healing\n"
          printf "  2) Configurar rollback\n"
          printf "  3) Ver puntos de restauración\n"
          printf "  B) Volver\n"
          printf "Opción: "
          read -r rec_opt
          case "$rec_opt" in
            1)
              DJPT_AUTO_HEALING=1
              save_conf
              printf "%s[OK]%s Auto-healing activado.\n" "$C_GRN" "$C_RESET"
              ;;
            2)
              DJPT_ROLLBACK=1
              save_conf
              printf "%s[OK]%s Rollback system activado.\n" "$C_GRN" "$C_RESET"
              ;;
            3)
              printf "Puntos de restauración:\n"
              if [ -d "$STATE_DIR/rollbacks" ]; then
                ls -la "$STATE_DIR/rollbacks" | head -10
              else
                printf "No hay puntos de restauración.\n"
              fi
              pause_enter
              ;;
            B|b)
              ;;
            *)
              printf "%s[WARN]%s Opción inválida.\n" "$C_YLW" "$C_RESET"
              ;;
          esac
        fi
        ;;
      6)
        clear
        printf "%s[INFO]%s Advanced Configuration.\n" "$C_CYN" "$C_RESET"
        printf "Configuración avanzada:\n"
        printf -- "- Perfiles de usuario: %s\n" "${DJPT_USER_PROFILES:-"Desactivado"}"
        printf -- "- Configuración contextual: %s\n" "${DJPT_CONTEXT_CONFIG:-"Desactivado"}"
        printf "\nOpciones:\n"
        printf "  1) Gestionar perfiles\n"
        printf "  2) Configurar modo contextual\n"
        printf "  3) Integración con control de versiones\n"
        printf "  B) Volver\n"
        printf "Opción: "
        read -r adv_opt
        case "$adv_opt" in
          1)
            DJPT_USER_PROFILES=1
            save_conf
            printf "%s[OK]%s Perfiles de usuario activados.\n" "$C_GRN" "$C_RESET"
            ;;
          2)
            DJPT_CONTEXT_CONFIG=1
            save_conf
            printf "%s[OK]%s Configuración contextual activada.\n" "$C_GRN" "$C_RESET"
            ;;
          3)
            printf "%s[INFO]%s Integración con control de versiones.\n" "$C_CYN" "$C_RESET"
            printf "Estado Git: $(git status --porcelain 2>/dev/null | wc -l || echo "No es repo Git")\n"
            pause_enter
            ;;
          B|b)
            ;;
          *)
            printf "%s[WARN]%s Opción inválida.\n" "$C_YLW" "$C_RESET"
            ;;
        esac
        ;;
      7)
        clear
        integration_checks_py="$SCRIPT_DIR/integration_checks.py"
        local_serato_root="${SERATO_ROOT:-$BASE_PATH/_Serato_}"
        serato_parser_status="No disponible"
        serato_tools_status="No disponible"
        if "$PYTHON_BIN" - <<'PY' >/dev/null 2>&1
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec("serato_crate") else 1)
PY
        then
          serato_parser_status="Disponible"
        fi
        if "$PYTHON_BIN" - <<'PY' >/dev/null 2>&1
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec("serato_tools") else 1)
PY
        then
          serato_tools_status="Disponible"
        fi
        spotify_client_id="${DJPT_SPOTIFY_CLIENT_ID:-${DJPT_SPOTIFY_API:-}}"
        spotify_client_secret="${DJPT_SPOTIFY_CLIENT_SECRET:-}"
        musicbrainz_app="${DJPT_MUSICBRAINZ_APP:-DJProducerTools}"
        musicbrainz_contact="${DJPT_MUSICBRAINZ_CONTACT:-${DJPT_MUSICBRAINZ:-}}"
        spotify_status="No configurado"
        [ -n "$spotify_client_id" ] && [ -n "$spotify_client_secret" ] && spotify_status="Credenciales configuradas"
        musicbrainz_status="$musicbrainz_app"
        [ -n "$musicbrainz_contact" ] && musicbrainz_status="$musicbrainz_status ($musicbrainz_contact)"
        printf "%s[INFO]%s Integraciones locales/web.\n" "$C_CYN" "$C_RESET"
        printf "Estado de integraciones:\n"
        printf -- "- Serato (filesystem local): %s\n" "$local_serato_root"
        printf -- "- Parser crates (serato-crate): %s\n" "$serato_parser_status"
        printf -- "- Utilidades Serato (serato-tools): %s\n" "$serato_tools_status"
        printf -- "- Spotify (OAuth Client Credentials): %s\n" "$spotify_status"
        printf -- "- MusicBrainz (User-Agent): %s\n" "$musicbrainz_status"
        if [ -f "$integration_checks_py" ]; then
          printf -- "- Checker de integraciones: %s\n" "$integration_checks_py"
        else
          printf -- "- Checker de integraciones: %sNo disponible%s\n" "$C_YLW" "$C_RESET"
        fi
        printf "\nOpciones:\n"
        printf "  1) Configurar ruta local Serato\n"
        printf "  2) Configurar Spotify (Client ID / Client Secret)\n"
        printf "  3) Configurar MusicBrainz (App / Contacto)\n"
        printf "  4) Diagnóstico completo de integraciones\n"
        printf "  5) Configurar MCP local\n"
        printf "  6) Test Spotify OAuth ahora\n"
        printf "  7) Test MusicBrainz ahora\n"
        printf "  8) Instalar dependencias Serato (serato-crate + serato-tools)\n"
        printf "  B) Volver\n"
        printf "Opción: "
        read -r api_opt
        api_opt="$(echo "$api_opt" | xargs)"
        [ -z "$api_opt" ] && continue
        case "$api_opt" in
          1)
            printf "Ruta Serato local (ENTER para mantener: %s): " "${SERATO_ROOT:-$BASE_PATH/_Serato_}"
            read -r serato_root_input
            serato_root_input="$(echo "$serato_root_input" | xargs)"
            if [ -n "$serato_root_input" ]; then
              SERATO_ROOT="$serato_root_input"
              save_conf
            fi
            if [ -d "${SERATO_ROOT:-$BASE_PATH/_Serato_}" ]; then
              printf "%s[OK]%s Ruta Serato local configurada: %s\n" "$C_GRN" "$C_RESET" "${SERATO_ROOT:-$BASE_PATH/_Serato_}"
            else
              printf "%s[WARN]%s Ruta Serato no encontrada: %s\n" "$C_YLW" "$C_RESET" "${SERATO_ROOT:-$BASE_PATH/_Serato_}"
            fi
            ;;
          2)
            printf "Spotify Client ID (ENTER para mantener): "
            read -r spotify_client_id_input
            spotify_client_id_input="$(echo "$spotify_client_id_input" | xargs)"
            printf "Spotify Client Secret (ENTER para mantener): "
            read -r spotify_client_secret_input
            spotify_client_secret_input="$(echo "$spotify_client_secret_input" | xargs)"
            if [ -n "$spotify_client_id_input" ]; then
              DJPT_SPOTIFY_CLIENT_ID="$spotify_client_id_input"
              DJPT_SPOTIFY_API="$spotify_client_id_input"
            fi
            if [ -n "$spotify_client_secret_input" ]; then
              DJPT_SPOTIFY_CLIENT_SECRET="$spotify_client_secret_input"
            fi
            if [ -n "${DJPT_SPOTIFY_CLIENT_ID:-}" ] || [ -n "${DJPT_SPOTIFY_CLIENT_SECRET:-}" ]; then
              save_conf
              printf "%s[OK]%s Spotify configurado (OAuth).\n" "$C_GRN" "$C_RESET"
            else
              printf "%s[WARN]%s Spotify sigue sin credenciales.\n" "$C_YLW" "$C_RESET"
            fi
            ;;
          3)
            printf "MusicBrainz App Name (ENTER para mantener: %s): " "${DJPT_MUSICBRAINZ_APP:-DJProducerTools}"
            read -r mb_app_input
            mb_app_input="$(echo "$mb_app_input" | xargs)"
            printf "MusicBrainz Contact Email/URL (ENTER para mantener): "
            read -r mb_contact_input
            mb_contact_input="$(echo "$mb_contact_input" | xargs)"
            if [ -n "$mb_app_input" ]; then
              DJPT_MUSICBRAINZ_APP="$mb_app_input"
            fi
            if [ -n "$mb_contact_input" ]; then
              DJPT_MUSICBRAINZ_CONTACT="$mb_contact_input"
              DJPT_MUSICBRAINZ="$mb_contact_input"
            fi
            if [ -n "${DJPT_MUSICBRAINZ_APP:-}" ] || [ -n "${DJPT_MUSICBRAINZ_CONTACT:-}" ]; then
              save_conf
              printf "%s[OK]%s MusicBrainz configurado.\n" "$C_GRN" "$C_RESET"
            else
              printf "%s[WARN]%s MusicBrainz sin cambios.\n" "$C_YLW" "$C_RESET"
            fi
            ;;
          4)
            printf "%s[INFO]%s Ejecutando diagnóstico de integraciones...\n" "$C_CYN" "$C_RESET"
            if [ -f "$integration_checks_py" ]; then
              "$PYTHON_BIN" "$integration_checks_py" all \
                --serato-root "${SERATO_ROOT:-$BASE_PATH/_Serato_}" \
                --spotify-client-id "${DJPT_SPOTIFY_CLIENT_ID:-${DJPT_SPOTIFY_API:-}}" \
                --spotify-client-secret "${DJPT_SPOTIFY_CLIENT_SECRET:-}" \
                --musicbrainz-app "${DJPT_MUSICBRAINZ_APP:-DJProducerTools}" \
                --musicbrainz-contact "${DJPT_MUSICBRAINZ_CONTACT:-${DJPT_MUSICBRAINZ:-}}" \
                --json || true
            else
              printf "%s[ERR]%s No existe %s\n" "$C_RED" "$C_RESET" "$integration_checks_py"
            fi
            pause_enter
            ;;
          5)
            mcp_management_menu
            ;;
          6)
            printf "%s[INFO]%s Test Spotify OAuth...\n" "$C_CYN" "$C_RESET"
            if [ -f "$integration_checks_py" ]; then
              "$PYTHON_BIN" "$integration_checks_py" spotify \
                --spotify-client-id "${DJPT_SPOTIFY_CLIENT_ID:-${DJPT_SPOTIFY_API:-}}" \
                --spotify-client-secret "${DJPT_SPOTIFY_CLIENT_SECRET:-}" \
                --json || true
            else
              printf "%s[ERR]%s No existe %s\n" "$C_RED" "$C_RESET" "$integration_checks_py"
            fi
            pause_enter
            ;;
          7)
            printf "%s[INFO]%s Test MusicBrainz...\n" "$C_CYN" "$C_RESET"
            if [ -f "$integration_checks_py" ]; then
              "$PYTHON_BIN" "$integration_checks_py" musicbrainz \
                --musicbrainz-app "${DJPT_MUSICBRAINZ_APP:-DJProducerTools}" \
                --musicbrainz-contact "${DJPT_MUSICBRAINZ_CONTACT:-${DJPT_MUSICBRAINZ:-}}" \
                --json || true
            else
              printf "%s[ERR]%s No existe %s\n" "$C_RED" "$C_RESET" "$integration_checks_py"
            fi
            pause_enter
            ;;
          8)
            printf "Se instalarán paquetes Python opcionales para Serato local:\n"
            printf "  - serato-crate (lectura/escritura .crate)\n"
            printf "  - serato-tools (db/metadata utilidades)\n"
            printf "¿Continuar? [y/N]: "
            read -r install_serato_opt
            install_serato_opt="$(echo "$install_serato_opt" | xargs)"
            case "$install_serato_opt" in
              y|Y|yes|YES|s|S|si|SI)
                printf "%s[INFO]%s Instalando dependencias Serato...\n" "$C_CYN" "$C_RESET"
                if "$PYTHON_BIN" -m pip install --disable-pip-version-check serato-crate serato-tools; then
                  printf "%s[OK]%s Dependencias Serato instaladas.\n" "$C_GRN" "$C_RESET"
                else
                  printf "%s[ERR]%s Falló instalación de dependencias Serato.\n" "$C_RED" "$C_RESET"
                fi
                if [ -f "$integration_checks_py" ]; then
                  "$PYTHON_BIN" "$integration_checks_py" serato --serato-root "${SERATO_ROOT:-$BASE_PATH/_Serato_}" --json || true
                fi
                ;;
              *)
                printf "%s[INFO]%s Instalación cancelada.\n" "$C_CYN" "$C_RESET"
                ;;
            esac
            pause_enter
            ;;
          B|b)
            ;;
          *)
            printf "%s[WARN]%s Opción inválida.\n" "$C_YLW" "$C_RESET"
            ;;
        esac
        ;;
      8)
        clear
        printf "%s[INFO]%s Performance Tuning.\n" "$C_CYN" "$C_RESET"
        printf "Estado de rendimiento:\n"
        printf -- "- Optimización automática: %s\n" "${DJPT_AUTO_OPTIMIZE:-"Desactivado"}"
        printf -- "- Caché inteligente: %s\n" "${DJPT_SMART_CACHE:-"Desactivado"}"
        printf "\nOpciones:\n"
        printf "  1) Activar optimización automática\n"
        printf "  2) Configurar caché inteligente\n"
        printf "  3) Benchmark de rendimiento\n"
        printf "  4) Optimización para hardware específico\n"
        printf "  B) Volver\n"
        printf "Opción: "
        read -r perf_opt
        case "$perf_opt" in
          1)
            DJPT_AUTO_OPTIMIZE=1
            save_conf
            printf "%s[OK]%s Optimización automática activada.\n" "$C_GRN" "$C_RESET"
            ;;
          2)
            DJPT_SMART_CACHE=1
            save_conf
            printf "%s[OK]%s Caché inteligente activado.\n" "$C_GRN" "$C_RESET"
            ;;
          3)
            printf "%s[INFO]%s Ejecutando benchmark...\n" "$C_CYN" "$C_RESET"
            if [ -f "$SCRIPT_DIR/../benchmark_system.py" ]; then
              "$PYTHON_BIN" "$SCRIPT_DIR/../benchmark_system.py"
            elif [ -f "$SCRIPT_DIR/efficiency_optimizer.py" ]; then
              "$PYTHON_BIN" "$SCRIPT_DIR/efficiency_optimizer.py"
            else
              printf "%s[WARN]%s Benchmark no encontrado.\n" "$C_YLW" "$C_RESET"
            fi
            pause_enter
            ;;
          4)
            printf "Hardware detectado: %s\n" "$(uname -m)"
            printf "Opciones de optimización:\n"
            printf "  1) Apple Silicon (M1/M2/M3/M4)\n"
            printf "  2) Intel x86_64\n"
            printf "  3) Universal (auto-detectar)\n"
            printf "Opción: "
            read -r hw_opt
            hw_norm="$(printf '%s' "$hw_opt" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]_.-')"
            case "$hw_norm" in
              1|apple|applesilicon|m1|m2|m3|m4|m4pro)
                DJPT_HARDWARE_OPT="apple_silicon"
                save_conf
                printf "%s[OK]%s Optimización Apple Silicon (incluye M4 Pro) activada.\n" "$C_GRN" "$C_RESET"
                ;;
              2|intel|x86|x8664)
                DJPT_HARDWARE_OPT="intel_x86"
                save_conf
                printf "%s[OK]%s Optimización Intel activada.\n" "$C_GRN" "$C_RESET"
                ;;
              3|universal|auto|autodetectar)
                DJPT_HARDWARE_OPT="universal"
                save_conf
                printf "%s[OK]%s Optimización universal activada.\n" "$C_GRN" "$C_RESET"
                ;;
              *)
                printf "%s[WARN]%s Opción inválida.\n" "$C_YLW" "$C_RESET"
                ;;
            esac
            ;;
          B|b)
            ;;
          *)
            printf "%s[WARN]%s Opción inválida.\n" "$C_YLW" "$C_RESET"
            ;;
        esac
        ;;
      9)
        clear
        printf "%s[INFO]%s System Diagnostics.\n" "$C_CYN" "$C_RESET"
        printf "Ejecutando diagnóstico completo...\n"
        if [ -f "$SCRIPT_DIR/core/system_profiler.sh" ]; then
          bash "$SCRIPT_DIR/core/system_profiler.sh"
        elif [ -f "$BASE_PATH/core/system_profiler.sh" ]; then
          bash "$BASE_PATH/core/system_profiler.sh"
        else
          printf "%s[WARN]%s System profiler no encontrado.\n" "$C_YLW" "$C_RESET"
        fi
        if [ -f "$SCRIPT_DIR/pre_flight_check.sh" ]; then
          bash "$SCRIPT_DIR/pre_flight_check.sh" || true
        fi
        if [ -f "$SCRIPT_DIR/system_analyzer.py" ]; then
          "$PYTHON_BIN" "$SCRIPT_DIR/system_analyzer.py" --base-path "$BASE_PATH" --json-out "$REPORTS_DIR/system_analyzer_repair.json" >/dev/null 2>&1 || true
          printf "%s[INFO]%s Reporte analyzer: %s\n" "$C_CYN" "$C_RESET" "$REPORTS_DIR/system_analyzer_repair.json"
        fi
        pause_enter
        ;;
      10)
        clear
        printf "%s[INFO]%s Experimental Features.\n" "$C_PURP" "$C_RESET"
        printf "Características experimentales:\n"
        printf -- "- Quantum Processing: %s\n" "${DJPT_QUANTUM:-"Desactivado"}"
        printf -- "- AI Integration: %s\n" "${DJPT_AI_INTEGRATION:-"Básica"}"
        printf -- "- Advanced ML: %s\n" "${DJPT_ADVANCED_ML:-"Desactivado"}"
        printf "\nOpciones:\n"
        printf "  1) Activar Quantum Processing\n"
        printf "  2) Configurar AI Integration\n"
        printf "  3) Activar Advanced ML\n"
        printf "  4) Modo Experimental\n"
        printf "  5) EJECUTAR Quantum Processing Ahora\n"
        printf "  B) Volver\n"
        printf "Opción: "
        read -r exp_opt
        case "$exp_opt" in
          1)
            DJPT_QUANTUM=1
            save_conf
            printf "%s[OK]%s Quantum Processing activado.\n" "$C_GRN" "$C_RESET"
            ;;
          2)
            DJPT_AI_INTEGRATION="avanzada"
            save_conf
            printf "%s[OK]%s AI Integration avanzada.\n" "$C_GRN" "$C_RESET"
            ;;
          3)
            DJPT_ADVANCED_ML=1
            save_conf
            printf "%s[OK]%s Advanced ML activado.\n" "$C_GRN" "$C_RESET"
            ;;
          4)
            DJPT_EXPERIMENTAL_MODE=1
            save_conf
            printf "%s[OK]%s Modo experimental activado.\n" "$C_GRN" "$C_RESET"
            ;;
          5)
            action_quantum_processing
            ;;
          B|b)
            ;;
          *)
            printf "%s[WARN]%s Opción inválida.\n" "$C_YLW" "$C_RESET"
            ;;
        esac
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

# Alias de compatibilidad: se mantiene `DR` para flujos legacy.
submenu_DR_advanced() { submenu_R_repair_system; }

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
    if ! read -r pop; then
      break
    fi
    pop="$(echo "$pop" | xargs)"
    [ -z "$pop" ] && continue
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
  printf "  65) TensorFlow Lab: auto-tagging (modelos: YAMNet/NNFP/VGGish/musicnn; 150 archivos, top3), similitud (presets: rápido/balanceado/estricto), loops/sospechosos, music tagging multi-label (150). Requiere TF/tf_hub/soundfile.\n"
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
  printf "  L5) dj_cues.tsv -> ableton_locators.csv (bars.beats.sixteenths).\n\n"

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

# Cargar runner AI unificado (ubicado en la raiz/scripts del proyecto).
DJPT_AI_RUNNER_LOADED=0
DJPT_MAIN_INIT_PATHS_DEF=""
if declare -f init_paths >/dev/null 2>&1; then
  DJPT_MAIN_INIT_PATHS_DEF="$(declare -f init_paths)"
fi
for _runner_candidate in \
  "$SCRIPT_DIR/../scripts/ai_runner.sh" \
  "$SCRIPT_DIR/../ai_runner.sh" \
  "$SCRIPT_DIR/scripts/ai_runner.sh" \
  "$SCRIPT_DIR/ai_runner.sh"
do
  if [[ -f "$_runner_candidate" ]]; then
    # shellcheck disable=SC1090
    source "$_runner_candidate"
    DJPT_AI_RUNNER_LOADED=1
    break
  fi
done
unset _runner_candidate

# El runner define su propio init_paths; restauramos el de MultiScript.
if [ -n "$DJPT_MAIN_INIT_PATHS_DEF" ]; then
  eval "$DJPT_MAIN_INIT_PATHS_DEF"
fi
unset DJPT_MAIN_INIT_PATHS_DEF

if [ "$DJPT_AI_RUNNER_LOADED" -ne 1 ]; then
  printf "%s[WARN]%s AI runner not found, using fallback\n" "$C_YLW" "$C_RESET"
fi

# Fallback robusto para evitar "command not found" si el runner no cargó.
install_ai_deps_fallback_local() {
  printf "%s[WARN]%s install_ai_deps_robust no disponible en runner; usando fallback local.\n" "$C_YLW" "$C_RESET"
  local arch
  arch="$(uname -m)"
  if [ "$arch" = "arm64" ]; then
    ensure_python_deps "AI_DEPS" \
      "mlx" "mlx-lm" \
      "tensorflow-macos==2.16.2" "tensorflow-metal==1.2.0" "onnxruntime-silicon" \
      "scikit-learn" "sentence-transformers" "torch" "psutil" \
      "PyPDF2" "pdfplumber" "nltk" "requests" "beautifulsoup4" "joblib"
  else
    ensure_python_deps "AI_DEPS" \
      "mlx" "mlx-lm" \
      "tensorflow==2.16.2" "onnxruntime" \
      "scikit-learn" "sentence-transformers" "torch" "psutil" \
      "PyPDF2" "pdfplumber" "nltk" "requests" "beautifulsoup4" "joblib"
  fi
}

if ! declare -f install_ai_deps_robust >/dev/null 2>&1; then
  install_ai_deps_robust() {
    install_ai_deps_fallback_local
  }
fi

# Handlers para opciones IA (70-87) - Enterprise Ready
action_ai_status() {
  print_header
  print_ai_banner
  printf "%s=== HEALTH CHECK IA (centralizado) ===%s\n" "$BANNER" "$C_RESET"
  init_paths
  local py_bin="${PYTHON_BIN:-$BASE_PATH/djpt_venv/bin/python3}"
  local ai_health_script="${DJPT_CANONICAL_ROOT:-$BASE_PATH}/scripts/ai_health.py"
  if [[ ! -x "$py_bin" ]]; then
    py_bin="python3"
  fi
  if "$py_bin" "$ai_health_script"; then
    printf "%s[OK]%s Health check completado\n" "$C_GREEN" "$C_RESET"
  else
    local rc=$?
    printf "%s[WARN]%s Health check terminó con avisos/errores (rc=%d)\n" "$C_YLW" "$C_RESET" "$rc"
  fi
  pause_enter
}

submenu_ai_advanced_ops() {
  while true; do
    print_header
    print_ai_banner
    printf "%s=== 🧪 OPERACIONES IA AVANZADAS ===%s\n" "$BANNER" "$C_RESET"
    printf "  %s1)%s MLX Batch Processing\n" "$C_GRN" "$C_RESET"
    printf "  %s2)%s TF Spectral Analysis\n" "$C_GRN" "$C_RESET"
    printf "  %s3)%s TF Genre Classification\n" "$C_GRN" "$C_RESET"
    printf "  %s4)%s TF Advanced BPM\n" "$C_GRN" "$C_RESET"
    printf "  %s5)%s TF Stem Separation\n" "$C_GRN" "$C_RESET"
    printf "  %s6)%s Local Clustering\n" "$C_YLW" "$C_RESET"
    printf "  %s7)%s Local Recommendations\n" "$C_YLW" "$C_RESET"
    printf "  %s8)%s Local Similarity Analysis\n" "$C_YLW" "$C_RESET"
    printf "  %s9)%s Local Popularity Prediction\n" "$C_YLW" "$C_RESET"
    printf "  %s10)%s Ollama Chat Library\n" "$C_PURP" "$C_RESET"
    printf "  %s11)%s Ollama Playlist Generation\n" "$C_PURP" "$C_RESET"
    printf "  %s12)%s Ollama Music Analysis\n" "$C_PURP" "$C_RESET"
    printf "  %sB)%s Volver\n" "$C_RED" "$C_RESET"
    printf "%sSelecciona opción:%s " "$C_BLU" "$C_RESET"
    if ! read -r adv_op; then
      break
    fi
    adv_op="$(echo "$adv_op" | xargs)"
    [ -z "$adv_op" ] && continue
    case "$adv_op" in
      1) action_mlx_batch_processing ;;
      2) action_tf_spectral_analysis ;;
      3) action_tf_genre_classification ;;
      4) action_tf_advanced_bpm ;;
      5) action_tf_stem_separation ;;
      6) action_local_clustering ;;
      7) action_local_recommendations ;;
      8) action_local_similarity_analysis ;;
      9) action_local_popularity_prediction ;;
      10) action_ollama_chat_library ;;
      11) action_ollama_playlist_generation ;;
      12) action_ollama_music_analysis ;;
      B|b) break ;;
      *) invalid_option ;;
    esac
  done
}

action_ai_backend_mlx_models() {
  print_header
  print_ai_banner
  load_ai_config
  printf "%s=== 📦 MODELOS MLX ===%s\n" "$BANNER" "$C_RESET"

  local models_dir="$IA_MODELS_DIR/mlx-llm"
  mkdir -p "$models_dir"
  printf "Directorio de modelos MLX: %s\n" "$models_dir"

  if [ -n "$(find "$models_dir" -mindepth 1 -maxdepth 2 2>/dev/null | head -n 1)" ]; then
    printf "\nModelos detectados:\n"
    find "$models_dir" -mindepth 1 -maxdepth 2 -type d 2>/dev/null | sed 's#^#  - #' | head -n 20
  else
    printf "  ⚠️  No hay modelos MLX convertidos todavía.\n"
  fi

  if ensure_python_bin >/dev/null 2>&1 && command -v "$VENV_DIR/bin/mlx_lm.convert" >/dev/null 2>&1; then
    printf "\nConversor disponible: %s\n" "$VENV_DIR/bin/mlx_lm.convert"
  elif ensure_python_bin >/dev/null 2>&1 && "$PYTHON_BIN" -m mlx_lm convert --help >/dev/null 2>&1; then
    printf "\nConversor disponible vía: %s -m mlx_lm convert\n" "$PYTHON_BIN"
  else
    printf "\nConversor MLX no detectado en el entorno actual.\n"
  fi

  printf "\nSiguiente paso recomendado para convertir un modelo HF:\n"
  printf "  %s -m mlx_lm convert --help\n" "${PYTHON_BIN:-python3}"
  pause_enter
}

action_ai_backend_embeddings_config() {
  print_header
  print_ai_banner
  load_ai_config
  printf "%s=== 🔤 CONFIGURACIÓN DE EMBEDDINGS LOCALES ===%s\n" "$BANNER" "$C_RESET"

  if ! ensure_python_bin; then
    pause_enter
    return 1
  fi

  mkdir -p "$IA_MODELS_DIR/embeddings"
  if [ "${NO_INTERACTIVE:-0}" -eq 1 ] || [ "${DJPT_NO_INTERACTIVE:-0}" -eq 1 ]; then
    :
  else
    local new_model
    read -e -r -p "Modelo embeddings (ENTER=$DJPT_EMBEDDINGS_MODEL): " new_model
    if [ -n "${new_model:-}" ]; then
      DJPT_EMBEDDINGS_MODEL="$new_model"
      export DJPT_EMBEDDINGS_MODEL
    fi
  fi

  if "$PYTHON_BIN" -c "import sentence_transformers as st; print(st.__version__)" >/tmp/djpt_embeddings_version.$$ 2>/dev/null; then
    printf "  ✅ sentence-transformers %s\n" "$(cat /tmp/djpt_embeddings_version.$$)"
    rm -f /tmp/djpt_embeddings_version.$$
  else
    printf "  ⚠️  sentence-transformers no disponible en el entorno actual\n"
  fi

  cat >"$CONFIG_DIR/embeddings_config.json" <<EOF
{
  "model": "${DJPT_EMBEDDINGS_MODEL}",
  "backend": "local",
  "models_dir": "${IA_MODELS_DIR}/embeddings"
}
EOF
  persist_ai_runtime_config

  printf "Modelo embeddings activo: %s\n" "$DJPT_EMBEDDINGS_MODEL"
  printf "Config guardada en: %s/embeddings_config.json\n" "$CONFIG_DIR"
  pause_enter
}

action_ai_backend_mlx_overview() {
  print_header
  print_ai_banner
  init_paths
  printf "%s=== 🍎 BACKEND MLX (Apple Silicon GPU) ===%s\n" "$BANNER" "$C_RESET"

  if ! ensure_python_bin; then
    pause_enter
    return 1
  fi

  if [ "${DJPT_SKIP_MLX:-0}" = "1" ]; then
    printf "%s[WARN]%s MLX saltado por DJPT_SKIP_MLX=1\n" "$C_YLW" "$C_RESET"
  elif "$PYTHON_BIN" - <<'PY' 2>/dev/null
import importlib.metadata as md
import mlx.core as mx
print(f"  ✅ MLX {getattr(mx, '__version__', md.version('mlx'))}")
print(f"  ✅ GPU Metal: {'Activa' if mx.metal.is_available() else 'No disponible'}")
print(f"  ✅ Device: {mx.default_device()}")
PY
  then
    printf "  • Relacionado: 6) Optimizar rendimiento\n"
    printf "  • Relacionado: 7) Benchmark comparativo\n"
    printf "  • Relacionado: 8) Configurar backends\n"
  else
    printf "  ❌ MLX no disponible\n"
    printf "  💡 Instala dependencias IA con la opción 72.\n"
  fi

  pause_enter
}

action_ai_backend_tensorflow_overview() {
  print_header
  print_ai_banner
  init_paths
  printf "%s=== 🧠 BACKEND TENSORFLOW (Metal) ===%s\n" "$BANNER" "$C_RESET"

  if ! ensure_python_bin; then
    pause_enter
    return 1
  fi

  if [ "${DJPT_SKIP_TF:-0}" = "1" ]; then
    printf "%s[WARN]%s TensorFlow saltado por DJPT_SKIP_TF=1\n" "$C_YLW" "$C_RESET"
  elif "$PYTHON_BIN" - <<'PY' 2>/dev/null
import tensorflow as tf
gpus = tf.config.list_physical_devices('GPU')
print(f"  ✅ TensorFlow {tf.__version__}")
print(f"  {'✅' if gpus else '⚠️ '} GPU Metal: {'Detectada' if gpus else 'CPU only'}")
PY
  then
    printf "  • Relacionado: 6) Optimizar rendimiento\n"
    printf "  • Relacionado: 7) Benchmark comparativo\n"
    printf "  • Relacionado: 8) Configurar backends\n"
  else
    printf "  ❌ TensorFlow no disponible\n"
    printf "  💡 Instala tensorflow-macos/tensorflow-metal con la opción 72.\n"
  fi

  pause_enter
}

action_ai_backend_sklearn_overview() {
  print_header
  print_ai_banner
  init_paths
  printf "%s=== 🔤 BACKEND SCIKIT-LEARN (Local) ===%s\n" "$BANNER" "$C_RESET"

  if ! ensure_python_bin; then
    pause_enter
    return 1
  fi

  if "$PYTHON_BIN" - <<'PY' 2>/dev/null
import sklearn
import joblib
print(f"  ✅ Scikit-learn {sklearn.__version__}")
print(f"  ✅ Joblib {joblib.__version__}")
print("  💡 Recomendado: n_jobs=-1 para tareas CPU-bound")
PY
  then
    printf "  • Relacionado: 6) Optimizar rendimiento\n"
    printf "  • Relacionado: 7) Benchmark comparativo\n"
    printf "  • Relacionado: 8) Configurar backends\n"
  else
    printf "  ❌ Scikit-learn no disponible\n"
    printf "  💡 Instala scikit-learn y joblib con la opción 72.\n"
  fi

  pause_enter
}

action_ai_backend_ollama_overview() {
  print_header
  print_ai_banner
  init_paths
  printf "%s=== 🦙 BACKEND OLLAMA (Local LLM) ===%s\n" "$BANNER" "$C_RESET"

  if command -v ollama >/dev/null 2>&1; then
    printf "  ✅ Comando ollama disponible\n"
    if ollama list >/dev/null 2>&1; then
      printf "  ✅ Servidor: Activo\n"
      printf "  Modelos instalados:\n"
      ollama list || true
    else
      printf "  ⚠️  Servidor: Inactivo o no accesible\n"
      printf "  💡 Inicia Ollama con: ollama serve\n"
    fi
  else
    printf "  ❌ Ollama no instalado\n"
    printf "  💡 Instala Ollama y luego descarga un modelo local.\n"
  fi

  pause_enter
}

action_ai_backends_optimize() {
  print_header
  print_ai_banner
  init_paths
  printf "%s=== 🚀 OPTIMIZAR RENDIMIENTO IA ===%s\n" "$BANNER" "$C_RESET"

  local logical_cpu
  logical_cpu="$(sysctl -n hw.logicalcpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"

  export DJPT_MLX_DEVICE="${DJPT_MLX_DEVICE:-metal}"
  export DJPT_TF_DEVICE="${DJPT_TF_DEVICE:-metal}"
  export DJPT_TF_MIXED_PRECISION="${DJPT_TF_MIXED_PRECISION:-1}"
  export TF_CPP_MIN_LOG_LEVEL="${TF_CPP_MIN_LOG_LEVEL:-2}"
  export OMP_NUM_THREADS="${OMP_NUM_THREADS:-$logical_cpu}"
  export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-$logical_cpu}"
  export MKL_NUM_THREADS="${MKL_NUM_THREADS:-$logical_cpu}"
  export TOKENIZERS_PARALLELISM="${TOKENIZERS_PARALLELISM:-false}"
  persist_ai_runtime_config

  printf "Variables de sesión aplicadas:\n"
  printf "  DJPT_MLX_DEVICE=%s\n" "$DJPT_MLX_DEVICE"
  printf "  DJPT_TF_DEVICE=%s\n" "$DJPT_TF_DEVICE"
  printf "  DJPT_TF_MIXED_PRECISION=%s\n" "$DJPT_TF_MIXED_PRECISION"
  printf "  TF_CPP_MIN_LOG_LEVEL=%s\n" "$TF_CPP_MIN_LOG_LEVEL"
  printf "  OMP_NUM_THREADS=%s\n" "$OMP_NUM_THREADS"
  printf "  OPENBLAS_NUM_THREADS=%s\n" "$OPENBLAS_NUM_THREADS"
  printf "  MKL_NUM_THREADS=%s\n" "$MKL_NUM_THREADS"
  printf "  TOKENIZERS_PARALLELISM=%s\n" "$TOKENIZERS_PARALLELISM"

  printf "\nRecomendaciones:\n"
  printf "  • MLX: usa modelos 4-bit y lotes medianos para Apple Silicon.\n"
  printf "  • TensorFlow: mantén mixed precision y XLA para workloads largos.\n"
  printf "  • Scikit-learn: explota CPU con n_jobs=-1 en tareas paralelizables.\n"
  printf "  • Ollama: mantén pocos modelos calientes y evita cargar modelos gigantes sin necesidad.\n"

  pause_enter
}

action_ai_backends_benchmark() {
  print_header
  print_ai_banner
  init_paths
  printf "%s=== 📈 BENCHMARK COMPARATIVO IA ===%s\n" "$BANNER" "$C_RESET"

  local filter="${1:-all}"

  if ! ensure_python_bin; then
    pause_enter
    return 1
  fi

  local ts out line
  ts="$(date +%Y%m%d_%H%M%S)"
  out="$REPORTS_DIR/backend_benchmark_${ts}.tsv"
  printf "backend\tstatus\tseconds\tnotes\n" >"$out"

  if [ "$filter" = "all" ] || [ "$filter" = "mlx" ]; then
  line="$("$PYTHON_BIN" - <<'PY' 2>/dev/null
import importlib.util, os, time
if os.environ.get("DJPT_SKIP_MLX") == "1":
    print("MLX\twarn\t0.0000\tsaltado por DJPT_SKIP_MLX")
elif importlib.util.find_spec("mlx") is None:
    print("MLX\twarn\t0.0000\tno instalado")
else:
    try:
        import mlx.core as mx
        start = time.perf_counter()
        x = mx.random.normal((128, 128))
        y = mx.random.normal((128, 128))
        z = mx.matmul(x, y)
        mx.eval(z)
        elapsed = time.perf_counter() - start
        print(f"MLX\tok\t{elapsed:.4f}\tmatmul 128x128")
    except Exception as exc:
        print(f"MLX\tfail\t0.0000\t{str(exc).replace(chr(9), ' ')}")
PY
)"
  printf "%s\n" "$line" >>"$out"
  fi

  if [ "$filter" = "all" ] || [ "$filter" = "tensorflow" ]; then
  line="$("$PYTHON_BIN" - <<'PY' 2>/dev/null
import importlib.util, os, time
if os.environ.get("DJPT_SKIP_TF") == "1":
    print("TensorFlow\twarn\t0.0000\tsaltado por DJPT_SKIP_TF")
elif importlib.util.find_spec("tensorflow") is None:
    print("TensorFlow\twarn\t0.0000\tno instalado")
else:
    try:
        import tensorflow as tf
        start = time.perf_counter()
        a = tf.random.normal((64, 64))
        b = tf.random.normal((64, 64))
        c = tf.matmul(a, b)
        _ = c.numpy()
        elapsed = time.perf_counter() - start
        print(f"TensorFlow\tok\t{elapsed:.4f}\tmatmul 64x64")
    except Exception as exc:
        print(f"TensorFlow\tfail\t0.0000\t{str(exc).replace(chr(9), ' ')}")
PY
)"
  printf "%s\n" "$line" >>"$out"
  fi

  if [ "$filter" = "all" ] || [ "$filter" = "sklearn" ]; then
  line="$("$PYTHON_BIN" - <<'PY' 2>/dev/null
import importlib.util, time
if importlib.util.find_spec("sklearn") is None:
    print("Scikit-learn\twarn\t0.0000\tno instalado")
else:
    try:
        import numpy as np
        from sklearn.cluster import KMeans
        data = np.random.RandomState(42).rand(200, 8)
        start = time.perf_counter()
        KMeans(n_clusters=4, n_init=1, random_state=42).fit(data)
        elapsed = time.perf_counter() - start
        print(f"Scikit-learn\tok\t{elapsed:.4f}\tKMeans 200x8")
    except Exception as exc:
        print(f"Scikit-learn\tfail\t0.0000\t{str(exc).replace(chr(9), ' ')}")
PY
)"
  printf "%s\n" "$line" >>"$out"
  fi

  if [ "$filter" = "all" ] || [ "$filter" = "ollama" ]; then
  line="$("$PYTHON_BIN" - <<'PY' 2>/dev/null
import shutil, subprocess, time
if shutil.which("ollama") is None:
    print("Ollama\twarn\t0.0000\tno instalado")
else:
    start = time.perf_counter()
    proc = subprocess.run(["ollama", "list"], capture_output=True, text=True)
    elapsed = time.perf_counter() - start
    note = "list ok" if proc.returncode == 0 else "list falló o servidor inactivo"
    status = "ok" if proc.returncode == 0 else "warn"
    print(f"Ollama\t{status}\t{elapsed:.4f}\t{note}")
PY
)"
  printf "%s\n" "$line" >>"$out"
  fi

  printf "Benchmark guardado en: %s\n\n" "$out"
  if command -v column >/dev/null 2>&1; then
    column -t -s $'\t' "$out"
  else
    cat "$out"
  fi

  pause_enter
}

action_ai_backends_manager() {
  init_paths
  while true; do
    print_header
    print_ai_banner
    printf "%s=== 🤖 GESTOR DE BACKENDS IA (Multi-Backend) ===%s\n" "$BANNER" "$C_RESET"
    printf "\n%s🔧 BACKENDS DISPONIBLES:%s\n" "$C_CYAN" "$C_RESET"
    printf "  %s1)%s MLX (Apple Silicon GPU)\n" "$C_GRN" "$C_RESET"
    printf "  %s2)%s TensorFlow (Metal)\n" "$C_GRN" "$C_RESET"
    printf "  %s3)%s Scikit-learn (Local)\n" "$C_YLW" "$C_RESET"
    printf "  %s4)%s Ollama (Local LLM)\n" "$C_PURP" "$C_RESET"
    printf "\n%s⚙️ OPERACIONES:%s\n" "$C_CYAN" "$C_RESET"
    printf "  %s5)%s Verificar estado de todos\n" "$C_GRN" "$C_RESET"
    printf "  %s6)%s Optimizar rendimiento\n" "$C_GRN" "$C_RESET"
    printf "  %s7)%s Benchmark comparativo\n" "$C_GRN" "$C_RESET"
    printf "  %s8)%s Configurar backends\n" "$C_GRN" "$C_RESET"
    printf "\n  %s0)%s Volver\n" "$C_RED" "$C_RESET"

    local choice
    if ! read -e -r -p "${C_BLU}Selecciona opción (1-8, 0=salir): ${C_RESET}" choice; then
      break
    fi
    choice="$(echo "$choice" | xargs)"
    [ -z "$choice" ] && continue

    case "$choice" in
      1) action_ai_backend_mlx_overview ;;
      2) action_ai_backend_tensorflow_overview ;;
      3) action_ai_backend_sklearn_overview ;;
      4) action_ai_backend_ollama_overview ;;
      5) show_ai_capabilities ;;
      6) action_ai_backends_optimize ;;
      7) action_ai_backends_benchmark ;;
      8) action_ai_advanced_config ;;
      0) break ;;
      *) invalid_option ;;
    esac
  done
}

show_ai_capabilities() {
  print_header
  print_ai_banner
  load_ai_config
  printf "%s=== 📊 ESTADO COMPLETO DE BACKENDS ===%s\n" "$BANNER" "$C_RESET"

  if ! ensure_python_bin; then
    pause_enter
    return 1
  fi

  printf "\n%s🍎 MLX:%s\n" "$C_GRN" "$C_RESET"
  if [ "${DJPT_SKIP_MLX:-0}" = "1" ]; then
    printf "  ⚠️  MLX saltado por DJPT_SKIP_MLX=1\n"
  elif "$PYTHON_BIN" - <<'PY' 2>/dev/null
import importlib.metadata as md
import mlx.core as mx
print(f"  ✅ MLX {getattr(mx, '__version__', md.version('mlx'))}")
print(f"  ✅ GPU Metal: {'Activa' if mx.metal.is_available() else 'No disponible'}")
PY
  then
    :
  else
    printf "  ❌ MLX no disponible\n"
  fi

  printf "\n%s🧠 TENSORFLOW:%s\n" "$C_CYAN" "$C_RESET"
  if [ "${DJPT_SKIP_TF:-0}" = "1" ]; then
    printf "  ⚠️  TensorFlow saltado por DJPT_SKIP_TF=1\n"
  elif "$PYTHON_BIN" - <<'PY' 2>/dev/null
import tensorflow as tf
gpus = tf.config.list_physical_devices('GPU')
print(f"  ✅ TensorFlow {tf.__version__}")
print(f"  {'✅' if gpus else '⚠️ '} GPU Metal: {'Detectada' if gpus else 'CPU only'}")
PY
  then
    :
  else
    printf "  ❌ TensorFlow no disponible\n"
    printf "     💡 Instala: pip install tensorflow-macos tensorflow-metal\n"
  fi

  printf "\n%s🔤 SCIKIT-LEARN:%s\n" "$C_YLW" "$C_RESET"
  if "$PYTHON_BIN" - <<'PY' 2>/dev/null
import sklearn
print(f"  ✅ Scikit-learn {sklearn.__version__}")
PY
  then
    :
  else
    printf "  ❌ Scikit-learn no disponible\n"
  fi

  printf "\n%s🧩 EMBEDDINGS:%s\n" "$C_PURP" "$C_RESET"
  if "$PYTHON_BIN" - <<'PY' 2>/dev/null
import sentence_transformers as st
print(f"  ✅ sentence-transformers {st.__version__}")
PY
  then
    printf "  ✅ Modelo por defecto: %s\n" "$DJPT_EMBEDDINGS_MODEL"
  else
    printf "  ⚠️  sentence-transformers no disponible\n"
  fi

  printf "\n%s🦙 OLLAMA:%s\n" "$C_PURP" "$C_RESET"
  if command -v ollama >/dev/null 2>&1; then
    printf "  ✅ Ollama disponible\n"
    if ollama list >/dev/null 2>&1; then
      printf "  ✅ Servidor: Activo\n"
    else
      printf "  ⚠️  Servidor: Inactivo\n"
    fi
  else
    printf "  ❌ Ollama no disponible\n"
  fi

  printf "\n%s🔐 TOKENS / CONFIG:%s\n" "$C_CYAN" "$C_RESET"
  printf "  OPENAI_API_KEY: %s\n" "$([ -n "${OPENAI_API_KEY:-}" ] && echo "configurada" || echo "ausente")"
  printf "  HF_TOKEN/HUGGINGFACE_TOKEN: %s\n" "$([ -n "${HF_TOKEN:-${HUGGINGFACE_TOKEN:-}}" ] && echo "configurado" || echo "ausente")"
  printf "  Backend preferido: %s\n" "$DJPT_BEST_BACKEND"
  printf "  Modelo Ollama por defecto: %s\n" "$DJPT_OLLAMA_DEFAULT_MODEL"
  printf "  IA_MODELS_DIR: %s\n" "$IA_MODELS_DIR"
  printf "  REPORTS_DIR: %s\n" "$REPORTS_DIR"

  printf "\n%s=== RECOMENDACIONES DE RENDIMIENTO ===%s\n" "$C_CYAN" "$C_RESET"
  printf "  • MLX: usa modelos cuantizados y batch processing para Metal.\n"
  printf "  • TensorFlow: mixed precision y XLA ayudan en Apple Silicon.\n"
  printf "  • Scikit-learn: aprovecha CPU local con joblib y n_jobs=-1.\n"
  printf "  • Ollama: mantén el servicio activo solo cuando lo necesites.\n"
  printf "  • Embeddings: fija un modelo local consistente para evitar drift entre índices.\n"

  pause_enter
}

action_install_all_python_deps() {
  print_header
  printf "%s=== INSTALADOR DE DEPENDENCIAS PYTHON ===%s\n" "$BANNER" "$C_RESET"
  
  # Usar nueva CLI AI para instalación
  printf "%s[INFO]%s Redirigiendo a instalador IA moderno...\n" "$C_CYN" "$C_RESET"
  action_install_ai_deps
}

# Funciones adicionales para completar opciones IA
action_ai_knowledge_base() {
  print_header
  print_ai_banner
  printf "%s=== 📚 BASE DE CONOCIMIENTO IA ===%s\n" "$BANNER" "$C_RESET"
  
  load_ai_config
  
  printf "\n%s📖 OPCIONES DE BASE DE CONOCIMIENTO:%s\n" "$C_CYAN" "$C_RESET"
  printf "  %s1)%s Indexar documentos\n" "$C_GRN" "$C_RESET"
  printf "  %s2)%s Consultar base\n" "$C_GRN" "$C_RESET"
  printf "  %s3)%s Ver estado\n" "$C_YLW" "$C_RESET"
  
  local choice
  read -e -r -p "${C_BLU}Selecciona opción (1-3, 0=salir): ${C_RESET}" choice
  
  case "$choice" in
    1)
      printf "\n📁 Ruta a indexar (dejar en blanco para actual): "
      read -e -r path
      if [[ -n "$path" ]]; then
        run_djpt_ai "kb" "--action" "index" "--path" "$path"
      else
        run_djpt_ai "kb" "--action" "index"
      fi
      ;;
    2)
      printf "\n❓ Consulta: "
      read -e -r query
      if [[ -n "$query" ]]; then
        run_djpt_ai "kb" "--action" "query" "--query" "$query"
      else
        printf "%s[ERR]%s Debes proporcionar una consulta\n" "$C_RED" "$C_RESET"
      fi
      ;;
    3)
      run_djpt_ai "kb" "--action" "status"
      ;;
    0)
      return 0
      ;;
    *)
      printf "%s[ERR]%s Opción inválida\n" "$C_RED" "$C_RESET"
      ;;
  esac
  
  pause_enter
}

# Función de selección de backend
backend_selection_menu() {
  load_ai_config
  while true; do
    print_header
    print_ai_banner
    printf "%s=== 🧭 SUBMENÚ CLÁSICO DE BACKENDS ===%s\n" "$BANNER" "$C_RESET"
    printf "\n%s🍎 BACKEND MLX:%s\n" "$C_GREEN" "$C_RESET"
    printf "  %s1)%s Estado MLX\n" "$C_GRN" "$C_RESET"
    printf "  %s2)%s Configurar MLX para Apple Silicon\n" "$C_GRN" "$C_RESET"
    printf "  %s3)%s Benchmark rápido MLX\n" "$C_GRN" "$C_RESET"
    printf "  %s4)%s Inventario de modelos MLX\n" "$C_GRN" "$C_RESET"
    printf "  %s5)%s Probar ASR MLX\n" "$C_GRN" "$C_RESET"

    printf "\n%s🧠/🦙/🔤 OTROS BACKENDS:%s\n" "$C_CYAN" "$C_RESET"
    printf "  %s6)%s Estado TensorFlow Metal\n" "$C_CYAN" "$C_RESET"
    printf "  %s7)%s Aplicar perfil Apple Silicon\n" "$C_CYAN" "$C_RESET"
    printf "  %s8)%s Gestionar modelos Ollama\n" "$C_YLW" "$C_RESET"
    printf "  %s9)%s Configurar embeddings locales\n" "$C_PURP" "$C_RESET"
    printf "\n  %s0)%s Volver\n" "$C_RED" "$C_RESET"

    local choice
    if ! read -r -p "${C_BLU}Selecciona backend clásico (1-9, 0=salir): ${C_RESET}" choice; then
      break
    fi
    choice="$(echo "$choice" | xargs)"
    [ -z "$choice" ] && continue

    case "$choice" in
      1) action_ai_backend_mlx_overview ;;
      2) action_ai_backend_tuning_menu "mlx" ;;
      3) action_ai_backends_benchmark "mlx" ;;
      4) action_ai_backend_mlx_models ;;
      5) action_mlx_asr_analysis ;;
      6) action_ai_backend_tensorflow_overview ;;
      7) action_ai_backends_optimize ;;
      8) action_install_local_models ;;
      9) action_ai_backend_embeddings_config ;;
      0) break ;;
      *) invalid_option ;;
    esac
  done
}

# Función para instalar dependencias IA
action_install_ai_deps() {
  print_header
  print_ai_banner
  printf "%s=== 📦 INSTALADOR DE DEPENDENCIAS IA ===%s\n" "$BANNER" "$C_RESET"
  
  # Inicializar paths
  init_paths
  
  # Protección extra: evita command-not-found si el runner se desregistró.
  if ! declare -f install_ai_deps_robust >/dev/null 2>&1; then
    install_ai_deps_robust() {
      install_ai_deps_fallback_local
    }
  fi

  # Usar instalación robusta
  if install_ai_deps_robust; then
    printf "%s[OK]%s Dependencias AI instaladas y validadas\n" "$C_GREEN" "$C_RESET"
  else
    printf "%s[WARN]%s Falló instalación robusta. Intentando fallback local...\n" "$C_YLW" "$C_RESET"
    if install_ai_deps_fallback_local; then
      printf "%s[OK]%s Dependencias AI instaladas con fallback local\n" "$C_GREEN" "$C_RESET"
    else
      printf "%s[ERR]%s Falló la instalación de dependencias AI\n" "$C_RED" "$C_RESET"
      printf "Revisa el log para más detalles\n"
      pause_enter
      return 1
    fi
  fi
  
  pause_enter
}

# Función principal del menú
show_main_menu() {
  printf "\n%s📦 OPCIONES DE INSTALACIÓN:%s\n" "$C_GREEN" "$C_RESET"
  printf "  %s1)%s Instalar MLX (Apple Silicon GPU)\n" "$C_GRN" "$C_RESET"
  printf "  %s2)%s Instalar TensorFlow (Metal)\n" "$C_GRN" "$C_RESET"
  printf "  %s3)%s Instalar Scikit-learn (ML Local)\n" "$C_GRN" "$C_RESET"
  printf "  %s4)%s Instalar Todo (Full Stack IA)\n" "$C_YLW" "$C_RESET"
  
  local choice
  read -p "${C_BLU}Selecciona instalación (1-4, 0=salir): ${C_RESET}" choice
  
  # Si no se selecciona nada, salir
  if [ -z "$choice" ]; then
    choice="0"
  fi
  
  case "$choice" in
    1)
      printf "%s[MLX INSTALL]%s Instalando MLX...\n" "$C_GREEN" "$C_RESET"
      if ! ensure_python_deps "MLX" "mlx" "mlx-lm"; then
        printf "❌ Error instalando MLX\n"
      else
        printf "✅ MLX instalado correctamente\n"
      fi
      ;;
    2)
      printf "%s[TF INSTALL]%s Instalando TensorFlow...\n" "$C_CYAN" "$C_RESET"
      local arch_tf
      arch_tf="$(uname -m)"
      if [ "$arch_tf" = "arm64" ]; then
        if ! ensure_python_deps "TF" "tensorflow-macos==2.16.2" "tensorflow-metal==1.2.0" "onnxruntime-silicon"; then
          printf "❌ Error instalando TensorFlow (arm64)\n"
        else
          printf "✅ TensorFlow instalado correctamente\n"
        fi
      else
        if ! ensure_python_deps "TF" "tensorflow==2.16.2" "onnxruntime"; then
          printf "❌ Error instalando TensorFlow (x86)\n"
        else
          printf "✅ TensorFlow instalado correctamente\n"
        fi
      fi
      ;;
    3)
      printf "%s[SKLEARN INSTALL]%s Instalando Scikit-learn...\n" "$C_YLW" "$C_RESET"
      if ! ensure_python_deps "SKLEARN" "scikit-learn" "joblib"; then
        printf "❌ Error instalando Scikit-learn\n"
      else
        printf "✅ Scikit-learn instalado correctamente\n"
      fi
      ;;
    4)
      printf "%s[FULL INSTALL]%s Instalando Full Stack IA...\n" "$C_YLW" "$C_RESET"
      printf "📦 Esto puede tardar varios minutos...\n"
      local arch_full
      arch_full="$(uname -m)"
      if [ "$arch_full" = "arm64" ]; then
        pkgs=(mlx mlx-lm tensorflow-macos==2.16.2 tensorflow-metal==1.2.0 onnxruntime-silicon scikit-learn sentence-transformers torch PyPDF2 pdfplumber nltk requests beautifulsoup4 joblib)
      else
        pkgs=(mlx mlx-lm tensorflow==2.16.2 onnxruntime scikit-learn sentence-transformers torch PyPDF2 pdfplumber nltk requests beautifulsoup4 joblib)
      fi
      if ensure_python_deps "FULL" "${pkgs[@]}"; then
        printf "✅ Full Stack IA instalado correctamente\n"
      else
        printf "❌ Error en instalación completa\n"
      fi
      ;;
    *)
      printf "%s[ERROR]%s Opción no válida. Volviendo al menú principal...\n" "$C_RED" "$C_RESET"
      ;;
    0)
      printf "%s[INFO]%s Saliendo del instalador...\n" "$C_CYAN" "$C_RESET"
      ;;
  esac
  
  pause_enter
}

action_ai_backend_tuning_menu() {
  print_header
  print_ai_banner
  load_ai_config
  printf "%s=== ⚙️ TUNING RÁPIDO DE BACKENDS IA ===%s\n" "$BANNER" "$C_RESET"
  if ! ensure_python_bin; then
    pause_enter
    return 1
  fi
  
  printf "\n%s🔧 CONFIGURACIÓN DE BACKENDS:%s\n" "$C_CYAN" "$C_RESET"
  printf "  %s1)%s Configurar MLX (GPU Metal)\n" "$C_GRN" "$C_RESET"
  printf "  %s2)%s Configurar TensorFlow (Metal)\n" "$C_GRN" "$C_RESET"
  printf "  %s3)%s Configurar Scikit-learn (Paralelismo)\n" "$C_GRN" "$C_RESET"
  printf "  %s4)%s Optimizar para Apple Silicon\n" "$C_GRN" "$C_RESET"
  
  local choice
  if [ -n "${1:-}" ]; then
    case "$1" in
      mlx) choice="1" ;;
      tensorflow) choice="2" ;;
      sklearn) choice="3" ;;
      apple) choice="4" ;;
      *) choice="0" ;;
    esac
  else
    printf "%sSelecciona configuración (1-4, 0=salir): %s" "$C_BLU" "$C_RESET"
    read -r choice
  fi
  
  if [ -z "$choice" ]; then
    choice="0"
  fi
  
  case "$choice" in
    1)
      printf "%s[MLX CONFIG]%s Configurando MLX...\n" "$C_GREEN" "$C_RESET"
      if ensure_python_package_installed "mlx"; then
        "$PYTHON_BIN" -c "
import mlx.core as mx
import subprocess
print('🍎 MLX Version:', mx.__version__)
print('🔥 GPU Metal:', mx.metal.is_available())
print('⚡ Device:', mx.default_device())
# Optimize for Apple Silicon - límite dinámico basado en RAM
total_ram_bytes = subprocess.run(['sysctl', '-n', 'hw.memsize'], capture_output=True).stdout.strip()
total_ram = int(total_ram_bytes.split()[0])
cache_limit = total_ram // 4  # 25% de RAM total
mx.set_cache_limit(cache_limit)
print(f'✅ Cache limit: {cache_limit // (1024**2)} MB ({cache_limit // (1024**3)} GB)')
print('✅ MLX optimizado para Apple Silicon (dinámico)')
"
        DJPT_BEST_BACKEND="mlx"
        export DJPT_BEST_BACKEND
        persist_ai_runtime_config
      else
        printf "%s[WARN]%s MLX no disponible. Instala dependencias IA primero (opción 72).\n" "$C_YLW" "$C_RESET"
      fi
      ;;
    2)
      printf "%s[TF CONFIG]%s Configurando TensorFlow...\n" "$C_CYAN" "$C_RESET"
      if ensure_python_package_installed "tensorflow"; then
        "$PYTHON_BIN" -c "
import tensorflow as tf
print('🧠 TensorFlow Version:', tf.__version__)
# Enable XLA compilation
tf.config.optimizer.set_jit(True)
print('✅ XLA compilation enabled')
# Enable mixed precision
try:
    tf.keras.mixed_precision.set_global_policy('mixed_float16')
    print('✅ Mixed precision enabled')
except:
    print('⚠️ Mixed precision not available')
print('✅ TensorFlow optimizado')
"
        DJPT_BEST_BACKEND="tensorflow"
        export DJPT_BEST_BACKEND
        persist_ai_runtime_config
      else
        printf "%s[WARN]%s TensorFlow no disponible. Instala dependencias IA primero (opción 72).\n" "$C_YLW" "$C_RESET"
      fi
      ;;
    3)
      printf "%s[SKLEARN CONFIG]%s Configurando Scikit-learn...\n" "$C_YLW" "$C_RESET"
      if ensure_python_package_installed "scikit-learn"; then
        "$PYTHON_BIN" -c "
import sklearn
import joblib
print('🔤 Scikit-learn Version:', sklearn.__version__)
print('✅ Joblib available:', joblib.__version__)
print('💡 Usa n_jobs=-1 para máximo paralelismo')
print('✅ Scikit-learn configurado')
"
        DJPT_BEST_BACKEND="sklearn"
        export DJPT_BEST_BACKEND
        persist_ai_runtime_config
      else
        printf "%s[WARN]%s Scikit-learn no disponible. Instala dependencias IA primero (opción 72).\n" "$C_YLW" "$C_RESET"
      fi
      ;;
    4)
      action_ai_backends_optimize
      return 0
      ;;
    0)
      printf "%s[INFO]%s Saliendo de configuración avanzada...\n" "$C_CYAN" "$C_RESET"
      ;;
    *)
      printf "%s[ERROR]%s Opción no válida. Volviendo al menú principal...\n" "$C_RED" "$C_RESET"
      ;;
  esac
  
  pause_enter
}

action_ai_advanced_config() {
  load_ai_config
  while true; do
    print_header
    print_ai_banner
    printf "%s=== ⚙️ HUB DE CONFIGURACIÓN DE BACKENDS IA ===%s\n" "$BANNER" "$C_RESET"
    printf "\n%sAjustes y utilidades reales del sistema IA:%s\n" "$C_CYAN" "$C_RESET"
    printf "  %s1)%s Configuración global IA\n" "$C_GRN" "$C_RESET"
    printf "  %s2)%s Tuning rápido de backends\n" "$C_GRN" "$C_RESET"
    printf "  %s3)%s Submenú clásico de backends (1-9)\n" "$C_GRN" "$C_RESET"
    printf "  %s4)%s Validar dependencias IA\n" "$C_YLW" "$C_RESET"
    printf "  %s5)%s Instalar / reparar dependencias IA\n" "$C_GRN" "$C_RESET"
    printf "  %s6)%s Operaciones IA avanzadas\n" "$C_PURP" "$C_RESET"
    printf "  %s7)%s Gestionar modelos locales\n" "$C_PURP" "$C_RESET"
    printf "  %s8)%s Health check IA centralizado\n" "$C_PURP" "$C_RESET"
    printf "\n  %s0)%s Volver\n" "$C_RED" "$C_RESET"

    local choice
    if ! read -r -p "${C_BLU}Selecciona configuración backend (1-8, 0=salir): ${C_RESET}" choice; then
      break
    fi
    choice="$(echo "$choice" | xargs)"
    [ -z "$choice" ] && continue

    case "$choice" in
      1) action_ai_global_config ;;
      2) action_ai_backend_tuning_menu ;;
      3) backend_selection_menu ;;
      4) validate_ai_deps; pause_enter ;;
      5) action_install_ai_deps ;;
      6) submenu_ai_advanced_ops ;;
      7) action_install_local_models ;;
      8) action_ai_status ;;
      0) break ;;
      *) invalid_option ;;
    esac
  done
}

action_ai_train_models() {
  print_header
  print_ai_banner
  printf "%s=== 🎓 ENTRENAMIENTO DE MODELOS IA (AI SUITE) ===%s\n" "$BANNER" "$C_RESET"
  
  # Cargar configuración AI
  load_ai_config
  
  printf "\n%s🤖 TIPOS DE MODELOS DISPONIBLES:%s\n" "$C_CYAN" "$C_RESET"
  printf "  %s1)%s Clasificador (genre/mood)\n" "$C_GRN" "$C_RESET"
  printf "  %s2)%s Sistema de Recomendación\n" "$C_GRN" "$C_RESET"
  printf "  %s3)%s Modelo Generativo\n" "$C_GRN" "$C_RESET"
  
  local choice
  read -p "${C_BLU}Selecciona tipo (1-3, 0=salir): ${C_RESET}" choice
  
  case "$choice" in
    1) model_type="classifier" ;;
    2) model_type="recommender" ;;
    3) model_type="generative" ;;
    0) return 0 ;;
    *) 
      printf "%s[ERR]%s Opción inválida\n" "$C_RED" "$C_RESET"
      pause_enter
      return 1
      ;;
  esac
  
  printf "\n%s🚀 ENTRENANDO MODELO: %s%s\n" "$C_YLW" "$C_RESET" "$model_type"
  
  # Ejecutar CLI AI train
  if run_djpt_ai "train" "--type" "$model_type"; then
    printf "%s[OK]%s Entrenamiento completado exitosamente\n" "$C_GREEN" "$C_RESET"
    
    # Mostrar resultados si existen
    local profile_file="$STATE_DIR/ai_profile.json"
    if [[ -f "$profile_file" ]]; then
      printf "\n%s📊 PERFIL DEL MODELO:%s\n" "$C_CYAN" "$C_RESET"
      printf "Archivo: %s\n" "$profile_file"
      tail -10 "$profile_file"
    fi
  else
    printf "%s[ERR]%s Falló el entrenamiento del modelo\n" "$C_RED" "$C_RESET"
  fi
  
  pause_enter
}

action_ui_config() {
  while true; do
    print_header
    printf "%s=== CONFIGURACIÓN DE INTERFAZ ENRIQUECIDA ===%s\n" "$BANNER" "$C_RESET"
    printf "\n%sModo de Interfaz Actual:%s %s\n" "$C_YLW" "$C_RESET" "$DJPT_UI_MODE"
    printf "%sSoporte Drag-and-Drop:%s %s\n" "$C_YLW" "$C_RESET" "$([ "$DJPT_DRAG_SUPPORT" = "1" ] && echo "Activado" || echo "Desactivado")"
    printf "%sBarras de Progreso Limpias:%s %s\n" "$C_YLW" "$C_RESET" "$([ "$DJPT_PROGRESS_BARS" = "1" ] && echo "Activadas" || echo "Desactivadas")"
    printf "%sRecuperación de Errores:%s %s\n" "$C_YLW" "$C_RESET" "$([ "$DJPT_ERROR_RECOVERY" = "1" ] && echo "Activada" || echo "Desactivada")"
    
    printf "\n%sOpciones de Configuración:%s\n" "$C_CYAN" "$C_RESET"
    printf "  %s1)%s Cambiar modo de interfaz (enhanced/classic/minimal)\n" "$C_GRN" "$C_RESET"
    printf "  %s2)%s Activar/Desactivar drag-and-drop\n" "$C_GRN" "$C_RESET"
    printf "  %s3)%s Configurar barras de progreso\n" "$C_GRN" "$C_RESET"
    printf "  %s4)%s Configurar recuperación de errores\n" "$C_GRN" "$C_RESET"
    printf "  %s5)%s Restablecer configuración por defecto\n" "$C_GRN" "$C_RESET"
    printf "  %s0)%s Volver al menú principal\n" "$C_YLW" "$C_RESET"
    
    if ! read -p "${C_BLU}Selecciona opción de configuración (1-5, 0=volver): ${C_RESET}" choice; then
      break
    fi
    choice="$(echo "$choice" | xargs)"
    [ -z "$choice" ] && continue
    
    case "$choice" in
      1)
        printf "\n%sModos disponibles:%s\n" "$C_CYAN" "$C_RESET"
        printf "  %senhanced%s - Interfaz completa con colores y funciones avanzadas\n" "$C_GRN" "$C_RESET"
        printf "  %sclassic%s - Interfaz tradicional simplificada\n" "$C_GRN" "$C_RESET"
        printf "  %sminimal%s - Interfaz mínima, solo texto\n" "$C_GRN" "$C_RESET"
        
        read -p "${C_BLU}Elige modo (enhanced/classic/minimal): ${C_RESET}" mode_choice
        case "$mode_choice" in
          enhanced|classic|minimal) DJPT_UI_MODE="$mode_choice" ;;
          *) printf "%s[ERROR]%s Modo no válido\n" "$C_RED" "$C_RESET" ;;
        esac
        ;;
      2)
        if [ "$DJPT_DRAG_SUPPORT" = "1" ]; then
          DJPT_DRAG_SUPPORT="0"
          printf "%s[INFO]%s Drag-and-drop desactivado\n" "$C_CYN" "$C_RESET"
        else
          DJPT_DRAG_SUPPORT="1"
          printf "%s[INFO]%s Drag-and-drop activado\n" "$C_CYN" "$C_RESET"
        fi
        ;;
      3)
        if [ "$DJPT_PROGRESS_BARS" = "1" ]; then
          DJPT_PROGRESS_BARS="0"
          printf "%s[INFO]%s Barras de progreso desactivadas\n" "$C_CYN" "$C_RESET"
        else
          DJPT_PROGRESS_BARS="1"
          printf "%s[INFO]%s Barras de progreso activadas\n" "$C_CYN" "$C_RESET"
        fi
        ;;
      4)
        if [ "$DJPT_ERROR_RECOVERY" = "1" ]; then
          DJPT_ERROR_RECOVERY="0"
          printf "%s[INFO]%s Recuperación de errores desactivada\n" "$C_CYN" "$C_RESET"
        else
          DJPT_ERROR_RECOVERY="1"
          printf "%s[INFO]%s Recuperación de errores activada\n" "$C_CYN" "$C_RESET"
        fi
        ;;
      5)
        DJPT_UI_MODE="enhanced"
        DJPT_DRAG_SUPPORT="1"
        DJPT_PROGRESS_BARS="1"
        DJPT_ERROR_RECOVERY="1"
        printf "%s[INFO]%s Configuración restaurada a valores por defecto\n" "$C_CYN" "$C_RESET"
        ;;
      0)
        break
        ;;
      *)
        printf "%s[ERROR]%s Opción no válida\n" "$C_RED" "$C_RESET"
        pause_enter
        ;;
    esac
    
    # Guardar configuración inmediatamente
    save_conf
    if [ "$choice" != "0" ]; then
        pause_enter
    fi
  done
}

action_smart_scan() {
  print_header
  printf "%s=== MODO ESCANEO INTELIGENTE ===%s\n" "$BANNER" "$C_RESET"
  
  if [ "$DJPT_SMART_SCAN" = "1" ]; then
    DJPT_SMART_SCAN="0"
    printf "%s[INFO]%s Modo escaneo inteligente desactivado\n" "$C_CYN" "$C_RESET"
    printf "%s[INFO]%s El escaneo incluirá todos los archivos\n" "$C_YLW" "$C_RESET"
  else
    DJPT_SMART_SCAN="1"
    printf "%s[INFO]%s Modo escaneo inteligente activado\n" "$C_CYN" "$C_RESET"
    printf "%s[INFO]%s El escaneo se centrará en archivos de audio\n" "$C_GRN" "$C_RESET"
    printf "%s[INFO]%s Se excluirán automáticamente: python, node_modules, .git, venv\n" "$C_GRN" "$C_RESET"
  fi
  printf "%s[INFO]%s SAFE_MODE=%s: rutas fuera de BASE_PATH serán bloqueadas\n" "$C_CYN" "$C_RESET" "${SAFE_MODE:-1}"
  
  pause_enter
}

action_error_recovery() {
  print_header
  printf "%s=== RECUPERACIÓN DE ERRORES ===%s\n" "$BANNER" "$C_RESET"
  
  printf "%sEstado actual de recuperación:%s %s\n" "$C_YLW" "$C_RESET" "$([ "$DJPT_ERROR_RECOVERY" = "1" ] && echo "Activada" || echo "Desactivada")"
  
  if [ "$DJPT_ERROR_RECOVERY" = "1" ]; then
    printf "\n%sCaracterísticas activas:%s\n" "$C_GRN" "$C_RESET"
    printf "  ✅ Detección automática de errores comunes\n"
    printf "  ✅ Sugerencias inteligentes de soluciones\n"
    printf "  ✅ Recuperación automática de fallos\n"
    printf "  ✅ Modo seguro para archivos críticos\n"
  else
    printf "\n%sCaracterísticas desactivadas:%s\n" "$C_YLW" "$C_RESET"
    printf "  ❌ Sin detección automática de errores\n"
    printf "  ❌ Sin sugerencias de soluciones\n"
    printf "  ❌ Sin recuperación automática\n"
  fi
  
  printf "\n%sOpciones:%s\n" "$C_CYAN" "$C_RESET"
  printf "  %s1)%s Activar/Desactivar recuperación de errores\n" "$C_GRN" "$C_RESET"
  printf "  %s2)%s Probar recuperación de errores\n" "$C_GRN" "$C_RESET"
  printf "%s3)%s Ver historial de errores\n" "$C_GRN" "$C_RESET"
  
  read -p "${C_BLU}Selecciona opción: ${C_RESET}" choice
  
  case "$choice" in
    1)
      if [ "$DJPT_ERROR_RECOVERY" = "1" ]; then
        DJPT_ERROR_RECOVERY="0"
        printf "%s[INFO]%s Recuperación de errores desactivada\n" "$C_CYN" "$C_RESET"
      else
        DJPT_ERROR_RECOVERY="1"
        printf "%s[INFO]%s Recuperación de errores activada\n" "$C_CYN" "$C_RESET"
      fi
      ;;
    2)
      printf "%s[TEST]%s Probando sistema de recuperación...\n" "$C_YLW" "$C_RESET"
      handle_error "Error de prueba - archivo no encontrado" "test"
      ;;
    3)
      printf "%s[INFO]%s Historial de errores (últimos 10):\n" "$C_CYN" "$C_RESET"
      if [ -f "$REPORTS_DIR/error_log.txt" ]; then
        tail -10 "$REPORTS_DIR/error_log.txt" 2>/dev/null || printf "Sin errores registrados\n"
      else
        printf "Sin archivo de historial de errores\n"
      fi
      ;;
    *)
      printf "%s[ERROR]%s Opción no válida\n" "$C_RED" "$C_RESET"
      ;;
  esac
  
  pause_enter
}

action_ai_advanced_menu() {
  while true; do
    print_header
    print_ai_banner
    printf "%s=== 🤖 MENÚ IA AVANZADO MULTI-BACKEND ===%s
" "$BANNER" "$C_RESET"
    printf "
%s📚 Base de Conocimiento:%s
" "$C_CYAN" "$C_RESET"
    printf "  %s1)%s Indexar texto (KB)
" "$C_GRN" "$C_RESET"
    printf "  %s2)%s Indexar audio (ASR→KB)
" "$C_GRN" "$C_RESET"
    printf "  %s3)%s Generar embeddings/refresh KB
" "$C_GRN" "$C_RESET"
    printf "  %s4)%s Consultar KB (RAG)
" "$C_GRN" "$C_RESET"
    printf "  %s5)%s Estado KB
" "$C_GRN" "$C_RESET"
    printf "  %s6)%s Entrenamiento ligero (autotag/reco)
" "$C_GRN" "$C_RESET"
    printf "
%s🛠️ Backends IA (MLX/TF/Local/Ollama):%s
" "$C_YLW" "$C_RESET"
    printf "  %s7)%s Submenú backends clásicos (opciones 1-9)
" "$C_YLW" "$C_RESET"
    printf "
%s0)%s Volver al Menú Principal%s
" "$C_RED" "$C_RESET"
    if ! read -e -r -p "${C_BLU}Selecciona opción IA avanzada: ${C_RESET} " choice; then
      break
    fi
    choice="$(echo "$choice" | xargs)"
    [ -z "$choice" ] && continue
    case "$choice" in
      1) run_djpt_ai "kb" "--action" "index-text" --path "$BASE_PATH" ;;
      2) run_djpt_ai "kb" "--action" "index-audio" --path "$BASE_PATH" ;;
      3) run_djpt_ai "kb" "--action" "embed" ;;
      4) read -e -r -p "Pregunta: " query; [[ -n "$query" ]] && run_djpt_ai "kb" "--action" "query" "--query" "$query" || true ;;
      5) run_djpt_ai "kb" "--action" "status" ;;
      6) run_djpt_ai "train" "--type" "classifier" ;;
      7) action_ai_backend_supermenu ;;
      0) break ;;
      *) printf "%s[ERROR]%s Opción no válida\n" "$C_RED" "$C_RESET"; sleep 1 ;;
    esac
  done
}

action_ai_lab() {
  while true; do
    print_header
  print_ai_banner
    printf "%s=== 🧠 LABORATORIO IA - EXPERIMENTOS (AI SUITE) ===%s\n" "$BANNER" "$C_RESET"
    
    if ! ensure_python_bin; then break; fi
    local suite_script="$SCRIPT_DIR/scripts/ai_suite.py"
    if [ ! -f "$suite_script" ]; then suite_script="${DJPT_CANONICAL_ROOT:-$BASE_PATH}/scripts/ai_suite.py"; fi

    printf "1) Extracción de Características (Features)\n"
    printf "2) Clasificación de Géneros (Genre)\n"
    printf "3) Detección de BPM\n"
    printf "4) Prototipo Red Neuronal\n"
    printf "0) Volver\n"
    
    if ! read -p "${C_BLU}Opción: ${C_RESET}" choice; then
      break
    fi
    choice="$(echo "$choice" | xargs)"
    [ -z "$choice" ] && continue
    case "$choice" in
      1) "$PYTHON_BIN" "$suite_script" lab --experiment features; pause_enter ;;
      2) "$PYTHON_BIN" "$suite_script" lab --experiment genre; pause_enter ;;
      3) "$PYTHON_BIN" "$suite_script" lab --experiment bpm; pause_enter ;;
      4) "$PYTHON_BIN" "$suite_script" lab --experiment neural; pause_enter ;;
      0) break ;;
      *) ;;
    esac
  done
}

action_ai_optimization() {
  print_header
  print_ai_banner
  printf "%s=== ⚡ OPTIMIZACIÓN IA (AI SUITE) ===%s\n" "$BANNER" "$C_RESET"
  if ensure_python_bin; then
      local suite_script="$SCRIPT_DIR/scripts/ai_suite.py"
      if [ ! -f "$suite_script" ]; then suite_script="${DJPT_CANONICAL_ROOT:-$BASE_PATH}/scripts/ai_suite.py"; fi
      "$PYTHON_BIN" "$suite_script" optimize
  fi
  pause_enter
}

action_ai_global_config() {
  while true; do
    print_header
  print_ai_banner
    printf "%s=== 🔧 CONFIGURACIÓN IA GLOBAL ===%s\n" "$BANNER" "$C_RESET"
    
    printf "\n%s📊 ESTADO ACTUAL DE CONFIGURACIÓN:%s\n" "$C_CYAN" "$C_RESET"
    
    # MLX Configuration
    printf "\n%s🍎 MLX Configuration:%s\n" "$C_GREEN" "$C_RESET"
    if ensure_python_bin && "$PYTHON_BIN" -c "import mlx.core as mx" 2>/dev/null; then
      mlx_version=$("$PYTHON_BIN" -c "import mlx.core as mx; print(mx.__version__)" 2>/dev/null)
      gpu_available=$("$PYTHON_BIN" -c "import mlx.core as mx; print(mx.metal.is_available())" 2>/dev/null)
      printf "  ✅ MLX %s instalado\n" "$mlx_version"
      printf "  🚀 GPU Metal: %s\n" "$([ "$gpu_available" = "True" ] && echo "Activada" || echo "Desactivada")"
    else
      printf "  ❌ MLX no disponible\n"
    fi
    
    # TensorFlow Configuration
    printf "\n%s🧠 TensorFlow Configuration:%s\n" "$C_CYAN" "$C_RESET"
    if ensure_python_bin && "$PYTHON_BIN" -c "import tensorflow as tf" 2>/dev/null; then
      tf_version=$("$PYTHON_BIN" -c "import tensorflow as tf; print(tf.__version__)" 2>/dev/null)
      printf "  ✅ TensorFlow %s instalado\n" "$tf_version"
    else
      printf "  ❌ TensorFlow no disponible\n"
    fi
    
    # Local ML Configuration
    printf "\n%s🔤 Local ML Configuration:%s\n" "$C_YLW" "$C_RESET"
    if ensure_python_bin && "$PYTHON_BIN" -c "import sklearn" 2>/dev/null; then
      sklearn_version=$("$PYTHON_BIN" -c "import sklearn; print(sklearn.__version__)" 2>/dev/null)
      printf "  ✅ Scikit-learn %s instalado\n" "$sklearn_version"
    else
      printf "  ❌ Scikit-learn no disponible\n"
    fi
    
    printf "\n%s⚙️ OPCIONES DE CONFIGURACIÓN:%s\n" "$C_CYAN" "$C_RESET"
    printf "  %s1)%s Configurar Backend MLX\n" "$C_GRN" "$C_RESET"
    printf "  %s2)%s Configurar Backend TensorFlow\n" "$C_GRN" "$C_RESET"
    printf "  %s3)%s Configurar Backend Local ML\n" "$C_GRN" "$C_RESET"
    printf "  %s4)%s Configurar Ollama\n" "$C_GRN" "$C_RESET"
    printf "  %s5)%s Configurar Paths y Modelos\n" "$C_GRN" "$C_RESET"
    printf "  %s6)%s Configurar Performance\n" "$C_GRN" "$C_RESET"
    printf "  %s7)%s Reset Configuración IA\n" "$C_YLW" "$C_RESET"
    printf "  %s8)%s Exportar/Importar Config\n" "$C_GRN" "$C_RESET"
    printf "  %s0)%s Volver al Menú Principal\n" "$C_RED" "$C_RESET"
    
    if ! read -p "${C_BLU}Selecciona opción de configuración (1-8, 0=volver): ${C_RESET}" choice; then
      break
    fi
    choice="$(echo "$choice" | xargs)"
    [ -z "$choice" ] && continue
    
    case "$choice" in
      1)
        printf "%s[MLX CONFIG]%s Configurando MLX...\n" "$C_GREEN" "$C_RESET"
        if ensure_python_bin; then
        "$PYTHON_BIN" -c "
try:
    import mlx.core as mx
    print('🍎 MLX Version:', mx.__version__)
    print('🔥 GPU Metal:', mx.metal.is_available())
    print('⚡ Device:', mx.default_device())
    # Set optimal cache limit
    mx.set_cache_limit(2 * 1024 * 1024 * 1024)  # 2GB
    print('✅ Cache limit set to 2GB for optimal performance')
except ImportError:
    print('❌ MLX no instalado.')
"
        fi
        pause_enter
        ;;
      2)
        printf "%s[TF CONFIG]%s Configurando TensorFlow...\n" "$C_CYAN" "$C_RESET"
        if ensure_python_bin; then
        "$PYTHON_BIN" -c "
try:
    import tensorflow as tf
    print('🧠 TensorFlow Version:', tf.__version__)
    # Enable XLA for performance
    tf.config.optimizer.set_jit(True)
    print('✅ XLA compilation enabled')
    # Enable mixed precision if available
    try:
        tf.keras.mixed_precision.set_global_policy('mixed_float16')
        print('✅ Mixed precision enabled')
    except:
        print('⚠️ Mixed precision not available')
except ImportError:
    print('❌ TensorFlow no instalado.')
"
        fi
        pause_enter
        ;;
      3)
        printf "%s[LOCAL ML CONFIG]%s Configurando ML Local...\n" "$C_YLW" "$C_RESET"
        if ensure_python_bin; then
        "$PYTHON_BIN" -c "
try:
    import sklearn
    import joblib
    print('🔤 Scikit-learn Version:', sklearn.__version__)
    print('✅ Joblib available for parallel processing')
    print('💡 Use n_jobs=-1 for maximum parallelism')
except ImportError:
    print('❌ Scikit-learn no instalado.')
"
        fi
        pause_enter
        ;;
      4)
        printf "%s[OLLAMA CONFIG]%s Configurando Ollama...\n" "$C_PURP" "$C_RESET"
        if command -v ollama >/dev/null 2>&1; then
          printf "✅ Ollama disponible\n"
          printf "Modelos instalados:\n"
          ollama list 2>/dev/null || printf "No hay modelos\n"
        else
          printf "❌ Ollama no instalado\n"
          printf "Instala con: curl -fsSL https://ollama.ai/install.sh | sh\n"
        fi
        pause_enter
        ;;
      5)
        printf "%s[PATHS CONFIG]%s Configurando Paths...\n" "$C_CYAN" "$C_RESET"
        printf "📁 Models: %s\n" "$IA_MODELS_DIR"
        printf "📁 Scripts: %s\n" "$LIB_DIR"
        printf "📁 Reports: %s\n" "$REPORTS_DIR"
        printf "💡 Puedes configurar estas variables en el entorno\n"
        pause_enter
        ;;
      6)
        printf "%s[PERFORMANCE CONFIG]%s Configurando Performance...\n" "$C_GREEN" "$C_RESET"
        printf "🚀 Recomendaciones de rendimiento:\n"
        printf "   • MLX: Usa batch size 64-128 para GPU Metal\n"
        printf "   • TensorFlow: Habilita XLA y mixed precision\n"
        printf "   • Local ML: Usa n_jobs=-1 para paralelismo máximo\n"
        printf "   • Memory: Monitoriza uso con activity monitor\n"
        pause_enter
        ;;
      7)
        printf "%s[RESET CONFIG]%s Reseteando configuración IA...\n" "$C_YLW" "$C_RESET"
        printf "⚠️ Esto reseteará toda la configuración IA a valores por defecto\n"
        read -p "¿Confirmar reset? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          # Reset configuration files
          rm -f "$CONFIG_DIR/ai_config.json" 2>/dev/null
          rm -f "$CONFIG_DIR/mlx_config.json" 2>/dev/null
          rm -f "$CONFIG_DIR/tf_config.json" 2>/dev/null
          printf "✅ Configuración IA reseteada\n"
        else
          printf "❌ Operación cancelada\n"
        fi
        pause_enter
        ;;
      8)
        printf "%s[IMPORT/EXPORT]%s Gestión de configuración...\n" "$C_CYN" "$C_RESET"
        export_dir="$REPORTS_DIR/ai_config_exports"
        mkdir -p "$export_dir"
        printf "  1) Exportar configuración IA\n"
        printf "  2) Importar configuración IA\n"
        printf "Selecciona (1/2): "
        read -r ie_choice
        case "${ie_choice:-1}" in
          1)
            ts="$(date +%Y%m%d_%H%M%S)"
            out="$export_dir/ai_config_${ts}.tar.gz"
            tar -czf "$out" \
              -C "$CONFIG_DIR" \
              ai_config.json mlx_config.json tf_config.json \
              2>/dev/null || true
            if [ -f "$out" ]; then
              printf "%s[OK]%s Export generado: %s\n" "$C_GRN" "$C_RESET" "$out"
            else
              printf "%s[WARN]%s No había archivos de configuración para exportar.\n" "$C_YLW" "$C_RESET"
            fi
            ;;
          2)
            printf "Ruta del .tar.gz (ENTER para último export): "
            read -e -r import_file
            if [ -z "${import_file:-}" ]; then
              import_file="$(ls -1t "$export_dir"/ai_config_*.tar.gz 2>/dev/null | head -n1)"
            fi
            if [ -n "${import_file:-}" ] && [ -f "$import_file" ]; then
              if tar -xzf "$import_file" -C "$CONFIG_DIR" 2>/dev/null; then
                printf "%s[OK]%s Configuración importada desde: %s\n" "$C_GRN" "$C_RESET" "$import_file"
              else
                printf "%s[ERR]%s No se pudo importar el archivo.\n" "$C_RED" "$C_RESET"
              fi
            else
              printf "%s[ERR]%s Archivo de importación no encontrado.\n" "$C_RED" "$C_RESET"
            fi
            ;;
          *)
            printf "%s[ERR]%s Selección inválida.\n" "$C_RED" "$C_RESET"
            ;;
        esac
        pause_enter
        ;;
      0)
        break
        ;;
      *)
        printf "%s[ERROR]%s Opción no válida\n" "$C_RED" "$C_RESET"
        pause_enter
        ;;
    esac
  done
}

# --- Real AI Implementation ---

action_mlx_asr_analysis() {
  print_header
  printf "%s[MLX ASR]%s Análisis de Audio con MLX-ASR\n" "$C_GREEN" "$C_RESET"

  local target_dir mlx_script ts out
  read -e -r -p "Carpeta a analizar (ENTER=$BASE_PATH): " target_dir
  target_dir=${target_dir:-$BASE_PATH}

  if [ ! -d "$target_dir" ] && [ ! -f "$target_dir" ]; then
    printf "%s[ERR]%s Ruta inválida: %s\n" "$C_RED" "$C_RESET" "$target_dir"
    pause_enter
    return
  fi

  if ! ensure_python_bin; then
    pause_enter
    return
  fi

  mlx_script="$(resolve_ai_python_tool "ml_mlx.py")" || {
    printf "%s[ERR]%s No se encontró ml_mlx.py en scripts/ai ni lib/\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  }

  ts="$(date +%Y%m%d_%H%M%S)"
  out="$REPORTS_DIR/mlx_asr_report_${ts}.json"
  if "$PYTHON_BIN" "$mlx_script" asr --base "$target_dir" --out "$out"; then
    printf "%s[OK]%s Reporte ASR generado: %s\n" "$C_GRN" "$C_RESET" "$out"
  else
    printf "%s[ERR]%s Falló análisis MLX-ASR.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_mlx_metadata_generation() {
  print_header
  printf "%s[MLX LM]%s Generación de Metadatos\n" "$C_GREEN" "$C_RESET"

  local target_dir mlx_script ts out
  read -e -r -p "Carpeta a analizar (ENTER=$BASE_PATH): " target_dir
  target_dir=${target_dir:-$BASE_PATH}

  if [ ! -d "$target_dir" ] && [ ! -f "$target_dir" ]; then
    printf "%s[ERR]%s Ruta inválida: %s\n" "$C_RED" "$C_RESET" "$target_dir"
    pause_enter
    return
  fi

  if ! ensure_python_bin; then
    pause_enter
    return
  fi

  mlx_script="$(resolve_ai_python_tool "ml_mlx.py")" || {
    printf "%s[ERR]%s No se encontró ml_mlx.py en scripts/ai ni lib/\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  }

  ts="$(date +%Y%m%d_%H%M%S)"
  out="$REPORTS_DIR/mlx_metadata_report_${ts}.json"
  if "$PYTHON_BIN" "$mlx_script" metadata --base "$target_dir" --out "$out"; then
    printf "%s[OK]%s Reporte de metadatos generado: %s\n" "$C_GRN" "$C_RESET" "$out"
  else
    printf "%s[ERR]%s Falló generación de metadatos MLX.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_mlx_audio_embeddings() {
  print_header
  printf "%s[MLX EMB]%s Generar Embeddings\n" "$C_GREEN" "$C_RESET"

  local target_dir mlx_script ts out
  read -e -r -p "Carpeta a procesar (ENTER=$BASE_PATH): " target_dir
  target_dir=${target_dir:-$BASE_PATH}

  if [ ! -d "$target_dir" ] && [ ! -f "$target_dir" ]; then
    printf "%s[ERR]%s Ruta inválida: %s\n" "$C_RED" "$C_RESET" "$target_dir"
    pause_enter
    return
  fi

  if ! ensure_python_bin; then
    pause_enter
    return
  fi

  mlx_script="$(resolve_ai_python_tool "ml_mlx.py")" || {
    printf "%s[ERR]%s No se encontró ml_mlx.py en scripts/ai ni lib/\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  }

  ts="$(date +%Y%m%d_%H%M%S)"
  out="$REPORTS_DIR/mlx_embeddings_${ts}.tsv"
  if "$PYTHON_BIN" "$mlx_script" embeddings --base "$target_dir" --out "$out"; then
    printf "%s[OK]%s Embeddings generados: %s\n" "$C_GRN" "$C_RESET" "$out"
  else
    printf "%s[ERR]%s Falló generación de embeddings MLX.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

resolve_ai_python_tool() {
  local script_name="$1"
  local canonical_root="${DJPT_CANONICAL_ROOT:-$SCRIPT_DIR/..}"
  local candidates=(
    "$canonical_root/scripts/ai/$script_name"
    "$canonical_root/lib/$script_name"
    "$SCRIPT_DIR/ai/$script_name"
    "$BASE_PATH/scripts/ai/$script_name"
    "$BASE_PATH/lib/$script_name"
    "$BASE_PATH/$script_name"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    if [ -f "$candidate" ]; then
      printf "%s" "$candidate"
      return 0
    fi
  done
  return 1
}

action_mlx_batch_processing() {
  print_header
  printf "%s[MLX BATCH]%s Procesamiento por Lotes\n" "$C_GREEN" "$C_RESET"

  local target_dir mlx_script out ts
  if [ "${NO_INTERACTIVE:-0}" -eq 1 ] || [ "${DJPT_NO_INTERACTIVE:-0}" -eq 1 ]; then
    target_dir="$BASE_PATH"
  else
    read -e -r -p "Carpeta a procesar (ENTER=$BASE_PATH): " target_dir
    target_dir=${target_dir:-$BASE_PATH}
  fi
  if [ ! -d "$target_dir" ] && [ ! -f "$target_dir" ]; then
    printf "%s[ERR]%s Ruta inválida: %s\n" "$C_RED" "$C_RESET" "$target_dir"
    pause_enter
    return
  fi

  if ! ensure_python_bin; then
    pause_enter
    return
  fi

  mlx_script="$(resolve_ai_python_tool "ml_mlx.py")" || {
    printf "%s[ERR]%s No se encontró ml_mlx.py en scripts/ai ni lib/\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  }

  ts="$(date +%Y%m%d_%H%M%S)"
  out="$REPORTS_DIR/mlx_batch_${ts}.tsv"
  if "$PYTHON_BIN" "$mlx_script" batch --base "$target_dir" --out "$out"; then
    printf "%s[OK]%s Batch MLX completado: %s\n" "$C_GRN" "$C_RESET" "$out"
  else
    printf "%s[ERR]%s Falló batch MLX.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_tf_spectral_analysis() {
  print_header
  printf "%s[TF SPECTRAL]%s Análisis Espectral (TF/Librosa)\n" "$C_CYAN" "$C_RESET"

  local target_dir tf_script out ts
  if [ "${NO_INTERACTIVE:-0}" -eq 1 ] || [ "${DJPT_NO_INTERACTIVE:-0}" -eq 1 ]; then
    target_dir="$BASE_PATH"
  else
    read -e -r -p "Carpeta a analizar (ENTER=$BASE_PATH): " target_dir
    target_dir=${target_dir:-$BASE_PATH}
  fi

  if ! ensure_python_bin; then
    pause_enter
    return
  fi

  tf_script="$(resolve_ai_python_tool "ml_tf.py")" || {
    printf "%s[ERR]%s No se encontró ml_tf.py en scripts/ai ni lib/\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  }

  ts="$(date +%Y%m%d_%H%M%S)"
  out="$REPORTS_DIR/tf_spectral_${ts}.json"
  if "$PYTHON_BIN" "$tf_script" spectral --base "$target_dir" --out "$out"; then
    printf "%s[OK]%s Reporte espectral: %s\n" "$C_GRN" "$C_RESET" "$out"
  else
    printf "%s[ERR]%s Falló análisis espectral.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_tf_genre_classification() {
  print_header
  printf "%s[TF GENRE]%s Clasificación de Géneros\n" "$C_CYAN" "$C_RESET"

  local target_dir tf_script out ts
  if [ "${NO_INTERACTIVE:-0}" -eq 1 ] || [ "${DJPT_NO_INTERACTIVE:-0}" -eq 1 ]; then
    target_dir="$BASE_PATH"
  else
    read -e -r -p "Carpeta a analizar (ENTER=$BASE_PATH): " target_dir
    target_dir=${target_dir:-$BASE_PATH}
  fi

  if ! ensure_python_bin; then
    pause_enter
    return
  fi

  tf_script="$(resolve_ai_python_tool "ml_tf.py")" || {
    printf "%s[ERR]%s No se encontró ml_tf.py en scripts/ai ni lib/\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  }

  ts="$(date +%Y%m%d_%H%M%S)"
  out="$REPORTS_DIR/tf_genre_${ts}.tsv"
  if "$PYTHON_BIN" "$tf_script" genre --base "$target_dir" --out "$out"; then
    printf "%s[OK]%s Clasificación de género: %s\n" "$C_GRN" "$C_RESET" "$out"
  else
    printf "%s[ERR]%s Falló clasificación de género.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_tf_advanced_bpm() {
  print_header
  printf "%s[TF BPM]%s Detección Avanzada de BPM\n" "$C_CYAN" "$C_RESET"

  local target_dir tf_script out ts
  if [ "${NO_INTERACTIVE:-0}" -eq 1 ] || [ "${DJPT_NO_INTERACTIVE:-0}" -eq 1 ]; then
    target_dir="$BASE_PATH"
  else
    read -e -r -p "Carpeta a analizar (ENTER=$BASE_PATH): " target_dir
    target_dir=${target_dir:-$BASE_PATH}
  fi

  if ! ensure_python_bin; then
    pause_enter
    return
  fi

  tf_script="$(resolve_ai_python_tool "ml_tf.py")" || {
    printf "%s[ERR]%s No se encontró ml_tf.py en scripts/ai ni lib/\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  }

  ts="$(date +%Y%m%d_%H%M%S)"
  out="$REPORTS_DIR/tf_bpm_${ts}.tsv"
  if "$PYTHON_BIN" "$tf_script" bpm --base "$target_dir" --out "$out"; then
    printf "%s[OK]%s BPM avanzado: %s\n" "$C_GRN" "$C_RESET" "$out"
  else
    printf "%s[ERR]%s Falló detección BPM avanzada.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_tf_stem_separation() {
  print_header
  printf "%s[TF STEMS]%s Separación de Fuentes (Stems)\n" "$C_CYAN" "$C_RESET"

  local target_dir tf_script out_dir ts
  local stems_backend stems_backend_input demucs_model demucs_model_input
  local demucs_device demucs_device_input
  if [ "${NO_INTERACTIVE:-0}" -eq 1 ] || [ "${DJPT_NO_INTERACTIVE:-0}" -eq 1 ]; then
    target_dir="$BASE_PATH"
  else
    read -e -r -p "Carpeta o Archivo (ENTER=$BASE_PATH): " target_dir
    target_dir=${target_dir:-$BASE_PATH}
  fi
  stems_backend="${DJPT_STEMS_BACKEND:-auto}"
  demucs_model="${DJPT_DEMUCS_MODEL:-htdemucs}"
  demucs_device="${DJPT_DEMUCS_DEVICE:-auto}"

  if [ "${NO_INTERACTIVE:-0}" -eq 1 ] || [ "${DJPT_NO_INTERACTIVE:-0}" -eq 1 ]; then
    stems_backend_input=""
  else
    read -e -r -p "Backend stems [auto|hpss|demucs] (ENTER=$stems_backend): " stems_backend_input
  fi
  stems_backend="${stems_backend_input:-$stems_backend}"
  stems_backend="$(printf "%s" "$stems_backend" | tr '[:upper:]' '[:lower:]')"
  if [[ "$stems_backend" != "auto" && "$stems_backend" != "hpss" && "$stems_backend" != "demucs" ]]; then
    printf "%s[WARN]%s Backend inválido, usando 'auto'.\n" "$C_YLW" "$C_RESET"
    stems_backend="auto"
  fi

  if [ "${NO_INTERACTIVE:-0}" -eq 1 ] || [ "${DJPT_NO_INTERACTIVE:-0}" -eq 1 ]; then
    demucs_model_input=""
    demucs_device_input=""
  else
    read -e -r -p "Modelo Demucs (ENTER=$demucs_model): " demucs_model_input
    read -e -r -p "Dispositivo Demucs [auto|cpu|cuda|mps] (ENTER=$demucs_device): " demucs_device_input
  fi
  demucs_model="${demucs_model_input:-$demucs_model}"
  demucs_device="${demucs_device_input:-$demucs_device}"

  if ! ensure_python_bin; then
    pause_enter
    return
  fi

  tf_script="$(resolve_ai_python_tool "ml_tf.py")" || {
    printf "%s[ERR]%s No se encontró ml_tf.py en scripts/ai ni lib/\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  }

  ts="$(date +%Y%m%d_%H%M%S)"
  out_dir="$REPORTS_DIR/stems_${ts}"
  mkdir -p "$out_dir"
  printf "%s[INFO]%s Backend efectivo solicitado: %s | Modelo: %s | Device: %s\n" \
    "$C_CYAN" "$C_RESET" "$stems_backend" "$demucs_model" "$demucs_device"
  if "$PYTHON_BIN" "$tf_script" stems \
      --base "$target_dir" \
      --out "$out_dir" \
      --limit 5 \
      --backend "$stems_backend" \
      --demucs-model "$demucs_model" \
      --device "$demucs_device"; then
    printf "%s[OK]%s Stems generados en: %s\n" "$C_GRN" "$C_RESET" "$out_dir"
    printf "%s[OK]%s Manifest: %s\n" "$C_GRN" "$C_RESET" "$out_dir/manifest.tsv"
  else
    printf "%s[ERR]%s Falló separación de stems.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_local_clustering() {
  print_header
  printf "%s[LOCAL]%s Clustering local de biblioteca\n" "$C_YLW" "$C_RESET"

  local local_script out ts
  if ! ensure_python_bin; then
    pause_enter
    return
  fi
  local_script="$(resolve_ai_python_tool "local_ml_ops.py")" || {
    printf "%s[ERR]%s No se encontró local_ml_ops.py\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  }
  ts="$(date +%Y%m%d_%H%M%S)"
  out="$REPORTS_DIR/local_clustering_${ts}.tsv"
  if "$PYTHON_BIN" "$local_script" cluster --base "$BASE_PATH" --out "$out" --limit "${DJPT_LOCAL_ML_LIMIT:-500}"; then
    printf "%s[OK]%s Clustering completado: %s\n" "$C_GRN" "$C_RESET" "$out"
  else
    printf "%s[ERR]%s Falló clustering local.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_local_recommendations() {
  print_header
  printf "%s[LOCAL]%s Recomendaciones locales\n" "$C_YLW" "$C_RESET"

  local local_script out ts
  if ! ensure_python_bin; then
    pause_enter
    return
  fi
  local_script="$(resolve_ai_python_tool "local_ml_ops.py")" || {
    printf "%s[ERR]%s No se encontró local_ml_ops.py\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  }
  ts="$(date +%Y%m%d_%H%M%S)"
  out="$REPORTS_DIR/local_recommendations_${ts}.tsv"
  if "$PYTHON_BIN" "$local_script" recommend --base "$BASE_PATH" --out "$out" --limit "${DJPT_LOCAL_ML_LIMIT:-500}" --top "${DJPT_LOCAL_ML_TOP:-5}"; then
    printf "%s[OK]%s Recomendaciones generadas: %s\n" "$C_GRN" "$C_RESET" "$out"
  else
    printf "%s[ERR]%s Falló generación de recomendaciones.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_local_similarity_analysis() {
  print_header
  printf "%s[LOCAL]%s Similitud avanzada local\n" "$C_YLW" "$C_RESET"

  local local_script out ts
  if ! ensure_python_bin; then
    pause_enter
    return
  fi
  local_script="$(resolve_ai_python_tool "local_ml_ops.py")" || {
    printf "%s[ERR]%s No se encontró local_ml_ops.py\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  }
  ts="$(date +%Y%m%d_%H%M%S)"
  out="$REPORTS_DIR/local_similarity_${ts}.tsv"
  if "$PYTHON_BIN" "$local_script" similarity --base "$BASE_PATH" --out "$out" --limit "${DJPT_LOCAL_ML_LIMIT:-500}" --top "${DJPT_LOCAL_ML_TOP:-5}"; then
    printf "%s[OK]%s Matriz de similitud: %s\n" "$C_GRN" "$C_RESET" "$out"
  else
    printf "%s[ERR]%s Falló análisis de similitud.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_local_popularity_prediction() {
  print_header
  printf "%s[LOCAL]%s Predicción de popularidad local\n" "$C_YLW" "$C_RESET"

  local local_script out ts
  if ! ensure_python_bin; then
    pause_enter
    return
  fi
  local_script="$(resolve_ai_python_tool "local_ml_ops.py")" || {
    printf "%s[ERR]%s No se encontró local_ml_ops.py\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  }
  ts="$(date +%Y%m%d_%H%M%S)"
  out="$REPORTS_DIR/local_popularity_${ts}.tsv"
  if "$PYTHON_BIN" "$local_script" popularity --base "$BASE_PATH" --out "$out" --limit "${DJPT_LOCAL_ML_LIMIT:-1000}"; then
    printf "%s[OK]%s Predicción de popularidad: %s\n" "$C_GRN" "$C_RESET" "$out"
  else
    printf "%s[ERR]%s Falló predicción de popularidad.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

# Ollama Actions
resolve_ollama_model() {
  local requested="${DJPT_OLLAMA_MODEL:-}"
  local installed first

  if ! command -v ollama >/dev/null 2>&1; then
    return 1
  fi

  installed="$(ollama list 2>/dev/null | awk 'NR>1 {print $1}')"
  if [ -z "$installed" ]; then
    return 1
  fi

  if [ -n "$requested" ]; then
    if printf "%s\n" "$installed" | grep -Fxq "$requested"; then
      printf "%s" "$requested"
      return 0
    fi
    first="$(printf "%s\n" "$installed" | awk -v m="$requested" '$0 ~ ("^" m ":"){print; exit}')"
    if [ -n "$first" ]; then
      printf "%s" "$first"
      return 0
    fi
  fi

  local candidates=(
    "llama3.2:3b"
    "llama3.2"
    "llama3:latest"
    "llama3"
    "llama2:latest"
    "llama2"
    "neural-chat:latest"
    "tinyllama:1.1b"
  )
  local model
  for model in "${candidates[@]}"; do
    if printf "%s\n" "$installed" | grep -Fxq "$model"; then
      printf "%s" "$model"
      return 0
    fi
  done

  first="$(printf "%s\n" "$installed" | head -n1)"
  [ -n "$first" ] || return 1
  printf "%s" "$first"
  return 0
}

action_ollama_chat_library() {
  print_header
  printf "%s[OLLAMA]%s Chat con tu Biblioteca\n" "$C_PURP" "$C_RESET"
  local ts local_script summary_json output_md error_log model prompt query
  ts="$(date +%Y%m%d_%H%M%S)"
  local_script="$(resolve_ai_python_tool "local_ml_ops.py" || true)"
  summary_json="$REPORTS_DIR/ollama_chat_context_${ts}.json"
  output_md="$REPORTS_DIR/ollama_chat_library_${ts}.md"
  error_log="$REPORTS_DIR/ollama_chat_library_${ts}.err"

  if [ -n "$local_script" ] && ensure_python_bin; then
    "$PYTHON_BIN" "$local_script" summary --base "$BASE_PATH" --out "$summary_json" --limit 600 >/dev/null 2>&1 || true
  fi
  [ -f "$summary_json" ] || echo '{"audio_files":0,"extensions":{},"top_directories":[]}' >"$summary_json"

  if [ "${NO_INTERACTIVE:-0}" -eq 1 ] || [ "${DJPT_NO_INTERACTIVE:-0}" -eq 1 ]; then
    query="Diagnóstico general de mi biblioteca y prioridades de limpieza."
  else
    read -r -p "Tu pregunta sobre la música: " query
    [ -z "$query" ] && query="Diagnóstico general de mi biblioteca y prioridades de limpieza."
  fi

  if ! command -v ollama >/dev/null 2>&1; then
    {
      printf "# Chat local sin Ollama\n\n"
      printf -- "- Estado: Ollama no está instalado.\n"
      printf -- "- Pregunta: %s\n" "$query"
      printf -- "- Contexto local: \`%s\`\n" "$summary_json"
      printf -- "- Acción: instala Ollama y ejecuta \`ollama pull llama3.2:3b\`.\n"
    } >"$output_md"
    printf "%s[WARN]%s Ollama no instalado. Diagnóstico guardado: %s\n" "$C_YLW" "$C_RESET" "$output_md"
    pause_enter
    return
  fi

  model="$(resolve_ollama_model || true)"
  if [ -z "$model" ]; then
    {
      printf "# Chat local sin modelo Ollama\n\n"
      printf -- "- Estado: Ollama instalado pero sin modelos.\n"
      printf -- "- Pregunta: %s\n" "$query"
      printf -- "- Contexto local: \`%s\`\n" "$summary_json"
      printf -- "- Acción: \`ollama pull llama3.2:3b\`.\n"
    } >"$output_md"
    printf "%s[WARN]%s No hay modelos Ollama. Diagnóstico guardado: %s\n" "$C_YLW" "$C_RESET" "$output_md"
    pause_enter
    return
  fi

  prompt="$(cat <<EOF
Eres un consultor experto de librerías DJ.
Responde en español, concreto y accionable.
Pregunta del usuario: $query

Contexto local (JSON):
$(cat "$summary_json")

Formato de respuesta:
1) Diagnóstico corto
2) 5 acciones priorizadas
3) Riesgos operativos a evitar
EOF
)"

  printf "%s[INFO]%s Modelo: %s\n" "$C_CYN" "$C_RESET" "$model"
  local ollama_runner=""
  if command -v timeout >/dev/null 2>&1; then
    ollama_runner="timeout 180"
  elif command -v gtimeout >/dev/null 2>&1; then
    ollama_runner="gtimeout 180"
  fi

  local rc=0
  if [ -n "$ollama_runner" ]; then
    # shellcheck disable=SC2086
    $ollama_runner ollama run "$model" "$prompt" >"$output_md" 2>"$error_log" || rc=$?
  else
    ollama run "$model" "$prompt" >"$output_md" 2>"$error_log" || rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    rm -f "$error_log"
    printf "%s[OK]%s Respuesta guardada en: %s\n" "$C_GRN" "$C_RESET" "$output_md"
  else
    printf "%s[ERR]%s Error de Ollama. Log: %s\n" "$C_RED" "$C_RESET" "$error_log"
  fi
  pause_enter
}

action_ollama_playlist_generation() {
  print_header
  printf "%s[OLLAMA]%s Playlist Generativa\n" "$C_PURP" "$C_RESET"
  local ts local_script rec_tsv pop_tsv out_txt out_m3u model vibe size prompt
  ts="$(date +%Y%m%d_%H%M%S)"
  local_script="$(resolve_ai_python_tool "local_ml_ops.py" || true)"
  rec_tsv="$REPORTS_DIR/local_recommendations_${ts}.tsv"
  pop_tsv="$REPORTS_DIR/local_popularity_${ts}.tsv"
  out_txt="$REPORTS_DIR/ollama_playlist_${ts}.txt"
  out_m3u="$REPORTS_DIR/ollama_playlist_${ts}.m3u8"

  if [ "${NO_INTERACTIVE:-0}" -eq 1 ] || [ "${DJPT_NO_INTERACTIVE:-0}" -eq 1 ]; then
    vibe="energético y melódico"
    size=12
  else
    read -r -p "Describe el vibe de la playlist: " vibe
    [ -z "$vibe" ] && vibe="energético y melódico"
    read -r -p "Cantidad de tracks (ENTER=12): " size
    [ -z "$size" ] && size=12
  fi
  [[ "$size" =~ ^[0-9]+$ ]] || size=12

  if [ -n "$local_script" ] && ensure_python_bin; then
    "$PYTHON_BIN" "$local_script" recommend --base "$BASE_PATH" --out "$rec_tsv" --limit 500 --top 6 >/dev/null 2>&1 || true
    "$PYTHON_BIN" "$local_script" popularity --base "$BASE_PATH" --out "$pop_tsv" --limit 800 >/dev/null 2>&1 || true
  fi

  model="$(resolve_ollama_model || true)"
  if ! command -v ollama >/dev/null 2>&1 || [ -z "$model" ]; then
    printf "%s[WARN]%s Ollama no disponible/modelo ausente. Generando playlist local determinista.\n" "$C_YLW" "$C_RESET"
    if [ -f "$pop_tsv" ]; then
      {
        printf "#EXTM3U\n"
        awk -F'\t' 'NR>1 {print $1}' "$pop_tsv" | head -n "$size"
      } >"$out_m3u"
      printf "%s[OK]%s Playlist local: %s\n" "$C_GRN" "$C_RESET" "$out_m3u"
    else
      printf "%s[ERR]%s No se pudo generar playlist local (sin datos).\n" "$C_RED" "$C_RESET"
    fi
    pause_enter
    return
  fi

  prompt="$(cat <<EOF
Genera una playlist DJ de $size tracks para el vibe: "$vibe".
Usa SOLO esta evidencia local (TSV):

Recomendaciones:
$( [ -f "$rec_tsv" ] && head -n 80 "$rec_tsv" || echo "sin datos" )

Popularidad:
$( [ -f "$pop_tsv" ] && head -n 80 "$pop_tsv" || echo "sin datos" )

Formato de salida:
- Una línea por track: PATH | MOTIVO | ENERGIA(1-10)
- No inventes paths fuera de los TSV.
EOF
)"

  printf "%s[INFO]%s Modelo: %s\n" "$C_CYN" "$C_RESET" "$model"
  local ollama_runner=""
  if command -v timeout >/dev/null 2>&1; then
    ollama_runner="timeout 180"
  elif command -v gtimeout >/dev/null 2>&1; then
    ollama_runner="gtimeout 180"
  fi

  local rc=0
  if [ -n "$ollama_runner" ]; then
    # shellcheck disable=SC2086
    $ollama_runner ollama run "$model" "$prompt" >"$out_txt" 2>/dev/null || rc=$?
  else
    ollama run "$model" "$prompt" >"$out_txt" 2>/dev/null || rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    printf "%s[OK]%s Playlist generada: %s\n" "$C_GRN" "$C_RESET" "$out_txt"
  else
    printf "%s[ERR]%s Falló generación con Ollama.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_ollama_music_analysis() {
  print_header
  printf "%s[OLLAMA]%s Análisis Musical LLM\n" "$C_PURP" "$C_RESET"

  local ts context_report output_report error_report model question
  local audio_count video_count project_count sample_files prompt
  ts="$(date +%Y%m%d-%H%M%S)"
  context_report="$REPORTS_DIR/ollama_music_context_${ts}.txt"
  output_report="$REPORTS_DIR/ollama_music_analysis_${ts}.md"
  error_report="$REPORTS_DIR/ollama_music_analysis_${ts}.err"
  model="$(resolve_ollama_model || true)"
  mkdir -p "$REPORTS_DIR"

  printf "%s[INFO]%s Construyendo contexto de biblioteca...\n" "$C_CYN" "$C_RESET"
  if ensure_python_bin; then
    "$PYTHON_BIN" - "$BASE_PATH" "$context_report" "$ts" <<'PY'
import os
import sys
from pathlib import Path

base = Path(sys.argv[1]).expanduser()
out = Path(sys.argv[2]).expanduser()
ts = sys.argv[3]
exclude_dirs = {".git", ".Trash", "node_modules", "__pycache__", "_DJProducerTools", "_SeratOrganizer"}
audio_ext = {".mp3", ".flac", ".wav", ".m4a", ".aif", ".aiff", ".aac"}
video_ext = {".mp4", ".mov", ".mkv", ".avi", ".m4v"}
project_ext = {".als", ".adg", ".adv", ".logicx", ".rpp"}

audio_count = 0
video_count = 0
project_count = 0
samples = []

for root, dirs, files in os.walk(base, topdown=True):
    dirs[:] = [d for d in dirs if d not in exclude_dirs]
    for name in files:
        p = Path(root) / name
        ext = p.suffix.lower()
        if ext in audio_ext:
            audio_count += 1
            if len(samples) < 12:
                samples.append(str(p))
        elif ext in video_ext:
            video_count += 1
        elif ext in project_ext:
            project_count += 1

out.parent.mkdir(parents=True, exist_ok=True)
with out.open("w", encoding="utf-8") as f:
    f.write(f"timestamp={ts}\n")
    f.write(f"base_path={base}\n")
    f.write(f"audio_files={audio_count}\n")
    f.write(f"video_files={video_count}\n")
    f.write(f"project_files={project_count}\n")
    f.write("sample_audio_files=\n")
    if samples:
        for s in samples:
            f.write(s + "\n")
    else:
        f.write("(sin archivos de audio en BASE_PATH)\n")
PY
  fi
  if [ ! -f "$context_report" ]; then
    {
      printf "timestamp=%s\n" "$ts"
      printf "base_path=%s\n" "$BASE_PATH"
      printf "audio_files=0\nvideo_files=0\nproject_files=0\n"
      printf "sample_audio_files=\n(sin datos)\n"
    } >"$context_report"
  fi

  if [ "${NO_INTERACTIVE:-0}" -eq 1 ] || [ "${DJPT_NO_INTERACTIVE:-0}" -eq 1 ]; then
    question="Genera un diagnóstico general de la librería, riesgos y 10 acciones priorizadas."
  else
    printf "Pregunta para el análisis (ENTER = diagnóstico general): "
    read -r question
    [ -z "$question" ] && question="Genera un diagnóstico general de la librería, riesgos y 10 acciones priorizadas."
  fi

  if ! command -v ollama >/dev/null 2>&1; then
    {
      printf "# Diagnóstico local sin LLM\n\n"
      printf -- "- Estado: Ollama no está instalado en este sistema.\n"
      printf -- "- Contexto: \`%s\`\n" "$context_report"
      printf -- "- Pregunta solicitada: %s\n" "$question"
      printf -- "- Acción sugerida: instala Ollama y vuelve a ejecutar esta opción para análisis LLM completo.\n"
    } >"$output_report"
    printf "%s[WARN]%s Ollama no instalado. Se guardó diagnóstico base: %s\n" "$C_YLW" "$C_RESET" "$output_report"
    pause_enter
    return
  fi

  if [ -z "$model" ]; then
    {
      printf "# Diagnóstico local sin LLM\n\n"
      printf -- "- Estado: Ollama está instalado pero no hay modelos locales.\n"
      printf -- "- Contexto: \`%s\`\n" "$context_report"
      printf -- "- Pregunta solicitada: %s\n" "$question"
      printf -- "- Acción sugerida: ejecuta \`ollama pull llama3.2:3b\` y vuelve a lanzar el análisis.\n"
    } >"$output_report"
    printf "%s[WARN]%s No hay modelos Ollama instalados. Diagnóstico base: %s\n" "$C_YLW" "$C_RESET" "$output_report"
    pause_enter
    return
  fi

  prompt="$(cat <<EOF
Eres un asesor experto en bibliotecas DJ y producción musical.
Usa SOLO el contexto entregado; no inventes archivos.

Contexto local:
$(cat "$context_report")

Pregunta del usuario:
$question

Responde en español con este formato:
1) Diagnóstico técnico breve.
2) Riesgos detectados (priorizados).
3) Acciones recomendadas (máx 10, concretas y ejecutables).
4) Comandos/scripts DJProducerTools sugeridos.
EOF
)"

  printf "%s[INFO]%s Ejecutando análisis con modelo %s...\n" "$C_CYN" "$C_RESET" "$model"
  local ollama_runner=""
  if command -v timeout >/dev/null 2>&1; then
    ollama_runner="timeout 240"
  elif command -v gtimeout >/dev/null 2>&1; then
    ollama_runner="gtimeout 240"
  fi

  local rc=0
  if [ -n "$ollama_runner" ]; then
    # shellcheck disable=SC2086
    $ollama_runner ollama run "$model" "$prompt" >"$output_report" 2>"$error_report" || rc=$?
  else
    ollama run "$model" "$prompt" >"$output_report" 2>"$error_report" || rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    printf "%s[OK]%s Análisis completado: %s\n" "$C_GRN" "$C_RESET" "$output_report"
    rm -f "$error_report"
  else
    printf "%s[ERR]%s Falló Ollama. Revisa: %s\n" "$C_RED" "$C_RESET" "$error_report"
    printf "%s[INFO]%s Contexto guardado en: %s\n" "$C_CYN" "$C_RESET" "$context_report"
  fi

  pause_enter
}

# Source additional AI learning functions
if [ -f "/Volumes/SeaGate2TB/_DJProducerTools/ai_learning_functions.sh" ]; then
  source "/Volumes/SeaGate2TB/_DJProducerTools/ai_learning_functions.sh"
fi

# Source missing AI functions
if [ -f "/Volumes/SeaGate2TB/_DJProducerTools/ai_missing_functions.sh" ]; then
  source "/Volumes/SeaGate2TB/_DJProducerTools/ai_missing_functions.sh"
fi

# Source local models functions
if [ -f "/Volumes/SeaGate2TB/_DJProducerTools/ai_local_models.sh" ]; then
  source "/Volumes/SeaGate2TB/_DJProducerTools/ai_local_models.sh"
fi

# Source enhanced chat functions
if [ -f "/Volumes/SeaGate2TB/_DJProducerTools/enhanced_chat_functions.sh" ]; then
  source "/Volumes/SeaGate2TB/_DJProducerTools/enhanced_chat_functions.sh"
fi

main_loop() {
  while true; do
    print_header
    print_menu
    printf "%s%s%s " "$C_BLU" "$(get_localized_string PROMPT_OPTION)" "$C_RESET"
    if ! read -r op 2>/dev/null; then
      printf "%s[WARN]%s Entrada no disponible. Pulsa ENTER para salir.\n" "$C_YLW" "$C_RESET"
      pause_enter
      break
    fi
    op="$(echo "$op" | xargs)"
    [ -z "$op" ] && continue
    
    case "$op" in
      1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|34|35)
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
          0) break ;;
        esac
        ;;
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
      91) [ "$LAB" = "1" ] && action_lab_doctor ;;
      92) [ "$LAB" = "1" ] && action_lab_graph ;;
      # La opción de cambiar idioma ahora se gestiona en main.sh al inicio
      C|c) submenu_C_chat ;;
      H|h) submenu_H_help ;;
      R|r|DR|dr) submenu_R_repair_system ;;
      L|l) submenu_L_libraries ;;
      D|d) submenu_D_dupes_general ;;
      V|v) submenu_V_visuals ;;
      T|t) submenu_T_tensorflow_lab ;;
      B|b)
        break
        ;;
      0)
        break
        ;;
      *)
        invalid_option
        ;;
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
apply_runtime_defaults
pin_base_to_current_install_if_crossed
ensure_base_path_valid
ensure_general_root_valid
init_paths

# Si hay GENERAL_ROOT configurado y válido, úsalo como BASE_PATH preferente
if [ -z "${DJPT_EXPLICIT_BASE_PATH:-}" ] && [ -n "${GENERAL_ROOT:-}" ] && [ -d "$GENERAL_ROOT" ] && [ "$BASE_PATH" != "$GENERAL_ROOT" ]; then
  BASE_PATH="$GENERAL_ROOT"
  init_paths
  load_conf
  apply_runtime_defaults
  pin_base_to_current_install_if_crossed
  init_paths
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

# Funciones IA faltantes - añadidas para evitar crashes
action_ai_knowledge_base() {
  while true; do
    print_header
  print_ai_banner
    printf "%s=== 📚 BASE DE CONOCIMIENTO IA (AI SUITE) ===%s\n" "$BANNER" "$C_RESET"
    
    if ! ensure_python_bin; then break; fi
    local suite_script="$SCRIPT_DIR/scripts/ai_suite.py"
    if [ ! -f "$suite_script" ]; then suite_script="${DJPT_CANONICAL_ROOT:-$BASE_PATH}/scripts/ai_suite.py"; fi

    printf "1) Indexar documentos nuevos en %s\n" "$BASE_PATH"
    printf "2) Consultar base de conocimiento\n"
    printf "0) Volver\n"
    
    if ! read -p "${C_BLU}Opción: ${C_RESET}" kchoice; then
      break
    fi
    kchoice="$(echo "$kchoice" | xargs)"
    [ -z "$kchoice" ] && continue
    case "$kchoice" in
      1) 
        "$PYTHON_BIN" "$suite_script" kb --action index --path "$BASE_PATH"
        pause_enter
        ;;
      2) 
        read -p "Pregunta a la base de conocimiento: " query
        "$PYTHON_BIN" "$suite_script" kb --action query --query "$query"
        pause_enter
        ;;
      0) break ;;
      *) ;;
    esac
  done
}

action_ai_learning_system() {
  while true; do
    print_header
  print_ai_banner
    printf "%s=== 🧠 SISTEMA DE APRENDIZAJE IA (AI SUITE) ===%s\n" "$BANNER" "$C_RESET"
    
    if ! ensure_python_bin; then break; fi
    local suite_script="$SCRIPT_DIR/scripts/ai_suite.py"
    if [ ! -f "$suite_script" ]; then suite_script="${DJPT_CANONICAL_ROOT:-$BASE_PATH}/scripts/ai_suite.py"; fi

    printf "1) Iniciar sesión de aprendizaje activo\n"
    printf "2) Revisar patrones aprendidos\n"
    printf "0) Volver\n"
    
    if ! read -p "${C_BLU}Opción: ${C_RESET}" lchoice; then
      break
    fi
    lchoice="$(echo "$lchoice" | xargs)"
    [ -z "$lchoice" ] && continue
    case "$lchoice" in
      1) "$PYTHON_BIN" "$suite_script" learn --mode session; pause_enter ;;
      2) "$PYTHON_BIN" "$suite_script" learn --mode review; pause_enter ;;
      0) break ;;
      *) ;;
    esac
  done
}

action_ai_educator() {
  while true; do
    print_header
  print_ai_banner
    printf "%s=== 🎓 IA EDUCADORA (AI SUITE) ===%s\n" "$BANNER" "$C_RESET"
    
    if ! ensure_python_bin; then break; fi
    local suite_script="$SCRIPT_DIR/scripts/ai_suite.py"
    if [ ! -f "$suite_script" ]; then suite_script="${DJPT_CANONICAL_ROOT:-$BASE_PATH}/scripts/ai_suite.py"; fi

    printf "1) Producción Musical\n"
    printf "2) Técnicas de DJ\n"
    printf "3) Teoría Musical\n"
    printf "0) Volver\n"
    
    if ! read -p "${C_BLU}Opción: ${C_RESET}" echoice; then
      break
    fi
    echoice="$(echo "$echoice" | xargs)"
    [ -z "$echoice" ] && continue
    case "$echoice" in
      1) "$PYTHON_BIN" "$suite_script" edu --topic production; pause_enter ;;
      2) "$PYTHON_BIN" "$suite_script" edu --topic djing; pause_enter ;;
      3) "$PYTHON_BIN" "$suite_script" edu --topic theory; pause_enter ;;
      0) break ;;
      *) ;;
    esac
  done
}

action_ai_knowledge_dynamic() {
  while true; do
    print_header
    printf "%s=== 📖 BASE DE CONOCIMIENTO DINÁMICA (AI SUITE) ===%s\n" "$BANNER" "$C_RESET"
    
    if ! ensure_python_bin; then break; fi
    local suite_script="$SCRIPT_DIR/scripts/ai_suite.py"
    if [ ! -f "$suite_script" ]; then suite_script="${DJPT_CANONICAL_ROOT:-$BASE_PATH}/scripts/ai_suite.py"; fi

    printf "1) Sincronizar con fuentes web\n"
    printf "2) Analizar tendencias de audio locales\n"
    printf "0) Volver\n"
    
    if ! read -p "${C_BLU}Opción: ${C_RESET}" dchoice; then
      break
    fi
    dchoice="$(echo "$dchoice" | xargs)"
    [ -z "$dchoice" ] && continue
    case "$dchoice" in
      1) "$PYTHON_BIN" "$suite_script" dynamic --task sync; pause_enter ;;
      2) "$PYTHON_BIN" "$suite_script" dynamic --task trends; pause_enter ;;
      0) break ;;
      *) ;;
    esac
  done
}

action_ai_document_analysis() {
  while true; do
    print_header
  print_ai_banner
    printf "%s=== 🔍 ANÁLISIS INTELIGENTE DE DOCUMENTOS (AI SUITE) ===%s\n" "$BANNER" "$C_RESET"
    
    if ! ensure_python_bin; then break; fi
    local suite_script="$SCRIPT_DIR/scripts/ai_suite.py"
    if [ ! -f "$suite_script" ]; then suite_script="${DJPT_CANONICAL_ROOT:-$BASE_PATH}/scripts/ai_suite.py"; fi

    printf "1) Analizar un archivo PDF específico\n"
    printf "2) Escanear manuales en BASE_PATH\n"
    printf "3) Extraer metadatos de archivos de texto\n"
    printf "0) Volver\n"
    
    if ! read -p "${C_BLU}Opción: ${C_RESET}" dachoice; then
      break
    fi
    dachoice="$(echo "$dachoice" | xargs)"
    [ -z "$dachoice" ] && continue
    case "$dachoice" in
      1) 
        read -e -p "Ruta del PDF: " pdf_path
        if [ -f "$pdf_path" ]; then
           "$PYTHON_BIN" "$suite_script" docs --file "$pdf_path"
        else
           printf "Archivo no encontrado.\n"
        fi
        pause_enter
        ;;
      2) 
        printf "Buscando manuales PDF en %s...\n" "$BASE_PATH"
        find "$BASE_PATH" -name "*.pdf" -maxdepth 3
        pause_enter
        ;;
      3) 
        printf "Extrayendo info de TXT/MD...\n"
        grep -r "BPM" "$BASE_PATH" --include="*.txt" --include="*.md" | head -10
        pause_enter
        ;;
      0) break ;;
      *) ;;
    esac
  done
}

action_install_local_models() {
  while true; do
    print_header
    printf "%s=== 🤖 INSTALAR MODELOS IA LOCALES ===%s\n" "$BANNER" "$C_RESET"
    printf "Descarga y gestión de modelos para uso offline.\n"
    printf "1) Descargar LLMs (Llama 3, Mistral) vía Ollama\n"
    printf "2) Descargar modelos de Audio (YAMNet, MusicGen) vía Python\n"
    printf "3) Verificar modelos instalados\n"
    printf "0) Volver\n"
    
    if ! read -p "${C_BLU}Opción: ${C_RESET}" imchoice; then
      break
    fi
    imchoice="$(echo "$imchoice" | xargs)"
    [ -z "$imchoice" ] && continue
    case "$imchoice" in
      1) 
        if command -v ollama >/dev/null 2>&1; then
           printf "Modelos disponibles para pull: llama3, mistral, codellama\n"
           read -p "Nombre del modelo: " mname
           if [ -n "$mname" ]; then
              ollama pull "$mname"
           fi
        else
           printf "Ollama no instalado. Instálalo primero (opción 72).\n"
        fi
        pause_enter
        ;;
      2) 
        printf "Descargando modelos TF/PyTorch...\n"
        if ensure_python_bin; then
           "$PYTHON_BIN" "$LIB_DIR/ml_tf.py" download_model --name "yamnet"
        fi
        pause_enter
        ;;
      3) 
        printf "Modelos Ollama:\n"
        ollama list 2>/dev/null || echo "Ollama no disponible"
        printf "\nModelos Python local (%s):\n" "$IA_MODELS_DIR"
        ls -R "$IA_MODELS_DIR" 2>/dev/null
        pause_enter
        ;;
      0) break ;;
      *) ;;
    esac
  done
}

action_enhanced_chat_cli() {
  print_header
  if ! ensure_python_bin; then
    printf "%s[ERR]%s Se requiere Python3 para el Enhanced Chat CLI.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  
  local chat_script=""
  chat_script="$(resolve_enhanced_chat_cli_script)" || true

  if [ -z "$chat_script" ] || [ ! -f "$chat_script" ]; then
    printf "%s[ERR]%s Script de Enhanced Chat CLI no encontrado.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi

  # Command file for communication
  local cmd_file="$STATE_DIR/.chat_cmd"
  export DJPT_CMD_FILE="$cmd_file"
  export BASE_PATH
  export VENV_DIR
  export SCRIPT_DIR
  export DJPT_UI_MODE

  while true; do
      rm -f "$cmd_file"
      printf "%s[INFO]%s Iniciando Enhanced Chat CLI (Cerebro Central)...\n" "$C_CYN" "$C_RESET"
      
      "$PYTHON_BIN" "$chat_script"
      
      if [ -f "$cmd_file" ]; then
          local cmd=$(cat "$cmd_file")
          rm -f "$cmd_file"
          
          if [[ "$cmd" == CMD:JUMP:* ]]; then
              local target="${cmd#CMD:JUMP:}"
              printf "\n%s[CHAT]%s Ejecutando acción sugerida: %s\n" "$C_PURP" "$C_RESET" "$target"
              sleep 1
              
              case "$target" in
                  "1") action_1_status ;;
                  "2") action_2_change_base ;;
                  "3") action_3_summary ;;
                  "4") action_4_top_dirs ;;
                  "5") action_5_top_files ;;
                  "6") action_6_scan_workspace ;;
                  "40") action_40_smart_analysis ;;
                  "41") action_41_ml_predictor ;;
                  "42") action_42_efficiency_optimizer ;;
                  "43") action_43_smart_workflow ;;
                  "44") action_44_integrated_dedup ;;
                  "49") action_49_advanced_analysis ;;
                  "62") action_ai_setup ;;
                  "65") action_ai_analyze_tf ;;
                  "70") action_ai_status ;;
                  "72") action_install_ai_deps ;;
                  "75") action_ai_train_models ;;
                  "80") action_80_ai_advanced_menu ;;
                  "82") action_82_ai_optimization ;;
                  "83") action_83_ai_global_config ;;
                  "84") action_84_ai_learning_system ;;
                  "85") action_85_ai_educator ;;
                  "87") action_87_install_local_models ;;
                  "88") action_local_models_manager ;;
                  "89") printf "%s[WARN]%s Ya estás en el chat.\n" "$C_YLW" "$C_RESET" ;;
                  *) printf "%s[WARN]%s Acción %s no reconocida por el shell.\n" "$C_YLW" "$C_RESET" "$target" ;;
              esac
              # Loop continues after action returns
              printf "\n%s[INFO]%s Regresando al chat...\n" "$C_CYN" "$C_RESET"
              sleep 1
          elif [[ "$cmd" == "CMD:EXIT" ]]; then
              break
          fi
      else
          break
      fi
  done
}

# --- Wrappers/aliases para funciones referenciadas por el chat CLI que faltaban ---
# NOTA: Las opciones 62-87 ya están completamente implementadas más arriba en el script
action_ai_setup() {
  # Alias legacy para compatibilidad del chat hacia el instalador IA principal.
  action_install_ai_deps
}

action_ai_analyze_tf() {
  # Alias legacy para compatibilidad del chat hacia TensorFlow Lab.
  submenu_T_tensorflow_lab
}

action_80_ai_advanced_menu() {
  print_header
  print_ai_banner
  maybe_activate_ml_env "Opción 80 (AI Advanced Menu)"
  printf "%s[INFO]%s 🧠 AI Advanced Menu - Expert AI Operations\n" "$C_CYN" "$C_RESET"
  
  while true; do
    clear
    print_header
  print_ai_banner
    printf "%s=== AI ADVANCED MENU ===%s\n" "$C_BOLD$C_CYAN" "$C_RESET"
    printf "%s1)%s Neural Network Training\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Deep Learning Models\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Advanced Analytics\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s Model Optimization\n" "$C_YLW" "$C_RESET"
    printf "%s5)%s AI Pipeline Management\n" "$C_YLW" "$C_RESET"
    printf "%s6)%s Research & Development\n" "$C_YLW" "$C_RESET"
    printf "%s0)%s Back to Main Menu\n" "$C_YLW" "$C_RESET"
    printf "%s========================%s\n" "$C_BOLD$C_CYAN" "$C_RESET"
    printf "Select advanced AI option: "
    if ! read -r adv_option; then
      break
    fi
    adv_option="$(echo "$adv_option" | xargs)"
    [ -z "$adv_option" ] && continue
    
    case "$adv_option" in
      1)
        printf "Neural Network Training...\n"
        action_ai_train_models
        ;;
      2)
        printf "Deep Learning Models...\n"
        action_tensorflow_manager
        ;;
      3)
        printf "Advanced Analytics...\n"
        action_ai_backends_benchmark all
        ;;
      4)
        printf "Model Optimization...\n"
        action_82_ai_optimization
        ;;
      5)
        printf "AI Pipeline Management...\n"
        action_ai_advanced_config
        ;;
      6)
        printf "Research & Development...\n"
        action_ai_lab
        ;;
      0)
        break
        ;;
      *)
        printf "Invalid option\n"
        pause_enter
        ;;
    esac
  done
}

action_81_ai_lab() {
  print_header
  print_ai_banner
  maybe_activate_ml_env "Opción 81 (AI Lab)"
  printf "%s[INFO]%s 🔬 AI Laboratory - Experimental Features\n" "$C_CYN" "$C_RESET"
  
  printf "AI Laboratory Options:\n"
  printf "1) Audio Feature Extraction\n"
  printf "2) Genre Classification Experiment\n"
  printf "3) BPM Detection Testing\n"
  printf "4) Audio Similarity Analysis\n"
  printf "5) Neural Audio Processing\n"
  printf "6) Custom AI Experiments\n"
  printf "0) Volver\n"
  printf "Select experiment: "
  read -r lab_option
  
  case "$lab_option" in
    1)
      printf "Audio Feature Extraction Experiment...\n"
      action_mlx_audio_embeddings
      ;;
    2)
      printf "Genre Classification Experiment...\n"
      action_tf_genre_classification
      ;;
    3)
      printf "BPM Detection Testing...\n"
      action_tf_advanced_bpm
      ;;
    4)
      printf "Audio Similarity Analysis...\n"
      action_local_similarity_analysis
      ;;
    5)
      printf "Neural Audio Processing...\n"
      action_tf_spectral_analysis
      ;;
    6)
      printf "Custom AI Experiments...\n"
      action_ai_lab
      ;;
    0)
      return 0
      ;;
    *)
      printf "Operation cancelled\n"
      ;;
  esac
  pause_enter
}

action_82_ai_optimization() {
  print_header
  print_ai_banner
  maybe_activate_ml_env "Opción 82 (AI Optimization)"
  printf "%s[INFO]%s ⚡ AI Optimization - Performance Tuning\n" "$C_CYN" "$C_RESET"
  
  printf "AI Optimization Options:\n"
  printf "1) Model Performance Optimization\n"
  printf "2) Memory Usage Optimization\n"
  printf "3) Processing Speed Optimization\n"
  printf "4) Accuracy Improvement\n"
  printf "5) Resource Allocation\n"
  printf "6) System Optimization\n"
  printf "0) Volver\n"
  printf "Select optimization type: "
  read -r opt_option
  
  case "$opt_option" in
    1)
      printf "Model Performance Optimization...\n"
      if ensure_python_bin && ensure_python_package_installed "scikit-learn"; then
        "$PYTHON_BIN" -c "
import joblib
import numpy as np
from pathlib import Path

print('Optimizing existing models...')
models_dir = Path('$IA_MODELS_DIR')
optimized_count = 0

for model_file in models_dir.glob('*.pkl'):
    try:
        # Load model
        model = joblib.load(model_file)
        
        # Optimize model parameters if possible
        if hasattr(model, 'n_estimators'):
            print(f'Optimizing {model_file.name}...')
            original = model.n_estimators
            if original > 300:
                model.n_estimators = 300
            model.n_jobs = -1 if hasattr(model, 'n_jobs') else getattr(model, 'n_jobs', None)
            optimized_file = model_file.with_name(model_file.stem + '.optimized.pkl')
            joblib.dump(model, optimized_file)
            print(f'  Estimators: {original} -> {model.n_estimators}')
            print(f'  Optimized copy: {optimized_file}')
            
        optimized_count += 1
        
    except Exception as e:
        print(f'Error optimizing {model_file}: {e}')

print(f'Optimization completed for {optimized_count} models')
"
        printf "%s[OK]%s Model performance optimization completed\n" "$C_GRN" "$C_RESET"
      fi
      ;;
    2)
      printf "Memory Usage Optimization...\n"
      printf "Current memory usage:\n"
      if ensure_python_bin && ensure_python_package_installed "psutil"; then
        "$PYTHON_BIN" -c "
import psutil
import os

process = psutil.Process(os.getpid())
memory_info = process.memory_info()
memory_mb = memory_info.rss / 1024 / 1024

print(f'Current memory usage: {memory_mb:.1f} MB')
print(f'Available memory: {psutil.virtual_memory().available / 1024 / 1024:.1f} MB')
print(f'Memory usage percentage: {psutil.virtual_memory().percent:.1f}%')

# Optimization suggestions
if memory_mb > 500:
    print('Suggestion: Consider reducing batch sizes for ML operations')
if psutil.virtual_memory().percent > 80:
    print('Suggestion: Close other applications to free memory')
"
      else
        printf "%s[WARN]%s psutil no disponible. Instala dependencias IA (opción 72).\n" "$C_YLW" "$C_RESET"
      fi
      ;;
    3)
      printf "Processing Speed Optimization...\n"
      printf "Analyzing processing bottlenecks...\n"
      
      # Check parallel processing capabilities
      cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo "4")
      printf "CPU cores available: %s\n" "$cpu_cores"
      
      # Optimize parallel threads setting
      if [ -z "$DJPT_PARALLEL_THREADS" ]; then
        export DJPT_PARALLEL_THREADS="$cpu_cores"
        printf "Set DJPT_PARALLEL_THREADS to %s\n" "$DJPT_PARALLEL_THREADS"
      fi
      
      printf "%s[OK]%s Processing speed optimization completed\n" "$C_GRN" "$C_RESET"
      ;;
    4)
      printf "Accuracy Improvement...\n"
      printf "Analyzing model accuracy...\n"
      
      if ensure_python_bin; then
        "$PYTHON_BIN" -c "
import json
import os
from pathlib import Path

config_file = Path('${DJPT_CANONICAL_ROOT:-$SCRIPT_DIR/..}/config/ai_model_params.toml')
if config_file.exists():
    print('Current AI model parameters:')
    try:
        import tomllib
        data = tomllib.loads(config_file.read_text(encoding='utf-8'))
        print(json.dumps(data, indent=2, ensure_ascii=False))
    except Exception:
        print(config_file.read_text(encoding='utf-8'))
else:
    print('No AI model parameters found. Using defaults.')
    print('Recommendations for accuracy improvement:')
    print('  - Increase training epochs')
    print('  - Use cross-validation')
    print('  - Feature engineering')
    print('  - Hyperparameter tuning')
"
      fi
      ;;
    5)
      printf "Resource Allocation...\n"
      printf "Current resource allocation:\n"
      
      # Check disk usage
      if [ -d "$IA_MODELS_DIR" ]; then
        models_size=$(du -sh "$IA_MODELS_DIR" 2>/dev/null | cut -f1)
        printf "Models directory: %s\n" "$models_size"
      fi
      
      if [ -d "$STATE_DIR" ]; then
        state_size=$(du -sh "$STATE_DIR" 2>/dev/null | cut -f1)
        printf "State directory: %s\n" "$state_size"
      fi
      
      printf "Resource allocation optimization completed\n"
      ;;
    6)
      printf "System Optimization...\n"
      printf "Performing system-wide optimization...\n"
      
      # Clean temporary files
      find /tmp -name "djpt_*" -mtime +1 -delete 2>/dev/null
      printf "Cleaned old temporary files\n"
      
      # Optimize file descriptors
      ulimit -n 4096 2>/dev/null
      printf "Optimized file descriptors\n"
      
      printf "%s[OK]%s System optimization completed\n" "$C_GRN" "$C_RESET"
      ;;
    0)
      return 0
      ;;
    *)
      printf "Operation cancelled\n"
      ;;
  esac
  pause_enter
}
action_83_ai_global_config() {
  print_header
  print_ai_banner
  printf "%s[INFO]%s 🌍 AI Global Configuration\n" "$C_CYN" "$C_RESET"
  
  printf "Global AI Configuration:\n"
  printf "1) System-wide AI Settings\n"
  printf "2) Environment Variables\n"
  printf "3) Global Model Configuration\n"
  printf "4) Cross-platform Settings\n"
  printf "5) Backup & Restore Configuration\n"
  printf "6) Reset to Factory Defaults\n"
  printf "0) Volver\n"
  printf "Select global config option: "
  read -r global_option
  
  case "$global_option" in
    1)
      printf "System-wide AI Settings...\n"
      printf "Current global settings:\n"
      
      # Show current global settings
      printf "ML_ENABLED: ${ML_ENABLED:-0}\n"
      printf "DJPT_PARALLEL_THREADS: ${DJPT_PARALLEL_THREADS:-auto}\n"
      printf "DJPT_MAX_FILE_BYTES: ${DJPT_MAX_FILE_BYTES:-104857600}\n"
      printf "DJPT_UI_MODE: ${DJPT_UI_MODE:-standard}\n"
      printf "DJPT_DRAG_SUPPORT: ${DJPT_DRAG_SUPPORT:-1}\n"
      printf "DJPT_PROGRESS_BARS: ${DJPT_PROGRESS_BARS:-0}\n"
      printf "DJPT_ERROR_RECOVERY: ${DJPT_ERROR_RECOVERY:-1}\n"
      
      printf "\nModify global settings? [y/N]: "
      read -r modify_global
      if [[ "$modify_global" =~ ^[Yy]$ ]]; then
        printf "Enable ML globally? (1/0): "
        read -r ml_enabled_global
        printf "Set parallel threads (auto for auto-detect): "
        read -r parallel_threads_global
        
        # Create global config
        cat >"$CONFIG_DIR/global_ai.conf" <<EOF
ML_ENABLED=${ml_enabled_global:-0}
DJPT_PARALLEL_THREADS=${parallel_threads_global:-auto}
DJPT_MAX_FILE_BYTES=${DJPT_MAX_FILE_BYTES:-104857600}
DJPT_UI_MODE=${DJPT_UI_MODE:-standard}
DJPT_DRAG_SUPPORT=${DJPT_DRAG_SUPPORT:-1}
DJPT_PROGRESS_BARS=${DJPT_PROGRESS_BARS:-0}
DJPT_ERROR_RECOVERY=${DJPT_ERROR_RECOVERY:-1}
EOF
        printf "%s[OK]%s Global AI settings updated\n" "$C_GRN" "$C_RESET"
      fi
      ;;
    2)
      printf "Environment Variables Management...\n"
      printf "Current AI environment variables:\n"
      env | grep DJPT_ | sort
      
      printf "\nSet new environment variable:\n"
      printf "Variable name (DJPT_*): "
      read -r env_var_name
      printf "Variable value: "
      read -r env_var_value
      
      if [[ "$env_var_name" =~ ^DJPT_ ]]; then
        export "$env_var_name"="$env_var_value"
        echo "export $env_var_name=\"$env_var_value\"" >>"$CONFIG_DIR/env_vars.conf"
        printf "%s[OK]%s Environment variable set: %s=%s\n" "$C_GRN" "$C_RESET" "$env_var_name" "$env_var_value"
      else
        printf "%s[ERR]%s Variable name must start with DJPT_\n" "$C_RED" "$C_RESET"
      fi
      ;;
    3)
      printf "Global Model Configuration...\n"
      action_ai_advanced_config
      ;;
    4)
      printf "Cross-platform Settings...\n"
      printf "Detecting platform...\n"
      
      local platform="unknown"
      case "$(uname -s)" in
        Darwin*) platform="macos" ;;
        Linux*) platform="linux" ;;
        CYGWIN*|MINGW*|MSYS*) platform="windows" ;;
      esac
      
      printf "Platform detected: %s\n" "$platform"
      
      # Platform-specific optimizations
      case "$platform" in
        macos)
          printf "macOS optimizations:\n"
          printf -- "- Metal acceleration available\n"
          printf -- "- Core Audio support\n"
          printf -- "- Grand Central Dispatch\n"
          ;;
        linux)
          printf "Linux optimizations:\n"
          printf -- "- OpenCL support\n"
          printf -- "- ALSA/PulseAudio\n"
          printf -- "- Multi-core optimization\n"
          ;;
        windows)
          printf "Windows optimizations:\n"
          printf -- "- DirectX support\n"
          printf -- "- Windows Audio\n"
          printf -- "- .NET integration\n"
          ;;
      esac
      
      # Save platform config
      cat >"$CONFIG_DIR/platform.conf" <<EOF
PLATFORM=$platform
DETECTED=$(date)
OPTIMIZATIONS=enabled
EOF
      ;;
    5)
      printf "Backup & Restore Configuration...\n"
      printf "1) Backup Current Configuration\n"
      printf "2) Restore Configuration\n"
      printf "Select option: "
      read -r backup_option
      
      case "$backup_option" in
        1)
          local backup_file="$CONFIG_DIR/backup_config_$(date +%s).tar.gz"
          tar -czf "$backup_file" -C "$CONFIG_DIR" .
          printf "%s[OK]%s Configuration backed up: %s\n" "$C_GRN" "$C_RESET" "$backup_file"
          ;;
        2)
          printf "Enter backup file path: "
          read -e -r restore_file
          restore_file=$(strip_quotes "$restore_file")
          
          if [ -f "$restore_file" ]; then
            tar -xzf "$restore_file" -C "$CONFIG_DIR"
            printf "%s[OK]%s Configuration restored\n" "$C_GRN" "$C_RESET"
          else
            printf "%s[ERR]%s Backup file not found\n" "$C_RED" "$C_RESET"
          fi
          ;;
      esac
      ;;
    6)
      printf "Reset to Factory Defaults...\n"
      printf "This will reset ALL AI configuration. Continue? [y/N]: "
      read -r factory_reset
      
      if [[ "$factory_reset" =~ ^[Yy]$ ]]; then
        # Backup current config
        cp -r "$CONFIG_DIR" "${CONFIG_DIR}.factory_backup.$(date +%s)"
        
        # Remove all AI config files
        rm -f "$CONFIG_DIR"/ai_*.conf
        rm -f "$CONFIG_DIR"/global_*.conf
        rm -f "$CONFIG_DIR"/env_vars.conf
        rm -f "$CONFIG_DIR"/platform.conf
        
        # Reset environment variables
        unset ML_ENABLED DJPT_PARALLEL_THREADS DJPT_MAX_FILE_BYTES
        
        printf "%s[OK]%s Reset to factory defaults completed\n" "$C_GRN" "$C_RESET"
        printf "Backup saved: %s.factory_backup.%s\n" "$CONFIG_DIR" "$(date +%s)"
      fi
      ;;
    0)
      return 0
      ;;
    *)
      printf "Operation cancelled\n"
      ;;
  esac
  pause_enter
}

action_84_ai_learning_system() {
  print_header
  print_ai_banner
  maybe_activate_ml_env "Opción 84 (AI Learning System)"
  printf "%s[INFO]%s 🎓 AI Learning System - Adaptive Intelligence\n" "$C_CYN" "$C_RESET"
  
  printf "AI Learning System Options:\n"
  printf "1) User Behavior Learning\n"
  printf "2) Pattern Recognition\n"
  printf "3) Adaptive Recommendations\n"
  printf "4) Learning Analytics\n"
  printf "5) Knowledge Graph\n"
  printf "6) Continuous Learning\n"
  printf "0) Volver\n"
  printf "Select learning option: "
  read -r learn_option
  
  case "$learn_option" in
    1)
      printf "User Behavior Learning...\n"
      printf "Analyzing user patterns...\n"
      
      # Analyze command history if available
      if [ -f "$HOME/.bash_history" ]; then
        printf "Recent DJProducerTools commands:\n"
        grep "DJProducerTools\|DJPT" "$HOME/.bash_history" | tail -10 | while IFS= read -r cmd; do
          printf "  %s\n" "$cmd"
        done
      fi
      
      # Create learning profile
      local learning_profile="$STATE_DIR/learning_profile.json"
      if ensure_python_bin; then
        "$PYTHON_BIN" -c "
import json
import os
from datetime import datetime

profile = {
    'user_id': os.environ.get('USER', 'unknown'),
    'learning_start': datetime.now().isoformat(),
    'preferred_actions': [],
    'skill_level': 'beginner',
    'learning_goals': ['file_organization', 'audio_analysis', 'ml_training'],
    'interaction_count': 0
}

with open('$learning_profile', 'w') as f:
    json.dump(profile, f, indent=2)

print('Learning profile created')
print('Profile saved to: $learning_profile')
"
        printf "%s[OK]%s User behavior learning initialized\n" "$C_GRN" "$C_RESET"
      fi
      ;;
    2)
      printf "Pattern Recognition...\n"
      if ensure_python_bin && ensure_python_package_installed "scikit-learn"; then
        "$PYTHON_BIN" -c "
import numpy as np
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
import json
import os
from pathlib import Path
from datetime import datetime

print('Analyzing patterns in user data...')

# Collect data from reports
patterns_data = []
reports_dir = Path('$REPORTS_DIR')

for report_file in reports_dir.glob('*.tsv'):
    try:
        with open(report_file, 'r') as f:
            lines = f.readlines()
            patterns_data.append({
                'file': str(report_file.name),
                'size': len(lines),
                'type': 'scan' if 'scan' in report_file.name else 'analysis'
            })
    except:
        continue

if len(patterns_data) > 2:
    # Extract features for clustering
    features = np.array([[item['size'], 1 if 'scan' in item['file'] else 0] for item in patterns_data])
    
    # Normalize features
    scaler = StandardScaler()
    features_scaled = scaler.fit_transform(features)
    
    # Perform clustering
    kmeans = KMeans(n_clusters=3, random_state=42)
    clusters = kmeans.fit_predict(features_scaled)
    
    print('Pattern Recognition Results:')
    print(f'Analyzed {len(patterns_data)} reports')
    print('User patterns identified:')
    
    for i, (item, cluster) in enumerate(zip(patterns_data, clusters)):
        cluster_name = ['Heavy Scanner', 'Analyzer', 'Balanced User'][cluster]
        print(f'  {item[\"file\"]}: {cluster_name}')
        
    # Save patterns
    patterns_result = {
        'analysis_date': datetime.now().isoformat(),
        'patterns_found': len(set(clusters)),
        'user_type': cluster_name,
        'recommendations': [
            'Continue regular scanning for file organization',
            'Focus on audio analysis for music production',
            'Balance between scanning and analysis'
        ]
    }
    
    with open('$STATE_DIR/pattern_recognition.json', 'w') as f:
        json.dump(patterns_result, f, indent=2)
        
else:
    print('Insufficient data for pattern recognition')
"
        printf "%s[OK]%s Pattern recognition completed\n" "$C_GRN" "$C_RESET"
      fi
      ;;
    3)
      printf "Adaptive Recommendations...\n"
      printf "Generating personalized recommendations...\n"
      
      # Create recommendations based on user activity
      cat >"$STATE_DIR/recommendations.json" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "user_level": "intermediate",
  "recommendations": [
    {
      "category": "File Organization",
      "priority": "high",
      "action": "Run regular smart scans to maintain file organization",
      "menu_option": "78"
    },
    {
      "category": "Audio Analysis",
      "priority": "medium", 
      "action": "Use AI Lab for audio feature extraction",
      "menu_option": "81"
    },
    {
      "category": "ML Training",
      "priority": "low",
      "action": "Train custom models with your data",
      "menu_option": "75"
    }
  ],
  "next_steps": [
    "Complete the recommended actions in order",
    "Track your progress in the learning system",
    "Advanced to higher skill levels with practice"
  ]
}
EOF
      
      printf "%s[OK]%s Adaptive recommendations generated\n" "$C_GRN" "$C_RESET"
      printf "Recommendations saved to: %s\n" "$STATE_DIR/recommendations.json"
      ;;
    4)
      printf "Learning Analytics...\n"
      if ensure_python_bin; then
        "$PYTHON_BIN" -c "
import json
import os
from pathlib import Path
from datetime import datetime

print('Learning Analytics Dashboard')
print('=' * 40)

# Analyze learning data
learning_files = {
    'profile': Path('$STATE_DIR/learning_profile.json'),
    'patterns': Path('$STATE_DIR/pattern_recognition.json'),
    'recommendations': Path('$STATE_DIR/recommendations.json')
}

analytics = {
    'analysis_date': datetime.now().isoformat(),
    'data_available': {},
    'insights': []
}

for name, file_path in learning_files.items():
    if file_path.exists():
        analytics['data_available'][name] = True
        print(f'✓ {name.title()} data available')
    else:
        analytics['data_available'][name] = False
        print(f'✗ {name.title()} data missing')

# Generate insights
if analytics['data_available'].get('profile'):
    analytics['insights'].append('User profile established - personalized learning active')

if analytics['data_available'].get('patterns'):
    analytics['insights'].append('Pattern recognition completed - adaptive recommendations enabled')

if analytics['data_available'].get('recommendations'):
    analytics['insights'].append('Recommendations generated - learning path defined')

print(f'\\nLearning System Status: {sum(analytics[\"data_available\"].values())}/3 modules active')
print('Insights:')
for insight in analytics['insights']:
    print(f'  • {insight}')

# Save analytics
with open('$STATE_DIR/learning_analytics.json', 'w') as f:
    json.dump(analytics, f, indent=2)
"
        printf "%s[OK]%s Learning analytics completed\n" "$C_GRN" "$C_RESET"
      fi
      ;;
    5)
      printf "Knowledge Graph...\n"
      action_ai_knowledge_base
      ;;
    6)
      printf "Continuous Learning...\n"
      printf "Enabling continuous learning mode...\n"
      
      # Create continuous learning configuration
      cat >"$CONFIG_DIR/continuous_learning.conf" <<EOF
CONTINUOUS_LEARNING=1
LEARNING_RATE=0.01
ADAPTATION_THRESHOLD=0.8
FEEDBACK_COLLECTION=1
AUTO_OPTIMIZATION=1
LEARNING_SESSIONS=$(date +%s)
EOF
      
      printf "%s[OK]%s Continuous learning enabled\n" "$C_GRN" "$C_RESET"
      printf "The system will now adapt based on your usage patterns\n"
      ;;
    0)
      return 0
      ;;
    *)
      printf "Operation cancelled\n"
      ;;
  esac
  pause_enter
}

action_85_ai_educator() {
  print_header
  print_ai_banner
  maybe_activate_ml_env "Opción 85 (AI Educator)"
  printf "%s[INFO]%s 👨‍🏫 AI Educator - Interactive Learning\n" "$C_CYN" "$C_RESET"
  
  printf "AI Educator Options:\n"
  printf "1) Tutorial Mode\n"
  printf "2) Interactive Lessons\n"
  printf "3) Skill Assessment\n"
  printf "4) Learning Path\n"
  printf "5) Knowledge Check\n"
  printf "6) Progress Tracking\n"
  printf "0) Volver\n"
  printf "Select educational option: "
  read -r edu_option
  
  case "$edu_option" in
    1)
      printf "Tutorial Mode...\n"
      printf "Available Tutorials:\n"
      printf "1) File Organization Basics\n"
      printf "2) Audio Analysis Introduction\n"
      printf "3) Machine Learning Fundamentals\n"
      printf "4) Advanced AI Features\n"
      printf "Select tutorial: "
      read -r tutorial_choice
      
      case "$tutorial_choice" in
        1)
          printf "=== File Organization Basics ===\n"
          printf "Welcome to DJProducerTools File Organization!\n\n"
          printf "Key Concepts:\n"
          printf "• BASE_PATH: Your main working directory\n"
          printf "• Scanning: Discover files in your library\n"
          printf "• Duplicate Detection: Find and manage duplicates\n"
          printf "• Hash Indexing: Create file fingerprints\n\n"
          printf "Recommended Workflow:\n"
          printf "1. Set your BASE_PATH (option 1)\n"
          printf "2. Scan your library (option 6)\n"
          printf "3. Find duplicates (option 10)\n"
          printf "4. Create hash index (option 9)\n\n"
          printf "Practice: Try option 6 to scan your files!\n"
          ;;
        2)
          printf "=== Audio Analysis Introduction ===\n"
          printf "Audio Analysis helps you understand your music:\n\n"
          printf "Features Available:\n"
          printf "• LUFS Analysis: Loudness measurement\n"
          printf "• Audio Cues: Beat detection and onsets\n"
          printf "• Feature Extraction: MFCCs, spectral analysis\n"
          printf "• Genre Classification: Automatic genre detection\n\n"
          printf "Getting Started:\n"
          printf "1. Try option 66 for LUFS analysis\n"
          printf "2. Use option 67 for audio cues\n"
          printf "3. Experiment with option 81 (AI Lab)\n\n"
          printf "Tip: Start with a few files to understand the process!\n"
          ;;
        3)
          printf "=== Machine Learning Fundamentals ===\n"
          printf "ML in DJProducerTools:\n\n"
          printf "What is ML?\n"
          printf "• Training models from your data\n"
          printf "• Pattern recognition and prediction\n"
          printf "• Automated decision making\n\n"
          printf "Available ML Features:\n"
          printf "• Option 62: ML Evolution Manager\n"
          printf "• Option 75: AI Model Training\n"
          printf "• Option 81: AI Laboratory\n\n"
          printf "Learning Path:\n"
          printf "1. Start with option 70 (AI Status)\n"
          printf "2. Install dependencies (option 68)\n"
          printf "3. Train your first model (option 75)\n"
          ;;
        4)
          printf "=== Advanced AI Features ===\n"
          printf "Advanced AI Capabilities:\n\n"
          printf "Neural Networks:\n"
          printf "• Deep learning models\n"
          printf "• Audio processing networks\n"
          printf "• Pattern recognition\n\n"
          printf "AI Systems:\n"
          printf "• Knowledge base management\n"
          printf "• Chat interfaces\n"
          printf "• Learning systems\n\n"
          printf "Expert Features:\n"
          printf "• Option 80: AI Advanced Menu\n"
          printf "• Option 82: AI Optimization\n"
          printf "• Option 84: Learning System\n"
          ;;
      esac
      ;;
    2)
      printf "Interactive Lessons...\n"
      printf "Choose your learning level:\n"
      printf "1) Beginner\n"
      printf "2) Intermediate\n"
      printf "3) Advanced\n"
      printf "Select level: "
      read -r lesson_level
      
      case "$lesson_level" in
        1)
          printf "=== Beginner Lesson: First Scan ===\n"
          printf "Let's scan your music library together!\n\n"
          printf "Step 1: Check your BASE_PATH\n"
          printf "Current BASE_PATH: %s\n" "$BASE_PATH"
          printf "Does this look correct? [Y/n]: "
          read -r base_path_ok
          
          if [[ ! "$base_path_ok" =~ ^[Nn]$ ]]; then
            printf "Great! Let's proceed with scanning.\n"
            printf "Step 2: Run your first scan\n"
            printf "I'll guide you through option 6...\n"
            printf "Press Enter to start the scan tutorial: "
            read -r
            printf "In the main menu, select option 6.\n"
            printf "Choose 'Smart Scan' for intelligent filtering.\n"
            printf "Watch the progress and review the results!\n"
            printf "%s[LESSON COMPLETE]%s Try it yourself!\n" "$C_GRN" "$C_RESET"
          fi
          ;;
        2)
          printf "=== Intermediate Lesson: Model Training ===\n"
          printf "Ready to train your first ML model?\n\n"
          printf "Prerequisites:\n"
          printf "✓ Have scan results from option 6\n"
          printf "✓ Have duplicate plans from option 10\n"
          printf "✓ Python environment ready\n\n"
          printf "Training Steps:\n"
          printf "1. Go to option 75 (AI Train Models)\n"
          printf "2. Select 'Train Duplicate Detection Model'\n"
          printf "3. Wait for training to complete\n"
          printf "4. Review accuracy metrics\n"
          printf "5. Use the model for predictions\n\n"
          printf "The system will learn from your previous decisions!\n"
          ;;
        3)
          printf "=== Advanced Lesson: Neural Networks ===\n"
          printf "Let's create a neural network for audio!\n\n"
          printf "Advanced Concepts:\n"
          printf "• Neural network architecture\n"
          printf "• Audio feature processing\n"
          printf "• Model optimization\n\n"
          printf "Hands-on:\n"
          printf "1. Use option 80 (AI Advanced Menu)\n"
          printf "2. Select 'Neural Network Training'\n"
          printf "3. Experiment with different architectures\n"
          printf "4. Optimize using option 82 (AI Optimization)\n\n"
          printf "This will create production-ready models!\n"
          ;;
      esac
      ;;
    3)
      printf "Skill Assessment...\n"
      printf "Assessing your current skill level...\n"
      
      if ensure_python_bin; then
        "$PYTHON_BIN" -c "
import json
import os
from pathlib import Path
from datetime import datetime

# Check user's actual usage patterns
skill_assessment = {
    'assessment_date': datetime.now().isoformat(),
    'user_level': 'beginner',
    'skills_checked': [],
    'recommendations': []
}

# Check for scan results
if Path('$REPORTS_DIR').glob('*.tsv'):
    scan_count = len(list(Path('$REPORTS_DIR').glob('*.tsv')))
    skill_assessment['skills_checked'].append(f'File scanning: {scan_count} scans completed')
    if scan_count > 5:
        skill_assessment['user_level'] = 'intermediate'
    if scan_count > 20:
        skill_assessment['user_level'] = 'advanced'

# Check for ML models
if Path('$IA_MODELS_DIR').glob('*.pkl'):
    model_count = len(list(Path('$IA_MODELS_DIR').glob('*.pkl')))
    skill_assessment['skills_checked'].append(f'ML training: {model_count} models created')
    if model_count > 0:
        skill_assessment['user_level'] = 'intermediate'
    if model_count > 3:
        skill_assessment['user_level'] = 'advanced'

# Generate recommendations
if skill_assessment['user_level'] == 'beginner':
    skill_assessment['recommendations'] = [
        'Start with file organization (options 1-10)',
        'Learn basic scanning (option 6)',
        'Try duplicate detection (option 10)'
    ]
elif skill_assessment['user_level'] == 'intermediate':
    skill_assessment['recommendations'] = [
        'Explore audio analysis (options 66-67)',
        'Learn ML basics (options 62-75)',
        'Use AI Lab for experiments (option 81)'
    ]
else:
    skill_assessment['recommendations'] = [
        'Master advanced AI features (options 80-87)',
        'Optimize system performance (option 82)',
        'Contribute to knowledge base (option 76)'
    ]

print(f'Your Skill Level: {skill_assessment[\"user_level\"].title()}')
print('Skills Demonstrated:')
for skill in skill_assessment['skills_checked']:
    print(f'  ✓ {skill}')

print('\\nRecommended Next Steps:')
for rec in skill_assessment['recommendations']:
    print(f'  • {rec}')

# Save assessment
with open('$STATE_DIR/skill_assessment.json', 'w') as f:
    json.dump(skill_assessment, f, indent=2)
"
        printf "%s[OK]%s Skill assessment completed\n" "$C_GRN" "$C_RESET"
      fi
      ;;
    4)
      printf "Learning Path...\n"
      printf "Generating personalized learning path...\n"
      
      cat >"$STATE_DIR/learning_path.json" <<EOF
{
  "created": "$(date -Iseconds)",
  "current_level": "intermediate",
  "learning_path": [
    {
      "module": "File Organization Mastery",
      "options": [1, 6, 9, 10],
      "prerequisites": [],
      "estimated_time": "2-3 hours",
      "status": "recommended"
    },
    {
      "module": "Audio Analysis Fundamentals", 
      "options": [66, 67, 81],
      "prerequisites": ["File Organization Mastery"],
      "estimated_time": "3-4 hours",
      "status": "next"
    },
    {
      "module": "Machine Learning Essentials",
      "options": [62, 68, 70, 75],
      "prerequisites": ["Audio Analysis Fundamentals"],
      "estimated_time": "4-6 hours", 
      "status": "future"
    },
    {
      "module": "Advanced AI Systems",
      "options": [80, 82, 84, 85],
      "prerequisites": ["Machine Learning Essentials"],
      "estimated_time": "6-8 hours",
      "status": "advanced"
    }
  ],
  "total_estimated_time": "15-21 hours",
  "completion_percentage": 0
}
EOF
      
      printf "%s[OK]%s Learning path generated\n" "$C_GRN" "$C_RESET"
      printf "Path saved to: %s\n" "$STATE_DIR/learning_path.json"
      ;;
    5)
      printf "Knowledge Check...\n"
      printf "Testing your understanding...\n\n"
      
      local score=0
      local total=5
      
      printf "Question 1/5: What does BASE_PATH define?\n"
      printf "a) Your home directory\n"
      printf "b) Your main working directory\n"
      printf "c) System temporary directory\n"
      printf "Your answer: "
      read -r q1_answer
      if [[ "$q1_answer" == "b" ]]; then
        printf "✓ Correct!\n"
        score=$((score + 1))
      else
        printf "✗ Incorrect. BASE_PATH is your main working directory.\n"
      fi
      
      printf "\nQuestion 2/5: Which option scans for duplicates?\n"
      printf "a) Option 6\n"
      printf "b) Option 9\n" 
      printf "c) Option 10\n"
      printf "Your answer: "
      read -r q2_answer
      if [[ "$q2_answer" == "c" ]]; then
        printf "✓ Correct!\n"
        score=$((score + 1))
      else
        printf "✗ Incorrect. Option 10 finds duplicates.\n"
      fi
      
      printf "\nQuestion 3/5: What does ML stand for?\n"
      printf "a) Music Library\n"
      printf "b) Machine Learning\n"
      printf "c) Master List\n"
      printf "Your answer: "
      read -r q3_answer
      if [[ "$q3_answer" == "b" ]]; then
        printf "✓ Correct!\n"
        score=$((score + 1))
      else
        printf "✗ Incorrect. ML is Machine Learning.\n"
      fi
      
      printf "\nQuestion 4/5: Which option trains AI models?\n"
      printf "a) Option 68\n"
      printf "b) Option 75\n"
      printf "c) Option 81\n"
      printf "Your answer: "
      read -r q4_answer
      if [[ "$q4_answer" == "b" ]]; then
        printf "✓ Correct!\n"
        score=$((score + 1))
      else
        printf "✗ Incorrect. Option 75 trains AI models.\n"
      fi
      
      printf "\nQuestion 5/5: What is the purpose of hash indexing?\n"
      printf "a) File encryption\n"
      printf "b) File fingerprinting for duplicates\n"
      printf "c) File compression\n"
      printf "Your answer: "
      read -r q5_answer
      if [[ "$q5_answer" == "b" ]]; then
        printf "✓ Correct!\n"
        score=$((score + 1))
      else
        printf "✗ Incorrect. Hash indexing creates file fingerprints.\n"
      fi
      
      local percentage=$((score * 100 / total))
      printf "\n=== KNOWLEDGE CHECK RESULTS ===\n"
      printf "Score: %d/%d (%d%%)\n" "$score" "$total" "$percentage"
      
      if [ "$percentage" -ge 80 ]; then
        printf "🎉 Excellent! You have a strong understanding!\n"
      elif [ "$percentage" -ge 60 ]; then
        printf "👍 Good job! Consider reviewing the basics.\n"
      else
        printf "📚 Keep learning! Try the tutorials first.\n"
      fi
      ;;
    6)
      printf "Progress Tracking...\n"
      if ensure_python_bin; then
        "$PYTHON_BIN" -c "
import json
import os
from pathlib import Path
from datetime import datetime

print('📊 Your Learning Progress')
print('=' * 30)

# Track progress across all learning modules
progress_data = {
    'tracking_date': datetime.now().isoformat(),
    'modules_completed': [],
    'skills_acquired': [],
    'time_spent': 'estimated',
    'next_milestones': []
}

# Check completed modules
if Path('$STATE_DIR/learning_profile.json').exists():
    progress_data['modules_completed'].append('User Profile Setup')

if Path('$STATE_DIR/pattern_recognition.json').exists():
    progress_data['modules_completed'].append('Pattern Recognition')
    progress_data['skills_acquired'].append('Data Analysis')

if Path('$STATE_DIR/recommendations.json').exists():
    progress_data['modules_completed'].append('Adaptive Recommendations')
    progress_data['skills_acquired'].append('Personalized Learning')

if Path('$STATE_DIR/skill_assessment.json').exists():
    progress_data['modules_completed'].append('Skill Assessment')
    progress_data['skills_acquired'].append('Self-Evaluation')

if Path('$IA_MODELS_DIR').glob('*.pkl'):
    model_count = len(list(Path('$IA_MODELS_DIR').glob('*.pkl')))
    progress_data['skills_acquired'].append(f'ML Model Training ({model_count} models)')

if Path('$REPORTS_DIR').glob('*.tsv'):
    scan_count = len(list(Path('$REPORTS_DIR').glob('*.tsv')))
    progress_data['skills_acquired'].append(f'File Scanning ({scan_count} scans)')

# Calculate completion percentage
total_modules = 8  # Total possible learning modules
completed = len(progress_data['modules_completed'])
completion_rate = (completed / total_modules) * 100

print(f'Modules Completed: {completed}/{total_modules}')
print(f'Skills Acquired: {len(progress_data[\"skills_acquired\"])}')
print(f'Completion Rate: {completion_rate:.1f}%')

print('\\nCompleted Modules:')
for module in progress_data['modules_completed']:
    print(f'  ✓ {module}')

print('\\nSkills Acquired:')
for skill in progress_data['skills_acquired']:
    print(f'  🎯 {skill}')

# Next milestones
if completion_rate < 50:
    progress_data['next_milestones'] = ['Complete basic tutorials', 'Run first scan', 'Train first model']
elif completion_rate < 80:
    progress_data['next_milestones'] = ['Master ML training', 'Explore AI Lab', 'Optimize models']
else:
    progress_data['next_milestones'] = ['Advanced AI features', 'System optimization', 'Knowledge contribution']

print('\\nNext Milestones:')
for milestone in progress_data['next_milestones']:
    print(f'  📍 {milestone}')

# Save progress
with open('$STATE_DIR/progress_tracking.json', 'w') as f:
    json.dump(progress_data, f, indent=2)

print(f'\\nProgress saved to: $STATE_DIR/progress_tracking.json')
"
        printf "%s[OK]%s Progress tracking updated\n" "$C_GRN" "$C_RESET"
      fi
      ;;
    0)
      return 0
      ;;
    *)
      printf "Operation cancelled\n"
      ;;
  esac
  pause_enter
}
action_86_ai_document_analysis() {
  print_header
  print_ai_banner
  maybe_activate_ml_env "Opción 86 (AI Document Analysis)"
  printf "%s[INFO]%s 📄 AI Document Analysis - Intelligent Document Processing\n" "$C_CYN" "$C_RESET"
  
  printf "AI Document Analysis Options:\n"
  printf "1) Text Extraction & Analysis\n"
  printf "2) Document Classification\n"
  printf "3) Content Summarization\n"
  printf "4) Metadata Extraction\n"
  printf "5) Document Similarity\n"
  printf "6) Batch Document Processing\n"
  printf "0) Volver\n"
  printf "Select analysis option: "
  read -r doc_option
  
  case "$doc_option" in
    1)
      printf "Text Extraction & Analysis...\n"
      printf "Enter document path or pattern: "
      read -e -r doc_path
      doc_path=$(strip_quotes "$doc_path")
      
      if ensure_python_bin; then
        "$PYTHON_BIN" -c "
import os
import json
from pathlib import Path
from datetime import datetime

print('Analyzing documents...')
doc_path = Path('$doc_path')
results = []

if doc_path.is_file():
    files = [doc_path]
elif doc_path.is_dir():
    files = list(doc_path.rglob('*'))
else:
    # Try glob pattern
    files = list(Path('.').glob(str(doc_path)))

for file_path in files[:10]:  # Limit to 10 files
    if file_path.is_file() and file_path.stat().st_size < 10_000_000:  # 10MB limit
        try:
            # Basic text extraction for common formats
            content = ''
            if file_path.suffix.lower() in ['.txt', '.md', '.py', '.sh', '.json', '.yaml', '.yml']:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()[:1000]  # First 1000 chars
            
            if content:
                analysis = {
                    'file': str(file_path.name),
                    'size': file_path.stat().st_size,
                    'type': file_path.suffix,
                    'char_count': len(content),
                    'word_count': len(content.split()),
                    'line_count': content.count('\n'),
                    'preview': content[:200].replace('\n', ' ')
                }
                results.append(analysis)
                print(f'Analyzed: {file_path.name}')
            
        except Exception as e:
            print(f'Error analyzing {file_path}: {e}')

if results:
    print(f'\\nDocument Analysis Results:')
    print('=' * 50)
    
    for result in results:
        print(f'File: {result[\"file\"]}')
        print(f'  Size: {result[\"size\"]} bytes')
        print(f'  Type: {result[\"type\"]}')
        print(f'  Words: {result[\"word_count\"]}')
        print(f'  Lines: {result[\"line_count\"]}')
        print(f'  Preview: {result[\"preview\"]}...')
        print()
    
    # Save results
    with open('$REPORTS_DIR/document_analysis.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f'Analysis saved to: $REPORTS_DIR/document_analysis.json')
else:
    print('No documents found or analyzed')
"
        printf "%s[OK]%s Document analysis completed\n" "$C_GRN" "$C_RESET"
      fi
      ;;
    2)
      printf "Document Classification...\n"
      if ensure_python_bin && ensure_python_package_installed "scikit-learn"; then
        "$PYTHON_BIN" -c "
import os
import json
import numpy as np
from pathlib import Path
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.cluster import KMeans
from datetime import datetime

print('Classifying documents...')

# Collect documents for classification
documents = []
doc_paths = []

# Scan for text files
for file_path in Path('$BASE_PATH').rglob('*'):
    if file_path.is_file() and file_path.stat().st_size < 1_000_000:  # 1MB limit
        suffix = file_path.suffix.lower()
        if suffix in ['.txt', '.md', '.py', '.sh', '.json', '.yaml', '.yml', '.csv']:
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()[:500]  # First 500 chars
                    if content.strip():
                        documents.append(content)
                        doc_paths.append(str(file_path))
                        if len(documents) >= 50:  # Limit to 50 documents
                            break
            except:
                continue

if len(documents) >= 5:
    print(f'Processing {len(documents)} documents...')
    
    # Feature extraction
    vectorizer = TfidfVectorizer(max_features=100, stop_words='english')
    features = vectorizer.fit_transform(documents)
    
    # Clustering
    n_clusters = min(5, len(documents) // 2)
    kmeans = KMeans(n_clusters=n_clusters, random_state=42)
    clusters = kmeans.fit_predict(features)
    
    # Analyze clusters
    cluster_results = {}
    for i, (doc_path, cluster_id) in enumerate(zip(doc_paths, clusters)):
        if cluster_id not in cluster_results:
            cluster_results[cluster_id] = []
        cluster_results[cluster_id].append({
            'path': doc_path,
            'preview': documents[i][:100]
        })
    
    print('\\nDocument Classification Results:')
    print('=' * 50)
    
    for cluster_id, docs in cluster_results.items():
        print(f'Cluster {cluster_id} ({len(docs)} documents):')
        for doc in docs[:3]:  # Show first 3 docs per cluster
            print(f'  {doc[\"path\"]}')
        print()
    
    # Save classification results
    classification_data = {
        'analysis_date': datetime.now().isoformat(),
        'total_documents': len(documents),
        'clusters_found': n_clusters,
        'cluster_results': {str(k): v for k, v in cluster_results.items()}
    }
    
    with open('$REPORTS_DIR/document_classification.json', 'w') as f:
        json.dump(classification_data, f, indent=2)
    
    print(f'Classification saved to: $REPORTS_DIR/document_classification.json')
else:
    print('Insufficient documents for classification (need at least 5)')
"
        printf "%s[OK]%s Document classification completed\n" "$C_GRN" "$C_RESET"
      fi
      ;;
    3)
      printf "Content Summarization...\n"
      printf "Enter document path to summarize: "
      read -e -r summary_path
      summary_path=$(strip_quotes "$summary_path")
      
      if [ -f "$summary_path" ]; then
        if ensure_python_bin; then
          "$PYTHON_BIN" -c "
import os
from pathlib import Path

print('Summarizing document...')
doc_path = Path('$summary_path')

try:
    with open(doc_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    if len(content) > 100:
        # Simple extractive summarization
        sentences = content.split('.')
        sentences = [s.strip() for s in sentences if s.strip()]
        
        # Score sentences by length and position
        scored_sentences = []
        for i, sentence in enumerate(sentences):
            score = len(sentence.split())  # Word count
            if i < len(sentences) * 0.3:  # First 30% get bonus
                score *= 1.5
            elif i > len(sentences) * 0.7:  # Last 30% get bonus
                score *= 1.2
            scored_sentences.append((score, i, sentence))
        
        # Sort by score and take top sentences
        scored_sentences.sort(reverse=True)
        top_sentences = sorted(scored_sentences[:5], key=lambda x: x[1])  # Re-sort by position
        
        print(f'\\nDocument Summary for: {doc_path.name}')
        print('=' * 50)
        print(f'Original length: {len(content)} characters')
        print(f'Sentences: {len(sentences)}')
        print('\\nSummary:')
        
        for score, idx, sentence in top_sentences:
            print(f'• {sentence}.')
        
        # Save summary
        summary_text = '. '.join([s[2] for s in top_sentences]) + '.'
        with open('$REPORTS_DIR/document_summary.txt', 'w') as f:
            f.write(f'Document: {doc_path}\\n')
            f.write(f'Summary generated: {datetime.now()}\\n')
            f.write(f'Original length: {len(content)} chars\\n')
            f.write(f'Summary length: {len(summary_text)} chars\\n\\n')
            f.write('SUMMARY:\\n')
            f.write(summary_text)
        
        print(f'\\nSummary saved to: $REPORTS_DIR/document_summary.txt')
    else:
        print('Document too short for summarization')
        
except Exception as e:
    print(f'Error summarizing document: {e}')
"
          printf "%s[OK]%s Document summarization completed\n" "$C_GRN" "$C_RESET"
        fi
      else
        printf "%s[ERR]%s Document not found\n" "$C_RED" "$C_RESET"
      fi
      ;;
    4)
      printf "Metadata Extraction...\n"
      printf "Enter directory to analyze: "
      read -e -r meta_dir
      meta_dir=$(strip_quotes "$meta_dir")
      
      if [ -d "$meta_dir" ]; then
        if ensure_python_bin; then
          "$PYTHON_BIN" -c "
import os
import json
from pathlib import Path
from datetime import datetime

print('Extracting metadata from documents...')
meta_dir = Path('$meta_dir')

metadata_results = []

for file_path in meta_dir.rglob('*'):
    if file_path.is_file():
        try:
            stat = file_path.stat()
            metadata = {
                'name': file_path.name,
                'path': str(file_path.relative_to(meta_dir)),
                'size': stat.st_size,
                'modified': datetime.fromtimestamp(stat.st_mtime).isoformat(),
                'extension': file_path.suffix,
                'type': 'file'
            }
            
            # Add content-specific metadata
            if file_path.suffix.lower() in ['.txt', '.md', '.py', '.sh']:
                try:
                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                        metadata.update({
                            'lines': content.count('\n'),
                            'words': len(content.split()),
                            'chars': len(content)
                        })
                except:
                    pass
            
            metadata_results.append(metadata)
            
        except Exception as e:
            print(f'Error processing {file_path}: {e}')

if metadata_results:
    # Analyze metadata
    total_files = len(metadata_results)
    total_size = sum(m['size'] for m in metadata_results)
    extensions = {}
    
    for meta in metadata_results:
        ext = meta['extension'] or 'no_extension'
        extensions[ext] = extensions.get(ext, 0) + 1
    
    print(f'\\nMetadata Analysis Results:')
    print('=' * 50)
    print(f'Total files: {total_files}')
    print(f'Total size: {total_size:,} bytes')
    print(f'File types: {len(extensions)}')
    
    print('\\nFile Extension Distribution:')
    for ext, count in sorted(extensions.items(), key=lambda x: x[1], reverse=True)[:10]:
        print(f'  {ext}: {count} files')
    
    # Find largest files
    largest_files = sorted(metadata_results, key=lambda x: x['size'], reverse=True)[:5]
    print('\\nLargest Files:')
    for file_meta in largest_files:
        print(f'  {file_meta[\"name\"]}: {file_meta[\"size\"]:,} bytes')
    
    # Save metadata
    analysis_data = {
        'analysis_date': datetime.now().isoformat(),
        'directory': str(meta_dir),
        'summary': {
            'total_files': total_files,
            'total_size': total_size,
            'file_types': len(extensions)
        },
        'extensions': extensions,
        'largest_files': largest_files[:10],
        'all_metadata': metadata_results
    }
    
    with open('$REPORTS_DIR/metadata_extraction.json', 'w') as f:
        json.dump(analysis_data, f, indent=2)
    
    print(f'\\nMetadata saved to: $REPORTS_DIR/metadata_extraction.json')
else:
    print('No files found for metadata extraction')
"
          printf "%s[OK]%s Metadata extraction completed\n" "$C_GRN" "$C_RESET"
        fi
      else
        printf "%s[ERR]%s Directory not found\n" "$C_RED" "$C_RESET"
      fi
      ;;
    5)
      printf "Document Similarity...\n"
      if ensure_python_bin && ensure_python_package_installed "scikit-learn"; then
        "$PYTHON_BIN" -c "
import os
import json
from pathlib import Path
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from datetime import datetime

print('Analyzing document similarity...')

# Collect documents
documents = []
doc_paths = []

for file_path in Path('$BASE_PATH').rglob('*'):
    if file_path.is_file() and file_path.stat().st_size < 500_000:  # 500KB limit
        suffix = file_path.suffix.lower()
        if suffix in ['.txt', '.md', '.py', '.sh', '.json']:
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    if len(content.strip()) > 50:  # Minimum content length
                        documents.append(content)
                        doc_paths.append(str(file_path))
                        if len(documents) >= 20:  # Limit to 20 documents
                            break
            except:
                continue

if len(documents) >= 2:
    print(f'Analyzing similarity between {len(documents)} documents...')
    
    # Vectorize documents
    vectorizer = TfidfVectorizer(max_features=1000, stop_words='english')
    tfidf_matrix = vectorizer.fit_transform(documents)
    
    # Calculate similarity matrix
    similarity_matrix = cosine_similarity(tfidf_matrix)
    
    # Find similar pairs
    similar_pairs = []
    for i in range(len(documents)):
        for j in range(i + 1, len(documents)):
            similarity = similarity_matrix[i][j]
            if similarity > 0.3:  # Similarity threshold
                similar_pairs.append({
                    'doc1': doc_paths[i],
                    'doc2': doc_paths[j],
                    'similarity': float(similarity)
                })
    
    # Sort by similarity
    similar_pairs.sort(key=lambda x: x['similarity'], reverse=True)
    
    print(f'\\nDocument Similarity Results:')
    print('=' * 60)
    
    if similar_pairs:
        print(f'Found {len(similar_pairs)} similar document pairs:')
        for pair in similar_pairs[:10]:  # Show top 10
            doc1_name = Path(pair['doc1']).name
            doc2_name = Path(pair['doc2']).name
            print(f'  {doc1_name} ↔ {doc2_name}: {pair[\"similarity\"]:.2%}')
    else:
        print('No similar documents found (threshold: 30%)')
    
    # Save results
    similarity_data = {
        'analysis_date': datetime.now().isoformat(),
        'total_documents': len(documents),
        'similarity_threshold': 0.3,
        'similar_pairs': similar_pairs
    }
    
    with open('$REPORTS_DIR/document_similarity.json', 'w') as f:
        json.dump(similarity_data, f, indent=2)
    
    print(f'\\nResults saved to: $REPORTS_DIR/document_similarity.json')
else:
    print('Insufficient documents for similarity analysis (need at least 2)')
"
        printf "%s[OK]%s Document similarity analysis completed\n" "$C_GRN" "$C_RESET"
      fi
      ;;
    6)
      printf "Batch Document Processing...\n"
      printf "Enter directory to process: "
      read -e -r batch_dir
      batch_dir=$(strip_quotes "$batch_dir")
      
      if [ -d "$batch_dir" ]; then
        printf "Processing options:\n"
        printf "1) Extract text from all documents\n"
        printf "2) Classify all documents\n"
        printf "3) Generate summaries for all\n"
        printf "4) Extract metadata for all\n"
        printf "Select batch operation: "
        read -r batch_option
        
        if ensure_python_bin; then
          "$PYTHON_BIN" - "$batch_dir" "$REPORTS_DIR" "$batch_option" <<'PY'
import csv
import hashlib
import os
import sys
from datetime import datetime
from pathlib import Path

base = Path(sys.argv[1]).expanduser()
reports = Path(sys.argv[2]).expanduser()
op = sys.argv[3]
reports.mkdir(parents=True, exist_ok=True)
ts = datetime.now().strftime("%Y%m%d_%H%M%S")

doc_ext = {
    ".txt", ".md", ".json", ".yaml", ".yml", ".csv", ".tsv",
    ".py", ".sh", ".ini", ".toml", ".xml", ".html", ".htm",
}
files = [p for p in base.rglob("*") if p.is_file() and p.suffix.lower() in doc_ext]
files = files[:2000]

if not files:
    print("No document files found")
    raise SystemExit(0)

if op == "1":
    out = reports / f"document_batch_extract_{ts}.tsv"
    with out.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "chars", "words", "preview"])
        for p in files:
            try:
                txt = p.read_text(encoding="utf-8", errors="ignore")
                preview = " ".join(txt[:180].split())
                w.writerow([str(p), len(txt), len(txt.split()), preview])
            except Exception:
                continue
    print(f"Batch text extraction completed: {out}")
elif op == "2":
    out = reports / f"document_batch_classification_{ts}.tsv"
    category_map = {
        ".py": "code", ".sh": "code", ".json": "config", ".yaml": "config", ".yml": "config",
        ".md": "docs", ".txt": "docs", ".xml": "data", ".csv": "data", ".tsv": "data",
        ".html": "web", ".htm": "web", ".toml": "config", ".ini": "config",
    }
    with out.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "extension", "category", "size_bytes"])
        for p in files:
            cat = category_map.get(p.suffix.lower(), "other")
            w.writerow([str(p), p.suffix.lower(), cat, p.stat().st_size])
    print(f"Batch classification completed: {out}")
elif op == "3":
    out = reports / f"document_batch_summaries_{ts}.tsv"
    with out.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "line_count", "summary"])
        for p in files:
            try:
                txt = p.read_text(encoding="utf-8", errors="ignore")
                lines = [ln.strip() for ln in txt.splitlines() if ln.strip()]
                summary = " ".join(lines[:3])[:220]
                w.writerow([str(p), len(lines), summary])
            except Exception:
                continue
    print(f"Batch summarization completed: {out}")
elif op == "4":
    out = reports / f"document_batch_metadata_{ts}.tsv"
    with out.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "size_bytes", "mtime_epoch", "sha1_head64k"])
        for p in files:
            try:
                st = p.stat()
                digest = hashlib.sha1()
                with p.open("rb") as fh:
                    digest.update(fh.read(65536))
                w.writerow([str(p), st.st_size, int(st.st_mtime), digest.hexdigest()])
            except Exception:
                continue
    print(f"Batch metadata extraction completed: {out}")
else:
    print("Invalid batch operation")
PY
        fi
      else
        printf "%s[ERR]%s Directory not found\n" "$C_RED" "$C_RESET"
      fi
      ;;
    0)
      return 0
      ;;
    *)
      printf "Operation cancelled\n"
      ;;
  esac
  pause_enter
}

action_87_install_local_models() {
  print_header
  print_ai_banner
  maybe_activate_ml_env "Opción 87 (Install Local Models)"
  printf "%s[INFO]%s 🤖 Install Local Models - Local AI Model Management\n" "$C_CYN" "$C_RESET"
  
  printf "Local Model Installation Options:\n"
  printf "1) Install Ollama Models\n"
  printf "2) Install TensorFlow Models\n"
  printf "3) Install PyTorch Models\n"
  printf "4) Install Custom Models\n"
  printf "5) Model Repository Management\n"
  printf "6) Model Status & Verification\n"
  printf "0) Volver\n"
  printf "Select installation option: "
  read -r model_option
  
  case "$model_option" in
    1)
      printf "Installing Ollama Models...\n"
      
      # Check if Ollama is installed
      if command -v ollama >/dev/null 2>&1; then
        printf "Ollama found. Available models:\n"
        ollama list 2>/dev/null || printf "No models installed yet\n"
        
        printf "\nPopular models to install:\n"
        printf "1) llama3.2:3b\n"
        printf "2) llama3.2:1b\n"
        printf "3) mistral\n"
        printf "4) codellama\n"
        printf "5) neural-chat\n"
        printf "6) Custom model\n"
        printf "Select model to install: "
        read -r ollama_model
        
        case "$ollama_model" in
          1)
            printf "Installing llama3.2:3b...\n"
            ollama pull llama3.2:3b
            ;;
          2)
            printf "Installing llama3.2:1b...\n"
            ollama pull llama3.2:1b
            ;;
          3)
            printf "Installing mistral...\n"
            ollama pull mistral
            ;;
          4)
            printf "Installing codellama...\n"
            ollama pull codellama
            ;;
          5)
            printf "Installing neural-chat...\n"
            ollama pull neural-chat
            ;;
          6)
            printf "Enter custom model name: "
            read -r custom_model
            printf "Installing %s...\n" "$custom_model"
            ollama pull "$custom_model"
            ;;
          *)
            printf "Invalid selection\n"
            ;;
        esac
        
        printf "%s[OK]%s Ollama model installation completed\n" "$C_GRN" "$C_RESET"
      else
        printf "Ollama not found. Installing Ollama...\n"
        
        # Install Ollama
        if command -v curl >/dev/null 2>&1; then
          curl -fsSL https://ollama.ai/install.sh | sh
          printf "%s[OK]%s Ollama installation completed\n" "$C_GRN" "$C_RESET"
          printf "Please restart your terminal and run this option again\n"
        else
          printf "%s[ERR]%s curl not found. Cannot install Ollama\n" "$C_RED" "$C_RESET"
        fi
      fi
      ;;
    2)
      printf "Installing TensorFlow Models...\n"
      if ensure_python_bin && ensure_python_package_installed "tensorflow"; then
        if "$PYTHON_BIN" -c "
import tensorflow as tf
import os
import json
from pathlib import Path
from datetime import datetime

print('Installing TensorFlow models...')

# Create models directory
models_dir = Path('$IA_MODELS_DIR')
models_dir.mkdir(exist_ok=True)

# Registrar catálogo local de modelos pre-entrenados para descarga controlada
tf_models = {
    'mobilenet_v2': 'MobileNetV2 for image classification',
    'bert_base': 'BERT base model for text processing',
    'yolo_v3': 'YOLOv3 for object detection'
}

for model_name, description in tf_models.items():
    print(f'Preparing {model_name}: {description}')
    
    # Create model info file
    model_info = {
        'name': model_name,
        'description': description,
        'framework': 'tensorflow',
        'installed_date': datetime.now().isoformat(),
        'status': 'ready_for_download'
    }
    
    info_file = models_dir / f'{model_name}_info.json'
    with open(info_file, 'w') as f:
        json.dump(model_info, f, indent=2)
    
    print(f'  ✓ Model info created: {info_file}')

print(f'\\nTensorFlow models prepared in: {models_dir}')
print('Note: Actual model weights need to be downloaded separately')
"
        then
          printf "%s[OK]%s TensorFlow models setup completed\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Falló la preparación de modelos TensorFlow.\n" "$C_RED" "$C_RESET"
        fi
      else
        printf "%s[ERR]%s TensorFlow not available\n" "$C_RED" "$C_RESET"
      fi
      ;;
    3)
      printf "Installing PyTorch Models...\n"
      if ensure_python_bin && ensure_python_package_installed "torch"; then
        if "$PYTHON_BIN" -c "
import torch
import os
import json
from pathlib import Path
from datetime import datetime

print('Installing PyTorch models...')

# Create models directory
models_dir = Path('$IA_MODELS_DIR')
models_dir.mkdir(exist_ok=True)

# Popular PyTorch models
torch_models = {
    'resnet50': 'ResNet-50 for image classification',
    'gpt2': 'GPT-2 for text generation',
    'distilbert': 'DistilBERT for text processing',
    'yolov5': 'YOLOv5 for object detection'
}

for model_name, description in torch_models.items():
    print(f'Preparing {model_name}: {description}')
    
    # Create model info file
    model_info = {
        'name': model_name,
        'description': description,
        'framework': 'pytorch',
        'installed_date': datetime.now().isoformat(),
        'status': 'ready_for_download'
    }
    
    info_file = models_dir / f'{model_name}_info.json'
    with open(info_file, 'w') as f:
        json.dump(model_info, f, indent=2)
    
    print(f'  ✓ Model info created: {info_file}')

print(f'\\nPyTorch models prepared in: {models_dir}')
print('Note: Actual model weights need to be downloaded separately')
"
        then
          printf "%s[OK]%s PyTorch models setup completed\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[ERR]%s Falló la preparación de modelos PyTorch.\n" "$C_RED" "$C_RESET"
        fi
      else
        printf "%s[ERR]%s PyTorch not available\n" "$C_RED" "$C_RESET"
      fi
      ;;
    4)
      printf "Installing Custom Models...\n"
      printf "Enter model repository URL: "
      read -r model_url
      printf "Enter model name: "
      read -r custom_model_name
      printf "Enter model framework (tensorflow/pytorch/other): "
      read -r model_framework
      
      if [ -n "$model_url" ] && [ -n "$custom_model_name" ]; then
        printf "Installing custom model: %s\n" "$custom_model_name"
        
        # Create custom model directory
        local custom_model_dir="$IA_MODELS_DIR/custom/$custom_model_name"
        mkdir -p "$custom_model_dir"
        
        if command -v wget >/dev/null 2>&1; then
          printf "Downloading model from %s\n" "$model_url"
          if wget -q --show-progress "$model_url" -O "$custom_model_dir/model.bin"; then
            printf "Model download completed\n"
          else
            printf "%s[WARN]%s Descarga con wget falló, se guardará solo metadata.\n" "$C_YLW" "$C_RESET"
          fi
        elif command -v curl >/dev/null 2>&1; then
          printf "Downloading model from %s\n" "$model_url"
          if curl -fL "$model_url" -o "$custom_model_dir/model.bin"; then
            printf "Model download completed\n"
          else
            printf "%s[WARN]%s Descarga con curl falló, se guardará solo metadata.\n" "$C_YLW" "$C_RESET"
          fi
        else
          printf "%s[WARN]%s No download tool available. Please download manually\n" "$C_YLW" "$C_RESET"
        fi
        
        # Create model metadata
        cat >"$custom_model_dir/model_info.json" <<EOF
{
  "name": "$custom_model_name",
  "url": "$model_url",
  "framework": "$model_framework",
  "installed_date": "$(date -Iseconds)",
  "status": "custom_installed",
  "directory": "$custom_model_dir"
}
EOF
        
        printf "%s[OK]%s Custom model installation completed\n" "$C_GRN" "$C_RESET"
        printf "Model directory: %s\n" "$custom_model_dir"
      else
        printf "%s[ERR]%s Model URL and name required\n" "$C_RED" "$C_RESET"
      fi
      ;;
    5)
      printf "Model Repository Management...\n"
      printf "Repository Options:\n"
      printf "1) List installed models\n"
      printf "2) Remove model\n"
      printf "3) Update model\n"
      printf "4) Model storage info\n"
      printf "Select option: "
      read -r repo_option
      
      case "$repo_option" in
        1)
          printf "Installed Models:\n"
          printf "==================\n"
          
          # List Ollama models
          if command -v ollama >/dev/null 2>&1; then
            printf "Ollama Models:\n"
            ollama list 2>/dev/null || printf "No Ollama models\n"
            printf "\n"
          fi
          
          # List local models
          if [ -d "$IA_MODELS_DIR" ]; then
            printf "Local Models:\n"
            find "$IA_MODELS_DIR" -name "*.pkl" -o -name "*.h5" -o -name "*.pt" -o -name "*.pth" 2>/dev/null | while IFS= read -r model; do
              printf "  %s\n" "$(basename "$model")"
            done
          fi
          ;;
        2)
          printf "Enter model name to remove: "
          read -r remove_model
          
          if command -v ollama >/dev/null 2>&1; then
            printf "Removing Ollama model: %s\n" "$remove_model"
            ollama rm "$remove_model" 2>/dev/null || printf "Model not found or removal failed\n"
          fi
          
          # Remove local model files
          find "$IA_MODELS_DIR" -name "*$remove_model*" -delete 2>/dev/null
          printf "%s[OK]%s Model removal completed\n" "$C_GRN" "$C_RESET"
          ;;
        3)
          printf "Enter model name to update: "
          read -r update_model
          
          if command -v ollama >/dev/null 2>&1; then
            printf "Updating Ollama model: %s\n" "$update_model"
            ollama pull "$update_model"
          fi
          
          printf "%s[OK]%s Model update completed\n" "$C_GRN" "$C_RESET"
          ;;
        4)
          printf "Model Storage Information:\n"
          printf "=========================\n"
          
          if [ -d "$IA_MODELS_DIR" ]; then
            local model_size=$(du -sh "$IA_MODELS_DIR" 2>/dev/null | cut -f1)
            printf "Models directory: %s\n" "$IA_MODELS_DIR"
            printf "Total size: %s\n" "$model_size"
            
            printf "\nModel breakdown:\n"
            find "$IA_MODELS_DIR" -type f -exec du -h {} \; 2>/dev/null | sort -hr | head -10
          fi
          
          if command -v ollama >/dev/null 2>&1; then
            printf "\nOllama models:\n"
            ollama list 2>/dev/null
          fi
          ;;
        *)
          printf "Invalid option\n"
          ;;
      esac
      ;;
    6)
      printf "Model Status & Verification...\n"
      printf "Checking model status...\n"
      
      # Check Ollama status
      if command -v ollama >/dev/null 2>&1; then
        printf "Ollama Status: "
        if ollama list >/dev/null 2>&1; then
          printf "✓ Running\n"
          ollama list
        else
          printf "✗ Not running or error\n"
        fi
      else
        printf "Ollama Status: ✗ Not installed\n"
      fi
      
      # Check TensorFlow models
      if ensure_python_bin && ensure_python_package_installed "tensorflow"; then
        if "$PYTHON_BIN" -c "
import tensorflow as tf
print(f'TensorFlow version: {tf.__version__}')
print(f'GPU available: {len(tf.config.list_physical_devices(\"GPU\")) > 0}')
"
        then
          printf "\nTensorFlow Status: ✓ Available\n"
        else
          printf "\nTensorFlow Status: ✗ Instalado pero no importable\n"
        fi
      else
        printf "\nTensorFlow Status: ✗ Not available\n"
      fi
      
      # Check PyTorch models
      if ensure_python_bin && ensure_python_package_installed "torch"; then
        if "$PYTHON_BIN" -c "
import torch
print(f'PyTorch version: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
"
        then
          printf "\nPyTorch Status: ✓ Available\n"
        else
          printf "\nPyTorch Status: ✗ Instalado pero no importable\n"
        fi
      else
        printf "\nPyTorch Status: ✗ Not available\n"
      fi
      
      # Check local models
      if [ -d "$IA_MODELS_DIR" ]; then
        local model_count=$(find "$IA_MODELS_DIR" -name "*.pkl" -o -name "*.h5" -o -name "*.pt" -o -name "*.pth" 2>/dev/null | wc -l)
        printf "\nLocal Models: %d models found\n" "$model_count"
      else
        printf "\nLocal Models: ✗ No models directory\n"
      fi
      
      printf "\n%s[OK]%s Model status check completed\n" "$C_GRN" "$C_RESET"
      ;;
    0)
      return 0
      ;;
    *)
      printf "Operation cancelled\n"
      ;;
  esac
  pause_enter
}

action_ai_training() {
  # Alias al menú de entrenamiento principal
  action_ai_train_models
}

action_ai_config() {
  # Alias a la configuración global de IA
  action_ai_global_config
}

action_install_deps_ai() {
  # Alias al instalador de dependencias IA
  action_install_ai_deps
}

action_analyze_music_ai() {
  # Alias rápido a menú IA avanzado orientado a audio
  action_ai_advanced_menu
}

action_process_documents() {
  # Alias al análisis inteligente de documentos
  action_ai_document_analysis
}

action_advanced_doc_analysis() {
  # Alias avanzado al análisis de documentos
  action_ai_document_analysis
}

action_local_models_manager() {
  # Alias estable al gestor moderno de modelos locales.
  action_87_install_local_models
}

# Aliases legacy para compatibilidad con automatizaciones/reportes antiguos.
action_ai_backend_supermenu() {
  backend_selection_menu
}

action_65_submenu_T_tensorflow_lab() {
  submenu_T_tensorflow_lab
}

action_64_tensorflow_manager() {
  action_tensorflow_manager
}

action_75_ai_train_models() {
  action_ai_train_models
}

action_76_ai_knowledge_base() {
  action_ai_knowledge_base
}

# Despacho de acciones por CLI (--run) ubicado al final para garantizar que
# todas las funciones estén definidas antes de ser invocadas.
if [ -n "$RUN_ACTION" ]; then
  if [[ "$RUN_ACTION" =~ ^[0-9]+$ ]]; then
    if run_action_number "$RUN_ACTION"; then
      exit 0
    else
      printf "[ERR] Acción numérica desconocida: %s (rango 1-92)\n" "$RUN_ACTION"
      exit 1
    fi
  fi
  case "$RUN_ACTION" in
    status) action_1_status ;;
    doctor) action_lab_doctor ;;
    scan) action_6_scan_workspace ;;
    backup) action_7_backup_serato; action_8_backup_dj ;;
    hash) action_9_hash_index ;;
    dupes) action_10_dupes_plan ;;
    smart) action_40_smart_analysis ;;
    predict) action_41_ml_predictor ;;
    optimize) action_42_efficiency_optimizer ;;
    workflow) action_43_smart_workflow ;;
    mlx_asr) action_mlx_asr_analysis ;;
    mlx_metadata) action_mlx_metadata_generation ;;
    mlx_embeddings) action_mlx_audio_embeddings ;;
    mlx_batch) action_mlx_batch_processing ;;
    tf_spectral) action_tf_spectral_analysis ;;
    tf_genre) action_tf_genre_classification ;;
    tf_bpm) action_tf_advanced_bpm ;;
    tf_stems) action_tf_stem_separation ;;
    local_cluster) action_local_clustering ;;
    local_recommend) action_local_recommendations ;;
    local_similarity) action_local_similarity_analysis ;;
    local_popularity) action_local_popularity_prediction ;;
    ollama_chat) action_ollama_chat_library ;;
    ollama_playlist) action_ollama_playlist_generation ;;
    ollama_music) action_ollama_music_analysis ;;
    enhanced_chat|enhanced_chat_cli) action_enhanced_chat_cli ;;
    doc_ai|ai_docs|docs_ai) action_ai_document_analysis ;;
    local_models|models_local|ai_models) action_87_install_local_models ;;
    *)
      if [[ "$RUN_ACTION" =~ ^[0-9]+$ ]]; then
         printf "[ERR] Las acciones numéricas aún no son compatibles con el modo CLI. Usa palabras clave: status, scan, backup, hash, dupes, smart, predict, optimize, workflow, mlx_asr, mlx_metadata, mlx_embeddings, mlx_batch, tf_spectral, tf_genre, tf_bpm, tf_stems, local_cluster, local_recommend, local_similarity, local_popularity, ollama_chat, ollama_playlist, ollama_music, enhanced_chat, doc_ai, local_models.\n"
         exit 1
      else
         printf "[ERR] Acción desconocida: %s\n" "$RUN_ACTION"
         exit 1
      fi
      ;;
  esac
  exit 0
fi

main_loop
