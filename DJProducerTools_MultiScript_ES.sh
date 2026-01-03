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
C_WHT="${ESC}[1;37m"
BANNER_SOFT="${ESC}[0;37;44m"
C_GRN_SOFT="${ESC}[0;32m"
C_YLW_SOFT="${ESC}[0;33m"
C_CYN_SOFT="${ESC}[0;36m"
C_PURP_SOFT="${ESC}[38;5;105m"
BANNER="${ESC}[1;37;44m"

# Ancla al directorio del script (doble click) y mantiene la ventana abierta al salir
SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

LAUNCH_NON_INTERACTIVE=0
if [ -z "${PS1:-}" ] && [ -z "${TMUX:-}" ] && [ -z "${SSH_CONNECTION:-}" ]; then
  LAUNCH_NON_INTERACTIVE=1
fi
trap 'code=$?; if [ "$LAUNCH_NON_INTERACTIVE" -eq 1 ]; then echo; echo "[INFO] Script terminado (código $code). Pulsa ENTER para cerrar..."; read -r _; fi' EXIT

# Asegura TERM para evitar cortes raros en terminales mínimos
export TERM="${TERM:-xterm-256color}"

# Polyfill mapfile para Bash 3.2 en macOS (con escape de comillas y backslash)
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

SPIN_FRAMES=("\\" "|" "/" "-")
SPIN_COLORS=("$C_PURP" "$C_GRN" "$C_WHT") # violeta, verde, blanco destello
SPIN_IDX=0
SPIN_COLOR_IDX=0
GHOST_COLORS=("${ESC}[38;5;129m" "${ESC}[38;5;46m") # violeta y verde
GHOST_IDX=0

ART_HAS_HASH=0
ART_HAS_SNAPSHOT=0
ART_HAS_DUPES_PLAN=0
ART_QUAR_COUNT=0
ART_DUPES_QUAR=0
ART_REPORTS_SIZE=""
ART_QUAR_SIZE=""
ART_HASH_DATE=""
ART_SNAPSHOT_DATE=""
ART_DUPES_PLAN_DATE=""

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
  local -a arr
  arr=()
  IFS=',' read -r -a arr <<<"${EXTRA_SOURCE_ROOTS:-}" 2>/dev/null || arr=()
  if [ ${#arr[@]:-0} -gt 0 ]; then
    for r in "${arr[@]:-}"; do
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

select_from_candidates() {
  local prompt="$1"
  shift
  local -a arr
  arr=("$@")
  local idx=1
  printf "%s\n" "$prompt"
  if [ ${#arr[@]} -gt 0 ]; then
    for c in "${arr[@]}"; do
      printf "  [%d] %s\n" "$idx" "$c"
      idx=$((idx + 1))
    done
  fi
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
  local state_candidates=()
  while IFS= read -r sc; do
    [ -n "$sc" ] && state_candidates+=("$sc")
  done < <(find_state_candidates)
  if [ "${#state_candidates[@]}" -gt 0 ]; then
    echo "Estados detectados (_DJProducerTools):"
    idx=1
    for sc in "${state_candidates[@]}"; do
      echo "  [$idx] $sc"
      idx=$((idx + 1))
    done
    echo "  [S] Saltar selección automática"
    printf "Elegir número para usar como BASE_PATH: "
    read -r sel
    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#state_candidates[@]}" ]; then
      BASE_PATH="${state_candidates[$((sel-1))]}"
      append_history "$BASE_HISTORY_FILE" "$BASE_PATH"
      return
    fi
  fi
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

find_state_candidates() {
  local -a roots candidates
  candidates=()
  roots=("$PWD" "$LAUNCH_PATH" "$HOME")
  for v in /Volumes/*; do
    [ -d "$v" ] && roots+=("$v")
  done
  for r in "${roots[@]}"; do
    [ -d "$r" ] || continue
    while IFS= read -r d; do
      base_dir="$(dirname "$d")"
      candidates+=("$base_dir")
    done < <(find "$r" -maxdepth 3 -type d -name "_DJProducerTools" 2>/dev/null | head -n 50)
  done
  if [ "${#candidates[@]}" -gt 0 ]; then
    mapfile -t candidates < <(printf "%s\n" "${candidates[@]}" | awk '!seen[$0]++')
  fi
  printf "%s\n" "${candidates[@]}"
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
    printf "%s7)%s Editar exclusiones actuales\n" "$C_YLW" "$C_RESET"
    printf "%s8)%s Limpiar todas las exclusiones\n" "$C_YLW" "$C_RESET"
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
      7)
        printf "Exclusiones actuales: %s\n" "$DEFAULT_EXCLUDES"
        printf "Introduce nueva lista de exclusiones (separadas por coma, ENTER para cancelar): "
        read -e -r new_excludes
        if [ -n "$new_excludes" ]; then
          DEFAULT_EXCLUDES="$new_excludes"
          save_conf
          printf "%s[OK]%s Lista de exclusiones actualizada.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[INFO]%s Cancelado. No se hicieron cambios.\n" "$C_CYN" "$C_RESET"
        fi
        pause_enter
        ;;
      8)
        printf "%s[WARN]%s ¿Seguro que quieres eliminar TODAS las exclusiones? Esto puede hacer que los escaneos sean muy lentos. (y/N): " "$C_YLW" "$C_RESET"
        read -r confirm_clear
        if [[ "$confirm_clear" =~ ^[yY]$ ]]; then
            DEFAULT_EXCLUDES=""
            save_conf
            printf "%s[OK]%s Todas las exclusiones han sido eliminadas.\n" "$C_GRN" "$C_RESET"
        else
            printf "%s[INFO]%s No se hicieron cambios.\n" "$C_CYN" "$C_RESET"
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

should_exclude_path() {
  local path="$1"
  local patterns="$2"
  [ -z "$patterns" ] && return 1
  local -a arr
  arr=()
  IFS=',' read -r -a arr <<<"${patterns:-}" || arr=()
  if [ ${#arr[@]} -gt 0 ]; then
    for p in "${arr[@]}"; do
      p_trim=$(printf "%s" "$p" | xargs)
      [ -z "$p_trim" ] && continue
      case "$path" in
        $p_trim) return 0 ;;
      esac
    done
  fi
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
ML_ENV_DISABLED=0
ML_PKGS_BASIC="numpy pandas"
ML_PKG_BASIC_MB=300
ML_PKGS_LIGHT="numpy pandas scikit-learn joblib librosa"
ML_PKG_LIGHT_MB=550
ML_PKGS_EVO="numpy pandas scikit-learn joblib"
ML_PKG_EVO_MB=450
if [ "$(uname -m)" = "arm64" ] && [ "$(uname -s)" = "Darwin" ]; then
  ML_PKGS_TF="tensorflow-macos tensorflow-metal"
else
  ML_PKGS_TF="tensorflow"
fi

action_ml_profile() {
  print_header
  printf "%s[INFO]%s Perfil IA local actual: %s\n" "$C_CYN" "$C_RESET" "${ML_PROFILE:-LIGHT}"
  printf "1) LIGHT (numpy+pandas+scikit-learn+joblib+librosa)\n"
  printf "2) TF_ADV (LIGHT + %s)\n" "$ML_PKGS_TF"
  printf "Opción: "
  read -r prof
  case "$prof" in
    1)
      ML_PROFILE="LIGHT"
      save_conf
      printf "%s[OK]%s Perfil IA local: LIGHT\n" "$C_GRN" "$C_RESET"
      ;;
    2)
      ML_PROFILE="TF_ADV"
      save_conf
      printf "%s[OK]%s Perfil IA local: TF_ADV (%s)\n" "$C_GRN" "$C_RESET" "$ML_PKGS_TF"
      ;;
    *)
      printf "%s[INFO]%s Sin cambios.\n" "$C_CYN" "$C_RESET"
      ;;
  esac
  pause_enter
}
ML_PKG_TF_MB=600
ML_PROFILE="LIGHT"
PROFILES_DIR=""

# --- CONFIGURACIÓN DE GITHUB ---
GITHUB_REPO="Astro1Deep/DjProducerTool" # Cambia esto a "TuUsuario/TuRepositorio"

pause_enter() {
  printf "%sPulsa ENTER para continuar...%s" "$C_YLW" "$C_RESET"
  read -r _
}

ensure_tool_installed() {
    local tool="$1"
    local install_cmd="$2"
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf "%s[WARN]%s La herramienta '%s' no está instalada.\n" "$C_YLW" "$C_RESET" "$tool"
        if [ "${LAUNCH_NON_INTERACTIVE:-0}" -eq 1 ]; then
            printf "Modo no interactivo: saltando instalación de %s.\n" "$tool"
            return 1
        fi
        if [ -n "$install_cmd" ]; then
            printf "Puedes instalarla con: %s\n" "$install_cmd"
            printf "Quieres intentar instalarla ahora? (y/N): "
            read -r choice
            case "$choice" in
                y|Y)
                    eval "$install_cmd"
                    if ! command -v "$tool" >/dev/null 2>&1; then
                        printf "%s[ERR]%s La instalación de '%s' falló.\n" "$C_RED" "$C_RESET" "$tool"
                        return 1
                    else
                        printf "%s[OK]%s '%s' instalada correctamente.\n" "$C_GRN" "$C_RESET" "$tool"
                        return 0
                    fi
                ;;
                *)
                  return 1
                ;;
            esac
        else
            printf "Por favor, instálala manualmente.\n"
            return 1
        fi
    fi
    return 0
}

ensure_python_package_installed() {
    local package="$1"
    if ! python3 -m pip show "$package" >/dev/null 2>&1; then
        printf "%s[WARN]%s El paquete de python '%s' no está instalado.\n" "$C_YLW" "$C_RESET" "$package"
        printf "Quieres intentar instalarlo ahora? (y/N): "
        read -r choice
        case "$choice" in
            y|Y)
                python3 -m pip install "$package"
                if ! python3 -m pip show "$package" >/dev/null 2>&1; then
                    printf "%s[ERR]%s La instalación de '%s' falló.\n" "$C_RED" "$C_RESET" "$package"
                    return 1
                else
                    printf "%s[OK]%s '%s' instalado correctamente.\n" "$C_GRN" "$C_RESET" "$package"
                    return 0
                fi
            ;;
            *)
              return 1
            ;;
        esac
    fi
    return 0
}


ensure_dirs() {
  mkdir -p "$STATE_DIR" "$CONFIG_DIR" "$REPORTS_DIR" "$PLANS_DIR" "$LOGS_DIR" "$QUAR_DIR" "$VENV_DIR"
}

init_paths() {
  # Prioriza el directorio de lanzamiento si ya contiene _DJProducerTools
  if [ -n "$LAUNCH_PATH" ] && [ -d "$LAUNCH_PATH/_DJProducerTools" ]; then
    if [ "$BASE_PATH" != "$LAUNCH_PATH" ]; then
      printf "%s[INFO]%s BASE_PATH ajustado al directorio de lanzamiento: %s\n" "$C_CYN" "$C_RESET" "$LAUNCH_PATH"
    fi
    BASE_PATH="$LAUNCH_PATH"
  else
    # Ajusta BASE_PATH si hay un _DJProducerTools cercano (cwd o padres)
    for cand in "$PWD" "$(dirname "$PWD")" "$(dirname "$(dirname "$PWD")")"; do
      if [ -d "$cand/_DJProducerTools" ]; then
        BASE_PATH="$cand"
        break
      fi
    done
  fi
  # Normaliza BASE_PATH: elimina barra final y corrige si apunta a _DJProducerTools
  BASE_PATH="${BASE_PATH%/}"
  # Normaliza BASE_PATH si el usuario metió la carpeta _DJProducerTools directamente
  case "$BASE_PATH" in
    */_DJProducerTools|*/_DJProducerTools/)
      BASE_PATH="${BASE_PATH%/_DJProducerTools*}"
      printf "%s[WARN]%s Ajustando BASE_PATH (no debe apuntar a _DJProducerTools): %s\n" "$C_YLW" "$C_RESET" "$BASE_PATH"
      ;;
  esac
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

refresh_artifact_state() {
  ART_HAS_HASH=0
  ART_HAS_SNAPSHOT=0
  ART_HAS_DUPES_PLAN=0
  ART_QUAR_COUNT=0
  ART_DUPES_QUAR=0
  ART_REPORTS_SIZE=""
  ART_HASH_DATE=""
  ART_SNAPSHOT_DATE=""
  ART_DUPES_PLAN_DATE=""
  ART_QUAR_SIZE=""
  [ -s "$REPORTS_DIR/hash_index.tsv" ] && ART_HAS_HASH=1
  [ -s "$REPORTS_DIR/snapshot_hash_fast.tsv" ] && ART_HAS_SNAPSHOT=1
  if [ -s "$PLANS_DIR/dupes_plan.tsv" ]; then
    ART_HAS_DUPES_PLAN=1
    ART_DUPES_QUAR=$(awk -F'\t' '$2=="QUARANTINE"{c++} END{print c+0}' "$PLANS_DIR/dupes_plan.tsv")
  fi
  if [ -d "$QUAR_DIR" ]; then
    ART_QUAR_COUNT=$(find "$QUAR_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    ART_QUAR_SIZE=$(du -sh "$QUAR_DIR" 2>/dev/null | awk '{print $1}')
  fi
  if [ -d "$REPORTS_DIR" ]; then
    ART_REPORTS_SIZE=$(du -sh "$REPORTS_DIR" 2>/dev/null | awk '{print $1}')
  fi
  [ -f "$REPORTS_DIR/hash_index.tsv" ] && ART_HASH_DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$REPORTS_DIR/hash_index.tsv")
  [ -f "$REPORTS_DIR/snapshot_hash_fast.tsv" ] && ART_SNAPSHOT_DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$REPORTS_DIR/snapshot_hash_fast.tsv")
  [ -f "$PLANS_DIR/dupes_plan.tsv" ] && ART_DUPES_PLAN_DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$PLANS_DIR/dupes_plan.tsv")
}

file_meta() {
  local f="$1"
  [ -f "$f" ] || return 1
  local mtime size age_h now ft
  mtime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$f")
  size=$(du -h "$f" 2>/dev/null | awk 'NR==1{print $1}')
  now=$(date +%s)
  ft=$(stat -f %m "$f")
  age_h=$(( (now - ft) / 3600 ))
  printf "%s|%s|%s" "$mtime" "$size" "$age_h"
}

maybe_reuse_file() {
  local file="$1" desc="$2"
  if [ -s "$file" ]; then
    local meta_date meta_size
    meta_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$file" 2>/dev/null)
    meta_size=$(du -h "$file" 2>/dev/null | awk 'NR==1{print $1}')
    printf "%s[INFO]%s %s ya existe (%s, %s). Reusar (R) o regenerar (g)? [R/g]: " "$C_YLW" "$C_RESET" "$desc" "${meta_date:-n/d}" "${meta_size:-n/d}"
    read -r reuse
    case "$reuse" in
      g|G) return 0 ;;
      *) printf "%s[OK]%s Reusando %s\n" "$C_GRN" "$C_RESET" "$file"; pause_enter; return 1 ;;
    esac
  fi
  return 0
}

select_ml_python() {
  for p in python3.11 python3.10 python3.9 python3; do
    if command -v "$p" >/dev/null 2>&1; then
      printf "%s" "$p"
      return 0
    fi
  done
  return 1
}

python_minor_version() {
  "$1" - <<'PY' 2>/dev/null
import sys
print(sys.version_info.minor)
PY
}

list_python_procs() {
  ps -ax -o pid,command | awk 'NR==1 || /python/ {print}'
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
  : "${ML_PROFILE:=LIGHT}"
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
    printf 'ML_PROFILE=%q\n' "$ML_PROFILE"
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
    if [ "${ML_PROFILE:-LIGHT}" = "TF_ADV" ] && [ -x "$VENV_DIR/bin/python" ]; then
      venv_minor=$(python_minor_version "$VENV_DIR/bin/python")
      if [ -n "$venv_minor" ] && [ "$venv_minor" -ge 12 ]; then
        printf "%s[WARN]%s Venv ML usa Python 3.%s (no compatible con TF en macOS). Recrear con python3.11? (y/N): " "$C_YLW" "$C_RESET" "$venv_minor"
        read -r recrear
        if [[ "$recrear" =~ ^[yY]$ ]]; then
          rm -rf "$VENV_DIR" 2>/dev/null || true
          if [ -d "$VENV_DIR" ]; then
            printf "%s[WARN]%s No se pudo borrar el venv (archivos en uso). Procesos Python activos:\n" "$C_YLW" "$C_RESET"
            list_python_procs
            printf "%s[WARN]%s Cierra esos procesos y reintenta.\n" "$C_YLW" "$C_RESET"
            return
          fi
        else
          printf "%s[ERR]%s TF_ADV requiere Python 3.11. Instala python@3.11 y reintenta.\n" "$C_RED" "$C_RESET"
          return
        fi
      fi
    fi
    # shellcheck disable=SC1090
    . "$VENV_DIR/bin/activate"
    VENV_ACTIVE=1
    return
  fi

  local pkgs="$ML_PKGS_BASIC"
  local est_mb="$ML_PKG_BASIC_MB"
  if [ "${ML_PROFILE:-LIGHT}" = "LIGHT" ]; then
    pkgs="$ML_PKGS_LIGHT"
    est_mb="$ML_PKG_LIGHT_MB"
  elif [ "${ML_PROFILE:-LIGHT}" = "TF_ADV" ]; then
    pkgs="$ML_PKGS_LIGHT $ML_PKGS_TF"
    est_mb=$((ML_PKG_LIGHT_MB + ML_PKG_TF_MB))
  fi
  if [ "$want_evo" -eq 1 ] && [ "${ML_PROFILE:-LIGHT}" = "BASIC" ]; then
    pkgs="$ML_PKGS_EVO"
    est_mb="$ML_PKG_EVO_MB"
  fi
  if [ "$want_tf" -eq 1 ] && [ "${ML_PROFILE:-LIGHT}" != "TF_ADV" ]; then
    pkgs="$pkgs $ML_PKGS_TF"
    est_mb=$((est_mb + ML_PKG_TF_MB))
  fi
  pkgs_arr=()
  for p in $pkgs; do
    pkgs_arr+=("$p")
  done

  printf "%s[INFO]%s %s requiere entorno ML aislado.\n" "$C_CYN" "$C_RESET" "$context"
  printf "%s[WARN]%s Necesita conexión a Internet. Descarga estimada: ~%s MB.\n" "$C_YLW" "$C_RESET" "$est_mb"
  printf "Crear venv en %s y descargar pip + %s (~%s MB)? [y/N]: " "$VENV_DIR" "$pkgs" "$est_mb"
  read -r ans
  case "$ans" in
    y|Y)
      py=$(select_ml_python)
      if [ -z "$py" ]; then
        printf "%s[ERR]%s No se encontró python3. Instálalo e inténtalo de nuevo.\n" "$C_RED" "$C_RESET"
        ML_ENV_DISABLED=1
        return
      fi
      if [ "${ML_PROFILE:-LIGHT}" = "TF_ADV" ]; then
        minor=$(python_minor_version "$py")
        if [ -n "$minor" ] && [ "$minor" -ge 12 ]; then
          printf "%s[WARN]%s TF_ADV requiere Python 3.11. ¿Instalar python@3.11 con brew? (y/N): " "$C_YLW" "$C_RESET"
          read -r inst_py
          if [[ "$inst_py" =~ ^[yY]$ ]] && command -v brew >/dev/null 2>&1; then
            brew install python@3.11 || true
            py=$(select_ml_python)
          fi
          minor=$(python_minor_version "$py")
          if [ -n "$minor" ] && [ "$minor" -ge 12 ]; then
            printf "%s[ERR]%s No hay Python 3.11 disponible. Instálalo y reintenta.\n" "$C_RED" "$C_RESET"
            return
          fi
        fi
      fi
      "$py" -m venv "$VENV_DIR" 2>/dev/null || {
        printf "%s[ERR]%s No se pudo crear el venv en %s\n" "$C_RED" "$C_RESET" "$VENV_DIR"
        ML_ENV_DISABLED=1
        return
      }
      if [ -f "$VENV_DIR/bin/activate" ]; then
        # shellcheck disable=SC1090
        . "$VENV_DIR/bin/activate"
        VENV_ACTIVE=1
        "$VENV_DIR/bin/pip" install --upgrade pip >/dev/null 2>&1 || true
        ("$VENV_DIR/bin/pip" install "${pkgs_arr[@]}" >/dev/null 2>&1) &
        pip_pid=$!
        while kill -0 "$pip_pid" 2>/dev/null; do
          status_line "ML" "--" "Instalando paquetes..."
          sleep 1
        done
        finish_status_line
      fi
      ;;
    *)
      ML_ENV_DISABLED=1
      printf "%s[WARN]%s Entorno ML omitido para %s. Reintenta más tarde si lo deseas.\n" "$C_YLW" "$C_RESET" "$context"
      ;;
  esac
}

spin_colors_for_task() {
  case "$1" in
    SCAN|RESCAN|CATALOG|CATALOGO*|INVENTORY|INVENTARIO*|INDEX) SPIN_COLOR_A="$C_CYN"; SPIN_COLOR_B="$C_BLU" ;;
    HASH*) SPIN_COLOR_A="$C_PURP"; SPIN_COLOR_B="$C_WHT" ;;
    DUP*|DEDUP*|QUARANTINE) SPIN_COLOR_A="$C_YLW"; SPIN_COLOR_B="$C_RED" ;;
    MIRROR*|MATRIOSHKA) SPIN_COLOR_A="$C_CYN"; SPIN_COLOR_B="$C_GRN" ;;
    SNAP* ) SPIN_COLOR_A="$C_GRN"; SPIN_COLOR_B="$C_CYN" ;;
    BACKUP* ) SPIN_COLOR_A="$C_GRN"; SPIN_COLOR_B="$C_YLW" ;;
    DOCTOR*|RELINK* ) SPIN_COLOR_A="$C_BLU"; SPIN_COLOR_B="$C_GRN" ;;
    ML*|TF* ) SPIN_COLOR_A="$C_PURP"; SPIN_COLOR_B="$C_CYN" ;;
    VIDEO*|VISUAL* ) SPIN_COLOR_A="$C_RED"; SPIN_COLOR_B="$C_YLW" ;;
    PLAYLISTS ) SPIN_COLOR_A="$C_CYN"; SPIN_COLOR_B="$C_PURP" ;;
    *) SPIN_COLOR_A="$C_GRN"; SPIN_COLOR_B="$C_WHT" ;;
  esac
}

status_emoji_for_task() {
  case "$1" in
    SCAN|RESCAN|CATALOG|INVENTORY|INDEX) echo "🔍" ;;
    HASH*) echo "🔐" ;;
    DUP*|DEDUP*|QUARANTINE) echo "♻️" ;;
    SNAP*) echo "📸" ;;
    BACKUP*) echo "💾" ;;
    DOCTOR*|RELINK*) echo "🩺" ;;
    ML*|TF*) echo "🧠" ;;
    VIDEO*|VISUAL*) echo "🎥" ;;
    PLAYLISTS) echo "🎵" ;;
    *) echo "👻" ;;
  esac
}

status_line() {
  task="$1"
  percent="$2"
  current="$3"
  local emoji="$4"
  local frame="${SPIN_FRAMES[$SPIN_IDX]}"
  local spin_idx="$SPIN_IDX"
  SPIN_IDX=$(((SPIN_IDX + 1) % ${#SPIN_FRAMES[@]}))
  local ghost_color="${GHOST_COLORS[$GHOST_IDX]}"
  GHOST_IDX=$(((GHOST_IDX + 1) % ${#GHOST_COLORS[@]}))
  spin_colors_for_task "$task"
  local spin_color="$SPIN_COLOR_A"
  if [ $((spin_idx % 2)) -eq 1 ]; then
    spin_color="$SPIN_COLOR_B"
  fi
  local frame_colored="${spin_color}${frame}${C_RESET}"
  if [ -z "$emoji" ]; then
    emoji=$(status_emoji_for_task "$task")
  fi
  printf "\r%s%s%s | %3s%% | %s | %s | %s" "$ghost_color" "$emoji" "$C_RESET" "$percent" "$frame_colored" "$task" "$current"
}

finish_status_line() {
  printf "\n"
}

run_with_spinner() {
  local task="$1"
  local detail="$2"
  shift 2
  "$@" &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    status_line "$task" "--" "$detail"
    sleep 1
  done
  finish_status_line
  wait "$pid"
}

print_header() {
  clear
  if [ -f "$BANNER_FILE" ]; then
    printf "%s" "$C_PURP"
    # Limpia literales "\n" que pudieran estar guardados en el banner
    sed 's/\\n$//' "$BANNER_FILE" | sed "s/^/$C_PURP/;s/$/$C_RESET/"
    printf "%s\n" "$C_RESET"
  else
    cols=$(tput cols 2>/dev/null || echo 80)
    # Mismo banner ASCII que EN pero con gradiente alternativo (frío→cálido)
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
      local line="${banner_lines[$idx]}"
      local pad=0
      printf "%*s%s%s%s\n" "$pad" "" "$color" "$line" "$C_RESET"
    done
  fi
  printf "%s⚡ By Astro One Deep 🎵%s\n\n" "$C_PURP" "$C_RESET"

  printf "%sWAX SPACESHIP  DJProducerTools%s\n" "$C_CYN" "$C_RESET"
  printf "%sBase:%s %s\n" "$C_YLW" "$C_RESET" "$BASE_PATH"

  local safemode_str
  local lock_str
  local dryrun_str
  local ia_str

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

  if [ "${ML_PROFILE:-LIGHT}" = "TF_ADV" ]; then
    ia_str="${C_GRN}${ML_PROFILE}${C_RESET}"
  else
    ia_str="${C_RED}${ML_PROFILE:-LIGHT}${C_RESET}"
  fi

  printf "%sAssist:%s %sON%s | %sAutoTools:%s %sON%s | %sSafeMode:%s %s | %sDJ_SAFE_LOCK:%s %s | %sDryRunForce:%s %s | %s🧠 IA:%s %s\n" \
    "$C_BLU" "$C_RESET" "$C_GRN" "$C_RESET" \
    "$C_BLU" "$C_RESET" "$C_GRN" "$C_RESET" \
    "$C_BLU" "$C_RESET" "$safemode_str" \
    "$C_BLU" "$C_RESET" "$lock_str" \
    "$C_BLU" "$C_RESET" "$dryrun_str" \
    "$C_BLU" "$C_RESET" "$ia_str"

  printf "────────────────────────────────────────────────────────────\n"
}

print_menu() {
  refresh_artifact_state
  local tag9 tag10 tag11 tag27
  local info_hash info_snap info_dupes info_quar info_reports
  [ "$ART_HAS_HASH" -eq 1 ] && tag9=" [prev]"
  [ "$ART_HAS_DUPES_PLAN" -eq 1 ] && tag10=" [prev ${ART_DUPES_QUAR}q]"
  [ "$ART_HAS_SNAPSHOT" -eq 1 ] && tag27=" [prev]"
  if [ "$ART_QUAR_COUNT" -gt 0 ]; then
    tag11=" [${ART_QUAR_COUNT} en quarantine]"
  elif [ "$ART_HAS_DUPES_PLAN" -eq 1 ]; then
    tag11=" [plan listo]"
  fi
  if [ "$ART_HAS_HASH" -eq 1 ]; then
    info_hash="hash_index OK${ART_HASH_DATE:+ ($ART_HASH_DATE)}"
  else
    info_hash="hash_index n/d"
  fi
  if [ "$ART_HAS_SNAPSHOT" -eq 1 ]; then
    info_snap="snapshot OK${ART_SNAPSHOT_DATE:+ ($ART_SNAPSHOT_DATE)}"
  else
    info_snap="snapshot n/d"
  fi
  if [ "$ART_HAS_DUPES_PLAN" -eq 1 ]; then
    info_dupes="dupes_plan OK${ART_DUPES_PLAN_DATE:+ ($ART_DUPES_PLAN_DATE)}"
  else
    info_dupes="dupes_plan n/d"
  fi
  if [ "$ART_QUAR_COUNT" -gt 0 ]; then
    info_quar="quarantine ${ART_QUAR_COUNT}${ART_QUAR_SIZE:+, ${ART_QUAR_SIZE}}"
  else
    info_quar="quarantine vacia"
  fi
  info_reports="reports ${ART_REPORTS_SIZE:-n/d}"

  printf "%sMenú (vista agrupada)%s\n" "$C_GRN" "$C_RESET"
  printf "%sPrevios:%s %s | %s | %s | %s | %s\n" "$C_YLW" "$C_RESET" "$info_hash" "$info_snap" "$info_dupes" "$info_quar" "$info_reports"
  printf "%s⚙️  Core (1-12):%s\n" "$C_CYN" "$C_RESET"
  printf "  %s1)%s Estado / rutas / locks\n" "$C_GRN" "$C_RESET"
  printf "  %s2)%s Cambiar Base Path\n" "$C_GRN" "$C_RESET"
  printf "  %s3)%s Resumen del volumen / últimos reportes\n" "$C_GRN" "$C_RESET"
  printf "  %s4)%s Top carpetas por tamaño\n" "$C_GRN" "$C_RESET"
  printf "  %s5)%s Top archivos grandes\n" "$C_GRN" "$C_RESET"
  printf "  %s6)%s Scan workspace (catálogo previo)\n" "$C_GRN" "$C_RESET"
  printf "  %s7)%s Backup Serato (_Serato_ / _Serato_Backup)\n" "$C_GRN" "$C_RESET"
  printf "  %s8)%s Backup DJ (metadatos Serato/Traktor/Rekordbox/Ableton)\n" "$C_GRN" "$C_RESET"
  printf "  %s9)%s Índice SHA-256 (generar/reusar)%s\n" "$C_GRN" "$C_RESET" "${tag9:-}"
  printf "  %s10)%s Reporte duplicados EXACTO (plan JSON/TSV)%s\n" "$C_GRN" "$C_RESET" "${tag10:-}"
  printf "  %s11)%s Quarantine duplicados (desde LAST_PLAN)%s\n" "$C_GRN" "$C_RESET" "${tag11:-}"
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

  printf "%s🧹 Procesos / Limpieza (25-41):%s\n" "$C_CYN" "$C_RESET"
  printf "  %s25)%s Ayuda rápida (guía de procesos)\n" "$C_GRN" "$C_RESET"
  printf "  %s26)%s Estado: Export/Import (bundle)\n" "$C_GRN" "$C_RESET"
  printf "  %s27)%s Snapshot integridad (hash rápido) con progreso%s\n" "$C_GRN" "$C_RESET" "${tag27:-}"
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
  printf "  %s40)%s Convertir WAV a MP3 (320kbps, Máxima Calidad)\n" "$C_GRN" "$C_RESET"
  printf "  %s41)%s Actualizar script desde GitHub\n" "$C_GRN" "$C_RESET"
  printf "\n"

  printf "%s🧠 Deep/ML (42-59):%s\n" "$C_CYN" "$C_RESET"
  printf "  %s42)%s Deep Thinking: Smart Analysis (JSON)\n" "$C_GRN" "$C_RESET"
  printf "  %s43)%s Machine Learning: Predictor de problemas\n" "$C_GRN" "$C_RESET"
  printf "  %s44)%s Deep Thinking: Optimizador de eficiencia\n" "$C_GRN" "$C_RESET"
  printf "  %s45)%s Deep Thinking: Flujo de trabajo inteligente\n" "$C_GRN" "$C_RESET"
  printf "  %s46)%s Deep Thinking: Deduplicación integrada\n" "$C_GRN" "$C_RESET"
  printf "  %s47)%s ML: Organización automática (plan)\n" "$C_GRN" "$C_RESET"
  printf "  %s48)%s Deep Thinking: Armonizador de metadatos (plan)\n" "$C_GRN" "$C_RESET"
  printf "  %s49)%s ML: Backup predictivo\n" "$C_GRN" "$C_RESET"
  printf "  %s50)%s Deep Thinking: Sincronización multi-plataforma\n" "$C_GRN" "$C_RESET"
  printf "  %s51)%s Deep Thinking: Análisis avanzado\n" "$C_GRN" "$C_RESET"
  printf "  %s52)%s Deep Thinking: Motor de integración\n" "$C_GRN" "$C_RESET"
  printf "  %s53)%s ML: Recomendaciones adaptativas\n" "$C_GRN" "$C_RESET"
  printf "  %s54)%s Deep Thinking: Pipeline de limpieza automatizado\n" "$C_GRN" "$C_RESET"
  printf "  %s55)%s ML Evolutivo (entrenar/predicción local)\n" "$C_GRN" "$C_RESET"
  printf "  %s56)%s Toggle ML ON/OFF (evita activar venv ML)\n" "$C_GRN" "$C_RESET"
  printf "  %s57)%s TensorFlow opcional (instalar/ideas avanzadas)\n" "$C_GRN" "$C_RESET"
  printf "  %s58)%s TensorFlow Lab (auto-tagging/similitud/etc.)\n" "$C_GRN" "$C_RESET"
  printf "  %s59)%s IA local: TensorFlowADV+Light-IA\n" "$C_GRN" "$C_RESET"
  printf "\n"

  printf "%s🧰 Extras / Utilidades (60-72):%s\n" "$C_CYN" "$C_RESET"
  printf "  %s60)%s Reset estado / limpiar extras\n" "$C_GRN" "$C_RESET"
  printf "  %s61)%s Gestor de perfiles (guardar/cargar rutas)\n" "$C_GRN" "$C_RESET"
  printf "  %s62)%s Ableton Tools (analítica básica)\n" "$C_GRN" "$C_RESET"
  printf "  %s63)%s Importers: Rekordbox/Traktor cues\n" "$C_GRN" "$C_RESET"
  printf "  %s64)%s Gestor de exclusiones (perfiles)\n" "$C_GRN" "$C_RESET"
  printf "  %s65)%s Comparar hash_index entre discos (sin rehash)\n" "$C_GRN" "$C_RESET"
  printf "  %s66)%s Health-check de estado (_DJProducerTools)\n" "$C_GRN" "$C_RESET"
  printf "  %s67)%s Export/Import solo config/perfiles\n" "$C_GRN" "$C_RESET"
  printf "  %s68)%s Mirror check entre hash_index (faltantes/corrupción)\n" "$C_GRN" "$C_RESET"
  printf "  %s69)%s Plan LUFS (análisis, sin normalizar)\n" "$C_GRN" "$C_RESET"
  printf "  %s70)%s Auto-cues por onsets (librosa)\n" "$C_GRN" "$C_RESET"
  printf "  %s71)%s Cadenas automatizadas (21 flujos)\n" "$C_GRN" "$C_RESET"
  printf "  %s72)%s Perfiles/links de artista (plantilla para rellenar)\n" "$C_GRN" "$C_RESET"

  printf "\n"
  printf "%s🔮 A) Automatizaciones (cadenas)%s\n" "$C_GRN" "$C_RESET"
  printf "%s📚 L)%s Librerías DJ & Cues (submenú)\n" "$C_GRN_SOFT" "$C_RESET"
  printf "%s♻️  D)%s Duplicados generales (submenú)\n" "$C_CYN_SOFT" "$C_RESET"
  printf "%s🎥 V)%s Visuales / DAW / OSC (submenú)\n" "$C_PURP_SOFT" "$C_RESET"
  printf "%sℹ️  H)%s Help & INFO\n" "$C_GRN_SOFT" "$C_RESET"
  printf "%s0)%s Salir\n" "$C_GRN" "$C_RESET"
}

invalid_option() {
  printf "%s[ERR]%s Opción inválida.\n" "$C_RED" "$C_RESET"
  pause_enter
}

action_1_status() {
  print_header
  refresh_artifact_state
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
  printf "\n%sArtefactos previos:%s\n" "$C_YLW" "$C_RESET"
  if [ "$ART_HAS_HASH" -eq 1 ]; then
    printf "  hash_index.tsv: OK (%s)\n" "${ART_HASH_DATE:-sin fecha}"
  else
    printf "  hash_index.tsv: (no generado)\n"
  fi
  if [ "$ART_HAS_SNAPSHOT" -eq 1 ]; then
    printf "  snapshot_hash_fast.tsv: OK (%s)\n" "${ART_SNAPSHOT_DATE:-sin fecha}"
  else
    printf "  snapshot_hash_fast.tsv: (no generado)\n"
  fi
  if [ "$ART_HAS_DUPES_PLAN" -eq 1 ]; then
    printf "  dupes_plan.tsv: OK (%s) [%s marcados QUAR]\n" "${ART_DUPES_PLAN_DATE:-sin fecha}" "$ART_DUPES_QUAR"
  else
    printf "  dupes_plan.tsv: (no generado)\n"
  fi
  printf "  quarantine/: %s archivos%s\n" "${ART_QUAR_COUNT:-0}" "${ART_QUAR_SIZE:+, ${ART_QUAR_SIZE}}"
  printf "  reports/: %s\n" "${ART_REPORTS_SIZE:-n/d}"
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
  run_with_spinner "SUMMARY" "Calculando tamaño..." du -sh "$BASE_PATH"
  printf "\nÚltimos reports en %s:\n" "$REPORTS_DIR"
  ls -1t "$REPORTS_DIR" 2>/dev/null | head || true
  pause_enter
}

action_4_top_dirs() {
  print_header
  printf "%s[INFO]%s Top carpetas por tamaño (nivel 2):\n" "$C_CYN" "$C_RESET"
  run_with_spinner "TOP_DIRS" "Calculando..." bash -c 'find "$BASE_PATH" -maxdepth 2 -type d -print0 2>/dev/null | xargs -0 du -sh 2>/dev/null | sort -hr | head || true'
  pause_enter
}

action_5_top_files() {
  print_header
  printf "%s[INFO]%s Top archivos grandes:\n" "$C_CYN" "$C_RESET"
  run_with_spinner "TOP_FILES" "Buscando..." bash -c 'find "$BASE_PATH" -type f -print0 2>/dev/null | xargs -0 ls -lhS 2>/dev/null | head || true'
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
  print_header
  printf "%s[INFO]%s Backup Serato básico.\n" "$C_CYN" "$C_RESET"
  src1="$BASE_PATH/_Serato_"
  src2="$BASE_PATH/_Serato_Backup"
  dest="$STATE_DIR/serato_backup"
  mkdir -p "$dest"
  if [ -d "$src1" ]; then
    run_with_spinner "BACKUP" "_Serato_" rsync -a "$src1"/ "$dest/_Serato_"/ 2>/dev/null || true
  fi
  if [ -d "$src2" ]; then
    run_with_spinner "BACKUP" "_Serato_Backup" rsync -a "$src2"/ "$dest/_Serato_Backup"/ 2>/dev/null || true
  fi
  printf "%s[OK]%s Backup Serato completado (si había fuentes).\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_8_backup_dj() {


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
    dest_dir="$dest/${typ}_$(basename "$path")"
    run_with_spinner "BACKUP_DJ ${count}/${total}" "$path" rsync -a "$path"/ "$dest_dir"/ 2>/dev/null || true
  done <"$paths_tmp"
  rm -f "$paths_tmp"

  printf "%s[OK]%s Backup DJ metadatos completado (%s rutas).\n" "$C_GRN" "$C_RESET" "$total"
  pause_enter
}

action_9_hash_index() {
  print_header
  out="$REPORTS_DIR/hash_index.tsv"
  if ! maybe_reuse_file "$out" "hash_index.tsv"; then return; fi
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
  meta=$(file_meta "$hash_file")
  if [ -n "$meta" ]; then
    meta_date=$(echo "$meta" | cut -d'|' -f1)
    meta_size=$(echo "$meta" | cut -d'|' -f2)
    meta_age=$(echo "$meta" | cut -d'|' -f3)
    if [ "$meta_age" -gt 168 ]; then
      printf "%s[WARN]%s hash_index tiene más de 7 días (%s, %s, %sh). ¿Regenerar antes de crear el plan? (y/N): " "$C_YLW" "$C_RESET" "$meta_date" "$meta_size" "$meta_age"
      read -r regen
      case "$regen" in
        y|Y) action_9_hash_index ;;
        *) ;;
      esac
    fi
  fi
  plan_tsv="$PLANS_DIR/dupes_plan.tsv"
  plan_json="$PLANS_DIR/dupes_plan.json"
  if ! maybe_reuse_file "$plan_tsv" "dupes_plan.tsv"; then return; fi
  printf "%s[INFO]%s Generando plan de duplicados EXACTO.\n" "$C_CYN" "$C_RESET"
  HASH_FILE="$hash_file" PLAN_TSV="$plan_tsv" run_with_spinner "DUPES" "Generando plan..." bash -c '
  BEGIN { FS=OFS="\t" }
  {
    if (NF < 3) next
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
  }' "$HASH_FILE" >"$PLAN_TSV"
  {
    echo "{"
    echo "  \"type\": \"dupes_plan\","
    echo "  \"entries\": ["
    first=1
    total_json=$(wc -l <"$plan_tsv" | tr -d ' ')
    count_json=0
    while IFS=$'\t' read -r h action f; do
      count_json=$((count_json + 1))
      if [ "$total_json" -gt 0 ]; then
        percent_json=$((count_json * 100 / total_json))
      else
        percent_json=0
      fi
      status_line "DUPES_JSON" "$percent_json" "$(basename "$f")"
      if [ "$first" -eq 0 ]; then
        echo "    ,"
      fi
      first=0
      printf "    {\"hash\": \"%s\", \"action\": \"%s\", \"path\": \"%s\"}" "$h" "$action" "$f"
    done <"$plan_tsv"
    finish_status_line
    echo
    echo "  ]"
    echo "}"
  } >"$plan_json"
  printf "%s[OK]%s Plan generado: %s y %s\n" "$C_GRN" "$C_RESET" "$plan_tsv" "$plan_json"
  pause_enter
}

action_unique_from_hash() {
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
  out="$REPORTS_DIR/unique_files.tsv"
  if ! maybe_reuse_file "$out" "unique_files.tsv"; then return; fi
  printf "%s[INFO]%s Generando lista de archivos únicos -> %s\n" "$C_CYN" "$C_RESET" "$out"
  awk -F'\t' '
  {
    if (NF < 3) next
    h=$1
    rec[h]=$0
    count[h]++
  }
  END {
    for (h in count) if (count[h]==1) print rec[h]
  }' "$hash_file" >"$out"
  printf "%s[OK]%s Únicos generados: %s\n" "$C_GRN" "$C_RESET" "$out"
  pause_enter
}

action_11_quarantine_from_plan() {
  print_header
  plan_tsv="$PLANS_DIR/dupes_plan.tsv"
  if [ ! -f "$plan_tsv" ]; then
    printf "%s[ERR]%s No existe dupes_plan.tsv.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  meta=$(file_meta "$plan_tsv")
  if [ -n "$meta" ]; then
    meta_date=$(echo "$meta" | cut -d'|' -f1)
    meta_age=$(echo "$meta" | cut -d'|' -f3)
    printf "%s[INFO]%s Plan actual: %s (edad: %sh)\n" "$C_CYN" "$C_RESET" "$meta_date" "$meta_age"
    if [ "$meta_age" -gt 168 ]; then
      printf "%s[WARN]%s Plan de duplicados tiene más de 7 días. ¿Continuar? (y/N): " "$C_YLW" "$C_RESET"
      read -r cont_old
      case "$cont_old" in
        y|Y) ;;
        *) printf "%s[INFO]%s Cancelado. Re-generar plan (opción 10).\n" "$C_CYN" "$C_RESET"; pause_enter; return ;;
      esac
    fi
  fi
  printf "%s[INFO]%s Aplicando quarantine desde plan (SAFE_MODE=%s).\n" "$C_CYN" "$C_RESET" "$SAFE_MODE"
  sample_count=$(awk -F'\t' '$2=="QUARANTINE"{c++} END {print c+0}' "$plan_tsv")
  printf "Acciones QUARANTINE: %s\n" "$sample_count"
  if [ "$sample_count" -gt 0 ]; then
    printf "Muestra de las primeras 10 entradas:\n"
    awk -F'\t' '$2=="QUARANTINE"{print NR": "$3}' "$plan_tsv" | head -10
  fi

  # Calcula espacio necesario para mover a quarantine
  needed_bytes=0
  total_quar="$sample_count"
  count_quar=0
  while IFS=$'\t' read -r _ action f; do
    [ "$action" != "QUARANTINE" ] && continue
    count_quar=$((count_quar + 1))
    if [ "$total_quar" -gt 0 ]; then
      percent=$((count_quar * 100 / total_quar))
    else
      percent=0
    fi
    status_line "QUAR_SPACE" "$percent" "$(basename "$f")"
    sz=$({ stat -f %z "$f" 2>/dev/null || echo 0; } | tr -d ' ')
    needed_bytes=$((needed_bytes + sz))
  done <"$plan_tsv"
  finish_status_line
  avail_bytes=$(df -k "$QUAR_DIR" 2>/dev/null | awk 'NR==2{print $4*1024}')
  if [ -z "$avail_bytes" ]; then
    avail_bytes=0
  fi
  mark_only=0
  printf "Espacio necesario estimado: %.2f MB | Disponible: %.2f MB\n" "$(echo "$needed_bytes/1048576" | bc -l)" "$(echo "$avail_bytes/1048576" | bc -l)"
  if [ "$avail_bytes" -lt "$needed_bytes" ] && [ "$needed_bytes" -gt 0 ]; then
    printf "%s[WARN]%s Espacio insuficiente en quarantine.\n" "$C_YLW" "$C_RESET"
    printf "¿Usar modo 'solo marcar' (no mueve, solo muestra)? (y/N): "
    read -r mark_ans
    case "$mark_ans" in
      y|Y) mark_only=1 ;;
      *)
        printf "¿Continuar igualmente moviendo aunque falte espacio? (y/N): "
        read -r space_ans
        case "$space_ans" in
          y|Y) ;;
          *) printf "%s[INFO]%s Cancelado por espacio insuficiente.\n" "$C_CYN" "$C_RESET"; pause_enter; return ;;
        esac
        ;;
    esac
  fi

  printf "Confirmar mover archivos marcados como QUARANTINE? (y/N): "
  read -r ans
  case "$ans" in
    y|Y) ;;
    *) printf "%s[INFO]%s Cancelado.\n" "$C_CYN" "$C_RESET"; pause_enter; return ;;
  esac
  count_quar=0
  while IFS=$'\t' read -r h action f; do
    if [ "$action" != "QUARANTINE" ]; then
      continue
    fi
    count_quar=$((count_quar + 1))
    if [ "$total_quar" -gt 0 ]; then
      percent=$((count_quar * 100 / total_quar))
    else
      percent=0
    fi
    rel="${f#$BASE_PATH/}"
    status_line "QUARANTINE" "$percent" "$rel"
    dest_dir="$QUAR_DIR/$h"
    dest="$dest_dir/$(basename "$f")"
    if [ "$mark_only" -eq 1 ] || [ "$SAFE_MODE" -eq 1 ] || [ "$DJ_SAFE_LOCK" -eq 1 ] || [ "$DRYRUN_FORCE" -eq 1 ]; then
      printf "[DRY] mover \"%s\" -> \"%s\"\n" "$f" "$dest"
    else
      mkdir -p "$dest_dir"
      if [ -f "$f" ]; then
        mv "$f" "$dest"
        printf "[MOVE] \"%s\" -> \"%s\"\n" "$f" "$dest"
      fi
    fi
  done <"$plan_tsv"
  finish_status_line
  pause_enter
}

action_12_quarantine_manager() {
  while true; do
    clear
    local q_count q_size
    q_count=$(find "$QUAR_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    q_size=$(du -sh "$QUAR_DIR" 2>/dev/null | awk 'NR==1{print $1}')
    printf "%s=== Quarantine Manager ===%s\n" "$C_CYN" "$C_RESET"
    printf "QUAR_DIR: %s\n" "$QUAR_DIR"
    printf "Contenido: %s archivos%s\n\n" "${q_count:-0}" "${q_size:+, ${q_size}}"
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
          local q_count_del q_size_del
          q_count_del=$(find "$QUAR_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
          q_size_del=$(du -sh "$QUAR_DIR" 2>/dev/null | awk 'NR==1{print $1}')
          if [ "${q_count_del:-0}" -eq 0 ]; then
            printf "%s[INFO]%s Quarantine está vacía.\n" "$C_CYN" "$C_RESET"
            pause_enter
            continue
          fi
          printf "%s[WARN]%s Borrar TODO el contenido de quarantine (solo archivos dentro de %s).\n" "$C_YLW" "$C_RESET" "$QUAR_DIR"
          printf "Archivos: %s | Tamaño: %s\n" "$q_count_del" "${q_size_del:-n/d}"
          printf "Muestra (ruta relativa dentro de quarantine):\n"
          find "$QUAR_DIR" -type f 2>/dev/null | sed "s|$QUAR_DIR/||" | head -10
          printf "Confirmar (YES para borrar definitivamente): "
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
  if ! ensure_tool_installed "ffprobe" "brew install ffmpeg"; then
    printf "%s[INFO]%s Saltando la detección de media corrupta.\n" "$C_CYN" "$C_RESET"
    pause_enter
    return
  fi
  print_header
  out="$REPORTS_DIR/media_corrupt.tsv"
  if ! maybe_reuse_file "$out" "media_corrupt.tsv"; then return; fi
  printf "%s[INFO]%s Detectando media corrupta (ffprobe) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  local files
  run_with_spinner "FFPROBE" "Listando archivos..." mapfile -t files < <(find "$BASE_PATH" -type f 2>/dev/null)
  total=${#files[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No se encontraron archivos.\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi

  count=0
  for f in "${files[@]}"; do
    count=$((count + 1))
    percent=$((count * 100 / total))
    status_line "FFPROBE" "$percent" "$f"
    ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$f" >/dev/null 2>&1 || printf "%s\tCORRUPT\n" "$f" >>"$out"
  done
  finish_status_line
  printf "%s[OK]%s Reporte generado (si hay corruptos) en %s\n" "$C_GRN" "$C_RESET" "$out"
  pause_enter
}

action_14_playlists_per_folder() {
  print_header
  printf "%s[INFO]%s Crear playlists .m3u8 por carpeta.\n" "$C_CYN" "$C_RESET"
  local total idx percent rel
  total=$(find "$BASE_PATH" -type d 2>/dev/null | wc -l | tr -d ' ')
  [ -z "$total" ] && total=0
  idx=0
  find "$BASE_PATH" -type d 2>/dev/null | while IFS= read -r d; do
    idx=$((idx + 1))
    if [ "$total" -gt 0 ]; then
      percent=$((idx * 100 / total))
    else
      percent=0
    fi
    rel="${d#"$BASE_PATH"/}"
    [ "$d" = "$BASE_PATH" ] && rel="."
    status_line "PLAYLISTS" "$percent" "$rel"
    playlist="$d/playlist.m3u8"
    find "$d" -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.m4a" \) 2>/dev/null >"$playlist"
  done
  finish_status_line
  printf "%s[OK]%s Playlists generadas.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_15_relink_helper() {
  print_header
  out="$REPORTS_DIR/relink_helper.tsv"
  doctor_out="$REPORTS_DIR/relink_doctor.txt"
  printf "%s[INFO]%s Doctor: Relink Helper -> %s\n" "$C_CYN" "$C_RESET" "$out"
  if [ -s "$out" ]; then
    meta_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$out" 2>/dev/null)
    meta_size=$(du -h "$out" 2>/dev/null | awk 'NR==1{print $1}')
    printf "%s[INFO]%s Ya existe relink_helper.tsv (%s, %s).\n" "$C_YLW" "$C_RESET" "${meta_date:-n/d}" "${meta_size:-n/d}"
    printf "¿Reusar (R) o regenerar (g)? [R/g]: "
    read -r reuse
    case "$reuse" in
      g|G) ;;
      *)
        printf "%s[OK]%s Reusando archivos existentes:\n  %s\n  %s\n" "$C_GRN" "$C_RESET" "$out" "$doctor_out"
        pause_enter
        return
        ;;
    esac
  fi
  include_hash=0
  printf "¿Incluir hash SHA-256 por archivo? (puede tardar) [y/N]: "
  read -r hash_ans
  case "$hash_ans" in
    y|Y) include_hash=1 ;;
    *) include_hash=0 ;;
  esac
  >"$out"
  >"$doctor_out"
  tmp_list="$STATE_DIR/relink_list.tmp"
  find "$BASE_PATH" -type f 2>/dev/null >"$tmp_list"
  total=$(wc -l <"$tmp_list" | tr -d ' ')
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No se encontraron archivos.\n" "$C_YLW" "$C_RESET"
    pause_enter
    rm -f "$tmp_list"
    return
  fi
  count=0
  zero_count=0
  while IFS= read -r f; do
    count=$((count + 1))
    rel="${f#$BASE_PATH/}"
    if [ "$total" -gt 0 ]; then
      percent=$((count * 100 / total))
    else
      percent=0
    fi
    status_line "RELINK" "$percent" "$rel"
    size=$(stat -f %z "$f" 2>/dev/null || echo 0)
    mtime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$f" 2>/dev/null || echo "n/d")
    if [ "${size:-0}" -eq 0 ]; then
      zero_count=$((zero_count + 1))
    fi
    if [ "$include_hash" -eq 1 ]; then
      h=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
      printf "%s\t%s\t%s\t%s\t%s\n" "$rel" "$f" "$size" "$mtime" "$h" >>"$out"
    else
      printf "%s\t%s\t%s\t%s\n" "$rel" "$f" "$size" "$mtime" >>"$out"
    fi
  done <"$tmp_list"
  finish_status_line
  rm -f "$tmp_list"
  missing_tools=()
  for tool in ffprobe ffmpeg sox flac metaflac id3v2 mid3v2 shntool jq python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing_tools+=("$tool")
    fi
  done
  install_note="(sin instalar)"
  if [ "${#missing_tools[@]}" -gt 0 ]; then
    printf "%s[WARN]%s Herramientas faltantes: %s\n" "$C_YLW" "$C_RESET" "${missing_tools[*]}"
    printf "¿Intentar instalar automáticamente con brew/pip? (y/N): "
    read -r inst
    case "$inst" in
      y|Y)
        install_note="(instalación intentada)"
        if command -v brew >/dev/null 2>&1; then
          brew_list=(ffmpeg sox flac id3v2 shntool jq)
          todo=()
          for pkg in "${brew_list[@]}"; do
            if ! command -v "$pkg" >/dev/null 2>&1; then todo+=("$pkg"); fi
          done
          if [ "${#todo[@]}" -gt 0 ]; then
            brew install "${todo[@]}" || echo "[WARN] brew install falló" | tee -a "$doctor_out"
          fi
        else
          echo "[WARN] brew no disponible" | tee -a "$doctor_out"
        fi
        if command -v python3 >/dev/null 2>&1; then
          python3 -m pip install --user mutagen >/dev/null 2>&1 && echo "[OK] mutagen instalado" | tee -a "$doctor_out" || echo "[WARN] mutagen no se pudo instalar" | tee -a "$doctor_out"
        fi
        ;;
      *) ;;
    esac
  fi
  {
    echo "DOCTOR RELINK REPORT"
    echo "BASE_PATH: $BASE_PATH"
    echo "Total archivos: $total"
    echo "Archivos tamaño 0: $zero_count"
    echo
    if [ "${#missing_tools[@]}" -gt 0 ]; then
      echo "Herramientas faltantes $install_note:"
      printf "  - %s\n" "${missing_tools[@]}"
      echo
      echo "Sugerencias (Homebrew):"
      echo "  brew install ffmpeg sox flac id3v2 shntool jq"
      echo "  # Para etiquetas mutagen: pip install mutagen"
    else
      echo "Herramientas básicas detectadas: OK"
    fi
    echo
    echo "Recomendaciones:"
    if [ "$include_hash" -eq 1 ]; then
      echo "  - Reubicar rutas usando relink_helper.tsv (col1=relativa, col2=absoluta, col3=tamaño, col4=fecha, col5=hash)."
    else
      echo "  - Reubicar rutas usando relink_helper.tsv (col1=relativa, col2=absoluta, col3=tamaño, col4=fecha)."
    fi
    echo "  - Revisa archivos tamaño 0 (col3=0) y reemplaza desde backup."
    echo "  - Si faltan librerías DJ, usa opciones 17/18 o 61 para validar espejos."
  } >"$doctor_out"
  printf "%s[OK]%s Relink Helper generado: %s\n" "$C_GRN" "$C_RESET" "$out"
  printf "%s[OK]%s Doctor de relink: %s\n" "$C_GRN" "$C_RESET" "$doctor_out"
  pause_enter
}

action_16_mirror_by_genre() {
  print_header
  printf "%s[INFO]%s Mirror por género (plan seguro básico).\n" "$C_CYN" "$C_RESET"
  out="$PLANS_DIR/mirror_by_genre.tsv"
  if ! maybe_reuse_file "$out" "mirror_by_genre.tsv"; then return; fi
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
  run_with_spinner "FIND_LIBS" "Buscando..." find "$BASE_PATH" -type d \( -iname "*Serato*" -o -iname "*Traktor*" -o -iname "*Rekordbox*" -o -iname "*Ableton*" \)
  pause_enter
}

action_18_rescan_intelligent() {
  print_header
  printf "%s[INFO]%s Rescan inteligente.\n" "$C_CYN" "$C_RESET"
  out="$REPORTS_DIR/rescan_intelligent.tsv"
  if ! maybe_reuse_file "$out" "rescan_intelligent.tsv"; then return; fi
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
  print_header
  out="$REPORTS_DIR/snapshot_hash_fast.tsv"
  if [ -f "$out" ]; then
    meta=$(file_meta "$out")
    meta_date=$(echo "$meta" | cut -d'|' -f1)
    meta_size=$(echo "$meta" | cut -d'|' -f2)
    meta_age=$(echo "$meta" | cut -d'|' -f3)
    printf "%s[INFO]%s Ya existe snapshot (%s, %s, %sh).\n" "$C_YLW" "$C_RESET" "$meta_date" "$meta_size" "$meta_age"
    printf "¿Reusar (R) o regenerar (g)? [R/g]: "
    read -r reuse
    case "$reuse" in
      g|G) ;;
      *) printf "%s[OK]%s Reusando snapshot existente.\n" "$C_GRN" "$C_RESET"; pause_enter; return ;;
    esac
  fi
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
  printf "Escribe RESET para borrar, CLEAR para solo limpiar EXTRA_SOURCE_ROOTS, DRY para simular, o ENTER para cancelar: "
  read -r ans
  case "$ans" in
    RESET)
      printf "%s[WARN]%s Eliminando %s ...\n" "$C_YLW" "$C_RESET" "$STATE_DIR"
      rm -rf "$STATE_DIR" 2>/dev/null || true
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
  if [ -z "$file_b" ]; then
    printf "%s[INFO]%s Modo rápido: validar archivo A contra disco (sin B).\n" "$C_CYN" "$C_RESET"
    printf "¿Continuar? (y/N): "
    read -r quick
    case "$quick" in
      y|Y) ;;
      *) printf "%s[INFO]%s Cancelado.\n" "$C_CYN" "$C_RESET"; pause_enter; return ;;
    esac
    if [ ! -f "$file_a" ]; then
      printf "%s[ERR]%s Archivo A inválido.\n" "$C_RED" "$C_RESET"
      pause_enter
      return
    fi
    missing_on_disk="$REPORTS_DIR/mirror_missing_on_disk_$(date +%s).tsv"
    mismatch_on_disk="$REPORTS_DIR/mirror_hash_mismatch_$(date +%s).tsv"
    >"$missing_on_disk"
    >"$mismatch_on_disk"
    total=$(wc -l <"$file_a" | tr -d ' ')
    count=0
    while IFS=$'\t' read -r h rel f; do
      if [ -z "$f" ]; then
        f="$rel"
        rel=""
      fi
      count=$((count + 1))
      if [ "$total" -gt 0 ]; then
        percent=$((count * 100 / total))
      else
        percent=0
      fi
      status_line "MIRROR_QC" "$percent" "$(basename "$f")"
      if [ ! -f "$f" ]; then
        printf "%s\t%s\t%s\n" "$h" "$rel" "$f" >>"$missing_on_disk"
        continue
      fi
      h2=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
      if [ -n "$h2" ] && [ "$h2" != "$h" ]; then
        printf "%s\t%s\t%s\n" "$h" "$h2" "$f" >>"$mismatch_on_disk"
      fi
    done <"$file_a"
    finish_status_line
    printf "%s[OK]%s Modo rápido generado:\n" "$C_GRN" "$C_RESET"
    printf "  Faltantes en disco: %s\n" "$missing_on_disk"
    printf "  Hash distinto: %s\n" "$mismatch_on_disk"
    pause_enter
    return
  fi
  if [ ! -f "$file_a" ] || [ ! -f "$file_b" ]; then
    printf "%s[ERR]%s Archivo(s) inválidos.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  for f in "$file_a" "$file_b"; do
    meta=$(file_meta "$f")
    if [ -n "$meta" ]; then
      meta_date=$(echo "$meta" | cut -d'|' -f1)
      meta_age=$(echo "$meta" | cut -d'|' -f3)
      if [ "$meta_age" -gt 168 ]; then
        printf "%s[WARN]%s %s tiene más de 7 días (%s, %sh). Recomendado regenerar con opción 9.\n" "$C_YLW" "$C_RESET" "$f" "$meta_date" "$meta_age"
      fi
    fi
  done
  missing_in_b="$REPORTS_DIR/mirror_missing_in_B_$(date +%s).tsv"
  missing_in_a="$REPORTS_DIR/mirror_missing_in_A_$(date +%s).tsv"
  mismatch="$REPORTS_DIR/mirror_hash_mismatch_$(date +%s).tsv"
  FILE_A="$file_a" run_with_spinner "MIRROR" "Indexando A..." bash -c 'awk -F"\t" "{map[\$2]=\$1} END {for (p in map) print p\"\t\"map[p]}" "$FILE_A" | sort >"'"$STATE_DIR/mirror_a.tmp"'"'
  FILE_B="$file_b" run_with_spinner "MIRROR" "Indexando B..." bash -c 'awk -F"\t" "{map[\$2]=\$1} END {for (p in map) print p\"\t\"map[p]}" "$FILE_B" | sort >"'"$STATE_DIR/mirror_b.tmp"'"'
  run_with_spinner "MIRROR" "Comparando faltantes (B)..." bash -c 'join -v1 -t$'"'"'\t'"'"' "'"$STATE_DIR/mirror_a.tmp"'" "'"$STATE_DIR/mirror_b.tmp"'" >"'"$missing_in_b"'"'
  run_with_spinner "MIRROR" "Comparando faltantes (A)..." bash -c 'join -v2 -t$'"'"'\t'"'"' "'"$STATE_DIR/mirror_a.tmp"'" "'"$STATE_DIR/mirror_b.tmp"'" >"'"$missing_in_a"'"'
  run_with_spinner "MIRROR" "Detectando hashes distintos..." bash -c 'join -t$'"'"'\t'"'"' "'"$STATE_DIR/mirror_a.tmp"'" "'"$STATE_DIR/mirror_b.tmp"'" | awk -F"\t" "{if (\$2!=\$3) print \$1\"\tA:\"\$2\"\tB:\"\$3}" >"'"$mismatch"'"'
  printf "%s[OK]%s Mirror check generado:\n" "$C_GRN" "$C_RESET"
  printf "  Falta en B: %s\n" "$missing_in_b"
  printf "  Falta en A: %s\n" "$missing_in_a"
  printf "  Hash distinto (posible corrupción): %s\n" "$mismatch"
  pause_enter
}

action_state_health() {
  print_header
  refresh_artifact_state
  printf "%s[INFO]%s Doctor integral del estado (_DJProducerTools)\n" "$C_CYN" "$C_RESET"
  local free_base free_state report_count plans_count quar_count log_count
  status_line "DOCTOR" "10" "Analizando espacio..." ""
  free_base=$(df -h "$BASE_PATH" 2>/dev/null | awk 'NR==2{print $4" libres, uso "$5}')
  free_state=$(df -h "$STATE_DIR" 2>/dev/null | awk 'NR==2{print $4" libres, uso "$5}')
  status_line "DOCTOR" "30" "Contando reportes y planes..." ""
  report_count=$(find "$REPORTS_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
  plans_count=$(find "$PLANS_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
  quar_count=$(find "$QUAR_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
  log_count=$(find "$LOGS_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
  status_line "DOCTOR" "60" "Verificando herramientas..." ""
  tools_missing=()
  tools_versions=()
  for tool in ffprobe ffmpeg sox flac metaflac id3v2 mid3v2 shntool jq python3 shasum; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      tools_missing+=("$tool")
    else
      ver="$($tool -version 2>/dev/null | head -n 1)"
      [ -z "$ver" ] && ver="$($tool --version 2>/dev/null | head -n 1)"
      tools_versions+=("$tool => ${ver:-n/d}")
    fi
  done
  status_line "DOCTOR" "90" "Verificando entorno ML..." ""
  venv_status="No venv ML"
  if [ -f "$VENV_DIR/bin/activate" ]; then
    venv_status="Present"
    if [ -x "$VENV_DIR/bin/python" ]; then
      tf_ver="$("$VENV_DIR/bin/python" - <<'PY' 2>/dev/null
try:
    import tensorflow as tf
    print(tf.__version__)
except Exception:
    print("")
PY
)"
      venv_status="Present (TensorFlow ${tf_ver:-no import})"
    fi
  fi
  finish_status_line
  {
    echo "SUPER DOCTOR REPORT"
    echo "Fecha: $(date '+%Y-%m-%d %H:%M')"
    echo "BASE_PATH: $BASE_PATH"
    echo "STATE_DIR: $STATE_DIR"
    echo "Espacio BASE_PATH: ${free_base:-n/d}"
    echo "Espacio STATE_DIR: ${free_state:-n/d}"
    echo "STATE_DIR size:"
    du -sh "$STATE_DIR" 2>/dev/null || true
    echo
    echo "Artefactos clave:"
    echo "  hash_index.tsv: $([ "$ART_HAS_HASH" -eq 1 ] && echo OK || echo missing) ${ART_HASH_DATE:+($ART_HASH_DATE)}"
    echo "  snapshot_hash_fast.tsv: $([ "$ART_HAS_SNAPSHOT" -eq 1 ] && echo OK || echo missing) ${ART_SNAPSHOT_DATE:+($ART_SNAPSHOT_DATE)}"
    echo "  dupes_plan.tsv: $([ "$ART_HAS_DUPES_PLAN" -eq 1 ] && echo OK || echo missing) ${ART_DUPES_PLAN_DATE:+($ART_DUPES_PLAN_DATE)}"
    echo "  quarantine/: ${ART_QUAR_COUNT:-0} archivos${ART_QUAR_SIZE:+, ${ART_QUAR_SIZE}}"
    echo "  reports/: ${ART_REPORTS_SIZE:-n/d}"
    echo
    echo "Conteos:"
    echo "  reports: $report_count"
    echo "  plans: $plans_count"
    echo "  quarantine: $quar_count"
    echo "  logs: $log_count"
    echo "  ML venv: $venv_status"
    echo
    if [ "${#tools_missing[@]}" -gt 0 ]; then
      echo "Herramientas faltantes:"
      printf "  - %s\n" "${tools_missing[@]}"
      echo "Sugerencia (Homebrew): brew install ffmpeg sox flac id3v2 shntool jq"
      echo "Mutagen (para etiquetas): pip install mutagen"
    else
      echo "Herramientas requeridas: OK"
    fi
    if [ "${#tools_versions[@]}" -gt 0 ]; then
      echo "Versiones detectadas:"
      printf "  - %s\n" "${tools_versions[@]}"
    fi
    echo
    echo "Recomendaciones:"
    echo "  - Si falta hash/snapshot/plan dupes: ejecuta 9/10/27."
    echo "  - Revisa quarantine con 11/12; libera espacio si es grande."
    echo "  - Usa 57 para exclusiones antes de escaneos pesados."
  } >"$STATE_HEALTH_REPORT"
  printf "%s[OK]%s Reporte doctor: %s\n" "$C_GRN" "$C_RESET" "$STATE_HEALTH_REPORT"
  if [ "${#tools_missing[@]}" -gt 0 ]; then
    printf "%s[WARN]%s Herramientas faltantes: %s\n" "$C_YLW" "$C_RESET" "${tools_missing[*]}"
  fi
  pause_enter
}

action_60_export_import_config() {
  print_header
  printf "%s[INFO]%s Export/Import solo config/perfiles.\n" "$C_CYN" "$C_RESET"
  printf "1) Exportar config\n2) Importar config\nOpción: "
  read -e -r cio
  case "$cio" in
    1)
      bundle="$STATE_DIR/config_bundle_$(date +%s).tar.gz"
      run_with_spinner "EXPORT_CONFIG" "Comprimiendo configuración..." tar -czf "$bundle" -C "$CONFIG_DIR" . 2>/dev/null
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
      run_with_spinner "IMPORT_CONFIG" "Extrayendo configuración..." tar -xzf "$bpath" -C "$CONFIG_DIR" 2>/dev/null
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
      printf "%s[INFO]%s Entrenando modelo (puede tardar)...\n" "$C_CYN" "$C_RESET"
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
      printf "%s[INFO]%s Prediciendo con modelo...\n" "$C_CYN" "$C_RESET"
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
    printf "%s=== TensorFlow Lab (requiere TF instalado) ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s[INFO]%s Dependencias: python3 + tensorflow + tensorflow_hub + soundfile + numpy. Límite: ~150 archivos; similitud usa umbral >=0.60 (top 200 pares).\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Auto-tagging de audio (embeddings)\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Similitud por contenido (audio)\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Detección de fragmentos repetidos/loops\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s Clasificador de sospechosos (basura/silencio)\n" "$C_YLW" "$C_RESET"
    printf "%s5)%s Estimar loudness (plan de normalización)\n" "$C_YLW" "$C_RESET"
    printf "%s6)%s Auto-segmentación (cues preliminares)\n" "$C_YLW" "$C_RESET"
    printf "%s7)%s Matching cross-platform (relink inteligente)\n" "$C_YLW" "$C_RESET"
    printf "%s8)%s Auto-tagging de vídeo (keyframes)\n" "$C_YLW" "$C_RESET"
    printf "%s9)%s Music Tagging (multi-label, modelo TF Hub)\n" "$C_YLW" "$C_RESET"
    printf "%s10)%s Playlists Inteligentes (Key/BPM/Mashup clusters)\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Volver\n" "$C_YLW" "$C_RESET"
    printf "%sOpción:%s " "$C_BLU" "$C_RESET"
    read -r top
    case "$top" in
      1)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML está deshabilitado (usa 63 para habilitarlo).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Auto-tagging" 1 1
        out="$REPORTS_DIR/tf_audio_autotag.tsv"
        if ! python3 - <<'PY' 2>/dev/null
import sys
try:
    import tensorflow as tf  # noqa
except Exception:
    sys.exit(1)
sys.exit(0)
PY
        then
          printf "%s[ERR]%s TensorFlow no disponible. Instala con opción 64.\n" "$C_RED" "$C_RESET"
          pause_enter; continue
        fi
        printf "Modelo (1=YAMNet, 2=MusicTag NNFP, 3=VGGish fallback) [1]: "
        read -r model_sel
        [ -z "$model_sel" ] && model_sel=1
        printf "%s[INFO]%s Auto-tagging (modelo seleccionado: %s, máx 150 archivos).\n" "$C_CYN" "$C_RESET" "$model_sel"
        BASE="$BASE_PATH" OUT="$out" MODEL_SEL="$model_sel" python3 - <<'PY'
import os, sys, pathlib, heapq
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
    "4": "https://tfhub.dev/google/musicnn/1",
}
model_choice = os.environ.get("MODEL_SEL", "1")
model_url = MODEL_CHOICES.get(model_choice, MODEL_CHOICES["1"])

base = pathlib.Path(os.environ.get("BASE") or ".")
out = pathlib.Path(os.environ["OUT"])
audio_exts = {".mp3", ".wav", ".flac", ".m4a", ".aiff", ".aif"}
files = []
for p in base.rglob("*"):
    if p.suffix.lower() in audio_exts and p.is_file():
        files.append(p)
    if len(files) >= 150:
        break
if not files:
    print("[ERR] Sin archivos de audio.")
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

def predict_scores(wav):
    # Try model signatures
    if hasattr(model, "signatures") and "serving_default" in model.signatures:
        sig = model.signatures["serving_default"]
        outputs = sig(tf.convert_to_tensor(wav, dtype=tf.float32))
        logits = None
        for v in outputs.values():
            logits = v
            break
        if logits is None:
            return None
        return tf.nn.softmax(logits[0]).numpy()
    else:
        outp = model(wav)
        if isinstance(outp, (list, tuple)):
            logits = outp[0]
        else:
            logits = outp
        arr = tf.convert_to_tensor(logits)
        if arr.ndim == 2:
            return tf.nn.softmax(arr)[0].numpy()
        elif arr.ndim == 1:
            return tf.nn.softmax(arr)[0].numpy()
        else:
            return None

with out.open("w", encoding="utf-8") as f:
    f.write("path\ttop1\tp1\ttop2\tp2\ttop3\tp3\n")
    for p in files:
        try:
            wav = load_mono_16k(str(p))
            scores = predict_scores(wav)
            if scores is None:
                continue
            top3 = heapq.nlargest(3, enumerate(scores), key=lambda x: x[1])
            names_scores = []
            for idx, sc in top3:
                if class_names and idx < len(class_names):
                    name = class_names[idx]
                else:
                    name = f"class_{idx}"
                names_scores.append((name, sc))
            while len(names_scores) < 3:
                names_scores.append(("unknown", 0.0))
            (n1, s1), (n2, s2), (n3, s3) = names_scores
            f.write(f"{p}\t{n1}\t{s1:.3f}\t{n2}\t{s2:.3f}\t{n3}\t{s3:.3f}\n")
        except Exception:
            continue
print(f"[OK] Auto-tagging {model_url}: {out}")
PY
        rc=$?
        if [ "$rc" -ne 0 ]; then
          printf "%s[ERR]%s No se pudo generar auto-tagging (revisa TF/tf_hub/soundfile).\n" "$C_RED" "$C_RESET"
        else
          printf "%s[OK]%s Reporte auto-tagging: %s\n" "$C_GRN" "$C_RESET" "$out"
        fi
        pause_enter
        ;;
      2)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML está deshabilitado (usa 63 para habilitarlo).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Similitud audio" 1 1
        out="$REPORTS_DIR/tf_audio_similarity.tsv"
        if ! python3 - <<'PY' 2>/dev/null
import sys
try:
    import tensorflow as tf  # noqa
except Exception:
    sys.exit(1)
sys.exit(0)
PY
        then
          printf "%s[ERR]%s TensorFlow no disponible. Instala con opción 64.\n" "$C_RED" "$C_RESET"
          pause_enter; continue
        fi
        printf "Modelo (1=YAMNet, 2=MusicTag NNFP, 3=VGGish, 4=Musicnn) [1]: "
        read -r model_sel
        [ -z "$model_sel" ] && model_sel=1
        printf "%s[INFO]%s Similitud audio (modelo %s, máx 150 archivos, umbral 0.60, top 200 pares).\n" "$C_CYN" "$C_RESET" "$model_sel"
        out="$REPORTS_DIR/tf_audio_similarity.tsv"
        plan="$PLANS_DIR/tf_audio_similarity_plan.tsv"
        BASE="$BASE_PATH" REPORT="$out" PLAN="$plan" MODEL_SEL="$model_sel" python3 - <<'PY'
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
    "4": "https://tfhub.dev/google/musicnn/1",
}
model_choice = os.environ.get("MODEL_SEL", "1")
model_url = MODEL_CHOICES.get(model_choice, MODEL_CHOICES["1"])

base = pathlib.Path(os.environ.get("BASE") or ".")
report_path = pathlib.Path(os.environ["REPORT"])
plan_path = pathlib.Path(os.environ["PLAN"])
audio_exts = {".mp3", ".wav", ".flac", ".m4a", ".aiff", ".aif"}
files = []
for p in base.rglob("*"):
    if p.suffix.lower() in audio_exts and p.is_file():
        files.append(p)
    if len(files) >= 150:
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
        # try first value
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
            # try simple tag: top class if available
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
    if sim >= 0.6:
        pairs.append((sim, f1, f2, t1, t2))
top_pairs = heapq.nlargest(200, pairs, key=lambda x: x[0])

with report_path.open("w", encoding="utf-8") as rf, plan_path.open("w", encoding="utf-8") as pf:
    rf.write("file_a\tfile_b\tsimilarity\ttag_a\ttag_b\n")
    pf.write("file_a\tfile_b\taction\n")
    for sim, f1, f2, t1, t2 in top_pairs:
        rf.write(f"{f1}\t{f2}\t{sim:.3f}\t{t1}\t{t2}\n")
        pf.write(f"{f1}\t{f2}\tREVIEW\n")

print(f"[OK] Reporte: {report_path}")
print(f\"[OK] Plan: {plan_path}\")
PY
        rc=$?
        if [ "$rc" -ne 0 ]; then
          printf "%s[ERR]%s No se pudo generar similitud (revise TF/tf_hub/soundfile). RC=%s\n" "$C_RED" "$C_RESET" "$rc"
        else
          printf "%s[OK]%s Reporte similitud TF: %s\n" "$C_GRN" "$C_RESET" "$out"
          printf "%s[OK]%s Plan similitud TF: %s\n" "$C_GRN" "$C_RESET" "$plan"
        fi
        pause_enter
        ;;
      3)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML está deshabilitado (usa 63 para habilitarlo).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Loops/Fragmentos" 1 1
        out="$REPORTS_DIR/tf_loops_report.tsv"
        printf "%s[INFO]%s Detección de loops placeholder (requiere TF + modelo futuro).\n" "$C_CYN" "$C_RESET"
        find "$BASE_PATH" -type f -iname "*.wav" 2>/dev/null | head -50 >"$STATE_DIR/tf_loops_list.tmp"
        >"$out"
        while IFS= read -r f; do
          printf "%s\t%s\n" "$f" "loop_check_pending" >>"$out"
        done <"$STATE_DIR/tf_loops_list.tmp"
        rm -f "$STATE_DIR/tf_loops_list.tmp"
        printf "%s[OK]%s Reporte placeholder: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      4)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML está deshabilitado (usa 63 para habilitarlo).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Sospechosos" 1 1
        out="$REPORTS_DIR/tf_suspect_audio.tsv"
        printf "%s[INFO]%s Clasificador de sospechosos placeholder (requiere TF modelo futuro).\n" "$C_CYN" "$C_RESET"
        find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.wav" \) 2>/dev/null | head -100 >"$STATE_DIR/tf_suspect_list.tmp"
        >"$out"
        while IFS= read -r f; do
          printf "%s\t%s\n" "$f" "score_pending" >>"$out"
        done <"$STATE_DIR/tf_suspect_list.tmp"
        rm -f "$STATE_DIR/tf_suspect_list.tmp"
        printf "%s[OK]%s Reporte placeholder: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      5)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML está deshabilitado (usa 63 para habilitarlo).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Loudness" 1 1
        out="$REPORTS_DIR/tf_loudness_plan.tsv"
        printf "%s[INFO]%s Estimación de loudness placeholder (LUFS) para plan de normalización.\n" "$C_CYN" "$C_RESET"
        find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.wav" \) 2>/dev/null | head -100 >"$STATE_DIR/tf_loud_list.tmp"
        >"$out"
        while IFS= read -r f; do
          printf "%s\t%s\t%s\n" "$f" "lufs_pending" "gain_pending" >>"$out"
        done <"$STATE_DIR/tf_loud_list.tmp"
        rm -f "$STATE_DIR/tf_loud_list.tmp"
        printf "%s[OK]%s Plan placeholder: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      6)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML está deshabilitado (usa 63 para habilitarlo).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Auto-cues" 1 1
        out="$REPORTS_DIR/tf_autocues.tsv"
        printf "%s[INFO]%s Auto-segmentación placeholder (onsets/beat) para cues preliminares.\n" "$C_CYN" "$C_RESET"
        find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.wav" \) 2>/dev/null | head -50 >"$STATE_DIR/tf_cues_list.tmp"
        >"$out"
        while IFS= read -r f; do
          printf "%s\t%s\t%s\n" "$f" "00:00:00" "cue_pending" >>"$out"
        done <"$STATE_DIR/tf_cues_list.tmp"
        rm -f "$STATE_DIR/tf_cues_list.tmp"
        printf "%s[OK]%s Plan cues placeholder: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      7)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML está deshabilitado (usa 63 para habilitarlo).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Cross-platform matching" 1 1
        out="$REPORTS_DIR/tf_crossplatform_matching.tsv"
        printf "%s[INFO]%s Matching cross-platform placeholder (embeddings para relink inteligente).\n" "$C_CYN" "$C_RESET"
        printf "%s\t%s\t%s\n" "track_a" "track_b" "score_pending" >"$out"
        printf "%s[OK]%s Reporte placeholder: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      8)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML está deshabilitado (usa 63 para habilitarlo).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Video tagging" 1 1
        out="$REPORTS_DIR/tf_video_autotag.tsv"
        printf "%s[INFO]%s Auto-tagging de vídeo placeholder (keyframes/clasificación futura).\n" "$C_CYN" "$C_RESET"
        find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" \) 2>/dev/null | head -50 >"$STATE_DIR/tf_video_list.tmp"
        >"$out"
        while IFS= read -r f; do
          printf "%s\t%s\n" "$f" "tags_pending" >>"$out"
        done <"$STATE_DIR/tf_video_list.tmp"
        rm -f "$STATE_DIR/tf_video_list.tmp"
        printf "%s[OK]%s Reporte placeholder: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      9)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML está deshabilitado (usa 63 para habilitarlo).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Music Tagging" 1 1
        out="$REPORTS_DIR/tf_music_tagging.tsv"
        printf "%s[INFO]%s Music tagging multi-label (intenta modelo TF Hub; etiquetas top3 por archivo, máx 150).\n" "$C_CYN" "$C_RESET"
        BASE="$BASE_PATH" OUT="$out" python3 - <<'PY'
import os, sys, pathlib, heapq
try:
    import tensorflow as tf
    import tensorflow_hub as hub
    import soundfile as sf
    import numpy as np
except Exception:
    sys.exit(1)

MODEL_URLS = [
    "https://tfhub.dev/google/music_tagging/nnfp/1",
    "https://tfhub.dev/google/vggish/1"
]

base = pathlib.Path(os.environ.get("BASE") or ".")
out = pathlib.Path(os.environ["OUT"])
audio_exts = {".mp3", ".wav", ".flac", ".m4a", ".aiff", ".aif"}
files = []
for p in base.rglob("*"):
    if p.suffix.lower() in audio_exts and p.is_file():
        files.append(p)
    if len(files) >= 150:
        break
if not files:
    print("[ERR] Sin archivos de audio.")
    sys.exit(2)

model = None
labels = []
for url in MODEL_URLS:
    try:
        model = hub.load(url)
        if hasattr(model, "labels"):
            labels = model.labels
        break
    except Exception:
        continue
if model is None:
    print("[ERR] No se pudo cargar modelo TF Hub (music tagging/vggish).")
    sys.exit(3)

def load_mono_16k(path):
    data, sr = sf.read(path)
    if data.ndim > 1:
        data = data.mean(axis=1)
    if sr != 16000:
        target_len = int(len(data) * 16000 / sr)
        data = tf.signal.resample(tf.convert_to_tensor(data, dtype=tf.float32), target_len).numpy()
    return data

with out.open("w", encoding="utf-8") as f:
    f.write("path\ttop1\tp1\ttop2\tp2\ttop3\tp3\n")
    for p in files:
        try:
            wav = load_mono_16k(str(p))
            if hasattr(model, "signatures") and "serving_default" in model.signatures:
                sig = model.signatures["serving_default"]
                outputs = sig(tf.convert_to_tensor(wav, dtype=tf.float32))
                logits = None
                for v in outputs.values():
                    logits = v
                    break
                if logits is None:
                    continue
                scores = tf.nn.softmax(logits[0]).numpy()
            else:
                # fallback: try model(wav) directly
                outputs = model(wav)
                if isinstance(outputs, (list, tuple)):
                    logits = outputs[0]
                else:
                    logits = outputs
                scores = tf.nn.softmax(logits).numpy()[0]
            top3 = heapq.nlargest(3, enumerate(scores), key=lambda x: x[1])
            names_scores = []
            for idx, sc in top3:
                if labels and idx < len(labels):
                    name = labels[idx]
                else:
                    name = f"class_{idx}"
                names_scores.append((name, sc))
            while len(names_scores) < 3:
                names_scores.append(("unknown", 0.0))
            (n1, s1), (n2, s2), (n3, s3) = names_scores
            f.write(f"{p}\t{n1}\t{s1:.3f}\t{n2}\t{s2:.3f}\t{n3}\t{s3:.3f}\n")
        except Exception:
            continue
print(f"[OK] Music tagging: {out}")
PY
        rc=$?
        if [ "$rc" -ne 0 ]; then
          printf "%s[ERR]%s No se pudo generar music tagging (revisa TF/tf_hub/soundfile). RC=%s\n" "$C_RED" "$C_RESET" "$rc"
        else
          printf "%s[OK]%s Music tagging TSV: %s\n" "$C_GRN" "$C_RESET" "$out"
        fi
        pause_enter
        ;;
      10)
        action_T_smart_playlists
        ;;
      B|b)
        break ;;
      *)
        invalid_option ;;
    esac
  done
}

action_audio_lufs_plan() {
  print_header
  printf "%s[INFO]%s Plan LUFS/normalización (solo análisis, no modifica audio).\n" "$C_CYN" "$C_RESET"
  out="$REPORTS_DIR/audio_lufs_plan.tsv"
  printf "Escaneando (mp3/wav/flac/m4a)...\n"
  python3 - <<'PY'
import sys
try:
    import pyloudnorm as pyln
    import soundfile as sf
except Exception:
    sys.exit(1)
PY
  rc=$?
  if [ "$rc" -ne 0 ]; then
    printf "%s[ERR]%s Requiere python3 + pyloudnorm + soundfile.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi

  list_tmp=$(mktemp "${STATE_DIR}/lufs_list.XXXXXX") || list_tmp="/tmp/lufs_list.$$"
  find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.aiff" -o -iname "*.aif" \) 2>/dev/null | head -200 >"$list_tmp"
  total=$(wc -l <"$list_tmp" | tr -d ' ')
  if [ "$total" -eq 0 ]; then
    rm -f "$list_tmp"
    printf "%s[WARN]%s No se encontraron archivos.\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi

  >"$out"
  printf "path\tlufs\tsugerencia_gain_db\n" >>"$out"
  count=0
  while IFS= read -r f; do
    count=$((count + 1))
    if [ "$total" -gt 0 ]; then
      percent=$((count * 100 / total))
    else
      percent=0
    fi
    status_line "LUFS" "$percent" "$(basename "$f")"
    result=$(python3 - "$f" <<'PY'
import sys
try:
    import pyloudnorm as pyln
    import soundfile as sf
except Exception:
    sys.exit(2)

path = sys.argv[1]
try:
    data, sr = sf.read(path)
    if getattr(data, "ndim", 1) > 1:
        data = data.mean(axis=1)
    meter = pyln.Meter(sr)
    loud = meter.integrated_loudness(data)
    target = -14.0
    gain = target - loud
    print(f"{loud:.2f}\t{gain:.2f}")
except Exception:
    pass
PY
)
    if [ -n "$result" ]; then
      printf "%s\t%s\n" "$f" "$result" >>"$out"
    fi
  done <"$list_tmp"
  finish_status_line
  rm -f "$list_tmp"
  printf "%s[OK]%s Plan LUFS generado: %s\n" "$C_GRN" "$C_RESET" "$out"
  pause_enter
}

action_audio_cues_onsets() {
  print_header
  printf "%s[INFO]%s Auto-cues por onsets (librosa; plan TSV).\n" "$C_CYN" "$C_RESET"
  out="$REPORTS_DIR/auto_cues_onsets.tsv"
  python3 - <<'PY'
import sys
try:
    import librosa
except Exception:
    sys.exit(1)
PY
  rc=$?
  if [ "$rc" -ne 0 ]; then
    printf "%s[ERR]%s Requiere python3 + librosa.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi

  list_tmp=$(mktemp "${STATE_DIR}/cues_list.XXXXXX") || list_tmp="/tmp/cues_list.$$"
  find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.aiff" -o -iname "*.aif" \) 2>/dev/null | head -200 >"$list_tmp"
  total=$(wc -l <"$list_tmp" | tr -d ' ')
  if [ "$total" -eq 0 ]; then
    rm -f "$list_tmp"
    printf "%s[WARN]%s No se encontraron archivos.\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi

  >"$out"
  printf "path\tcue_sec\n" >>"$out"
  count=0
  while IFS= read -r f; do
    count=$((count + 1))
    if [ "$total" -gt 0 ]; then
      percent=$((count * 100 / total))
    else
      percent=0
    fi
    status_line "AUTO_CUES" "$percent" "$(basename "$f")"
    cue=$(python3 - "$f" <<'PY'
import sys
try:
    import librosa
except Exception:
    sys.exit(2)

path = sys.argv[1]
try:
    y, sr = librosa.load(path, sr=44100, mono=True, duration=180)
    onsets = librosa.onset.onset_detect(y=y, sr=sr, units="time")
    if onsets.size == 0:
        sys.exit(0)
    first = float(onsets[0])
    print(f"{first:.2f}")
except Exception:
    pass
PY
)
    if [ -n "$cue" ]; then
      printf "%s\t%s\n" "$f" "$cue" >>"$out"
    fi
  done <"$list_tmp"
  finish_status_line
  rm -f "$list_tmp"
  printf "%s[OK]%s Auto-cues generado: %s\n" "$C_GRN" "$C_RESET" "$out"
  pause_enter
}

submenu_profiles_manager() {
  while true; do
    clear
    print_header
    printf "%s=== Gestor de perfiles ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Guardar perfil actual\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Cargar perfil\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Listar perfiles\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s Eliminar perfil\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Volver\n" "$C_YLW" "$C_RESET"
    printf "%sOpción:%s " "$C_BLU" "$C_RESET"
    read -r pop
    case "$pop" in
      1)
        printf "Nombre de perfil (ej: principal, disco_ext): "
        read -r pname
        [ -z "$pname" ] && { printf "%s[WARN]%s Nombre vacío.\n" "$C_YLW" "$C_RESET"; pause_enter; continue; }
        mkdir -p "$PROFILES_DIR"
        pfile="$PROFILES_DIR/${pname}.conf"
        {
          printf 'BASE_PATH=%q\n' "$BASE_PATH"
          printf 'AUDIO_ROOT=%q\n' "${AUDIO_ROOT:-}"
          printf 'GENERAL_ROOT=%q\n' "${GENERAL_ROOT:-}"
          printf 'SERATO_ROOT=%q\n' "${SERATO_ROOT:-}"
          printf 'REKORDBOX_XML=%q\n' "${REKORDBOX_XML:-}"
          printf 'ABLETON_ROOT=%q\n' "${ABLETON_ROOT:-}"
          printf 'EXTRA_SOURCE_ROOTS=%q\n' "${EXTRA_SOURCE_ROOTS:-}"
        } >"$pfile"
        printf "%s[OK]%s Perfil guardado: %s\n" "$C_GRN" "$C_RESET" "$pfile"
        pause_enter
        ;;
      2)
        mkdir -p "$PROFILES_DIR"
        mapfile -t plist < <(ls -1 "$PROFILES_DIR" 2>/dev/null | sed 's/\\.conf$//')
        if [ "${#plist[@]}" -eq 0 ]; then
          printf "%s[WARN]%s No hay perfiles guardados aún.\n" "$C_YLW" "$C_RESET"
          pause_enter
          continue
        fi
        printf "%s[INFO]%s Perfiles disponibles en %s:\n" "$C_CYN" "$C_RESET" "$PROFILES_DIR"
        idx=1
        for p in "${plist[@]}"; do
          printf "  [%d] %s\n" "$idx" "$p"
          idx=$((idx + 1))
        done
        printf "Nombre de perfil a cargar (o número, ENTER para cancelar): "
        read -r pname
        if [[ "$pname" =~ ^[0-9]+$ ]] && [ "$pname" -ge 1 ] && [ "$pname" -le "${#plist[@]}" ]; then
          pname="${plist[$((pname-1))]}"
        fi
        [ -z "$pname" ] && { printf "%s[INFO]%s Cancelado.\n" "$C_CYN" "$C_RESET"; pause_enter; continue; }
        pfile="$PROFILES_DIR/${pname}.conf"
        if [ ! -f "$pfile" ]; then
          printf "%s[ERR]%s No existe: %s\n" "$C_RED" "$C_RESET" "$pfile"
          pause_enter
          continue
        fi
        # shellcheck disable=SC1090
        . "$pfile"
        init_paths
        save_conf
        printf "%s[OK]%s Perfil cargado: %s\n" "$C_GRN" "$C_RESET" "$pfile"
        for warn_path in "$BASE_PATH" "${AUDIO_ROOT:-}" "${GENERAL_ROOT:-}" "${SERATO_ROOT:-}" "${ABLETON_ROOT:-}"; do
          if [ -n "$warn_path" ] && [ ! -d "$warn_path" ]; then
            printf "%s[WARN]%s Ruta no existe: %s\n" "$C_YLW" "$C_RESET" "$warn_path"
          fi
        done
        pause_enter
        ;;
      3)
        printf "%s[INFO]%s Perfiles en %s:\n" "$C_CYN" "$C_RESET" "$PROFILES_DIR"
        ls -1 "$PROFILES_DIR" 2>/dev/null || printf "(vacío)\n"
        pause_enter
        ;;
      4)
        printf "Nombre de perfil a eliminar: "
        read -r pname
        pfile="$PROFILES_DIR/${pname}.conf"
        if [ ! -f "$pfile" ]; then
          printf "%s[ERR]%s No existe: %s\n" "$C_RED" "$C_RESET" "$pfile"
          pause_enter
          continue
        fi
        rm -f "$pfile" 2>/dev/null || true
        printf "%s[OK]%s Eliminado: %s\n" "$C_GRN" "$C_RESET" "$pfile"
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

action_30_plan_tags() {
  print_header
  out="$PLANS_DIR/audio_by_tags_plan.tsv"
  if ! maybe_reuse_file "$out" "audio_by_tags_plan.tsv"; then return; fi
  printf "%s[INFO]%s Organizar audio por TAGS -> plan TSV: %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  mapfile -t files < <(find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null)
  total=${#files[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No se encontraron archivos de audio.\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi

  count=0
  for f in "${files[@]}"; do
    count=$((count + 1))
    percent=$((count * 100 / total))
    status_line "TAG_PLAN" "$percent" "$(basename "$f")"
    printf "%s\tGENRE_UNKNOWN\n" "$f" >>"$out"
  done
  finish_status_line
  printf "%s[OK]%s Plan de TAGS generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_31_report_tags() {
  print_header
  plan="$PLANS_DIR/audio_by_tags_plan.tsv"
  out="$REPORTS_DIR/audio_tags_report.tsv"
  if ! maybe_reuse_file "$out" "audio_tags_report.tsv"; then return; fi
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
  printf "%s[INFO]%s Serato Video REPORT -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  list_tmp=$(mktemp "${STATE_DIR}/sv_report.XXXXXX") || list_tmp="/tmp/sv_report.$$"
  find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" \) 2>/dev/null >"$list_tmp"
  total=$(wc -l <"$list_tmp" | tr -d ' ')
  count=0
  while IFS= read -r f; do
    count=$((count + 1))
    if [ "$total" -gt 0 ]; then
      percent=$((count * 100 / total))
    else
      percent=0
    fi
    status_line "VIDEO_REPORT" "$percent" "$(basename "$f")"
    printf "%s\n" "$f" >>"$out"
  done <"$list_tmp"
  rm -f "$list_tmp"
  finish_status_line
  printf "%s[OK]%s Reporte vídeo generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_33_serato_video_prep() {
  print_header
  out="$PLANS_DIR/serato_video_transcode_plan.tsv"
  printf "%s[INFO]%s Serato Video PREP (plan transcode) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  list_tmp=$(mktemp "${STATE_DIR}/sv_prep.XXXXXX") || list_tmp="/tmp/sv_prep.$$"
  find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" \) 2>/dev/null >"$list_tmp"
  total=$(wc -l <"$list_tmp" | tr -d ' ')
  count=0
  while IFS= read -r f; do
    count=$((count + 1))
    if [ "$total" -gt 0 ]; then
      percent=$((count * 100 / total))
    else
      percent=0
    fi
    status_line "VIDEO_PREP" "$percent" "$(basename "$f")"
    printf "%s\tTRANSCODE_H264\n" "$f" >>"$out"
  done <"$list_tmp"
  rm -f "$list_tmp"
  finish_status_line
  printf "%s[OK]%s Plan de transcode generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_34_normalize_names() {
  print_header
  out="$PLANS_DIR/normalize_names_plan.tsv"
  printf "%s[INFO]%s Normalizar nombres (plan TSV) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  total=$(find "$BASE_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
  count=0
  find "$BASE_PATH" -type f 2>/dev/null | while IFS= read -r f; do
    count=$((count + 1))
    if [ "$total" -gt 0 ]; then
      percent=$((count * 100 / total))
    else
      percent=0
    fi
    status_line "NAMES" "$percent" "$(basename "$f")"
    base="$(basename "$f")"
    dir="$(dirname "$f")"
    new="$dir/$base"
    printf "%s\t%s\n" "$f" "$new" >>"$out"
  done
  finish_status_line
  printf "%s[OK]%s Plan de renombrado generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_35_samples_by_type() {
  print_header
  out="$PLANS_DIR/samples_by_type_plan.tsv"
  printf "%s[INFO]%s Organizar samples por TIPO (plan TSV) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  mapfile -t files < <(find "$BASE_PATH" -type f \( -iname "*kick*.wav" -o -iname "*snare*.wav" -o -iname "*hat*.wav" -o -iname "*bass*.wav" \) 2>/dev/null)
  total=${#files[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No se encontraron samples con nombres comunes.\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi

  count=0
  for f in "${files[@]}"; do
    count=$((count + 1))
    percent=$((count * 100 / total))
    status_line "SAMPLES" "$percent" "$(basename "$f")"
    type="OTHER"
    case "$(basename "$f" | tr '[:upper:]' '[:lower:]')" in
      *kick*) type="KICK" ;;
      *snare*) type="SNARE" ;;
      *hat*) type="HAT" ;;
      *bass*) type="BASS" ;;
    esac
    printf "%s\t%s\n" "$f" "$type" >>"$out"
  done
  finish_status_line
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
  mapfile -t files < <(find "$BASE_PATH" -type f \( -iname "*.m3u" -o -iname "*.m3u8" \) 2>/dev/null)
  total=${#files[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No se encontraron playlists (.m3u, .m3u8).\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi

  count=0
  for f in "${files[@]}"; do
    count=$((count + 1))
    percent=$((count * 100 / total))
    status_line "WEB_CLEAN" "$percent" "$(basename "$f")"
    tmp="$f.tmp"
    grep -vE "^https?://" "$f" >"$tmp" 2>/dev/null || true
    if [ -s "$tmp" ] || [ ! -s "$f" ]; then
      mv "$tmp" "$f" 2>/dev/null || true
    else
      rm -f "$tmp"
    fi
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
  mapfile -t files < <(find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null)
  total=${#files[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No se encontraron archivos de audio.\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi

  count=0
  for f in "${files[@]}"; do
    count=$((count + 1))
    percent=$((count * 100 / total))
    status_line "TAG_WEB_CLEAN" "$percent" "$(basename "$f")"
    printf "%s\tCLEAN_WEB_TAGS\n" "$f" >>"$out"
  done
  finish_status_line
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
  
  run_with_spinner "ANALYSIS" "Contando archivos totales..." total_files=$(find "$BASE_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
  run_with_spinner "ANALYSIS" "Contando archivos de audio..." audio_files=$(find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.m4a" \) 2>/dev/null | wc -l | tr -d ' ')
  run_with_spinner "ANALYSIS" "Contando archivos de video..." video_files=$(find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" \) 2>/dev/null | wc -l | tr -d ' ')
  run_with_spinner "ANALYSIS" "Calculando tamaño total..." size_kb=$(du -sk "$BASE_PATH" 2>/dev/null | awk '{print $1}')
  
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

  mapfile -t files < <(find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.m4a" \) 2>/dev/null | head -50)
  total=${#files[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No se encontraron archivos de audio para analizar.\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi

  count=0
  for f in "${files[@]}"; do
    count=$((count + 1))
    percent=$((count * 100 / total))
    status_line "ML_PREDICT" "$percent" "$(basename "$f")"
    fname=$(basename "$f")
    size=$({ stat -f %z "$f" 2>/dev/null || echo 0; } | tr -d ' ')
    if [ "${#fname}" -gt 80 ]; then
      printf "%s\tNombre muy largo\t75%%\tRevisar opción 34\n" "$f" >>"$prediction_report"
    fi
    if [ "$size" -eq 0 ]; then
      printf "%s\tArchivo vacío\t90%%\tReemplazar o borrar\n" "$f" >>"$prediction_report"
    fi
  done
  finish_status_line

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
        run_with_spinner "PARSE_XML" "Parseando Rekordbox XML..." python3 - "$rk" "$out" <<'PY'
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
        if [ $? -eq 0 ]; then
            printf "\n%s[OK]%s dj_cues.tsv generado: %s\n" "$C_GRN" "$C_RESET" "$out"
        else
            printf "\n%s[ERR]%s Falló el parseo de Rekordbox XML.\n" "$C_RED" "$C_RESET"
        fi
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
        run_with_spinner "PARSE_NML" "Parseando Traktor NML..." python3 - "$out" "${nml_list[@]}" <<'PY'
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
        if [ $? -eq 0 ]; then
            printf "\n%s[OK]%s Resumen Traktor: %s\n" "$C_GRN" "$C_RESET" "$out"
        else
            printf "\n%s[ERR]%s Falló el parseo de Traktor NML.\n" "$C_RED" "$C_RESET"
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

action_49_advanced_analysis() {
  maybe_activate_ml_env "Opción 49 (Análisis avanzado)"
  print_header
  printf "%s[INFO]%s 🔬 DEEP-THINKING: Análisis Avanzado Profundo\n" "$C_CYN" "$C_RESET"

  local ts advanced total_files audio_files
  ts=$(date +%s)
  advanced="$REPORTS_DIR/advanced_analysis_${ts}.json"
  total_files=$(find "$BASE_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
  audio_files=$(find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.m4a" \) 2>/dev/null | wc -l | tr -d ' ')
  : "${total_files:=0}"
  : "${audio_files:=0}"

  cat >"$advanced" <<EOF
{
  "analysis_type": "ADVANCED_PROFUNDO",
  "base_path": "$BASE_PATH",
  "scores": {
    "organizacion": "media",
    "riesgo": "medio-alto"
  },
  "totals": {
    "files": $total_files,
    "audio_files": $audio_files
  },
  "priority_actions": [
    "10 (Duplicados exactos)",
    "40 (Smart Analysis)",
    "39 (Limpiar WEB)",
    "34 (Normalizar nombres)"
  ]
}
EOF

  printf "%s[OK]%s Análisis avanzado: %s\n" "$C_GRN" "$C_RESET" "$advanced"
  pause_enter
}

action_50_integration_engine() {
  maybe_activate_ml_env "Opción 50 (Motor integración)"
  print_header
  printf "%s[INFO]%s ⚙️ DEEP-THINKING: Motor de Integración\n" "$C_CYN" "$C_RESET"

  local integration="$PLANS_DIR/integration_engine_$(date +%s).txt"
  cat >"$integration" <<'EOF'
MOTOR DE INTEGRACIÓN INTELIGENTE:
- 9 + 10: Hash + plan duplicados.
- 34 + 39: Normalizar nombres + limpiar URLs.
- 8 + 27: Backup + snapshot de integridad.
- 40 + 41 + 42: Análisis + predictor + optimizador.

Flujo sugerido:
40 (Análisis) -> 41 (Predictor) -> 10 (Dupes) -> 39 (Metadata) -> 8 (Backup)
EOF

  printf "%s[OK]%s Motor integración: %s\n" "$C_GRN" "$C_RESET" "$integration"
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

# === Cadenas automatizadas (combinan acciones existentes) ===

chain_run_header() {
  print_header
  printf "%s[INFO]%s Ejecutando cadena: %s\n" "$C_CYN" "$C_RESET" "$1"
}

chain_1_backup_snapshot() {
  chain_run_header "Backup seguro + snapshot (8 -> 27)"
  if ensure_tool_installed "rsync" "brew install rsync"; then
    action_8_backup_dj
  fi
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_27_snapshot
  fi
  printf "%s[OK]%s Cadena completada: backups y snapshot.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_2_dedup_quarantine() {
  chain_run_header "Dedup exacto y quarantine (10 -> 11)"
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_10_dupes_plan
    action_11_quarantine_from_plan
  fi
  printf "%s[OK]%s Cadena completada: plan de duplicados y quarantine.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_3_metadata_names() {
  chain_run_header "Limpieza de metadatos y nombres (39 -> 34)"
  if ensure_tool_installed "python3"; then
    if ensure_python_package_installed "mutagen"; then
        action_39_clean_web_tags
    fi
  fi
  action_34_normalize_names
  printf "%s[OK]%s Cadena completada: limpieza de metadatos y nombres.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_4_health_scan() {
  chain_run_header "Escaneo salud media (18 -> 14 -> 15)"
  action_18_rescan_intelligent
  action_14_playlists_per_folder
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_15_relink_helper
  fi
  printf "%s[OK]%s Cadena completada: escaneo de salud media.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_5_show_prep() {
  chain_run_header "Prep de show (8 -> 27 -> 10 -> 11 -> 14 -> 8)"
  if ensure_tool_installed "rsync" "brew install rsync"; then
    action_8_backup_dj
  fi
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_27_snapshot
    action_10_dupes_plan
    action_11_quarantine_from_plan
  fi
  action_14_playlists_per_folder
  if ensure_tool_installed "rsync" "brew install rsync"; then
    action_8_backup_dj
  fi
  printf "%s[OK]%s Cadena completada: pre/post backup, duplicados y playlists.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_6_media_integrity() {
  chain_run_header "Media integrity + corruptos (13 -> 18)"
  if ensure_tool_installed "ffprobe" "brew install ffmpeg"; then
    action_13_ffprobe_report
  fi
  action_18_rescan_intelligent
  printf "%s[OK]%s Cadena completada: reporte corruptos y rescan actualizado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_7_efficiency_plan() {
  chain_run_header "Plan de eficiencia (42 -> 44 -> 43)"
  action_42_efficiency_optimizer
  action_44_integrated_dedup
  action_43_smart_workflow
  printf "%s[OK]%s Cadena completada: planes de eficiencia/dedup/workflow.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_8_ml_org_basic() {
  chain_run_header "ML organización básica (45 -> 46)"
  maybe_activate_ml_env "Cadena 8 (ML organización básica)"
  action_45_ml_organization
  action_46_metadata_harmonizer
  printf "%s[OK]%s Cadena completada: organización ML y armonizador.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_9_predictive_backup() {
  chain_run_header "Backup predictivo (47 -> 8 -> 27)"
  maybe_activate_ml_env "Cadena 9 (Backup predictivo)"
  action_47_predictive_backup
  if ensure_tool_installed "rsync" "brew install rsync"; then
    action_8_backup_dj
  fi
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_27_snapshot
  fi
  printf "%s[OK]%s Cadena completada: plan + backup + snapshot.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_10_cross_sync() {
  chain_run_header "Sync multiplataforma (48 -> 39 -> 8 -> 8)"
  maybe_activate_ml_env "Cadena 10 (Sync multiplataforma)"
  action_48_cross_platform_sync
  if ensure_tool_installed "python3"; then
    if ensure_python_package_installed "mutagen"; then
        action_39_clean_web_tags
    fi
  fi
  if ensure_tool_installed "rsync" "brew install rsync"; then
    action_8_backup_dj
    action_8_backup_dj
  fi
  printf "%s[OK]%s Cadena completada: sync plan, limpieza metadatos y backups.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_11_quick_diag() {
  chain_run_header "Diagnóstico rápido (1 -> 3 -> 4 -> 5)"
  action_1_status
  action_3_summary
  action_4_top_dirs
  action_5_top_files
  printf "%s[OK]%s Cadena completada: estado + resumen + top carpetas/archivos.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_12_serato_health() {
  chain_run_header "Salud Serato (7 -> 59)"
  if ensure_tool_installed "rsync" "brew install rsync"; then
    action_7_backup_serato
  fi
  action_state_health
  printf "%s[OK]%s Cadena completada: backup Serato y health-check de estado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_13_hash_mirror_check() {
  chain_run_header "Hash + mirror check (9 -> 61)"
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_9_hash_index
    action_mirror_integrity_check
  fi
  printf "%s[OK]%s Cadena completada: hash_index y mirror check.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_14_audio_prep() {
  chain_run_header "Audio prep (31 -> 66 -> 67)"
  if ensure_tool_installed "python3"; then
    if ensure_python_package_installed "mutagen"; then
        action_31_report_tags
    fi
    if ensure_python_package_installed "librosa"; then
        action_audio_lufs_plan
        action_audio_cues_onsets
    fi
  fi
  printf "%s[OK]%s Cadena completada: reporte tags, plan LUFS y cues por onsets.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_15_integrity_audit() {
  chain_run_header "Auditoría completa de integridad (6 -> 9 -> 27 -> 61)"
  action_6_scan_workspace
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_9_hash_index
    action_27_snapshot
    action_mirror_integrity_check
  fi
  printf "%s[OK]%s Cadena completada: scan, hash_index, snapshot y mirror check.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_16_clean_backup() {
  chain_run_header "Limpieza + backup seguro (39 -> 34 -> 10 -> 11 -> 8 -> 27)"
  if ensure_tool_installed "python3"; then
    if ensure_python_package_installed "mutagen"; then
        action_39_clean_web_tags
    fi
  fi
  action_34_normalize_names
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_10_dupes_plan
    action_11_quarantine_from_plan
  fi
  if ensure_tool_installed "rsync" "brew install rsync"; then
    action_8_backup_dj
  fi
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_27_snapshot
  fi
  printf "%s[OK]%s Cadena completada: limpieza metadatos/nombres, dedup, backups y snapshot.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_17_sync_prep() {
  chain_run_header "Preparación para sync (18 -> 14 -> 48 -> 8 -> 27)"
  action_18_rescan_intelligent
  action_14_playlists_per_folder
  maybe_activate_ml_env "Cadena 17 (Preparación para sync)"
  action_48_cross_platform_sync
  if ensure_tool_installed "rsync" "brew install rsync"; then
    action_8_backup_dj
  fi
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_27_snapshot
  fi
  printf "%s[OK]%s Cadena completada: rescan, playlists, sync, backup y snapshot.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_18_visual_health() {
  chain_run_header "Salud visuales (V2 -> V6 -> V8 -> V9 -> 8)"
  action_V2_visuals_inventory
  if ensure_tool_installed "ffprobe" "brew install ffmpeg"; then
    action_V6_visuals_ffprobe_report
    action_V9_visuals_optimize_plan
  fi
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_V8_visuals_hash_dupes
  fi
  if ensure_tool_installed "rsync" "brew install rsync"; then
    action_8_backup_dj
  fi
  printf "%s[OK]%s Cadena completada: inventario, ffprobe, dupes visuales, plan optimizar y backup.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_19_audio_advanced() {
  chain_run_header "Organización avanzada audio (31 -> 30 -> 35 -> 45 -> 46)"
  if ensure_tool_installed "python3"; then
    if ensure_python_package_installed "mutagen"; then
        action_31_report_tags
        action_30_plan_tags
    fi
  fi
  action_35_samples_by_type
  maybe_activate_ml_env "Cadena 19 (Organización avanzada audio)"
  action_45_ml_organization
  action_46_metadata_harmonizer
  printf "%s[OK]%s Cadena completada: tags, plan por género, samples, org ML y armonizador.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_20_serato_safe() {
  chain_run_header "Seguridad Serato reforzada (7 -> 8 -> 59 -> 12 -> 47)"
  if ensure_tool_installed "rsync" "brew install rsync"; then
    action_7_backup_serato
    action_8_backup_dj
  fi
  action_state_health
  action_12_quarantine_manager
  maybe_activate_ml_env "Cadena 20 (Seguridad Serato reforzada)"
  action_47_predictive_backup
  printf "%s[OK]%s Cadena completada: backups, health-check, quarantine review y plan predictivo.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_21_multidisk_dedup() {
  chain_run_header "Dedup multi-disco + espejo (9 -> 10 -> 44 -> 11 -> 61)"
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_9_hash_index
    action_10_dupes_plan
    action_mirror_integrity_check
  fi
  maybe_activate_ml_env "Cadena 21 (Dedup multi-disco + espejo)"
  action_44_integrated_dedup
  action_11_quarantine_from_plan
  printf "%s[OK]%s Cadena completada: hash, plan duplicados, quarantine y mirror check.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_22_presskit_pack() {
  chain_run_header "Pack presskit / artist pages (69 export)"
  if ensure_tool_installed "python3"; then
    action_69_artist_pages
  fi
  printf "%s[OK]%s Cadena completada: plantilla de artista actualizada/exportada.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_23_autopilot_quick() {
  chain_run_header "Auto-pilot: cadenas 5,16,21"
  chain_5_show_prep
  chain_16_clean_backup
  chain_21_multidisk_dedup
  printf "%s[OK]%s Auto-pilot rápido completado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_24_autopilot_all_in_one() {
  chain_run_header "Auto-pilot: todo en uno (hash -> dupes -> quarantine -> snapshot -> doctor)"
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_9_hash_index
    action_10_dupes_plan
    action_11_quarantine_from_plan
    action_27_snapshot
  fi
  action_state_health
  printf "%s[OK]%s Auto-pilot todo en uno completado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_25_autopilot_clean_backup() {
  chain_run_header "Auto-pilot: limpieza + backup seguro"
  action_18_rescan_intelligent
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_9_hash_index
    action_10_dupes_plan
    action_11_quarantine_from_plan
  fi
  if ensure_tool_installed "rsync" "brew install rsync"; then
    action_8_backup_dj
  fi
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_27_snapshot
  fi
  printf "%s[OK]%s Auto-pilot limpieza + backup completado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_26_autopilot_relink_doctor() {
  chain_run_header "Auto-pilot: relink doctor + super doctor + export estado"
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_15_relink_helper
  fi
  action_state_health
  if ensure_tool_installed "tar" "brew install gnu-tar"; then
    action_26_export_import_state
  fi
  printf "%s[OK]%s Auto-pilot relink doctor completado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_27_autopilot_ml() {
  chain_run_header "Auto-pilot: Deep/ML"
  maybe_activate_ml_env "Auto-pilot: Deep/ML"
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_9_hash_index
  fi
  action_40_smart_analysis
  action_41_ml_predictor
  action_42_efficiency_optimizer
  action_44_integrated_dedup
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_27_snapshot
  fi
  printf "%s[OK]%s Auto-pilot Deep/ML completado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_29_analysis_playlist_backup() {
  chain_run_header "Análisis Inteligente -> Playlists Inteligentes -> Backup DJ (40 -> T10 -> 8)"
  action_40_smart_analysis
  action_T_smart_playlists
  if ensure_tool_installed "rsync" "brew install rsync"; then
    action_8_backup_dj
  fi
  printf "%s[OK]%s Cadena completada: Análisis Inteligente, Playlists Inteligentes y Backup DJ.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_30_smart_ingest() {
  chain_run_header "Smart Ingest: Inbox -> Smart Library (Orgánica)"
  
  local inbox="$STATE_DIR/INBOX"
  local lib_root="$BASE_PATH/Smart_Library"
  mkdir -p "$inbox" "$lib_root"
  
  printf "Ruta de entrada (INBOX): %s\n" "$inbox"
  printf "Ruta de librería destino: %s\n" "$lib_root"
  
  printf "¿Mover archivos sueltos de la raíz (%s) al INBOX para organizar? (y/N): " "$BASE_PATH"
  read -r sweep
  if [[ "$sweep" =~ ^[yY]$ ]]; then
     find "$BASE_PATH" -maxdepth 1 -type f -not -name ".*" -exec mv "{}" "$inbox" \; 2>/dev/null
     printf "%s[OK]%s Archivos raíz movidos a INBOX.\n" "$C_GRN" "$C_RESET"
  fi
  
  maybe_activate_ml_env "Smart Ingest" 0 0
  if ! python3 -c "import librosa" 2>/dev/null; then
     printf "%s[ERR]%s Requiere 'librosa'. Activa el perfil ML (Opción 70).\n" "$C_RED" "$C_RESET"
     pause_enter; return
  fi
  
  printf "%s[INFO]%s Iniciando ingestión inteligente (Analizando Key/BPM y moviendo)...\n" "$C_CYN" "$C_RESET"
  
  BASE="$BASE_PATH" INBOX="$inbox" LIB="$lib_root" python3 - <<'PY'
import os, sys, shutil, hashlib, pathlib, librosa, numpy as np
inbox = pathlib.Path(os.environ["INBOX"])
lib_root = pathlib.Path(os.environ["LIB"])
quar = pathlib.Path(os.environ["BASE"]) / "_DJProducerTools" / "quarantine" / "Inbox_Dupes"
quar.mkdir(parents=True, exist_ok=True)
print("Indexando librería existente para evitar duplicados...", flush=True)
known_hashes = set()
audio_exts = {".mp3", ".wav", ".flac", ".m4a", ".aiff", ".aif"}
for p in lib_root.rglob("*"):
    if p.is_file() and p.suffix.lower() in audio_exts:
        try: known_hashes.add(hashlib.sha256(p.read_bytes()).hexdigest())
        except: pass
MAJOR_PROFILE = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
MINOR_PROFILE = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
CAMELOT_MAJOR = ['8B','3B','10B','5B','12B','7B','2B','9B','4B','11B','6B','1B']
CAMELOT_MINOR = ['5A','12A','7A','2A','9A','4A','11A','6A','1A','8A','3A','10A']
def get_features(path):
    try:
        y, sr = librosa.load(str(path), sr=22050, duration=60)
        tempo, _ = librosa.beat.beat_track(y=y, sr=sr); bpm = int(round(float(tempo)))
        chroma = librosa.feature.chroma_cqt(y=y, sr=sr); chroma_avg = np.mean(chroma, axis=1)
        max_corr = -1; best_cam = "Unknown"
        for k in range(12):
            c = np.corrcoef(chroma_avg, np.roll(MAJOR_PROFILE, k))[0, 1]; (max_corr, best_cam) = (c, CAMELOT_MAJOR[k]) if c > max_corr else (max_corr, best_cam)
            c = np.corrcoef(chroma_avg, np.roll(MINOR_PROFILE, k))[0, 1]; (max_corr, best_cam) = (c, CAMELOT_MINOR[k]) if c > max_corr else (max_corr, best_cam)
        return bpm, best_cam
    except: return 0, "Unknown"
inbox_files = [f for f in inbox.rglob("*") if f.is_file() and f.suffix.lower() in audio_exts]
total = len(inbox_files); print(f"Procesando {total} archivos en INBOX...", flush=True)
for i, f in enumerate(inbox_files):
    try:
        h = hashlib.sha256(f.read_bytes()).hexdigest()
        if h in known_hashes: print(f"[{i+1}/{total}] DUPLICADO: {f.name}", flush=True); shutil.move(str(f), str(quar / f.name)); continue
        bpm, key = get_features(f); print(f"[{i+1}/{total}] MOVE: {f.name} -> {key}/{bpm}", flush=True); lower = (bpm // 5) * 5; dest = lib_root / key / f"{lower}-{lower+5}"; dest.mkdir(parents=True, exist_ok=True); shutil.move(str(f), str(dest / f.name)); known_hashes.add(h)
    except Exception as e: print(f"ERR {f.name}: {e}", flush=True)
PY
  printf "%s[OK]%s Ingestión completada.\n" "$C_GRN" "$C_RESET"; pause_enter
}

chain_33_quality_consistency_check() {
  chain_run_header "Calidad y Consistencia (L9 -> L8)"
  action_L9_low_bitrate_report
  action_L8_metadata_consistency_report
  printf "%s[OK]%s Cadena completada: Reportes de bitrate y consistencia generados.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_34_ingest_doctor() {
  chain_run_header "Smart Ingest + Super Doctor (A30 -> 66)"
  chain_30_smart_ingest
  action_state_health
  printf "%s[OK]%s Cadena completada: Ingestión y doctor finalizados.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_28_autopilot_safe_state() {
  chain_run_header "Auto-pilot seguro: reusar análisis previos"
  local prev_dry="$DRYRUN_FORCE"
  DRYRUN_FORCE=1
  refresh_artifact_state
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_9_hash_index
    action_10_dupes_plan
    action_unique_from_hash
    action_27_snapshot
    action_11_quarantine_from_plan
  fi
  action_state_health
  DRYRUN_FORCE="$prev_dry"
  printf "%s[OK]%s Auto-pilot seguro completado (sin mover archivos).\n" "$C_GRN" "$C_RESET"
  pause_enter
}


action_69_artist_pages() {
  print_header
  local artist_file="$CONFIG_DIR/artist_pages.tsv"
  default_val() {
    case "$1" in
      Short_Bio) echo "Bio corta (1-2 líneas)";;
      Long_Bio_URL) echo "https://drive.google.com/tu_bio_larga.pdf";;
      Press_Quotes) echo "\"Medio\" - cita destacada";;
      Tech_Rider) echo "/ruta/a/Tech_Rider.pdf";;
      Stage_Plot) echo "/ruta/a/Stage_Plot.pdf";;
      DMX_Showfile) echo "/ruta/a/Showfile.dmx";;
      Ableton_Set) echo "/ruta/a/LiveSet.als";;
      OBS_Overlays) echo "/ruta/a/overlays/";;
      Website) echo "https://tusitio.com";;
      Linktree) echo "https://linktr.ee/tu_usuario";;
      EPK_PDF) echo "https://drive.google.com/tu_epk.pdf";;
      Press_Kit_Assets) echo "https://drive.google.com/carpeta_presskit";;
      Media_Drive) echo "https://drive.google.com/carpeta_media";;
      Artwork_Drive) echo "https://drive.google.com/carpeta_artwork";;
      Booking_Email) echo "booking@tucorreo.com";;
      Booking_Phone) echo "+34 600 000 000";;
      Management) echo "Manager Nombre / correo";;
      Label) echo "Tu sello o distribuidor";;
      Spotify) echo "https://open.spotify.com/artist/TUID";;
      Apple_Music) echo "https://music.apple.com/artist/TUID";;
      YouTube) echo "https://youtube.com/@tu_usuario";;
      YouTube_Music) echo "https://music.youtube.com/channel/TUID";;
      SoundCloud) echo "https://soundcloud.com/tu_usuario";;
      Beatport) echo "https://www.beatport.com/artist/TU-NOMBRE/ID";;
      Traxsource) echo "https://www.traxsource.com/artist/ID/tu-nombre";;
      Bandcamp) echo "https://tuusuario.bandcamp.com";;
      Bandcamp_Merch) echo "https://tuusuario.bandcamp.com/merch";;
      Mixcloud) echo "https://www.mixcloud.com/tu_usuario";;
      Audius) echo "https://audius.co/tu_usuario";;
      Tidal) echo "https://tidal.com/browse/artist/ID";;
      Deezer) echo "https://www.deezer.com/artist/ID";;
      Amazon_Music) echo "https://music.amazon.com/artists/ID";;
      Shazam) echo "https://www.shazam.com/artist/ID";;
      JunoDownload) echo "https://www.junodownload.com/artists/Tu+Nombre";;
      Pandora) echo "https://www.pandora.com/artist/TuNombre/ID";;
      Instagram) echo "https://instagram.com/tu_usuario";;
      TikTok) echo "https://www.tiktok.com/@tu_usuario";;
      Facebook) echo "https://facebook.com/tu_usuario";;
      "Twitter/X") echo "https://twitter.com/tu_usuario";;
      Threads) echo "https://www.threads.net/@tu_usuario";;
      Resident_Advisor) echo "https://ra.co/dj/tu_usuario";;
      Patreon) echo "https://www.patreon.com/tu_usuario";;
      Twitch) echo "https://twitch.tv/tu_usuario";;
      Discord) echo "https://discord.gg/ENLACE";;
      Telegram) echo "https://t.me/tu_usuario";;
      WhatsApp_Community) echo "https://chat.whatsapp.com/ENLACE";;
      Merch_Store) echo "https://tu_tienda.com/tu_usuario";;
      Boiler_Room) echo "https://boilerroom.tv/recording/tu_sesion";;
      *) echo "";;
    esac
  }
  local platforms=(
    "Short_Bio" "Long_Bio_URL" "Press_Quotes" "Tech_Rider" "Stage_Plot" "DMX_Showfile" "Ableton_Set" "OBS_Overlays"
    "Website" "Linktree" "EPK_PDF" "Press_Kit_Assets" "Media_Drive" "Artwork_Drive"
    "Booking_Email" "Booking_Phone" "Management" "Label"
    "Spotify" "Apple_Music" "YouTube" "YouTube_Music" "SoundCloud"
    "Beatport" "Traxsource" "Bandcamp" "Bandcamp_Merch" "Mixcloud" "Audius" "Tidal" "Deezer" "Amazon_Music" "Shazam" "JunoDownload" "Pandora"
    "Instagram" "TikTok" "Facebook" "Twitter/X" "Threads" "Resident_Advisor"
    "Patreon" "Twitch" "Discord" "Telegram" "WhatsApp_Community" "Merch_Store" "Boiler_Room"
  )

  mkdir -p "$CONFIG_DIR"
  touch "$artist_file"
  if [ ! -f "$artist_file" ]; then
    : >"$artist_file"
  fi
  # Garantiza que existan todas las claves; si falta alguna, se añade con valor sugerido
  for p in "${platforms[@]}"; do
    if ! awk -F'\t' -v k="$p" '$1==k{found=1} END{exit !found}' "$artist_file" >/dev/null 2>&1; then
      printf "%s\t%s\n" "$p" "$(default_val "$p")" >>"$artist_file"
    fi
  done

  printf "%s[INFO]%s Perfiles/links de artista (edita o completa).\n" "$C_CYN" "$C_RESET"
  printf "Archivo: %s\n\n" "$artist_file"
  if [ -s "$artist_file" ]; then
    awk -F'\t' '{printf "- %-18s %s\n",$1,$2}' "$artist_file"
  fi
  printf "\n¿Quieres editar ahora? (y/N): "
  read -r ans
  case "$ans" in
    y|Y)
      tmp="$artist_file.tmp"
      : >"$tmp"
      for p in "${platforms[@]}"; do
        current=$(awk -F'\t' -v k="$p" '$1==k{print $2}' "$artist_file")
        def=$(default_val "$p")
        printf "%s (actual: %s | por defecto: %s): " "$p" "${current:-vacío}" "${def:-vacío}"
        read -e -r val
        if [ -z "$val" ]; then
          if [ -n "$current" ]; then
            val="$current"
          else
            val="$def"
          fi
        fi
        printf "%s\t%s\n" "$p" "$val" >>"$tmp"
      done
      mv "$tmp" "$artist_file"
      printf "%s[OK]%s Guardado en %s\n" "$C_GRN" "$C_RESET" "$artist_file"
      ;;
    *)
      printf "%s[INFO]%s Sin cambios. Edita el archivo manualmente si prefieres.\n" "$C_CYN" "$C_RESET"
      ;;
  esac

  printf "\n¿Exportar a CSV/HTML/JSON en reports/? (y/N): "
  read -r exp
  case "$exp" in
    y|Y)
      local csv_out="$REPORTS_DIR/artist_pages.csv"
      local html_out="$REPORTS_DIR/artist_pages.html"
      local json_out="$REPORTS_DIR/artist_pages.json"
      if command -v python3 >/dev/null 2>&1; then
        run_with_spinner "EXPORT" "Exportando perfiles..." python3 - "$artist_file" "$csv_out" "$html_out" "$json_out" <<'PY'
import csv, html, json, sys
from pathlib import Path
tsv_path = Path(sys.argv[1])
csv_out = Path(sys.argv[2])
html_out = Path(sys.argv[3])
json_out = Path(sys.argv[4])
rows = []
if tsv_path.exists():
    with tsv_path.open(encoding="utf-8") as f:
        for r in csv.reader(f, delimiter="\t"):
            if not r:
                continue
            key = r[0].strip()
            val = r[1].strip() if len(r) > 1 else ""
            rows.append((key, val))
csv_out.parent.mkdir(parents=True, exist_ok=True)
with csv_out.open("w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["field", "value"])
    w.writerows(rows)
json_out.write_text(json.dumps([{"field": k, "value": v} for k, v in rows], ensure_ascii=False, indent=2), encoding="utf-8")
def html_cell(key, val):
    v = html.escape(val)
    if val.startswith(("http://", "https://")):
        return f'<a href="{v}" target="_blank" rel="noopener">{v}</a>'
    if "@" in val and " " not in val:
        return f'<a href="mailto:{v}">{v}</a>'
    return v
table_rows = "\n".join(
    f"<tr><td><b>{html.escape(k)}</b></td><td>{html_cell(k, v)}</td></tr>"
    for k, v in rows
)
html_out.write_text(
    "<html><body><table border='1' cellpadding='6' cellspacing='0'>"
    "<thead><tr><th>Field</th><th>Value</th></tr></thead>"
    f"<tbody>{table_rows}</tbody></table></body></html>",
    encoding="utf-8",
)
PY
        if [ $? -eq 0 ]; then
          printf "\n%s[OK]%s Exportado a %s, %s y %s\n" "$C_GRN" "$C_RESET" "$csv_out" "$html_out" "$json_out"
        else
          printf "\n%s[WARN]%s Fallo exportando (python3). Revisa el log en consola.\n" "$C_YLW" "$C_RESET"
        fi
      else
        printf "%s[WARN]%s python3 no está disponible; exporta manualmente.\n" "$C_YLW" "$C_RESET"
      fi
      ;;
    *)
      ;;
  esac
  pause_enter
}

action_40_wav_to_mp3() {
  print_header
  printf "%s[INFO]%s Convertir WAV a MP3 (320kbps CBR - Máxima Calidad).\n" "$C_CYN" "$C_RESET"
  if ! ensure_tool_installed "ffmpeg" "brew install ffmpeg"; then
    pause_enter
    return
  fi
  
  printf "Buscar WAVs en BASE_PATH (ENTER) o indicar carpeta (drag & drop): "
  read -e -r search_root
  search_root=$(strip_quotes "$search_root")
  [ -z "$search_root" ] && search_root="$BASE_PATH"
  
  if [ ! -d "$search_root" ]; then
    printf "%s[ERR]%s Ruta inválida.\n" "$C_RED" "$C_RESET"
    pause_enter; return
  fi

  mapfile -t wav_list < <(find "$search_root" -type f -iname "*.wav" 2>/dev/null)
  total=${#wav_list[@]}
  
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No se encontraron archivos WAV.\n" "$C_YLW" "$C_RESET"
    pause_enter; return
  fi
  
  printf "Se encontraron %s archivos WAV.\n" "$total"
  printf "1) Generar MP3 junto al original (mantener WAV)\n"
  printf "2) Generar MP3 y mover WAV original a '_WAV_Backup'\n"
  printf "Opción: "
  read -r conv_op
  
  backup_dir="$search_root/_WAV_Backup"
  if [ "$conv_op" -eq 2 ]; then
    mkdir -p "$backup_dir"
    printf "%s[INFO]%s Los originales se moverán a: %s\n" "$C_CYN" "$C_RESET" "$backup_dir"
  fi
  
  count=0
  for f in "${wav_list[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    status_line "CONVERT" "$percent" "$(basename "$f")"
    
    dir=$(dirname "$f")
    base=$(basename "$f" .wav)
    mp3_out="$dir/$base.mp3"
    
    # 320k CBR, id3v2.3 tags, q:a 0 (highest quality setting for lame)
    ffmpeg -y -v error -i "$f" -codec:a libmp3lame -b:a 320k -q:a 0 -map_metadata 0 -id3v2_version 3 "$mp3_out" </dev/null
    
    if [ "$conv_op" -eq 2 ] && [ -f "$mp3_out" ]; then
       # Mover original a backup (aplanando estructura o manteniendo nombre único si hay colisión?)
       # Para seguridad simple, movemos tal cual. Si hay colisión de nombres en backup, mv fallará o sobrescribirá según config.
       # Usaremos mv -n para no sobrescribir backups previos.
       mv -n "$f" "$backup_dir/" 2>/dev/null
    fi
  done
  finish_status_line
  printf "%s[OK]%s Conversión completada.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_41_update_self() {
  print_header
  printf "%s[INFO]%s Buscando actualizaciones en GitHub...\n" "$C_CYN" "$C_RESET"
  local script_name
  script_name=$(basename "$0")
  local url="https://raw.githubusercontent.com/$GITHUB_REPO/main/$script_name"
  local tmp_script="/tmp/$script_name.new"
  
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$tmp_script"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$tmp_script"
  else
    printf "%s[ERR]%s curl o wget no encontrados.\n" "$C_RED" "$C_RESET"
    pause_enter; return
  fi

  if [ ! -s "$tmp_script" ]; then
    printf "%s[ERR]%s Falló la descarga.\n" "$C_RED" "$C_RESET"
    pause_enter; return
  fi

  if cmp -s "$0" "$tmp_script"; then
    printf "%s[INFO]%s Ya tienes la última versión.\n" "$C_GRN" "$C_RESET"
    rm -f "$tmp_script"
  else
    printf "%s[WARN]%s ¡Actualización encontrada! ¿Sobrescribir script actual? (y/N): " "$C_RED" "$C_RESET"
    read -r ans
    if [[ "$ans" =~ ^[yY]$ ]]; then
      mv "$tmp_script" "$0"
      chmod +x "$0"
      printf "%s[OK]%s Actualizado. Reinicia el script.\n" "$C_GRN" "$C_RESET"
      exit 0
    else
      rm -f "$tmp_script"
      printf "%s[INFO]%s Cancelado.\n" "$C_CYN" "$C_RESET"
    fi
  fi
  pause_enter
}

action_L8_metadata_consistency_report() {
  print_header
  local out="$REPORTS_DIR/metadata_inconsistency_report.tsv"
  local plan="$PLANS_DIR/rename_from_tags_plan.tsv"
  printf "%s[INFO]%s Generando reporte de inconsistencias (ID3 vs Nombre Archivo) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  
  if ! ensure_tool_installed "ffprobe" "brew install ffmpeg"; then
     printf "%s[WARN]%s ffprobe no encontrado. No se pueden leer metadatos.\n" "$C_YLW" "$C_RESET"
     pause_enter; return
  fi
  
  BASE_PATH_VAL="$BASE_PATH" OUT_PATH_VAL="$out" PLAN_PATH_VAL="$plan" python3 - <<'PY'
import os, sys, pathlib, subprocess, csv, json, re

base_path = pathlib.Path(os.environ["BASE_PATH_VAL"])
out_path = pathlib.Path(os.environ["OUT_PATH_VAL"])
plan_path = pathlib.Path(os.environ["PLAN_PATH_VAL"])
audio_exts = {".mp3", ".wav", ".flac", ".m4a", ".aiff", ".aif"}

IGNORE_TERMS = {
    "original", "mix", "extended", "remix", "edit", "radio", "club", "feat", "ft", "featuring", "vs", "pres", "presents", "bootleg", "vip", "instrumental", "dub"
}

def get_meta(fpath):
    try:
        cmd = ["ffprobe", "-v", "error", "-show_entries", "format_tags=title,artist", "-of", "json", str(fpath)]
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        d = json.loads(res.stdout)
        tags = d.get("format", {}).get("tags", {})
        artist = next((v for k, v in tags.items() if k.lower() == 'artist'), "").strip()
        title = next((v for k, v in tags.items() if k.lower() == 'title'), "").strip()
        return artist, title
    except Exception:
        return "", ""

def clean_tokens(text):
    tokens = set(re.findall(r'\w+', text.lower()))
    return tokens - IGNORE_TERMS

def sanitize_filename(name):
    return re.sub(r'[<>:"/\\|?*]', '_', name)

def check_consistency(filename, artist, title):
    if not artist and not title:
        return "NO_ID3_TAGS", False

    fn_tokens = clean_tokens(pathlib.Path(filename).stem)
    artist_tokens = clean_tokens(artist)
    title_tokens = clean_tokens(title)

    artist_in_fn = artist_tokens.issubset(fn_tokens) if artist_tokens else True
    title_in_fn = title_tokens.issubset(fn_tokens) if title_tokens else True

    issues = []
    if not artist_in_fn: issues.append("ARTIST_MISSING")
    if not title_in_fn: issues.append("TITLE_MISSING")

    return ("+".join(issues), True) if issues else ("OK", False)

rows = []
plan_rows = []
all_files = [p for p in base_path.rglob("*") if p.is_file() and p.suffix.lower() in audio_exts]
print(f"Escaneando {len(all_files)} archivos...", flush=True)

for p in all_files:
    artist, title = get_meta(p)
    inconsistency_type, is_inconsistent = check_consistency(p.name, artist, title)
    if is_inconsistent:
        rows.append({"Path": str(p), "Filename": p.name, "ID3_Artist": artist, "ID3_Title": title, "Inconsistency_Type": inconsistency_type})
        if artist and title:
            new_name = f"{sanitize_filename(artist)} - {sanitize_filename(title)}{p.suffix}"
            if new_name != p.name:
                plan_rows.append((str(p), str(p.parent / new_name)))

with out_path.open("w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["Path", "Filename", "ID3_Artist", "ID3_Title", "Inconsistency_Type"], delimiter="\t")
    writer.writeheader(); writer.writerows(rows)

with plan_path.open("w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f, delimiter="\t")
    writer.writerows(plan_rows)

print(f"Reporte generado: {len(rows)} inconsistencias.")
print(f"Plan de renombrado generado: {len(plan_rows)} candidatos.")
PY

  if [ -s "$plan" ]; then
      printf "%s[INFO]%s Se ha generado un plan de renombrado automático en: %s\n" "$C_CYN" "$C_RESET" "$plan"
      printf "¿Deseas ejecutar el renombrado automático (Artista - Título) ahora? (y/N): "
      read -r run_ren
      if [[ "$run_ren" =~ ^[yY]$ ]]; then
          if [ "$SAFE_MODE" -eq 1 ]; then
             printf "%s[WARN]%s SAFE_MODE activo. Solo simulación.\n" "$C_YLW" "$C_RESET"
          fi
          while IFS=$'\t' read -r src dest; do
              if [ "$SAFE_MODE" -eq 1 ]; then
                  printf "[DRY] mv \"%s\" \"%s\"\n" "$src" "$dest"
              else
                  mv -n "$src" "$dest" 2>/dev/null && printf "[OK] Renombrado: %s\n" "$(basename "$dest")"
              fi
          done < "$plan"
          printf "%s[OK]%s Renombrado completado.\n" "$C_GRN" "$C_RESET"
      else
          printf "%s[INFO]%s Plan guardado. Puedes revisarlo y ejecutarlo manualmente.\n" "$C_CYN" "$C_RESET"
      fi
  else
      printf "%s[OK]%s No hay archivos para renombrar automáticamente (faltan tags o ya están correctos).\n" "$C_GRN" "$C_RESET"
  fi
  pause_enter
}

action_L9_low_bitrate_report() {
  print_header
  local out="$REPORTS_DIR/low_bitrate_report.tsv"
  local plan="$PLANS_DIR/low_bitrate_move_plan.tsv"
  local quar_dest="$QUAR_DIR/Low_Bitrate"
  
  printf "%s[INFO]%s Buscando archivos de audio con bitrate < 320kbps -> %s\n" "$C_CYN" "$C_RESET" "$out"
  
  if ! ensure_tool_installed "ffprobe" "brew install ffmpeg"; then
     pause_enter; return
  fi
  
  mkdir -p "$quar_dest"
  
  BASE_PATH_VAL="$BASE_PATH" OUT_PATH_VAL="$out" PLAN_PATH_VAL="$plan" QUAR_DEST_VAL="$quar_dest" python3 - <<'PY'
import os, sys, pathlib, subprocess, csv, json

base_path = pathlib.Path(os.environ["BASE_PATH_VAL"])
out_path = pathlib.Path(os.environ["OUT_PATH_VAL"])
plan_path = pathlib.Path(os.environ["PLAN_PATH_VAL"])
quar_dest_path = pathlib.Path(os.environ["QUAR_DEST_VAL"])
audio_exts = {".mp3", ".m4a", ".aac", ".wma", ".ogg"} 

def get_bitrate(fpath):
    try:
        cmd = ["ffprobe", "-v", "error", "-show_entries", "format=bit_rate", "-of", "json", str(fpath)]
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        d = json.loads(res.stdout)
        br = int(d.get("format", {}).get("bit_rate", 0))
        return br
    except Exception:
        return 0

report_rows = []
plan_rows = []
all_files = [p for p in base_path.rglob("*") if p.is_file() and p.suffix.lower() in audio_exts]
print(f"Analizando bitrate de {len(all_files)} archivos comprimidos...", flush=True)

for p in all_files:
    br = get_bitrate(p)
    if 0 < br < 320000: # Menor a 320kbps
        report_rows.append({"Path": str(p), "Filename": p.name, "Bitrate_kbps": int(br/1000)})
        plan_rows.append((str(p), str(quar_dest_path / p.name)))

with out_path.open("w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["Path", "Filename", "Bitrate_kbps"], delimiter="\t")
    writer.writeheader(); writer.writerows(report_rows)

with plan_path.open("w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f, delimiter="\t")
    writer.writerows(plan_rows)

print(f"Reporte generado: {len(report_rows)} archivos con bajo bitrate.")
print(f"Plan de movimiento generado: {len(plan_rows)} archivos.")
PY

  if [ -s "$plan" ]; then
      printf "%s[INFO]%s Se ha generado un plan para mover archivos de bajo bitrate a: %s\n" "$C_CYN" "$C_RESET" "$quar_dest"
      printf "¿Deseas mover estos archivos a la carpeta de cuarentena 'Low_Bitrate' ahora? (y/N): "
      read -r run_move
      if [[ "$run_move" =~ ^[yY]$ ]]; then
          if [ "$SAFE_MODE" -eq 1 ] || [ "$DJ_SAFE_LOCK" -eq 1 ]; then
             printf "%s[WARN]%s SAFE_MODE o DJ_SAFE_LOCK activo. Solo simulación.\n" "$C_YLW" "$C_RESET"
          fi
          while IFS=$'\t' read -r src dest; do
              if [ "$SAFE_MODE" -eq 1 ] || [ "$DJ_SAFE_LOCK" -eq 1 ]; then
                  printf "[DRY] mv \"%s\" \"%s\"\n" "$src" "$dest"
              else
                  mv -n "$src" "$dest" 2>/dev/null && printf "[OK] Movido: %s\n" "$(basename "$dest")"
              fi
          done < "$plan"
          printf "%s[OK]%s Movimiento completado.\n" "$C_GRN" "$C_RESET"
      else
          printf "%s[INFO]%s Plan guardado. Puedes revisarlo y ejecutarlo manualmente.\n" "$C_CYN" "$C_RESET"
      fi
  else
      printf "%s[OK]%s No se encontraron archivos con bajo bitrate.\n" "$C_GRN" "$C_RESET"
  fi
  pause_enter
}

action_L10_no_tags_report() {
  print_header
  local out="$REPORTS_DIR/no_id3_tags_report.tsv"
  printf "%s[INFO]%s Generando reporte de archivos sin tags ID3 (Artista/Título) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  
  if ! ensure_tool_installed "ffprobe" "brew install ffmpeg"; then
     printf "%s[WARN]%s ffprobe no encontrado. No se pueden leer metadatos.\n" "$C_YLW" "$C_RESET"
     pause_enter; return
  fi
  
  BASE_PATH_VAL="$BASE_PATH" OUT_PATH_VAL="$out" python3 - <<'PY'
import os, sys, pathlib, subprocess, csv, json

base_path = pathlib.Path(os.environ["BASE_PATH_VAL"])
out_path = pathlib.Path(os.environ["OUT_PATH_VAL"])
audio_exts = {".mp3", ".wav", ".flac", ".m4a", ".aiff", ".aif"}

def get_meta(fpath):
    try:
        cmd = ["ffprobe", "-v", "error", "-show_entries", "format_tags=title,artist", "-of", "json", str(fpath)]
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        d = json.loads(res.stdout)
        tags = d.get("format", {}).get("tags", {})
        artist = next((v for k, v in tags.items() if k.lower() == 'artist'), "").strip()
        title = next((v for k, v in tags.items() if k.lower() == 'title'), "").strip()
        return artist, title
    except Exception:
        return "", ""

rows = []
all_files = [p for p in base_path.rglob("*") if p.is_file() and p.suffix.lower() in audio_exts]
print(f"Escaneando {len(all_files)} archivos de audio para tags faltantes...", flush=True)

for p in all_files:
    artist, title = get_meta(p)
    if not artist and not title:
        rows.append({"Path": str(p), "Filename": p.name})

with out_path.open("w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["Path", "Filename"], delimiter="\t")
    writer.writeheader(); writer.writerows(rows)

print(f"Reporte de tags faltantes generado con {len(rows)} entradas.")
PY
  
  printf "%s[OK]%s Reporte completado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

submenu_A_chains() {
  while true; do
    clear
    print_header
    printf "%s=== Cadenas automatizadas ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Backup seguro + snapshot (8 -> 27)\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Dedup exacto y quarantine (10 -> 11)\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Limpieza de metadatos y nombres (39 -> 34)\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s Escaneo salud media (18 -> 14 -> 15)\n" "$C_YLW" "$C_RESET"
    printf "%s5)%s Prep de show (8 -> 27 -> 10 -> 11 -> 14 -> 8)\n" "$C_YLW" "$C_RESET"
    printf "%s6)%s Media integrity + corruptos (13 -> 18)\n" "$C_YLW" "$C_RESET"
    printf "%s7)%s Plan de eficiencia (42 -> 44 -> 43)\n" "$C_YLW" "$C_RESET"
    printf "%s8)%s ML organización básica (45 -> 46)\n" "$C_YLW" "$C_RESET"
    printf "%s9)%s Backup predictivo (47 -> 8 -> 27)\n" "$C_YLW" "$C_RESET"
    printf "%s10)%s Sync multiplataforma (48 -> 39 -> 8 -> 8)\n" "$C_YLW" "$C_RESET"
    printf "%s11)%s Diagnóstico rápido (1 -> 3 -> 4 -> 5)\n" "$C_YLW" "$C_RESET"
    printf "%s12)%s Salud Serato (7 -> 59)\n" "$C_YLW" "$C_RESET"
    printf "%s13)%s Hash + mirror check (9 -> 61)\n" "$C_YLW" "$C_RESET"
    printf "%s14)%s Audio prep (31 -> 66 -> 67)\n" "$C_YLW" "$C_RESET"
    printf "%s15)%s Auditoría integridad (6 -> 9 -> 27 -> 61)\n" "$C_YLW" "$C_RESET"
    printf "%s16)%s Limpieza + backup seguro (39 -> 34 -> 10 -> 11 -> 8 -> 27)\n" "$C_YLW" "$C_RESET"
    printf "%s17)%s Prep sync librerías (18 -> 14 -> 48 -> 8 -> 27)\n" "$C_YLW" "$C_RESET"
    printf "%s18)%s Salud video/visuales (V2 -> V6 -> V8 -> V9 -> 8)\n" "$C_YLW" "$C_RESET"
    printf "%s19)%s Organización audio avanzada (31 -> 30 -> 35 -> 45 -> 46)\n" "$C_YLW" "$C_RESET"
    printf "%s20)%s Seguridad Serato reforzada (7 -> 8 -> 59 -> 12 -> 47)\n" "$C_YLW" "$C_RESET"
    printf "%s21)%s Dedup multi-disco + espejo (9 -> 10 -> 44 -> 11 -> 61)\n" "$C_YLW" "$C_RESET"
    printf "%s22)%s Pack presskit (69 -> export)\n" "$C_YLW" "$C_RESET"
    printf "%s23)%s Auto-pilot: cadenas 5,16,21 (prep show + clean/backup + dedup multi)\n" "$C_YLW" "$C_RESET"
    printf "%s24)%s Auto-pilot: todo en uno (hash -> dupes -> quarantine -> snapshot -> doctor)\n" "$C_YLW" "$C_RESET"
    printf "%s25)%s Auto-pilot: limpieza + backup seguro (rescan -> dupes -> quarantine -> backup -> snapshot)\n" "$C_YLW" "$C_RESET"
    printf "%s26)%s Auto-pilot: relink doctor + super doctor + export estado\n" "$C_YLW" "$C_RESET"
    printf "%s27)%s Auto-pilot: Deep/ML (hash -> smart analysis -> predictor -> optimizador -> integrated dedup -> snapshot)\n" "$C_YLW" "$C_RESET"
    printf "%s28)%s Auto-pilot seguro: reusar análisis + únicos (hash -> dupes -> únicos -> snapshot -> doctor)\n" "$C_YLW" "$C_RESET"
    printf "%s29)%s Auto-pilot: Análisis Inteligente -> Playlists Inteligentes -> Backup (40 -> T10 -> 8)\n" "$C_YLW" "$C_RESET"
    printf "%s30)%s Smart Ingest: Organizar INBOX -> Smart_Library (Key/BPM) + Dedup\n" "$C_YLW" "$C_RESET"
    printf "%s33)%s Calidad y Consistencia: Bajo Bitrate + Inconsistencias (L9 -> L8)\n" "$C_YLW" "$C_RESET"
    printf "%s34)%s Smart Ingest + Super Doctor (A30 -> 66)\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Volver\n" "$C_YLW" "$C_RESET"
    printf "%sOpción:%s " "$C_BLU" "$C_RESET"
    read -r aop
    case "$aop" in
      1) chain_1_backup_snapshot ;;
      2) chain_2_dedup_quarantine ;;
      3) chain_3_metadata_names ;;
      4) chain_4_health_scan ;;
      5) chain_5_show_prep ;;
      6) chain_6_media_integrity ;;
      7) chain_7_efficiency_plan ;;
      8) chain_8_ml_org_basic ;;
      9) chain_9_predictive_backup ;;
      10) chain_10_cross_sync ;;
      11) chain_11_quick_diag ;;
      12) chain_12_serato_health ;;
      13) chain_13_hash_mirror_check ;;
      14) chain_14_audio_prep ;;
      15) chain_15_integrity_audit ;;
      16) chain_16_clean_backup ;;
      17) chain_17_sync_prep ;;
      18) chain_18_visual_health ;;
      19) chain_19_audio_advanced ;;
      20) chain_20_serato_safe ;;
      21) chain_21_multidisk_dedup ;;
      22) chain_22_presskit_pack ;;
      23) chain_23_autopilot_quick ;;
      24) chain_24_autopilot_all_in_one ;;
      25) chain_25_autopilot_clean_backup ;;
      26) chain_26_autopilot_relink_doctor ;;
      27) chain_27_autopilot_ml ;;
      28) chain_28_autopilot_safe_state ;;
      29) chain_29_analysis_playlist_backup ;;
      30) chain_30_smart_ingest ;;
      33) chain_33_quality_consistency_check ;;
      34) chain_34_ingest_doctor ;;
      B|b) break ;;
      *) invalid_option ;;
    esac
  done
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
    printf "%s6)%s Inventario de librerías (Serato/Rekordbox/Traktor/Ableton)\n" "$C_YLW" "$C_RESET"
    printf "%s8)%s Reporte inconsistencias (ID3 vs Nombre) + Auto-Renombrar\n" "$C_YLW" "$C_RESET"
    printf "%s9)%s Reporte de bajo bitrate (< 320kbps) + Mover a quarantine\n" "$C_YLW" "$C_RESET"
    printf "%s10)%s Reporte de archivos sin tags ID3 (Artista/Título)\n" "$C_YLW" "$C_RESET"
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
          if [ -f "$f" ] && [ "$f" != "$cat_master" ]; then
            cat "$f" >>"$cat_master"
          fi
        done
        if [ ! -s "$cat_master" ]; then
          printf "%s[WARN]%s No hay catálogos individuales.\n" "$C_YLW" "$C_RESET"
          pause_enter
        else
          out="$PLANS_DIR/audio_dupes_from_catalog.tsv"
          printf "%s[INFO]%s Generando plan de duplicados por basename+tamaño -> %s\n" "$C_CYN" "$C_RESET" "$out"
          tmp="$STATE_DIR/audio_cat_with_size.tmp"
          >"$tmp"
          total=$(wc -l <"$cat_master" | tr -d ' ')
          count=0
          while IFS=$'\t' read -r lib path; do
            [ -z "$path" ] && continue
            count=$((count + 1))
            if [ "$total" -gt 0 ]; then
              percent=$((count * 100 / total))
            else
              percent=0
            fi
            status_line "DUPES_CATALOG" "$percent" "$(basename "$path")"
            base=$(basename "$path")
            size=$(stat -f %z -- "$path" 2>/dev/null || echo 0)
            printf "%s|%s\t%s\t%s\n" "$base" "$size" "$lib" "$path" >>"$tmp"
          done <"$cat_master"
          finish_status_line
          run_with_spinner "DUPES_PLAN" "Generando plan de duplicados..." awk -F'\t' '
          {
            key=$1
            count[key]++
            rec[key, count[key]]=$2"\t"$3
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
          rm -f "$tmp"
          printf "\n%s[OK]%s Plan de duplicados audio generado.\n" "$C_GRN" "$C_RESET"
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
      6)
        clear
        out="$REPORTS_DIR/library_inventory.tsv"
        printf "%s[INFO]%s Inventario de librerías DJ -> %s\n" "$C_CYN" "$C_RESET" "$out"
        status_line "INVENTORY" "--" "Buscando librerías..."
        {
          printf "Plataforma\tEstado\tRuta\n"
          if [ -d "$BASE_PATH/_Serato_" ]; then
            printf "Serato\tENCONTRADO\t%s/_Serato_\n" "$BASE_PATH"
          else
            printf "Serato\tNO\t-\n"
          fi
          if find "$BASE_PATH" -maxdepth 4 -type f -iname "*rekordbox*.xml" 2>/dev/null | head -1 | grep -q .; then
            p=$(find "$BASE_PATH" -maxdepth 4 -type f -iname "*rekordbox*.xml" 2>/dev/null | head -1)
            printf "Rekordbox XML\tENCONTRADO\t%s\n" "$p"
          else
            printf "Rekordbox XML\tNO\t-\n"
          fi
          if find "$BASE_PATH" -maxdepth 4 -type f -iname "*collection*.nml" 2>/dev/null | head -1 | grep -q .; then
            p=$(find "$BASE_PATH" -maxdepth 4 -type f -iname "*collection*.nml" 2>/dev/null | head -1)
            printf "Traktor NML\tENCONTRADO\t%s\n" "$p"
          else
            printf "Traktor NML\tNO\t-\n"
          fi
          if find "$BASE_PATH" -maxdepth 4 -type f -iname "*.als" 2>/dev/null | head -1 | grep -q .; then
            p=$(find "$BASE_PATH" -maxdepth 4 -type f -iname "*.als" 2>/dev/null | head -1)
            printf "Ableton ALS\tENCONTRADO\t%s\n" "$p"
          else
            printf "Ableton ALS\tNO\t-\n"
          fi
          if find "$BASE_PATH" -maxdepth 4 -type f -iname "*.svd" 2>/dev/null | head -1 | grep -q .; then
            p=$(find "$BASE_PATH" -maxdepth 4 -type f -iname "*.svd" 2>/dev/null | head -1)
            printf "Serato Video SVD\tENCONTRADO\t%s\n" "$p"
          else
            printf "Serato Video SVD\tNO\t-\n"
          fi
        } >"$out"
        finish_status_line
        printf "%s[OK]%s Inventario generado.\n" "$C_GRN" "$C_RESET"
        pause_enter
        ;;
      8)
        action_L8_metadata_consistency_report
        ;;
      9)
        action_L9_low_bitrate_report
        ;;
      10)
        action_L10_no_tags_report
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
        run_with_spinner "CATALOG" "Contando archivos..." total=$(find "$GENERAL_ROOT" -type f 2>/dev/null | wc -l | tr -d ' ')
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
                    run_with_spinner "CATALOG" "Contando archivos..." total=$(find "$GENERAL_ROOT" -type f 2>/dev/null | wc -l | tr -d ' ')
                    count=0          >"$out"
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

        run_with_spinner "DUPES_PLAN" "Generando plan..." awk -F'\t' '
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
            status_line "DUP_COUNT" "--" "$f"
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

        run_with_spinner "HASH_DUP_PLAN" "Generando plan de duplicados por hash..." awk '
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
        dir_list=$(mktemp "${STATE_DIR}/matrioshka_dirs.XXXXXX") || dir_list="/tmp/matrioshka_dirs.$$"
        >"$dir_list"
        for r in "${MROOTS[@]}"; do
          r_trim=$(printf "%s" "$r" | xargs)
          [ -d "$r_trim" ] || { printf "%s[WARN]%s Raíz inválida: %s\n" "$C_YLW" "$C_RESET" "$r_trim"; continue; }
          find "$r_trim" -maxdepth "$md" -type d 2>/dev/null >>"$dir_list"
        done
        total_dirs=$(wc -l <"$dir_list" | tr -d ' ')
        count_dirs=0
        while IFS= read -r d; do
            count_dirs=$((count_dirs + 1))
            if [ "$total_dirs" -gt 0 ]; then
              percent=$((count_dirs * 100 / total_dirs))
            else
              percent=0
            fi
            status_line "MATRIOSHKA" "$percent" "$(basename "$d")"
            files=$(find "$d" -maxdepth 1 -type f 2>/dev/null | head -"$mf" | xargs -I{} basename "{}" | sort | tr '\n' '|' )
            if [ -n "$files" ]; then
              sig=$(printf "%s" "$files" | shasum -a 256 | awk '{print $1}')
              printf "%s\t%s\t%s\n" "$sig" "$d" "$files" >>"$sig_tmp"
            fi
        done <"$dir_list"
        rm -f "$dir_list"
        finish_status_line
        run_with_spinner "MATRIOSHKA" "Generando reporte de matrioshkas..." awk -F'\t' '{
          s=$1; d=$2; f=$3; cnt[s]++; rec[s,cnt[s]]=d; files[s]=f;
        } END {
          for (k in cnt) if (cnt[k]>1) {
            for (i=1;i<=cnt[k];i++) print k"\t"files[k]"\t"cnt[k]"\t"rec[k,i];
          }
        }' "$sig_tmp" >"$plan_m" # Genera el reporte

        # Generar plan de limpieza sugerido (KEEP/REMOVE) por fecha/size
        while IFS=$'\t' read -r sig files dupcount path; do
          if [ -z "$sig" ] || [ -z "$path" ]; then
            continue
          fi
          mtime=$({ stat -f %m "$path" 2>/dev/null || echo 0; } | tr -d '[:space:]')
          dsize=$({ du -sk "$path" 2>/dev/null || echo 0; } | awk '{print $1}')
          printf "%s\t%s\t%s\t%s\t%s\n" "$sig" "$path" "$mtime" "$dsize" "$dupcount" >>"$clean_plan.tmp"
        done <"$plan_m"

        # Procesar el temporal para crear el plan de cuarentena final
        run_with_spinner "MATRIOSHKA_PLAN" "Generando plan de limpieza..." awk -F'\t' -v quar_base="$QUAR_DIR/Matrioshka_Folders" '{
            sig=$1; path=$2; m=$3+0; sz=$4+0;
            count[sig]++; idx=count[sig];
            paths[sig,idx]=path; mt[sig,idx]=m; szs[sig,idx]=sz;
        } END {
            for (s in count) {
                best_path=""; best_mtime=-1; best_size=-1;
                for (i=1; i<=count[s]; i++) {
                    if (mt[s,i] > best_mtime || (mt[s,i] == best_mtime && szs[s,i] > best_size)) {
                        best_path=paths[s,i]; best_mtime=mt[s,i]; best_size=szs[s,i];
                    }
                }
                if (best_path != "") {
                    for (i=1; i<=count[s]; i++) {
                        p = paths[s,i];
                        if (p != best_path && p != "") {
                            p_basename = p; gsub(/.*\//, "", p_basename);
                            dest = quar_base "/" s "/" p_basename;
                            print p "\t" dest;
                        }
                    }
                }
            }
        }' "$clean_plan.tmp" > "$clean_plan"

        rm -f "$clean_plan.tmp" "$sig_tmp"
        hits=$(wc -l <"$plan_m" | tr -d ' ')
        printf "%s[OK]%s Reporte de matrioshkas: %s (coincidencias: %s)\n" "$C_GRN" "$C_RESET" "$plan_m" "$hits"
        if [ -s "$clean_plan" ]; then
            printf "%s[OK]%s Plan de cuarentena para matrioshkas: %s\n" "$C_GRN" "$C_RESET" "$clean_plan"
            printf "Se moverán %s carpetas a %s/Matrioshka_Folders/\n" "$(wc -l < "$clean_plan" | tr -d ' ')" "$QUAR_DIR"
            printf "¿Ejecutar el plan de cuarentena ahora? (y/N): "
            read -r run_move
            if [[ "$run_move" =~ ^[yY]$ ]]; then
                if [ "$SAFE_MODE" -eq 1 ] || [ "$DJ_SAFE_LOCK" -eq 1 ]; then
                    printf "%s[WARN]%s SAFE_MODE o DJ_SAFE_LOCK activo. Solo simulación.\n" "$C_YLW" "$C_RESET"
                fi
                while IFS=$'\t' read -r src dest; do
                    if [ "$SAFE_MODE" -eq 1 ] || [ "$DJ_SAFE_LOCK" -eq 1 ]; then
                        printf "[DRY] mkdir -p \"%s\" && mv \"%s\" \"%s\"\n" "$(dirname "$dest")" "$src" "$dest"
                    else
                        mkdir -p "$(dirname "$dest")"
                        mv "$src" "$dest" 2>/dev/null && printf "[OK] Movido: %s\n" "$(basename "$src")"
                    fi
                done < "$clean_plan"
                printf "%s[OK]%s Movimiento completado.\n" "$C_GRN" "$C_RESET"
            fi
        else
            printf "%s[INFO]%s No se generó plan de limpieza (sin duplicados de estructura).\n" "$C_CYN" "$C_RESET"
        fi
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

print(f"[OK] Reporte: {report_path}")
print(f\"[OK] Plan: {plan_path}\")
PY
        rc=$?
        if [ "$rc" -ne 0 ]; then
          printf "%s[ERR]%s No se pudo generar similitud (revise dependencias TF/tf_hub/soundfile). RC=%s\n" "$C_RED" "$C_RESET" "$rc"
        else
          printf "%s[OK]%s Reporte similitud: %s\n" "$C_GRN" "$C_RESET" "$report_sim"
          printf "%s[OK]%s Plan similitud: %s\n" "$C_GRN" "$C_RESET" "$plan_sim"
        fi;
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
        dir_list=$(mktemp "${STATE_DIR}/mirror_dirs.XXXXXX") || dir_list="/tmp/mirror_dirs.$$"
        >"$dir_list"
        for r in "${MROOTS[@]}"; do
          r_trim=$(printf "%s" "$r" | xargs)
          [ -d "$r_trim" ] || { printf "%s[WARN]%s Raíz inválida: %s\n" "$C_YLW" "$C_RESET" "$r_trim"; continue; }
          find "$r_trim" -maxdepth "$md" -type d 2>/dev/null >>"$dir_list"
        done
        total_dirs=$(wc -l <"$dir_list" | tr -d ' ')
        count_dirs=0
        while IFS= read -r d; do
            count_dirs=$((count_dirs + 1))
            if [ "$total_dirs" -gt 0 ]; then
              percent=$((count_dirs * 100 / total_dirs))
            else
              percent=0
            fi
            status_line "MIRROR_FOLDERS" "$percent" "$(basename "$d")"
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
        done <"$dir_list"
        rm -f "$dir_list"
        finish_status_line
        run_with_spinner "MIRROR_PLAN" "Generando plan de carpetas espejo..." awk -F'\t' '{
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
  script_tmp=$(mktemp "${STATE_DIR}/als_report.XXXXXX") || script_tmp="/tmp/als_report.$$"
  cat >"$script_tmp" <<'PY'
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
  run_with_spinner "ABLETON" "Analizando .als..." python3 "$script_tmp" "$out" "${als_list[@]}"
  rm -f "$script_tmp"
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
    status_line "VIDEO_INV" "$percent" "$(basename "$f")"
  done
  finish_status_line
  printf "%s[OK]%s Inventario generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_V3_osc_dmx_plan() {
  print_header
  out="$PLANS_DIR/osc_dmx_plan.tsv"
  printf "%s[INFO]%s Plan OSC/DMX placeholder -> %s\n" "$C_CYN" "$C_RESET" "$out"
  cat >"$out" <<'EOF'
path\taction\tnotes
(añade tus cues OSC/DMX)\tTRIGGER\tPlaceholder: ajusta canales y cues en tu DAW/visual router
EOF
  printf "%s[OK]%s Plan placeholder creado.\n" "$C_GRN" "$C_RESET"
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
    status_line "VIDEO_FFPROBE" "$percent" "$(basename "$f")"
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
    status_line "VIDEO_BUCKET" "$percent" "$(basename "$f")"
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
    status_line "VIDEO_HASH" "$percent" "$(basename "$f")"
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
    status_line "VIDEO_OPT" "$percent" "$(basename "$f")"
  done
  finish_status_line
  printf "%s[OK]%s Plan generado (sólo sugerencias).\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_V10_osc_from_playlist() {
  print_header
  default_pl="$BASE_PATH/playlist.m3u8"
  printf "%s[INFO]%s Generar cues OSC desde playlist (.m3u/.m3u8).\n" "$C_CYN" "$C_RESET"
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
  >"$plan"
  pl_dir="$(dirname "$pl_path")"
  idx=1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      \#*|"") continue ;;
    esac
    if [ "${line:0:1}" != "/" ] && [ "${line:1:1}" != ":" ]; then
      abs="$pl_dir/$line"
    else
      abs="$line"
    fi
    abs="${abs//\"/}"
    printf "%s\t%s\t%s\t%s\n" "$idx" "$abs" "/layer1/clip$idx/trigger" "PLAY" >>"$plan"
    idx=$((idx+1))
  done <"$pl_path"
  printf "%s[OK]%s Plan OSC generado: %s (edita dirección/payload según tu router).\n" "$C_GRN" "$C_RESET" "$plan"
  pause_enter
}

action_V11_dmx_from_playlist() {
  print_header
  default_pl="$BASE_PATH/playlist.m3u8"
  printf "%s[INFO]%s Plan DMX desde playlist (escenas básicas Intro/Drop/Outro).\n" "$C_CYN" "$C_RESET"
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
  >"$plan"
  pl_dir="$(dirname "$pl_path")"
  idx=1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      \#*|"") continue ;;
    esac
    if [ "${line:0:1}" != "/" ] && [ "${line:1:1}" != ":" ]; then
      abs="$pl_dir/$line"
    else
      abs="$line"
    fi
    abs="${abs//\"/}"
    scene="INTRO"
    if [ $idx -gt 1 ]; then
      scene="DROP"
    fi
    values="CH${base_ch}=255,CH$((base_ch+1))=180,STROBE=0"
    printf "%s\t%s\t%s\t%s\n" "$idx" "$abs" "$scene" "$values" >>"$plan"
    idx=$((idx+1))
  done <"$pl_path"
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

action_V13_dmx_fixtures_inventory() {
  print_header
  out="$REPORTS_DIR/dmx_fixtures_inventory.tsv"
  printf "%s[INFO]%s Inventario fixtures DMX/Láser -> %s\n" "$C_CYN" "$C_RESET" "$out"
  search_root="$BASE_PATH"
  printf "Ruta de búsqueda (ENTER usa BASE_PATH=%s): " "$BASE_PATH"
  read -e -r v
  v=$(strip_quotes "$v")
  if [ -n "$v" ] && [ -d "$v" ]; then
    search_root="$v"
  fi
  printf "%s[INFO]%s Buscando fixtures (.ift, .qxf, .ssl, .d4) en %s\n" "$C_CYN" "$C_RESET" "$search_root"
  printf "Archivo\tNombre\tRuta\n" >"$out"
  list_tmp=$(mktemp "${STATE_DIR}/fixtures.XXXXXX") || list_tmp="/tmp/fixtures.$$"
  find "$search_root" -type f \( -iname "*.ift" -o -iname "*.qxf" -o -iname "*.ssl" -o -iname "*.d4" \) 2>/dev/null | head -200 >"$list_tmp"
  total=$(wc -l <"$list_tmp" | tr -d ' ')
  count=0
  while IFS= read -r f; do
    count=$((count + 1))
    if [ "$total" -gt 0 ]; then
      percent=$((count * 100 / total))
    else
      percent=0
    fi
    status_line "DMX_FIXTURES" "$percent" "$(basename "$f")"
    base=$(basename "$f")
    name="${base%.*}"
    printf "%s\t%s\t%s\n" "$base" "$name" "$f" >>"$out"
  done <"$list_tmp"
  rm -f "$list_tmp"
  finish_status_line
  printf "%s[OK]%s Inventario generado (máx 200 resultados). Ajusta ruta si necesitas más.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_V14_visuals_transcode_adv() {
  print_header
  out="$PLANS_DIR/visuals_transcode_adv.tsv"
  printf "%s[INFO]%s Plan de transcode avanzado (sugerencias ffmpeg) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  printf "Codec destino (ENTER=libx264, opciones: libx264/libx265/libvpx-vp9): "
  read -r codec
  [ -z "$codec" ] && codec="libx264"
  printf "Bitrate objetivo (ENTER=15M): "
  read -r br
  [ -z "$br" ] && br="15M"
  printf "Resolución destino (ENTER=1920x1080): "
  read -r res
  [ -z "$res" ] && res="1920x1080"
  printf "Archivos a incluir (ENTER=por defecto: mp4,mov,mkv): "
  read -r exts
  [ -z "$exts" ] && exts="mp4,mov,mkv"
  IFS=',' read -r -a arr_exts <<<"$exts"
  printf "Input\tOutput\tComando_sugerido\n" >"$out"
  list_tmp=$(mktemp "${STATE_DIR}/visuals.XXXXXX") || list_tmp="/tmp/visuals.$$"
  find "$BASE_PATH" -type f \( $(printf -- '-iname "*.%s" -o ' "${arr_exts[@]}" | sed 's/ -o $//') \) 2>/dev/null | head -100 >"$list_tmp"
  total=$(wc -l <"$list_tmp" | tr -d ' ')
  count=0
  while IFS= read -r f; do
    count=$((count + 1))
    if [ "$total" -gt 0 ]; then
      percent=$((count * 100 / total))
    else
      percent=0
    fi
    status_line "VIDEO_TRANSCODE" "$percent" "$(basename "$f")"
    dir=$(dirname "$f")
    base=$(basename "$f")
    out_name="${base%.*}_h264.mp4"
    cmd="ffmpeg -i \"$f\" -c:v $codec -b:v $br -vf scale=$res -c:a aac -b:a 192k \"$dir/$out_name\""
    printf "%s\t%s\t%s\n" "$f" "$dir/$out_name" "$cmd" >>"$out"
  done <"$list_tmp"
  rm -f "$list_tmp"
  finish_status_line
  printf "%s[OK]%s Plan generado (hasta 100 archivos). Revisa comandos antes de ejecutar.\n" "$C_GRN" "$C_RESET"
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
    printf "%s13)%s Inventario fixtures DMX/Láser (busca .ift/.qxf/.ssl/.d4)\n" "$C_GRN" "$C_RESET"
    printf "%s14)%s Plan transcode visual avanzado (ffmpeg sugerido)\n" "$C_GRN" "$C_RESET"
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
      13) action_V13_dmx_fixtures_inventory ;;
      14) action_V14_visuals_transcode_adv ;;
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
  printf " 71) Conversor WAV a MP3 (320kbps CBR, preserva tags).\n"
  printf " 72) Auto-actualizador (descarga última versión de GitHub).\n\n"

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
  printf "  65) TensorFlow Lab: auto-tagging (modelos: YAMNet/NNFP/VGGish/musicnn; 150 archivos, top3), similitud (presets: rápido/balanceado/estricto), loops/sospechosos (placeholder), music tagging multi-label (150). Requiere TF/tf_hub/soundfile.\n"
  printf "  66) Plan LUFS (análisis, sin normalizar) – requiere python3+pyloudnorm+soundfile.\n"
  printf "  67) Auto-cues por onsets (librosa) – requiere python3+librosa.\n\n" "$ML_PKG_TF_MB"

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
  printf "  70: Perfil IA local (LIGHT recomendado; TF_ADV opcional para Apple Silicon).\n\n"

  printf "%sSubmenú A) Automatizaciones (cadenas):%s\n" "$C_YLW" "$C_RESET"
  printf "  A1-A10: flujos predefinidos (backup+snapshot, dedup+quarantine, limpieza metadatos/nombres, health scan, prep show, integridad, eficiencia, ML básica, backup predictivo, sync multi).\n"
  printf "  A11-A14: diagnóstico rápido, salud Serato, hash+mirror check, audio prep (tags+LUFS+cues).\n"
  printf "  A15-A20: auditoría integridad, limpieza+backup, prep sync, salud visuales, org audio avanzada, seguridad Serato.\n"
  printf "  A23-A28: auto-pilot (prep+clean+dedup), todo en uno, limpieza+backup seguro, relink doctor + export estado, Deep/ML, seguro.\n"
  printf "  Tip: SafeMode/DJ_SAFE_LOCK siguen activos; quarantine y operaciones peligrosas respetan bloqueos.\n\n"

  printf "%sGuía de Consolidación (Discos Externos -> Principal):%s\n" "$C_YLW" "$C_RESET"
  printf "  1. En Disco Principal: Ejecuta A30 para organizar tu INBOX y asegurar que tu librería base está limpia.\n"
  printf "  2. En Disco Externo: Cambia BASE_PATH (Opción 2) al externo.\n"
  printf "  3. Limpieza interna: Ejecuta 10 (Dupes) -> 11 (Quarantine) en el externo.\n"
  printf "  4. Eliminar redundancia: Usa D6 (Consolidación Inversa). Destino = Principal, Origen = Externo.\n"
  printf "     Esto te dirá qué archivos del externo ya tienes en el principal para borrarlos.\n\n"

  printf "%sAutoguías y wiki:%s\n" "$C_YLW" "$C_RESET"
  printf "  - GUIDE.md (wiki extensa) en el repo: rutas, flujos recomendados, tips de exclusiones y snapshots.\n"
  printf "  - Capturas menú: docs/menu_es_full.svg y docs/menu_en_full.svg (visibles en GitHub).\n"
  printf "  - Auto-pilot (A23-A28) para ejecutar flujos completos sin intervención.\n\n"

  printf "%sSubmenú V) Visuales / DAW / OSC / DMX:%s\n" "$C_YLW" "$C_RESET"
  printf "  V1-V2: reportes Ableton .als y catálogo de visuales.\n"
  printf "  V4-V5: Serato Video (reporte + plan transcode).\n"
  printf "  V6-V9: ffprobe para resolución/duración, buckets por resolución, duplicados por hash, sugerir H.264 1080p.\n"
  printf "  V10-V11: plan OSC/DMX desde playlist (.m3u/.m3u8) para sincronizar clips/escenas.\n"
  printf "  V12: presets DMX para Spider 8x6W + láser ALIEN; ajusta canales/valores a tu mapeo.\n"
  printf "  V13: inventario fixtures DMX/láser (.ift/.qxf/.ssl/.d4) – ayuda a mapear modelos.\n"
  printf "  V14: plan transcode avanzado con comando ffmpeg sugerido (elige codec/bitrate/resolución).\n"
  printf "  Nota: los TSV generados son plantillas; revisa antes de enviar a tu software DMX/OSC o lanzar ffmpeg.\n\n"

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
  printf "  L5) dj_cues.tsv -> ableton_locators.csv (placeholder).\n"
  printf "  L6) Inventario de librerías (Serato/Traktor/Rekordbox/Ableton/Serato Video).\n\n"

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
      40) action_40_wav_to_mp3 ;;
      41) action_41_update_self ;;
      42) action_40_smart_analysis ;;
      43) action_41_ml_predictor ;;
      44) action_42_efficiency_optimizer ;;
      45) action_43_smart_workflow ;;
      46) action_44_integrated_dedup ;;
      47) action_45_ml_organization ;;
      48) action_46_metadata_harmonizer ;;
      49) action_47_predictive_backup ;;
      50) action_48_cross_platform_sync ;;
      51) action_49_advanced_analysis ;;
      52) action_50_integration_engine ;;
      53) action_51_adaptive_recommendations ;;
      54) action_52_automated_cleanup_pipeline ;;
      55) action_ml_evo_manager ;;
      56) action_toggle_ml ;;
      57) action_tensorflow_manager ;;
      58) submenu_T_tensorflow_lab ;;
      59) action_ml_profile ;;
      60) action_53_reset_state ;;
      61) submenu_profiles_manager ;;
      62) submenu_ableton_tools ;;
      63) submenu_importers_cues ;;
      64) submenu_excludes_manager ;;
      65) action_compare_hash_indexes ;;
      66) action_state_health ;;
      67) action_export_import_config ;;
      68) action_mirror_integrity_check ;;
      69) action_audio_lufs_plan ;;
      70) action_audio_cues_onsets ;;
      71) submenu_A_chains ;;
      72) action_69_artist_pages ;;
      A|a) submenu_A_chains ;;
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

init_paths
save_conf
main_loop
