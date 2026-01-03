#!/usr/bin/env bash
set -u

# Re-run with bash if launched from another shell (double click)
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
BANNER_SOFT="${ESC}[0;37;44m"
C_GRN_SOFT="${ESC}[0;32m"
C_YLW_SOFT="${ESC}[0;33m"
C_CYN_SOFT="${ESC}[0;36m"
C_PURP_SOFT="${ESC}[38;5;105m"
BANNER="${ESC}[1;37;44m"

# Anchor to script directory (double click) and keep window open on exit
SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

LAUNCH_NON_INTERACTIVE=0
if [ -z "${PS1:-}" ] && [ -z "${TMUX:-}" ] && [ -z "${SSH_CONNECTION:-}" ]; then
  LAUNCH_NON_INTERACTIVE=1
fi
trap 'code=$?; if [ "$LAUNCH_NON_INTERACTIVE" -eq 1 ]; then echo; echo "[INFO] Script finished (code $code). Press ENTER to close..."; read -r _; fi' EXIT

# Ensure TERM for non-interactive runs (prevents curses warnings)
export TERM="${TERM:-xterm-256color}"
COLOR_DISABLED=0

# Polyfill mapfile for older macOS Bash (3.2) with escaping
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
SPIN_IDX=0
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
  local arr=("$@")
  local idx=1
  printf "%s\n" "$prompt"
  for c in "${arr[@]}"; do
    printf "  [%d] %s\n" "$idx" "$c"
    idx=$((idx + 1))
  done
  printf "  [M] Enter manually\n"
  printf "Choice: "
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

  printf "%s[WARN]%s Invalid BASE_PATH: %s\n" "$C_YLW" "$C_RESET" "$BASE_PATH"
  if [ "${#candidates[@]}" -gt 0 ]; then
    choice=$(select_from_candidates "Pick BASE_PATH from suggestions:" "${candidates[@]}")
    if [ -n "$choice" ]; then
      BASE_PATH="$choice"
      append_history "$BASE_HISTORY_FILE" "$BASE_PATH"
      return
    fi
  fi
  printf "Enter BASE_PATH manually: "
  read -e -r new_base
  new_base=$(strip_quotes "$new_base")
  if [ -n "$new_base" ] && [ -d "$new_base" ]; then
    BASE_PATH="$new_base"
    append_history "$BASE_HISTORY_FILE" "$BASE_PATH"
  else
    printf "%s[WARN]%s Using PWD as BASE_PATH: %s\n" "$C_YLW" "$C_RESET" "$PWD"
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
    printf "%s=== Exclusions Manager ===%s\n" "$C_CYN" "$C_RESET"
    printf "Active profile: %s\n" "$DEFAULT_EXCLUDES"
    printf "%s1)%s Pick saved profile\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Save current profile\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Restore default exclusions\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s List profiles\n" "$C_YLW" "$C_RESET"
    printf "%s5)%s Load AUDIO preset\n" "$C_YLW" "$C_RESET"
    printf "%s6)%s Load PROJECTS preset\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Back\n" "$C_YLW" "$C_RESET"
    printf "%sOption:%s " "$C_BLU" "$C_RESET"
    read -e -r xop
    case "$xop" in
      1)
        mapfile -t profs < <(awk -F'\t' 'NF>=2{print $1"\t"$2}' "$EXCLUDES_PROFILES_FILE" 2>/dev/null)
        if [ "${#profs[@]}" -eq 0 ]; then
          printf "%s[WARN]%s No saved profiles.\n" "$C_YLW" "$C_RESET"
          pause_enter
          continue
        fi
        printf "Profiles:\n"
        idx=1
        for line in "${profs[@]}"; do
          name=$(printf "%s" "$line" | cut -f1)
          pat=$(printf "%s" "$line" | cut -f2-)
          printf "  [%d] %s -> %s\n" "$idx" "$name" "$pat"
          idx=$((idx + 1))
        done
        printf "Pick number: "
        read -e -r sel
        if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#profs[@]}" ]; then
          line="${profs[$((sel-1))]}"
          DEFAULT_EXCLUDES=$(printf "%s" "$line" | cut -f2-)
          save_conf
          printf "%s[OK]%s Profile loaded.\n" "$C_GRN" "$C_RESET"
        else
          printf "%s[WARN]%s Invalid selection.\n" "$C_YLW" "$C_RESET"
        fi
        pause_enter
        ;;
      2)
        printf "Name for the profile: "
        read -e -r pname
        pname=$(strip_quotes "$pname")
        [ -z "$pname" ] && { printf "%s[WARN]%s Empty name.\n" "$C_YLW" "$C_RESET"; pause_enter; continue; }
        tmp="$EXCLUDES_PROFILES_FILE.tmp"
        { printf "%s\t%s\n" "$pname" "$DEFAULT_EXCLUDES"; grep -v "^$pname\t" "$EXCLUDES_PROFILES_FILE" 2>/dev/null; } >"$tmp"
        mv "$tmp" "$EXCLUDES_PROFILES_FILE"
        printf "%s[OK]%s Profile saved.\n" "$C_GRN" "$C_RESET"
        pause_enter
        ;;
      3)
        DEFAULT_EXCLUDES="$DEFAULT_EXCLUDES_BASE"
        save_conf
        printf "%s[OK]%s Exclusions restored to base value.\n" "$C_GRN" "$C_RESET"
        pause_enter
        ;;
      4)
        printf "%s[INFO]%s Saved profiles:\n" "$C_CYN" "$C_RESET"
        if ! awk -F'\t' 'NF>=2{printf "- %s: %s\n",$1,$2}' "$EXCLUDES_PROFILES_FILE"; then
          printf "(empty)\n"
        fi
        pause_enter
        ;;
      5)
        DEFAULT_EXCLUDES="$PRESET_EXCLUDES_AUDIO"
        save_conf
        printf "%s[OK]%s AUDIO preset loaded.\n" "$C_GRN" "$C_RESET"
        pause_enter
        ;;
      6)
        DEFAULT_EXCLUDES="$PRESET_EXCLUDES_PROYECTOS"
        save_conf
        printf "%s[OK]%s PROJECTS preset loaded.\n" "$C_GRN" "$C_RESET"
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
  if [ ${#arr[@]:-0} -gt 0 ]; then
    for p in "${arr[@]:-}"; do
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
ML_PKGS_EVO="numpy pandas scikit-learn joblib"
ML_PKG_EVO_MB=450
ML_PKGS_TF="tensorflow"
ML_PKG_TF_MB=600
PROFILES_DIR=""

pause_enter() {
  printf "%sPress ENTER to continue...%s" "$C_YLW" "$C_RESET"
  read -r _
}

ensure_dirs() {
  mkdir -p "$STATE_DIR" "$CONFIG_DIR" "$REPORTS_DIR" "$PLANS_DIR" "$LOGS_DIR" "$QUAR_DIR" "$VENV_DIR"
}

init_paths() {
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
      printf "%s[WARN]%s Could not load %s, it will be regenerated.\n" "$C_YLW" "$C_RESET" "$CONF_FILE"
    fi
    set -u
  fi
}

maybe_activate_ml_env() {
  local context="${1:-ML}"
  local want_tf="${2:-0}"
  local want_evo="${3:-0}"
  if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
    printf "%s[WARN]%s ML is globally disabled (toggle in extras menu).\n" "$C_YLW" "$C_RESET"
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

  printf "%s[INFO]%s %s requires an isolated ML env.\n" "$C_CYN" "$C_RESET" "$context"
  printf "%s[WARN]%s Needs Internet connection. Estimated download: ~%s MB.\n" "$C_YLW" "$C_RESET" "$est_mb"
  printf "Create venv at %s and install pip + %s (~%s MB)? [y/N]: " "$VENV_DIR" "$pkgs" "$est_mb"
  read -r ans
  case "$ans" in
    y|Y)
      if ! command -v python3 >/dev/null 2>&1; then
        printf "%s[ERR]%s python3 not found. Install it and try again.\n" "$C_RED" "$C_RESET"
        ML_ENV_DISABLED=1
        return
      fi
      python3 -m venv "$VENV_DIR" 2>/dev/null || {
        printf "%s[ERR]%s Could not create venv at %s\n" "$C_RED" "$C_RESET" "$VENV_DIR"
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
      printf "%s[WARN]%s ML env skipped for %s. Retry later if needed.\n" "$C_YLW" "$C_RESET" "$context"
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
  local frame_colored="${ghost_color}${frame}${C_RESET}"
  printf "\r%s👻%s %s | %3s%% | %s | %s" "$ghost_color" "$C_RESET" "$task" "$percent" "$frame_colored" "$current"
}

finish_status_line() {
  printf "\n"
}

print_header() {
  clear
  if [ -f "$BANNER_FILE" ]; then
    printf "%s" "$C_PURP"
    sed "s/^/$C_PURP/;s/$/$C_RESET/" "$BANNER_FILE"
    printf "%s\n" "$C_RESET"
  else
    cols=$(tput cols 2>/dev/null || echo 80)
    # Gradient (cool→warm) for EN using script palette
    local colors=("$C_GRN" "$C_CYN" "$C_BLU" "$C_PURP" "$C_RED" "$C_YLW")
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
  printf "%sMenu (grouped view)%s\n" "$C_GRN" "$C_RESET"
  printf "%s⚙️  Core (1-12):%s\n" "$C_CYN" "$C_RESET"
  printf "  %s1)%s Status / paths / locks\n" "$C_GRN" "$C_RESET"
  printf "  %s2)%s Change Base Path\n" "$C_GRN" "$C_RESET"
  printf "  %s3)%s Volume summary / recent reports\n" "$C_GRN" "$C_RESET"
  printf "  %s4)%s Top folders by size\n" "$C_GRN" "$C_RESET"
  printf "  %s5)%s Top large files\n" "$C_GRN" "$C_RESET"
  printf "  %s6)%s Scan workspace (catalog)\n" "$C_GRN" "$C_RESET"
  printf "  %s7)%s Backup Serato (_Serato_ / _Serato_Backup)\n" "$C_GRN" "$C_RESET"
  printf "  %s8)%s Backup DJ (Serato/Traktor/Rekordbox/Ableton metadata)\n" "$C_GRN" "$C_RESET"
  printf "  %s9)%s SHA-256 index (generate/reuse)\n" "$C_GRN" "$C_RESET"
  printf "  %s10)%s Exact duplicate report (PLAN JSON/TSV)\n" "$C_GRN" "$C_RESET"
  printf "  %s11)%s Quarantine duplicates (from LAST_PLAN)\n" "$C_GRN" "$C_RESET"
  printf "  %s12)%s Quarantine Manager (list/purge/restore)\n" "$C_GRN" "$C_RESET"
  printf "\n"

  printf "%s🎛️  Media / organization (13-24):%s\n" "$C_CYN" "$C_RESET"
  printf "  %s13)%s Detect corrupt media (ffprobe) -> TSV\n" "$C_GRN" "$C_RESET"
  printf "  %s14)%s Create .m3u8 playlists per folder\n" "$C_GRN" "$C_RESET"
  printf "  %s15)%s Doctor: Relink Helper (non-destructive TSV)\n" "$C_GRN" "$C_RESET"
  printf "  %s16)%s Genre mirror (hardlink/copy/move) (safe plan)\n" "$C_GRN" "$C_RESET"
  printf "  %s17)%s Find DJ libraries\n" "$C_GRN" "$C_RESET"
  printf "  %s18)%s Smart rescan (match + ULTRA)\n" "$C_GRN" "$C_RESET"
  printf "  %s19)%s Tools: diagnostics/recommended install\n" "$C_GRN" "$C_RESET"
  printf "  %s20)%s Fix ownership/flags (plan + optional run)\n" "$C_GRN" "$C_RESET"
  printf "  %s21)%s Install universal command: djproducertool\n" "$C_GRN" "$C_RESET"
  printf "  %s22)%s Uninstall command: djproducertool\n" "$C_GRN" "$C_RESET"
  printf "  %s23)%s Toggle SafeMode (ON/OFF)\n" "$C_GRN" "$C_RESET"
  printf "  %s24)%s Toggle DJ_SAFE_LOCK (ACTIVE/INACTIVE)\n" "$C_GRN" "$C_RESET"
  printf "\n"

  printf "%s🧹 Processes / cleanup (25-39):%s\n" "$C_CYN" "$C_RESET"
  printf "  %s25)%s Quick Help (process guide)\n" "$C_GRN" "$C_RESET"
  printf "  %s26)%s State: Export/Import (bundle)\n" "$C_GRN" "$C_RESET"
  printf "  %s27)%s Integrity snapshot (fast hash) with progress\n" "$C_GRN" "$C_RESET"
  printf "  %s28)%s Logs viewer (selector)\n" "$C_GRN" "$C_RESET"
  printf "  %s29)%s Toggle DryRunForce (ON/OFF)\n" "$C_GRN" "$C_RESET"
  printf "  %s30)%s Organize audio by TAGS (genre) -> plan TSV\n" "$C_GRN" "$C_RESET"
  printf "  %s31)%s Audio tags report -> TSV\n" "$C_GRN" "$C_RESET"
  printf "  %s32)%s Serato Video: REPORT (no transcode)\n" "$C_GRN" "$C_RESET"
  printf "  %s33)%s Serato Video: PREP (transcode plan only)\n" "$C_GRN" "$C_RESET"
  printf "  %s34)%s Normalize names (plan TSV)\n" "$C_GRN" "$C_RESET"
  printf "  %s35)%s Organize samples by TYPE (plan TSV)\n" "$C_GRN" "$C_RESET"
  printf "  %s36)%s Clean WEB (submenu)\n" "$C_GRN" "$C_RESET"
  printf "  %s37)%s WEB: Whitelist Manager (allowed domains)\n" "$C_GRN" "$C_RESET"
  printf "  %s38)%s Clean WEB in Playlists (.m3u/.m3u8)\n" "$C_GRN" "$C_RESET"
  printf "  %s39)%s Clean WEB in TAGS (mutagen) (plan)\n" "$C_GRN" "$C_RESET"
  printf "\n"

  printf "%s🧠 Deep/ML (40-52):%s\n" "$C_CYN" "$C_RESET"
  printf "  %s40)%s Deep Thinking: Smart Analysis (JSON)\n" "$C_GRN" "$C_RESET"
  printf "  %s41)%s Machine Learning: Problem predictor\n" "$C_GRN" "$C_RESET"
  printf "  %s42)%s Deep Thinking: Efficiency optimizer\n" "$C_GRN" "$C_RESET"
  printf "  %s43)%s Deep Thinking: Smart workflow\n" "$C_GRN" "$C_RESET"
  printf "  %s44)%s Deep Thinking: Integrated deduplication\n" "$C_GRN" "$C_RESET"
  printf "  %s45)%s ML: Automatic organization (plan)\n" "$C_GRN" "$C_RESET"
  printf "  %s46)%s Deep Thinking: Metadata harmonizer (plan)\n" "$C_GRN" "$C_RESET"
  printf "  %s47)%s ML: Predictive backup\n" "$C_GRN" "$C_RESET"
  printf "  %s48)%s Deep Thinking: Cross-platform sync\n" "$C_GRN" "$C_RESET"
  printf "  %s49)%s Deep Thinking: Advanced analysis\n" "$C_GRN" "$C_RESET"
  printf "  %s50)%s Deep Thinking: Integration engine\n" "$C_GRN" "$C_RESET"
  printf "  %s51)%s ML: Adaptive recommendations\n" "$C_GRN" "$C_RESET"
  printf "  %s52)%s Deep Thinking: Automated cleanup pipeline\n" "$C_GRN" "$C_RESET"
  printf "  %s62)%s Evolutive ML (train/predict locally)\n" "$C_GRN" "$C_RESET"
  printf "  %s63)%s Toggle ML ON/OFF (avoid ML venv)\n" "$C_GRN" "$C_RESET"
  printf "  %s64)%s Optional TensorFlow (install/advanced ideas)\n" "$C_GRN" "$C_RESET"
  printf "  %s65)%s TensorFlow Lab (auto-tagging/similarity/etc.)\n" "$C_GRN" "$C_RESET"
  printf "\n"

  printf "%s🧰 Extras / utilities (53-67):%s\n" "$C_CYN" "$C_RESET"
  printf "  %s53)%s Reset state / clean extras\n" "$C_GRN" "$C_RESET"
  printf "  %s54)%s Profiles manager (save/load paths)\n" "$C_GRN" "$C_RESET"
  printf "  %s55)%s Ableton Tools (basic analytics)\n" "$C_GRN" "$C_RESET"
  printf "  %s56)%s Importers: Rekordbox/Traktor cues\n" "$C_GRN" "$C_RESET"
  printf "  %s57)%s Exclusions manager (profiles)\n" "$C_GRN" "$C_RESET"
  printf "  %s58)%s Compare hash_index between disks (no rehash)\n" "$C_GRN" "$C_RESET"
  printf "  %s59)%s State health-check (_DJProducerTools)\n" "$C_GRN" "$C_RESET"
  printf "  %s60)%s Export/Import config/profiles only\n" "$C_GRN" "$C_RESET"
  printf "  %s61)%s Mirror check between hash_index (missing/corruption)\n" "$C_GRN" "$C_RESET"
  printf "  %s66)%s LUFS plan (analysis, no normalize)\n" "$C_GRN" "$C_RESET"
  printf "  %s67)%s Auto-cues by onsets (librosa)\n" "$C_GRN" "$C_RESET"
  printf "  %s68)%s Automated chains (21 workflows)\n" "$C_GRN" "$C_RESET"
  printf "  %s69)%s Artist profiles/links (fillable template)\n" "$C_GRN" "$C_RESET"

  printf "\n"
  printf "%s🔮 A) Automations (chains)%s\n" "$C_GRN" "$C_RESET"
  printf "%s📚 L)%s DJ Libraries & Cues (submenu)\n" "$C_GRN_SOFT" "$C_RESET"
  printf "%s♻️  D)%s General duplicates (submenu)\n" "$C_CYN_SOFT" "$C_RESET"
  printf "%s🎥 V)%s Visuals / DAW / OSC (submenu)\n" "$C_PURP_SOFT" "$C_RESET"
  printf "%sℹ️  H)%s Help & INFO\n" "$C_GRN_SOFT" "$C_RESET"
  printf "%s0)%s Exit\n" "$C_GRN" "$C_RESET"
}

invalid_option() {
  printf "%s[ERR]%s Invalid option.\n" "$C_RED" "$C_RESET"
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
  printf "  VENV_DIR: %s (optional ML)\n" "$VENV_DIR"
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
  printf "%s[INFO]%s Current BASE_PATH: %s\n" "$C_CYN" "$C_RESET" "$BASE_PATH"
  printf "New BASE_PATH (ENTER to cancel; supports spaces/drag & drop): "
  read -e -r new_base
  if [ -z "$new_base" ]; then
    return
  fi
  new_base=$(strip_quotes "$new_base")
  if [ ! -d "$new_base" ]; then
    printf "%s[ERR]%s Invalid path.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  BASE_PATH="$new_base"
  init_paths
  save_conf
  printf "%s[OK]%s BASE_PATH updated.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_3_summary() {
  print_header
  printf "%s[INFO]%s Volume summary:\n" "$C_CYN" "$C_RESET"
  du -sh "$BASE_PATH" 2>/dev/null || true
  printf "\nLatest reports in %s:\n" "$REPORTS_DIR"
  ls -1t "$REPORTS_DIR" 2>/dev/null | head || true
  pause_enter
}

action_4_top_dirs() {
  print_header
  printf "%s[INFO]%s Top folders by size (depth 2):\n" "$C_CYN" "$C_RESET"
  find "$BASE_PATH" -maxdepth 2 -type d -print0 2>/dev/null | xargs -0 du -sh 2>/dev/null | sort -hr | head || true
  pause_enter
}

action_5_top_files() {
  print_header
  printf "%s[INFO]%s Top large files:\n" "$C_CYN" "$C_RESET"
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
    printf "%s[WARN]%s No files found.\n" "$C_YLW" "$C_RESET"
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
  printf "%s[OK]%s Generated %s\n" "$C_GRN" "$C_RESET" "$out"
  pause_enter
}

action_7_backup_serato() {
  print_header
  printf "%s[INFO]%s Basic Serato backup.\n" "$C_CYN" "$C_RESET"
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
  printf "%s[OK]%s Serato backup completed (if sources existed).\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_8_backup_dj() {
  print_header
  printf "%s[INFO]%s Backup DJ metadata.\n" "$C_CYN" "$C_RESET"
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
    printf "%s[WARN]%s No metadata paths found.\n" "$C_YLW" "$C_RESET"
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

  printf "%s[OK]%s DJ metadata backup completed (%s paths).\n" "$C_GRN" "$C_RESET" "$total"
  pause_enter
}

action_9_hash_index() {
  print_header
  out="$REPORTS_DIR/hash_index.tsv"
  printf "%s[INFO]%s Building SHA-256 index -> %s\n" "$C_CYN" "$C_RESET" "$out"
  total=$(find "$BASE_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$total" -eq 0 ]; then
    >"$out"
    printf "%s[WARN]%s No files found.\n" "$C_YLW" "$C_RESET"
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
  printf "%s[OK]%s Generated %s\n" "$C_GRN" "$C_RESET" "$out"
  pause_enter
}

action_10_dupes_plan() {
  print_header
  hash_file="$REPORTS_DIR/hash_index.tsv"
  if [ ! -f "$hash_file" ]; then
    printf "%s[WARN]%s hash_index.tsv missing, generating first.\n" "$C_YLW" "$C_RESET"
    action_9_hash_index
  fi
  hash_file="$REPORTS_DIR/hash_index.tsv"
  if [ ! -f "$hash_file" ]; then
    printf "%s[ERR]%s Could not generate hash_index.tsv.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  plan_tsv="$PLANS_DIR/dupes_plan.tsv"
  plan_json="$PLANS_DIR/dupes_plan.json"
  printf "%s[INFO]%s Building EXACT duplicates plan.\n" "$C_CYN" "$C_RESET"
  awk '
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
  printf "%s[OK]%s Plan generated: %s and %s\n" "$C_GRN" "$C_RESET" "$plan_tsv" "$plan_json"
  pause_enter
}

action_11_quarantine_from_plan() {
  print_header
  plan_tsv="$PLANS_DIR/dupes_plan.tsv"
  if [ ! -f "$plan_tsv" ]; then
    printf "%s[ERR]%s dupes_plan.tsv not found.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  printf "%s[INFO]%s Applying quarantine from plan (SAFE_MODE=%s).\n" "$C_CYN" "$C_RESET" "$SAFE_MODE"
  sample_count=$(awk -F'\t' '$2=="QUARANTINE"{c++} END {print c+0}' "$plan_tsv")
  printf "QUARANTINE actions: %s\n" "$sample_count"
  if [ "$sample_count" -gt 0 ]; then
    printf "Sample of first 10 entries:\n"
    awk -F'\t' '$2=="QUARANTINE"{print NR": "$3}' "$plan_tsv" | head -10
  fi

  # Estimate needed space for quarantine moves
  needed_bytes=0
  while IFS=$'\t' read -r _ action f; do
    [ "$action" != "QUARANTINE" ] && continue
    sz=$({ stat -f %z "$f" 2>/dev/null || echo 0; } | tr -d ' ')
    needed_bytes=$((needed_bytes + sz))
  done <"$plan_tsv"
  avail_bytes=$(df -k "$QUAR_DIR" 2>/dev/null | awk 'NR==2{print $4*1024}')
  [ -z "$avail_bytes" ] && avail_bytes=0
  printf "Estimated needed: %.2f MB | Available: %.2f MB\n" "$(echo "$needed_bytes/1048576" | bc -l)" "$(echo "$avail_bytes/1048576" | bc -l)"
  if [ "$avail_bytes" -lt "$needed_bytes" ] && [ "$needed_bytes" -gt 0 ]; then
    printf "%s[WARN]%s Not enough space in quarantine. Continue anyway? (y/N): " "$C_YLW" "$C_RESET"
    read -r space_ans
    case "$space_ans" in
      y|Y) ;;
      *) printf "%s[INFO]%s Cancelled due to insufficient space.\n" "$C_CYN" "$C_RESET"; pause_enter; return ;;
    esac
  fi

  printf "Confirm moving files marked as QUARANTINE? (y/N): "
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
    printf "%s1)%s List files in quarantine\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Restore ALL (if SAFE_MODE=0 and DJ_SAFE_LOCK=0)\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Delete ALL permanently (if SAFE_MODE=0 and DJ_SAFE_LOCK=0)\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Back\n" "$C_YLW" "$C_RESET"
    printf "%sOption:%s " "$C_BLU" "$C_RESET"
    read -r qop
    case "$qop" in
      1)
        printf "%s[INFO]%s Quarantine contents:\n" "$C_CYN" "$C_RESET"
        find "$QUAR_DIR" -type f 2>/dev/null || true
        pause_enter
        ;;
      2)
        if [ "$SAFE_MODE" -eq 1 ] || [ "$DJ_SAFE_LOCK" -eq 1 ]; then
          printf "%s[ERR]%s SAFE_MODE or DJ_SAFE_LOCK active. Nothing will be restored.\n" "$C_RED" "$C_RESET"
          pause_enter
        else
          printf "%s[WARN]%s Restore ALL from quarantine to BASE_PATH.\n" "$C_YLW" "$C_RESET"
          printf "Confirm (YES to continue): "
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
          printf "%s[ERR]%s SAFE_MODE or DJ_SAFE_LOCK active. Nothing will be deleted.\n" "$C_RED" "$C_RESET"
          pause_enter
        else
          printf "%s[WARN]%s Delete ALL quarantine contents.\n" "$C_YLW" "$C_RESET"
          printf "Confirm (YES to continue): "
          read -r ans2
          if [ "$ans2" = "YES" ]; then
            rm -rf "$QUAR_DIR"/*
            printf "%s[OK]%s Quarantine emptied.\n" "$C_GRN" "$C_RESET"
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
  printf "%s[INFO]%s Detecting corrupt media (ffprobe) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  if ! command -v ffprobe >/dev/null 2>&1; then
    printf "%s[ERR]%s ffprobe is not installed.\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  >"$out"
  find "$BASE_PATH" -type f 2>/dev/null | while IFS= read -r f; do
    status_line "FFPROBE" 0 "$f"
    ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$f" >/dev/null 2>&1 || printf "%s\tCORRUPT\n" "$f" >>"$out"
  done
  finish_status_line
  printf "%s[OK]%s Report generated (if corrupt files) at %s\n" "$C_GRN" "$C_RESET" "$out"
  pause_enter
}

action_14_playlists_per_folder() {
  print_header
  printf "%s[INFO]%s Create .m3u8 playlists per folder.\n" "$C_CYN" "$C_RESET"
  find "$BASE_PATH" -type d 2>/dev/null | while IFS= read -r d; do
    playlist="$d/playlist.m3u8"
    find "$d" -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.m4a" \) 2>/dev/null >"$playlist"
  done
  printf "%s[OK]%s Playlists generated.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_15_relink_helper() {
  print_header
  out="$REPORTS_DIR/relink_helper.tsv"
  printf "%s[INFO]%s Generating Relink Helper TSV: %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  find "$BASE_PATH" -type f 2>/dev/null | while IFS= read -r f; do
    rel="${f#$BASE_PATH/}"
    printf "%s\t%s\n" "$rel" "$f" >>"$out"
  done
  printf "%s[OK]%s Relink Helper generated.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_16_mirror_by_genre() {
  print_header
  printf "%s[INFO]%s Mirror by genre (basic safe plan).\n" "$C_CYN" "$C_RESET"
  out="$PLANS_DIR/mirror_by_genre.tsv"
  >"$out"
  find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null | while IFS= read -r f; do
    printf "%s\tGENRE_UNKNOWN\t%s\n" "$f" "$BASE_PATH/_MIRROR_BY_GENRE/GENRE_UNKNOWN/$(basename "$f")" >>"$out"
  done
  printf "%s[OK]%s Mirror-by-genre plan generated: %s\n" "$C_GRN" "$C_RESET" "$out"
  pause_enter
}

action_17_find_dj_libs() {
  print_header
  printf "%s[INFO]%s Searching DJ libraries in %s\n" "$C_CYN" "$C_RESET" "$BASE_PATH"
  find "$BASE_PATH" -type d \( -iname "*Serato*" -o -iname "*Traktor*" -o -iname "*Rekordbox*" -o -iname "*Ableton*" \) 2>/dev/null || true
  pause_enter
}

action_18_rescan_intelligent() {
  print_header
  printf "%s[INFO]%s Intelligent rescan.\n" "$C_CYN" "$C_RESET"
  out="$REPORTS_DIR/rescan_intelligent.tsv"
  total=$(find "$BASE_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$total" -eq 0 ]; then
    >"$out"
    printf "%s[WARN]%s No files found.\n" "$C_YLW" "$C_RESET"
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
  printf "%s[OK]%s Intelligent rescan completed.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_19_tools_diag() {
  print_header
  printf "%s[INFO]%s Tools diagnostic.\n" "$C_CYN" "$C_RESET"
  for cmd in ffprobe shasum rsync find ls du; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf "  %s: OK\n" "$cmd"
    else
      printf "  %s: NOT FOUND\n" "$cmd"
    fi
  done
  pause_enter
}

action_20_fix_ownership_flags() {
  print_header
  out="$PLANS_DIR/fix_ownership_flags.tsv"
  printf "%s[INFO]%s Fix ownership/flags plan -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  find "$BASE_PATH" -type f 2>/dev/null | while IFS= read -r f; do
    printf "%s\tchown-KEEP\tchmod-KEEP\n" "$f" >>"$out"
  done
  printf "%s[OK]%s Plan generated (not executed).\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_21_install_cmd() {
  print_header
  target="/usr/local/bin/djproducertool"
  printf "%s[INFO]%s Install universal command: %s\n" "$C_CYN" "$C_RESET" "$target"
  if [ "$SAFE_MODE" -eq 1 ]; then
    printf "%s[WARN]%s SAFE_MODE=1, only showing the action.\n" "$C_YLW" "$C_RESET"
    printf "ln -s \"%s/DJProducerTools_MultiScript.sh\" \"%s\"\n" "$BASE_PATH" "$target"
  else
    ln -sf "$BASE_PATH/DJProducerTools_MultiScript.sh" "$target" 2>/dev/null || printf "%s[ERR]%s Could not create symlink (permission required).\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_22_uninstall_cmd() {
  print_header
  target="/usr/local/bin/djproducertool"
  printf "%s[INFO]%s Uninstall universal command: %s\n" "$C_CYN" "$C_RESET" "$target"
  if [ -L "$target" ] || [ -f "$target" ]; then
    if [ "$SAFE_MODE" -eq 1 ]; then
      printf "%s[WARN]%s SAFE_MODE=1, nothing will be deleted.\n" "$C_YLW" "$C_RESET"
    else
      rm -f "$target" 2>/dev/null || true
      printf "%s[OK]%s Removed.\n" "$C_GRN" "$C_RESET"
    fi
  else
    printf "%s[INFO]%s Command does not exist.\n" "$C_CYN" "$C_RESET"
  fi
  pause_enter
}

action_23_toggle_safe_mode() {
  print_header
  printf "%s[INFO]%s Current SAFE_MODE: %s\n" "$C_CYN" "$C_RESET" "$SAFE_MODE"
  if [ "$SAFE_MODE" -eq 1 ]; then
    SAFE_MODE=0
  else
    SAFE_MODE=1
  fi
  save_conf
  printf "%s[OK]%s SAFE_MODE now: %s\n" "$C_GRN" "$C_RESET" "$SAFE_MODE"
  pause_enter
}

action_24_toggle_lock() {
  print_header
  printf "%s[INFO]%s Current DJ_SAFE_LOCK: %s\n" "$C_CYN" "$C_RESET" "$DJ_SAFE_LOCK"
  if [ "$DJ_SAFE_LOCK" -eq 1 ]; then
    DJ_SAFE_LOCK=0
  else
    DJ_SAFE_LOCK=1
  fi
  save_conf
  printf "%s[OK]%s DJ_SAFE_LOCK now: %s\n" "$C_GRN" "$C_RESET" "$DJ_SAFE_LOCK"
  pause_enter
}

action_25_quick_help() {
  print_header
  printf "%s[INFO]%s Quick process guide.\n" "$C_CYN" "$C_RESET"
  printf "  6 -> 9 -> 10 -> 11 -> 12 for duplicate flow.\n"
  printf "  7 -> 8 for DJ backups.\n"
  printf "  27 for quick integrity snapshot.\n"
  printf "  Reset state: delete _DJProducerTools in your BASE_PATH to restart (config/reports/plans/quarantine/venv).\n"
  printf "    Example: rm -rf \"<BASE_PATH>/_DJProducerTools\" (replace <BASE_PATH> with your current path).\n"
  pause_enter
}

action_26_export_import_state() {
  print_header
  bundle="$STATE_DIR/DJPT_state_bundle.tar.gz"
  printf "%s[INFO]%s Exporting state to %s\n" "$C_CYN" "$C_RESET" "$bundle"
  (tar -czf "$bundle" -C "$STATE_DIR" . 2>/dev/null) &
  tar_pid=$!
  while kill -0 "$tar_pid" 2>/dev/null; do
    status_line "EXPORT" "--" "Packing state..."
    sleep 1
  done
  finish_status_line
  if wait "$tar_pid"; then
    printf "%s[OK]%s Bundle created: %s\n" "$C_GRN" "$C_RESET" "$bundle"
  else
    printf "%s[ERR]%s Bundle creation failed.\n" "$C_RED" "$C_RESET"
  fi
  pause_enter
}

action_27_snapshot() {
  print_header
  out="$REPORTS_DIR/snapshot_hash_fast.tsv"
  printf "%s[INFO]%s Generating quick snapshot -> %s\n" "$C_CYN" "$C_RESET" "$out"
  total=$(find "$BASE_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$total" -eq 0 ]; then
    >"$out"
    printf "%s[WARN]%s No files found.\n" "$C_YLW" "$C_RESET"
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
  printf "%s[OK]%s Snapshot generated.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_28_logs_viewer() {
  print_header
  printf "%s[INFO]%s Logs in %s\n" "$C_CYN" "$C_RESET" "$LOGS_DIR"
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
  printf "%s[INFO]%s State reset (config/reports/plans/quarantine/venv).\n" "$C_CYN" "$C_RESET"
  printf "BASE_PATH: %s\n" "$BASE_PATH"
  printf "STATE_DIR to delete: %s\n" "$STATE_DIR"
  printf "Current EXTRA_SOURCE_ROOTS: %s\n" "${EXTRA_SOURCE_ROOTS:-<empty>}"
  printf "Type RESET to delete, CLEAR to only clean EXTRA_SOURCE_ROOTS, DRY to simulate, or ENTER to cancel: "
  read -r ans
  case "$ans" in
    RESET)
      printf "%s[WARN]%s Deleting %s ...\n" "$C_YLW" "$C_RESET" "$STATE_DIR"
      rm -rf "$STATE_DIR" 2>/dev/null || true
      EXTRA_SOURCE_ROOTS=""
      init_paths
      save_conf
      printf "%s[OK]%s State reset.\n" "$C_GRN" "$C_RESET"
      ;;
    CLEAR)
      EXTRA_SOURCE_ROOTS=""
      save_conf
      printf "%s[OK]%s EXTRA_SOURCE_ROOTS cleaned.\n" "$C_GRN" "$C_RESET"
      ;;
    DRY)
      printf "[DRY] Would remove: %s\n" "$STATE_DIR"
      ;;
    *)
      printf "%s[INFO]%s Cancelled.\n" "$C_CYN" "$C_RESET"
      ;;
  esac
  pause_enter
}

action_compare_hash_indexes() {
  print_header
  printf "%s[INFO]%s Compare two hash_index.tsv (no rehash, format: hash\\trel\\tpath).\n" "$C_CYN" "$C_RESET"
  printf "Hash index A (ENTER uses reports/hash_index.tsv): "
  read -e -r file_a
  [ -z "$file_a" ] && file_a="$REPORTS_DIR/hash_index.tsv"
  printf "Hash index B (drag & drop): "
  read -e -r file_b
  if [ ! -f "$file_a" ] || [ ! -f "$file_b" ]; then
    printf "%s[ERR]%s Invalid file(s).\n" "$C_RED" "$C_RESET"
    pause_enter
    return
  fi
  out_missing="$REPORTS_DIR/hash_compare_missing_$(date +%s).tsv"
  out_extra="$REPORTS_DIR/hash_compare_extra_$(date +%s).tsv"
  awk '{print $1"\t"$3}' "$file_a" | sort >"$STATE_DIR/hash_a.tmp"
  awk '{print $1"\t"$3}' "$file_b" | sort >"$STATE_DIR/hash_b.tmp"
  comm -23 "$STATE_DIR/hash_a.tmp" "$STATE_DIR/hash_b.tmp" >"$out_extra"
  comm -13 "$STATE_DIR/hash_a.tmp" "$STATE_DIR/hash_b.tmp" >"$out_missing"
  printf "%s[OK]%s Differences generated:\n" "$C_GRN" "$C_RESET"
  printf "  Extra in A vs B: %s\n" "$out_extra"
  printf "  Missing in A vs B: %s\n" "$out_missing"
  pause_enter
}

action_mirror_integrity_check() {
  print_header
  printf "%s[INFO]%s Validate integrity between disks (hash_index by path, format: hash\\trel\\tpath).\n" "$C_CYN" "$C_RESET"
  printf "Hash index A (ENTER uses reports/hash_index.tsv): "
  read -e -r file_a
  [ -z "$file_a" ] && file_a="$REPORTS_DIR/hash_index.tsv"
  printf "Hash index B (mirror path, drag & drop): "
  read -e -r file_b
  if [ ! -f "$file_a" ] || [ ! -f "$file_b" ]; then
    printf "%s[ERR]%s Invalid file(s).\n" "$C_RED" "$C_RESET"
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
  printf "%s[OK]%s Mirror check generated:\n" "$C_GRN" "$C_RESET"
  printf "  Missing in B: %s\n" "$missing_in_b"
  printf "  Missing in A: %s\n" "$missing_in_a"
  printf "  Different hash (possible corruption): %s\n" "$mismatch"
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
    echo "Top 10 in quarantine:"
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
  printf "1) Export config\n2) Import config\nOption: "
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
        printf "%s[ERR]%s Invalid file.\n" "$C_RED" "$C_RESET"
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
    printf "%s[OK]%s ML disabled (Deep/ML/62 will not activate venv).\n" "$C_GRN" "$C_RESET"
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
  printf "Option: "
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
        printf "%s[ERR]%s Missing ML dependencies (numpy/pandas/scikit-learn). Install them in the venv and try again.\n" "$C_RED" "$C_RESET"
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
# Priority 1: hash plan (action KEEP/QUARANTINE)
if plan_hash.exists() and plan_hash.stat().st_size > 0:
    with plan_hash.open() as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            _, action, path = parts[0], parts[1], parts[2]
            label = 1 if action.upper() != "KEEP" else 0
            rows.append(feature_row(path, label))
# Priority 2: name+size plan
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
    # Fallback: BASE_PATH sample with heuristic (no real positive labels)
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
    print("[WARN] Not enough positive/negative labels. Training skipped.")
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

print(f"[OK] Trained model: {model_out}")
print(f"[INFO] Features stored at: {features_out}")
print(f"[INFO] Metrics (macro f1): {report.get('macro avg', {}).get('f1-score', 0):.3f}")
PY
      printf "%s[OK]%s Training completed (see console for metrics).\n" "$C_GRN" "$C_RESET"
      pause_enter
      ;;
    2)
      if [ ! -f "$ML_MODEL_PATH" ]; then
        printf "%s[ERR]%s No trained model (run option 1 first).\n" "$C_RED" "$C_RESET"
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
    print("[ERR] No files to evaluate.")
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
    printf "%s[WARN]%s ML is disabled (use 63 to enable).\n" "$C_YLW" "$C_RESET"
    pause_enter
    return
  fi
  printf "%s[INFO]%s Optional TensorFlow (advanced auto-tagging, similarity embeddings, deep classifiers).\n" "$C_CYN" "$C_RESET"
  printf "Estimated extra download: ~%s MB. Install now in the ML venv? [y/N]: " "$ML_PKG_TF_MB"
  read -r tfa
  case "$tfa" in
    y|Y)
      maybe_activate_ml_env "Optional TensorFlow" 1 1
      if python3 - <<'PY' 2>/dev/null
import tensorflow as tf  # noqa
print("TF_OK")
PY
      then
        printf "%s[OK]%s TensorFlow available in venv.\n" "$C_GRN" "$C_RESET"
      else
        printf "%s[ERR]%s TensorFlow could not be imported (check installation).\n" "$C_RED" "$C_RESET"
      fi
      ;;
    *)
      printf "%s[INFO]%s Installation cancelled.\n" "$C_CYN" "$C_RESET"
      ;;
  esac
  printf "Possible future modules with TF:\n"
  printf " - Audio auto-tagging with pretrained embeddings.\n"
  printf " - Audio similarity detection (duplicate suggestions by sound).\n"
  printf " - Deep classifiers for advanced cleaning/organization.\n"
  pause_enter
}

submenu_T_tensorflow_lab() {
  while true; do
    clear
    print_header
    printf "%s=== TensorFlow Lab (requires TF installed) ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s[INFO]%s Deps: python3 + tensorflow + tensorflow_hub + soundfile + numpy. Limit: ~150 files; similarity uses threshold >=0.60 (top 200 pairs).\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Audio auto-tagging (embeddings)\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Content similarity (audio)\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Repeated fragments/loops detection\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s Suspicious classifier (trash/silence)\n" "$C_YLW" "$C_RESET"
    printf "%s5)%s Estimate loudness (normalization plan)\n" "$C_YLW" "$C_RESET"
    printf "%s6)%s Auto-segmentation (preliminary cues)\n" "$C_YLW" "$C_RESET"
    printf "%s7)%s Cross-platform matching (smart relink)\n" "$C_YLW" "$C_RESET"
    printf "%s8)%s Video auto-tagging (keyframes)\n" "$C_YLW" "$C_RESET"
    printf "%s9)%s Music Tagging (multi-label, TF Hub model)\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Back\n" "$C_YLW" "$C_RESET"
    printf "%sOption:%s " "$C_BLU" "$C_RESET"
    read -r top
    case "$top" in
      1)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML is disabled (use 63 to enable).\n" "$C_YLW" "$C_RESET"
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
          printf "%s[ERR]%s TensorFlow not available. Install with option 64.\n" "$C_RED" "$C_RESET"
          pause_enter; continue
        fi
        printf "Modelo (1=YAMNet, 2=MusicTag NNFP, 3=VGGish fallback) [1]: "
        read -r model_sel
        [ -z "$model_sel" ] && model_sel=1
        printf "%s[INFO]%s Auto-tagging (selected model: %s, max 150 files).\n" "$C_CYN" "$C_RESET" "$model_sel"
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
    print("[ERR] No audio files.")
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
print(f\"[OK] Auto-tagging {model_url}: {out}\")
PY
        rc=$?
        if [ "$rc" -ne 0 ]; then
          printf "%s[ERR]%s Could not generate auto-tagging (check TF/tf_hub/soundfile).\n" "$C_RED" "$C_RESET"
        else
          printf "%s[OK]%s Auto-tagging report: %s\n" "$C_GRN" "$C_RESET" "$out"
        fi
        pause_enter
        ;;
      2)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML is disabled (use 63 to enable).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Audio similarity" 1 1
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
          printf "%s[ERR]%s TensorFlow not available. Install with option 64.\n" "$C_RED" "$C_RESET"
          pause_enter; continue
        fi
        printf "Modelo (1=YAMNet, 2=MusicTag NNFP, 3=VGGish, 4=Musicnn) [1]: "
        read -r model_sel
        [ -z "$model_sel" ] && model_sel=1
        printf "%s[INFO]%s Audio similarity (model %s, max 150 files, threshold 0.60, top 200 pairs).\n" "$C_CYN" "$C_RESET" "$model_sel"
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
    print("[ERR] Too few files for similarity.")
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
    print("[ERR] Failed to generate embeddings (check dependencies).")
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

print(f\"[OK] Report: {report_path}\")
print(f\"[OK] Plan: {plan_path}\")
PY
        rc=$?
        if [ "$rc" -ne 0 ]; then
          printf "%s[ERR]%s Could not generate similarity (check TF/tf_hub/soundfile). RC=%s\n" "$C_RED" "$C_RESET" "$rc"
        else
          printf "%s[OK]%s TF similarity report: %s\n" "$C_GRN" "$C_RESET" "$out"
          printf "%s[OK]%s TF similarity plan: %s\n" "$C_GRN" "$C_RESET" "$plan"
        fi
        pause_enter
        ;;
      3)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML is disabled (use 63 to enable).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Loops/Fragments" 1 1
        out="$REPORTS_DIR/tf_loops_report.tsv"
        printf "%s[INFO]%s Loop detection placeholder (needs TF + future model).\n" "$C_CYN" "$C_RESET"
        find "$BASE_PATH" -type f -iname "*.wav" 2>/dev/null | head -50 >"$STATE_DIR/tf_loops_list.tmp"
        >"$out"
        while IFS= read -r f; do
          printf "%s\t%s\n" "$f" "loop_check_pending" >>"$out"
        done <"$STATE_DIR/tf_loops_list.tmp"
        rm -f "$STATE_DIR/tf_loops_list.tmp"
        printf "%s[OK]%s Placeholder report: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      4)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML is disabled (use 63 to enable).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Suspects" 1 1
        out="$REPORTS_DIR/tf_suspect_audio.tsv"
        printf "%s[INFO]%s Suspicious classifier placeholder (needs TF future model).\n" "$C_CYN" "$C_RESET"
        find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.wav" \) 2>/dev/null | head -100 >"$STATE_DIR/tf_suspect_list.tmp"
        >"$out"
        while IFS= read -r f; do
          printf "%s\t%s\n" "$f" "score_pending" >>"$out"
        done <"$STATE_DIR/tf_suspect_list.tmp"
        rm -f "$STATE_DIR/tf_suspect_list.tmp"
        printf "%s[OK]%s Placeholder report: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      5)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML is disabled (use 63 to enable).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Loudness" 1 1
        out="$REPORTS_DIR/tf_loudness_plan.tsv"
        printf "%s[INFO]%s Loudness estimation placeholder (LUFS) for normalization plan.\n" "$C_CYN" "$C_RESET"
        find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.wav" \) 2>/dev/null | head -100 >"$STATE_DIR/tf_loud_list.tmp"
        >"$out"
        while IFS= read -r f; do
          printf "%s\t%s\t%s\n" "$f" "lufs_pending" "gain_pending" >>"$out"
        done <"$STATE_DIR/tf_loud_list.tmp"
        rm -f "$STATE_DIR/tf_loud_list.tmp"
        printf "%s[OK]%s Placeholder plan: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      6)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML is disabled (use 63 to enable).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Auto-cues" 1 1
        out="$REPORTS_DIR/tf_autocues.tsv"
        printf "%s[INFO]%s Auto-segmentation placeholder (onsets/beat) for preliminary cues.\n" "$C_CYN" "$C_RESET"
        find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.wav" \) 2>/dev/null | head -50 >"$STATE_DIR/tf_cues_list.tmp"
        >"$out"
        while IFS= read -r f; do
          printf "%s\t%s\t%s\n" "$f" "00:00:00" "cue_pending" >>"$out"
        done <"$STATE_DIR/tf_cues_list.tmp"
        rm -f "$STATE_DIR/tf_cues_list.tmp"
        printf "%s[OK]%s Cues placeholder plan: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      7)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML is disabled (use 63 to enable).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Cross-platform matching" 1 1
        out="$REPORTS_DIR/tf_crossplatform_matching.tsv"
        printf "%s[INFO]%s Cross-platform matching placeholder (embeddings for smart relink).\n" "$C_CYN" "$C_RESET"
        printf "%s\t%s\t%s\n" "track_a" "track_b" "score_pending" >"$out"
        printf "%s[OK]%s Placeholder report: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      8)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML is disabled (use 63 to enable).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Video tagging" 1 1
        out="$REPORTS_DIR/tf_video_autotag.tsv"
        printf "%s[INFO]%s Video auto-tagging placeholder (keyframes/future classification).\n" "$C_CYN" "$C_RESET"
        find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" \) 2>/dev/null | head -50 >"$STATE_DIR/tf_video_list.tmp"
        >"$out"
        while IFS= read -r f; do
          printf "%s\t%s\n" "$f" "tags_pending" >>"$out"
        done <"$STATE_DIR/tf_video_list.tmp"
        rm -f "$STATE_DIR/tf_video_list.tmp"
        printf "%s[OK]%s Placeholder report: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      9)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML is disabled (use 63 to enable).\n" "$C_YLW" "$C_RESET"
          pause_enter; continue
        fi
        maybe_activate_ml_env "TF Music Tagging" 1 1
        out="$REPORTS_DIR/tf_music_tagging.tsv"
        printf "%s[INFO]%s Music tagging multi-label (tries TF Hub model; top3 labels per file, max 150).\n" "$C_CYN" "$C_RESET"
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
    print("[ERR] No audio files found.")
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
    print("[ERR] Could not load TF Hub model (music tagging/vggish).")
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
          printf "%s[ERR]%s Could not generate music tagging (check TF/tf_hub/soundfile). RC=%s\n" "$C_RED" "$C_RESET" "$rc"
        else
          printf "%s[OK]%s Music tagging TSV: %s\n" "$C_GRN" "$C_RESET" "$out"
        fi
        pause_enter
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
  printf "%s[INFO]%s LUFS/normalization plan (analysis only, no audio modification).\n" "$C_CYN" "$C_RESET"
  out="$REPORTS_DIR/audio_lufs_plan.tsv"
  printf "Scanning (mp3/wav/flac/m4a)...\n"
  BASE="$BASE_PATH" OUT="$out" python3 - <<'PY'
import os, sys, pathlib
try:
    import pyloudnorm as pyln
    import soundfile as sf
except Exception:
    sys.exit(1)

base = pathlib.Path(os.environ.get("BASE") or ".")
out = pathlib.Path(os.environ["OUT"])
audio_exts = {".mp3", ".wav", ".flac", ".m4a", ".aiff", ".aif"}
meter = pyln.Meter(44100)
rows = []
for p in base.rglob("*"):
    if p.suffix.lower() in audio_exts and p.is_file():
        try:
            data, sr = sf.read(p)
            if data.ndim > 1:
                data = data.mean(axis=1)
            loud = meter.integrated_loudness(data)
            rows.append((str(p), loud))
        except Exception:
            continue
    if len(rows) >= 200:
        break

with out.open("w", encoding="utf-8") as f:
    f.write("path\tlufs\tsugerencia_gain_db\n")
    for path, lufs in rows:
        target = -14.0
        gain = target - lufs
        f.write(f"{path}\t{lufs:.2f}\t{gain:.2f}\n")

print(f"[OK] Plan LUFS: {out}")
PY
  rc=$?
  if [ "$rc" -ne 0 ]; then
    printf "%s[ERR]%s Requires python3 + pyloudnorm + soundfile.\n" "$C_RED" "$C_RESET"
  else
    printf "%s[OK]%s Plan LUFS generado: %s\n" "$C_GRN" "$C_RESET" "$out"
  fi
  pause_enter
}

action_audio_cues_onsets() {
  print_header
  printf "%s[INFO]%s Auto-cues por onsets (librosa; plan TSV).\n" "$C_CYN" "$C_RESET"
  out="$REPORTS_DIR/auto_cues_onsets.tsv"
  BASE="$BASE_PATH" OUT="$out" python3 - <<'PY'
import os, sys, pathlib
try:
    import librosa
except Exception:
    sys.exit(1)

base = pathlib.Path(os.environ.get("BASE") or ".")
out = pathlib.Path(os.environ["OUT"])
audio_exts = {".mp3", ".wav", ".flac", ".m4a", ".aiff", ".aif"}
rows = []
for p in base.rglob("*"):
    if p.suffix.lower() in audio_exts and p.is_file():
        try:
            y, sr = librosa.load(p, sr=44100, mono=True, duration=180)
            onsets = librosa.onset.onset_detect(y=y, sr=sr, units="time")
            if onsets.size == 0:
                continue
            first = onsets[0]
            rows.append((str(p), first))
        except Exception:
            continue
    if len(rows) >= 200:
        break

with out.open("w", encoding="utf-8") as f:
    f.write("path\tcue_sec\n")
    for path, t in rows:
        f.write(f"{path}\t{t:.2f}\n")

print(f"[OK] Auto-cues: {out}")
PY
  rc=$?
  if [ "$rc" -ne 0 ]; then
    printf "%s[ERR]%s Requires python3 + librosa.\n" "$C_RED" "$C_RESET"
  else
    printf "%s[OK]%s Auto-cues generado: %s\n" "$C_GRN" "$C_RESET" "$out"
  fi
  pause_enter
}

submenu_profiles_manager() {
  while true; do
    clear
    print_header
    printf "%s=== Profiles Manager ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Save current profile\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Load profile\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s List profiles\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s Delete profile\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Back\n" "$C_YLW" "$C_RESET"
    printf "%sOption:%s " "$C_BLU" "$C_RESET"
    read -r pop
    case "$pop" in
      1)
        printf "Profile name (e.g., main, ext_disk): "
        read -r pname
        [ -z "$pname" ] && { printf "%s[WARN]%s Empty name.\n" "$C_YLW" "$C_RESET"; pause_enter; continue; }
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
        printf "%s[OK]%s Profile saved: %s\n" "$C_GRN" "$C_RESET" "$pfile"
        pause_enter
        ;;
      2)
        mkdir -p "$PROFILES_DIR"
        printf "%s[INFO]%s Profiles in %s:\n" "$C_CYN" "$C_RESET" "$PROFILES_DIR"
        ls -1 "$PROFILES_DIR" 2>/dev/null | sed 's/\\.conf$//' || true
        printf "Profile name to load (ENTER to cancel): "
        read -r pname
        [ -z "$pname" ] && { printf "%s[INFO]%s Cancelled.\n" "$C_CYN" "$C_RESET"; pause_enter; continue; }
        pfile="$PROFILES_DIR/${pname}.conf"
        if [ ! -f "$pfile" ]; then
          printf "%s[ERR]%s Does not exist: %s\n" "$C_RED" "$C_RESET" "$pfile"
          pause_enter
          continue
        fi
        # shellcheck disable=SC1090
        . "$pfile"
        init_paths
        save_conf
        printf "%s[OK]%s Profile loaded: %s\n" "$C_GRN" "$C_RESET" "$pfile"
        pause_enter
        ;;
      3)
        printf "%s[INFO]%s Profiles in %s:\n" "$C_CYN" "$C_RESET" "$PROFILES_DIR"
        ls -1 "$PROFILES_DIR" 2>/dev/null || printf "(empty)\n"
        pause_enter
        ;;
      4)
        printf "Profile name to delete: "
        read -r pname
        pfile="$PROFILES_DIR/${pname}.conf"
        if [ ! -f "$pfile" ]; then
          printf "%s[ERR]%s Does not exist: %s\n" "$C_RED" "$C_RESET" "$pfile"
          pause_enter
          continue
        fi
        rm -f "$pfile" 2>/dev/null || true
        printf "%s[OK]%s Deleted: %s\n" "$C_GRN" "$C_RESET" "$pfile"
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
  printf "%s[INFO]%s Organize audio by TAGS -> TSV plan: %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null | while IFS= read -r f; do
    printf "%s\tGENRE_UNKNOWN\n" "$f" >>"$out"
  done
  printf "%s[OK]%s TAGS plan generated.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_31_report_tags() {
  print_header
  plan="$PLANS_DIR/audio_by_tags_plan.tsv"
  out="$REPORTS_DIR/audio_tags_report.tsv"
  printf "%s[INFO]%s Audio tags report -> %s\n" "$C_CYN" "$C_RESET" "$out"
  if [ ! -f "$plan" ]; then
    printf "%s[WARN]%s TAGS plan missing, generating first.\n" "$C_YLW" "$C_RESET"
    action_30_plan_tags
  fi
  awk -F'\t' '{c[$2]++} END {for (g in c){printf "%s\t%d\n", g, c[g]}}' "$plan" >"$out"
  printf "%s[OK]%s Report generated.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_32_serato_video_report() {
  print_header
  out="$REPORTS_DIR/serato_video_report.tsv"
  printf "%s[INFO]%s Serato Video REPORT -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" \) 2>/dev/null | while IFS= read -r f; do
    printf "%s\n" "$f" >>"$out"
  done
  printf "%s[OK]%s Video report generated.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_33_serato_video_prep() {
  print_header
  out="$PLANS_DIR/serato_video_transcode_plan.tsv"
  printf "%s[INFO]%s Serato Video PREP (transcode plan) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" \) 2>/dev/null | while IFS= read -r f; do
    printf "%s\tTRANSCODE_H264\n" "$f" >>"$out"
  done
  printf "%s[OK]%s Transcode plan generated.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_34_normalize_names() {
  print_header
  out="$PLANS_DIR/normalize_names_plan.tsv"
  printf "%s[INFO]%s Normalize names (TSV plan) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  find "$BASE_PATH" -type f 2>/dev/null | while IFS= read -r f; do
    base="$(basename "$f")"
    dir="$(dirname "$f")"
    new="$dir/$base"
    printf "%s\t%s\n" "$f" "$new" >>"$out"
  done
  printf "%s[OK]%s Rename plan generated.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_35_samples_by_type() {
  print_header
  out="$PLANS_DIR/samples_by_type_plan.tsv"
  printf "%s[INFO]%s Organize samples by TYPE (TSV plan) -> %s\n" "$C_CYN" "$C_RESET" "$out"
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
  printf "%s[OK]%s Samples-by-type plan generated.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

submenu_36_web_clean() {
  while true; do
    clear
    printf "%s=== Clean WEB (submenu) ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Show whitelist summary\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Back\n" "$C_YLW" "$C_RESET"
    printf "%sOption:%s " "$C_BLU" "$C_RESET"
    read -r wop
    case "$wop" in
      1)
        printf "%s[INFO]%s Basic whitelist (allowed domains):\n" "$C_CYN" "$C_RESET"
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
  printf "%s[INFO]%s Simple WEB Whitelist Manager.\n" "$C_CYN" "$C_RESET"
  printf "Whitelist fixed in this version.\n"
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
  printf "%s[OK]%s Playlists cleaned.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_39_clean_web_tags() {
  print_header
  out="$PLANS_DIR/clean_web_tags_plan.tsv"
  printf "%s[INFO]%s Clean WEB in TAGS (plan) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null | while IFS= read -r f; do
    printf "%s\tCLEAN_WEB_TAGS\n" "$f" >>"$out"
  done
  printf "%s[OK]%s WEB cleanup in TAGS plan generated.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_40_smart_analysis() {
  maybe_activate_ml_env "Option 40 (Smart Analysis)"
  print_header
  printf "%s[INFO]%s 🧠 DEEP-THINKING: Smart Library Analysis\n" "$C_CYN" "$C_RESET"

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
    "9 -> 10 (hash + exact duplicates)",
    "27 (quick snapshot)",
    "39 (clean URLs in tags)",
    "8 (quick backup)"
  ]
}
EOF

  printf "%s[OK]%s Analysis generated: %s\n" "$C_GRN" "$C_RESET" "$analysis_report"
  pause_enter
}

action_41_ml_predictor() {
  maybe_activate_ml_env "Option 41 (ML Predictor)"
  print_header
  printf "%s[INFO]%s 🤖 MACHINE LEARNING: Issue Predictor\n" "$C_CYN" "$C_RESET"

  local ts prediction_report lines
  ts=$(date +%s)
  prediction_report="$REPORTS_DIR/ml_predictions_${ts}.tsv"
  printf "File\tProblem\tConfidence\tAction\n" >"$prediction_report"

  find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.m4a" \) 2>/dev/null | head -50 | while IFS= read -r f; do
    fname=$(basename "$f")
    size=$({ stat -f %z "$f" 2>/dev/null || echo 0; } | tr -d ' ')
    if [ "${#fname}" -gt 80 ]; then
      printf "%s\tName too long\t75%%\tReview option 34\n" "$f" >>"$prediction_report"
    fi
    if [ "$size" -eq 0 ]; then
      printf "%s\tEmpty file\t90%%\tReplace or delete\n" "$f" >>"$prediction_report"
    fi
  done

  lines=$(wc -l <"$prediction_report" | tr -d ' ')
  if [ "$lines" -le 1 ]; then
    printf "N/A\tNo simple findings\t100%%\tOK\n" >>"$prediction_report"
  fi

  printf "%s[OK]%s Predictions generated: %s\n" "$C_GRN" "$C_RESET" "$prediction_report"
  pause_enter
}

action_42_efficiency_optimizer() {
  maybe_activate_ml_env "Option 42 (Optimizer)"
  print_header
  printf "%s[INFO]%s ⚡ DEEP-THINKING: Efficiency Optimizer\n" "$C_CYN" "$C_RESET"

  local ts plan dupe_info
  ts=$(date +%s)
  plan="$PLANS_DIR/efficiency_${ts}.tsv"
  dupe_info="Generate plan with option 10"
  if [ -f "$PLANS_DIR/dupes_plan.tsv" ]; then
    dupe_info=$(awk -F'\t' '$2=="QUARANTINE"{c++} END {if (c=="") c=0; print c " candidates"}' "$PLANS_DIR/dupes_plan.tsv")
  fi

  printf "Area\tAction\tEstimated_Benefit\tReference\n" >"$plan"
  printf "Duplicates\tReview/remove duplicates\tHigh (%s)\tOption 10\n" "$dupe_info" >>"$plan"
  printf "Metadata\tClean URLs in tags\tMedium\tOption 39\n" >>"$plan"
  printf "Backup\tCheck recent backup\tMedium\tOption 8\n" >>"$plan"
  printf "Snapshot\tQuick hash for control\tLow\tOption 27\n" >>"$plan"

  printf "%s[OK]%s Efficiency plan generated: %s\n" "$C_GRN" "$C_RESET" "$plan"
  pause_enter
}

action_43_smart_workflow() {
  maybe_activate_ml_env "Option 43 (Smart workflow)"
  print_header
  printf "%s[INFO]%s 🚀 DEEP-THINKING: Smart Workflow\n" "$C_CYN" "$C_RESET"

  local workflow="$PLANS_DIR/workflow_$(date +%s).txt"
  cat >"$workflow" <<'EOF'
SMART WORKFLOW:
1. Option 40: Analysis (5 min)
2. Option 41: Predictor (10 min)
3. Option 42: Optimizer (5 min)
4. Option 8: Backup (30 min)
5. Option 10: Remove duplicates (45 min)
6. Option 39: Clean metadata (30 min)
7. Option 8: Final backup (30 min)
Total time: ~2-3 hours
EOF

  printf "%s[OK]%s Workflow generated: %s\n" "$C_GRN" "$C_RESET" "$workflow"
  pause_enter
}

action_44_integrated_dedup() {
  maybe_activate_ml_env "Option 44 (Integrated dedup)"
  print_header
  printf "%s[INFO]%s 🔄 DEEP-THINKING: Integrated Deduplication\n" "$C_CYN" "$C_RESET"

  local dedup_plan="$PLANS_DIR/integrated_dedup_$(date +%s).tsv"
  local dupes_plan="$PLANS_DIR/dupes_plan.tsv"
  local exact=0
  if [ -f "$dupes_plan" ]; then
    exact=$(awk -F'\t' '$2=="QUARANTINE"{c++} END {if (c=="") c=0; print c}' "$dupes_plan")
  fi

  printf "Type\tCount\tNote\n" >"$dedup_plan"
  printf "Exact (hash)\t%s\tGenerated with option 10\n" "$exact" >>"$dedup_plan"
  printf "Fuzzy (name/size)\t0\tUse submenu D2 to detect\n" >>"$dedup_plan"
  printf "Action\tRecommendation\tNext_Step\n" >>"$dedup_plan"
  printf "Review\tMove extras to quarantine\tOption 11\n" >>"$dedup_plan"

  printf "%s[OK]%s Integrated dedup plan: %s\n" "$C_GRN" "$C_RESET" "$dedup_plan"
  pause_enter
}

action_45_ml_organization() {
  maybe_activate_ml_env "Option 45 (ML Organization)"
  print_header
  printf "%s[INFO]%s 📂 MACHINE LEARNING: Automatic Organization\n" "$C_CYN" "$C_RESET"

  local org_plan="$PLANS_DIR/ml_organization_$(date +%s).tsv"
  printf "File\tSuggested_Folder\tConfidence\n" >"$org_plan"

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

  printf "%s[OK]%s ML organization plan: %s\n" "$C_GRN" "$C_RESET" "$org_plan"
  pause_enter
}

action_46_metadata_harmonizer() {
  maybe_activate_ml_env "Option 46 (Metadata harmonizer)"
  print_header
  printf "%s[INFO]%s 🎵 DEEP-THINKING: Metadata Harmonizer\n" "$C_CYN" "$C_RESET"

  local harmony_plan="$PLANS_DIR/metadata_harmony_$(date +%s).tsv"
  printf "Aspect\tDetail\tAction\n" >"$harmony_plan"
  printf "Tags/URLs\tDetect and clean http(s) in comments\tOption 39\n" >>"$harmony_plan"
  printf "Empty fields\tFill artist/title in batch\tOption 31\n" >>"$harmony_plan"
  printf "Consistency\tReview casing in names\tOption 34\n" >>"$harmony_plan"

  printf "%s[OK]%s Harmonization plan: %s\n" "$C_GRN" "$C_RESET" "$harmony_plan"
  pause_enter
}

action_47_predictive_backup() {
  maybe_activate_ml_env "Option 47 (Predictive backup)"
  print_header
  printf "%s[INFO]%s 🛡️ MACHINE LEARNING: Predictive Backup\n" "$C_CYN" "$C_RESET"

  local backup_plan="$PLANS_DIR/predictive_backup_$(date +%s).txt"
  cat >"$backup_plan" <<'EOF'
PREDICTIVE BACKUP - SMART STRATEGY:

1) Risk analysis: Serato/Traktor/Rekordbox/Ableton metadata = critical.
2) Suggested frequency: weekly (daily if shows).
3) Recommended flow:
   - Option 8: Incremental backup
   - Option 27: Quick integrity snapshot
   - Option 7: Copy _Serato_ and _Serato_Backup
4) Next window: early morning (03:00–05:00) to avoid locks.
EOF

  printf "%s[OK]%s Predictive backup plan: %s\n" "$C_GRN" "$C_RESET" "$backup_plan"
  pause_enter
}

action_48_cross_platform_sync() {
  maybe_activate_ml_env "Option 48 (Cross-platform sync)"
  print_header
  printf "%s[INFO]%s 🌐 DEEP-THINKING: Cross-Platform Sync\n" "$C_CYN" "$C_RESET"

  local sync_plan="$PLANS_DIR/cross_platform_$(date +%s).txt"
  local serato_status="NO"
  local rekordbox_hint="NO"
  local traktor_hint="NO"
  local ableton_hint="NO"

  [ -d "$BASE_PATH/_Serato_" ] && serato_status="OK"
  if find "$BASE_PATH" -maxdepth 4 -type f -iname "*.xml" 2>/dev/null | head -1 | grep -qi rekordbox; then
    rekordbox_hint="Detected"
  fi
  if find "$BASE_PATH" -maxdepth 4 -type f -iname "*collection*.nml" 2>/dev/null | head -1 >/dev/null; then
    traktor_hint="Detected"
  fi
  if find "$BASE_PATH" -maxdepth 4 -type f -iname "*.als" 2>/dev/null | head -1 >/dev/null; then
    ableton_hint="Detected"
  fi

  cat >"$sync_plan" <<EOF
SMART CROSS-PLATFORM SYNC:
- Serato: $serato_status
- Rekordbox XML: $rekordbox_hint
- Traktor NML: $traktor_hint
- Ableton ALS: $ableton_hint

Recommended actions:
1. Consolidate cues/notes into a master TSV.
2. Run option 39 to clean URLs before sync.
3. Run option 8 for pre/post sync backup.
EOF

  printf "%s[OK]%s Sync plan: %s\n" "$C_GRN" "$C_RESET" "$sync_plan"
  pause_enter
}

submenu_ableton_tools() {
  while true; do
    clear
    print_header
    printf "%s=== Ableton Tools ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Quick report of .als sets (samples/plugins)\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Back\n" "$C_YLW" "$C_RESET"
    printf "%sOption:%s " "$C_BLU" "$C_RESET"
    read -r aop
    case "$aop" in
      1)
        clear
        root="${ABLETON_ROOT:-$BASE_PATH}"
        printf "Ableton root (drag & drop; ENTER uses %s; scans .als): " "$root"
        read -r r
        [ -n "$r" ] && root="$r"
        if [ ! -d "$root" ]; then
          printf "%s[ERR]%s Invalid path.\n" "$C_RED" "$C_RESET"
          pause_enter
          continue
        fi
        if ! command -v python3 >/dev/null 2>&1; then
          printf "%s[ERR]%s python3 not available to analyze .als\n" "$C_RED" "$C_RESET"
          pause_enter
          continue
        fi
        out="$REPORTS_DIR/ableton_sets_report.tsv"
        printf "%s[INFO]%s Scanning .als in %s\n" "$C_CYN" "$C_RESET" "$root"
        total=$(find "$root" -type f -iname "*.als" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$total" -eq 0 ]; then
          printf "%s[WARN]%s No .als found\n" "$C_YLW" "$C_RESET"
          pause_enter
          continue
        fi
        count=0
        printf "Set\tSampleRefs\tPluginRefs\tNote\n" >"$out"
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
        printf "%s[OK]%s Ableton report: %s\n" "$C_GRN" "$C_RESET" "$out"
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
    printf "%s=== Cues/Playlists Importers ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Parse Rekordbox XML -> dj_cues.tsv\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Traktor NML summary (tracks/cues)\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Back\n" "$C_YLW" "$C_RESET"
    printf "%sOption (uses python3 if available):%s " "$C_BLU" "$C_RESET"
    read -r iop
    case "$iop" in
      1)
        clear
        rk="${REKORDBOX_XML:-}"
        printf "Rekordbox XML path (drag & drop, ENTER uses %s): " "${rk:-<empty>}"
        read -r r
        [ -n "$r" ] && rk="$r"
        if [ -z "$rk" ] || [ ! -f "$rk" ]; then
          printf "%s[ERR]%s Invalid XML.\n" "$C_RED" "$C_RESET"
          pause_enter
          continue
        fi
        if ! command -v python3 >/dev/null 2>&1; then
          printf "%s[ERR]%s python3 not available to parse XML.\n" "$C_RED" "$C_RESET"
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
        printf "%s[OK]%s dj_cues.tsv generated: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      2)
        clear
        if ! command -v python3 >/dev/null 2>&1; then
          printf "%s[ERR]%s python3 not available to parse NML.\n" "$C_RED" "$C_RESET"
          pause_enter
          continue
        fi
        printf "Search NML under BASE_PATH (ENTER) or provide folder (drag & drop): "
        read -e -r nml_root
        [ -z "$nml_root" ] && nml_root="$BASE_PATH"
        mapfile -t nml_list < <(find "$nml_root" -maxdepth 4 -type f -iname "*.nml" 2>/dev/null)
        if [ "${#nml_list[@]}" -eq 0 ]; then
          printf "%s[WARN]%s No NML files found in %s\n" "$C_YLW" "$C_RESET" "$nml_root"
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
        printf "%s[OK]%s Traktor summary: %s\n" "$C_GRN" "$C_RESET" "$out"
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
  maybe_activate_ml_env "Option 49 (Advanced analysis)"
  print_header
  printf "%s[INFO]%s 🔬 DEEP-THINKING: Deep Advanced Analysis\n" "$C_CYN" "$C_RESET"

  local ts advanced total_files audio_files
  ts=$(date +%s)
  advanced="$REPORTS_DIR/advanced_analysis_${ts}.json"
  total_files=$(find "$BASE_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
  audio_files=$(find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.m4a" \) 2>/dev/null | wc -l | tr -d ' ')
  : "${total_files:=0}"
  : "${audio_files:=0}"

  cat >"$advanced" <<EOF
{
  "analysis_type": "ADVANCED_DEEP",
  "base_path": "$BASE_PATH",
  "scores": {
    "organization": "medium",
    "risk": "medium-high"
  },
  "totals": {
    "files": $total_files,
    "audio_files": $audio_files
  },
  "priority_actions": [
    "10 (Exact duplicates)",
    "40 (Smart Analysis)",
    "39 (Clean WEB)",
    "34 (Normalize names)"
  ]
}
EOF

  printf "%s[OK]%s Advanced analysis: %s\n" "$C_GRN" "$C_RESET" "$advanced"
  pause_enter
}

action_50_integration_engine() {
  maybe_activate_ml_env "Option 50 (Integration engine)"
  print_header
  printf "%s[INFO]%s ⚙️ DEEP-THINKING: Integration Engine\n" "$C_CYN" "$C_RESET"

  local integration="$PLANS_DIR/integration_engine_$(date +%s).txt"
  cat >"$integration" <<'EOF'
SMART INTEGRATION ENGINE:
- 9 + 10: Hash + duplicates plan.
- 34 + 39: Normalize names + clean URLs.
- 8 + 27: Backup + integrity snapshot.
- 40 + 41 + 42: Analysis + predictor + optimizer.

Suggested flow:
40 (Analysis) -> 41 (Predictor) -> 10 (Dupes) -> 39 (Metadata) -> 8 (Backup)
EOF

  printf "%s[OK]%s Integration engine: %s\n" "$C_GRN" "$C_RESET" "$integration"
  pause_enter
}

action_51_adaptive_recommendations() {
  maybe_activate_ml_env "Option 51 (Adaptive recommendations)"
  print_header
  printf "%s[INFO]%s 💡 MACHINE LEARNING: Adaptive Recommendations\n" "$C_CYN" "$C_RESET"

  local recommendations="$REPORTS_DIR/adaptive_recommendations_$(date +%s).txt"
  local dupes_pending="Generate plan (option 10)"
  if [ -f "$PLANS_DIR/dupes_plan.tsv" ]; then
    dupes_pending=$(awk -F'\t' '$2=="QUARANTINE"{c++} END {if (c=="") c=0; print c " pending"}' "$PLANS_DIR/dupes_plan.tsv")
  fi

  cat >"$recommendations" <<EOF
ADAPTIVE RECOMMENDATIONS (AI-ASSISTED):

URGENT (Today):
- Run option 8: Create backup
- Run option 10: Remove duplicates (${dupes_pending})

IMPORTANT (This week):
- Run option 34: Normalize names
- Run option 39: Clean web metadata

NORMAL (This month):
- Run option 46: Harmonize metadata
- Run option 48: Check cross-platform sync
EOF

  printf "%s[OK]%s Recommendations: %s\n" "$C_GRN" "$C_RESET" "$recommendations"
  pause_enter
}

action_52_automated_cleanup_pipeline() {
  maybe_activate_ml_env "Option 52 (Automatic pipeline)"
  print_header
  printf "%s[INFO]%s 🔄 DEEP-THINKING: Automated Cleanup Pipeline\n" "$C_CYN" "$C_RESET"

  local pipeline="$PLANS_DIR/cleanup_pipeline_$(date +%s).txt"
  cat >"$pipeline" <<'EOF'
AUTOMATED CLEANUP PIPELINE:

PHASE 1: Analysis (Option 40)
PHASE 2: Predictor (Option 41)
PHASE 3: Initial backup (Option 8)
PHASE 4: Remove exact duplicates (Option 10)
PHASE 5: Clean web metadata (Option 39)
PHASE 6: Normalize names (Option 34)
PHASE 7: Final backup (Option 8)
PHASE 8: Quick snapshot (Option 27)
EOF

  printf "%s[OK]%s Cleanup pipeline: %s\n" "$C_GRN" "$C_RESET" "$pipeline"
  pause_enter
}

# === Automated chains (combine existing actions) ===

chain_run_header() {
  print_header
  printf "%s[INFO]%s Running chain: %s\n" "$C_CYN" "$C_RESET" "$1"
}

chain_1_backup_snapshot() {
  chain_run_header "Safe backup + snapshot (8 -> 27)"
  action_8_backup_dj
  action_27_snapshot
  printf "%s[OK]%s Chain done: backups and snapshot.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_2_dedup_quarantine() {
  chain_run_header "Exact dedup + quarantine (10 -> 11)"
  action_10_dupes_plan
  action_11_quarantine_from_plan
  printf "%s[OK]%s Chain done: duplicates quarantined.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_3_metadata_names() {
  chain_run_header "Metadata + names cleanup (39 -> 34)"
  action_39_clean_web_tags
  action_34_normalize_names
  printf "%s[OK]%s Chain done: tags cleaned and names normalized.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_4_health_scan() {
  chain_run_header "Media health quick scan (18 -> 14 -> 15)"
  action_18_rescan_intelligent
  action_14_playlists_per_folder
  action_15_relink_helper
  printf "%s[OK]%s Chain done: catalog, playlists, relink TSV.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_5_show_prep() {
  chain_run_header "Show prep (8 -> 27 -> 10 -> 11 -> 14 -> 8)"
  action_8_backup_dj
  action_27_snapshot
  action_10_dupes_plan
  action_11_quarantine_from_plan
  action_14_playlists_per_folder
  action_8_backup_dj
  printf "%s[OK]%s Chain done: pre/post backup, duplicates, playlists.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_6_media_integrity() {
  chain_run_header "Media integrity + corrupts (13 -> 18)"
  action_13_ffprobe_report
  action_18_rescan_intelligent
  printf "%s[OK]%s Chain done: corrupt report and updated rescan.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_7_efficiency_plan() {
  chain_run_header "Efficiency plan (42 -> 44 -> 43)"
  action_42_efficiency_optimizer
  action_44_integrated_dedup
  action_43_smart_workflow
  printf "%s[OK]%s Chain done: efficiency/dedup/workflow plans.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_8_ml_org_basic() {
  chain_run_header "ML org basics (45 -> 46)"
  action_45_ml_organization
  action_46_metadata_harmonizer
  printf "%s[OK]%s Chain done: ML org + harmonizer.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_9_predictive_backup() {
  chain_run_header "Predictive backup (47 -> 8 -> 27)"
  action_47_predictive_backup
  action_8_backup_dj
  action_27_snapshot
  printf "%s[OK]%s Chain done: plan + backup + snapshot.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_10_cross_sync() {
  chain_run_header "Cross-platform sync (48 -> 39 -> 8 -> 8)"
  action_48_cross_platform_sync
  action_39_clean_web_tags
  action_8_backup_dj
  action_8_backup_dj
  printf "%s[OK]%s Chain done: sync plan, metadata cleanup, backups.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_11_quick_diag() {
  chain_run_header "Quick diagnostics (1 -> 3 -> 4 -> 5)"
  action_1_status
  action_3_summary
  action_4_top_dirs
  action_5_top_files
  printf "%s[OK]%s Chain done: status, summary, top dirs/files.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_12_serato_health() {
  chain_run_header "Serato health (7 -> 59)"
  action_7_backup_serato
  action_state_health
  printf "%s[OK]%s Chain done: Serato backup and state health-check.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_13_hash_mirror_check() {
  chain_run_header "Hash + mirror check (9 -> 61)"
  action_9_hash_index
  action_mirror_integrity_check
  printf "%s[OK]%s Chain done: hash_index and mirror check.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_14_audio_prep() {
  chain_run_header "Audio prep (31 -> 66 -> 67)"
  action_31_report_tags
  action_audio_lufs_plan
  action_audio_cues_onsets
  printf "%s[OK]%s Chain done: tags report, LUFS plan, onset cues.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_15_integrity_audit() {
  chain_run_header "Integrity audit (6 -> 9 -> 27 -> 61)"
  action_6_scan_workspace
  action_9_hash_index
  action_27_snapshot
  action_mirror_integrity_check
  printf "%s[OK]%s Chain done: scan, hash_index, snapshot, mirror check.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_16_clean_backup() {
  chain_run_header "Cleanup + safe backup (39 -> 34 -> 10 -> 11 -> 8 -> 27)"
  action_39_clean_web_tags
  action_34_normalize_names
  action_10_dupes_plan
  action_11_quarantine_from_plan
  action_8_backup_dj
  action_27_snapshot
  printf "%s[OK]%s Chain done: metadata/name cleanup, dedup, backups, snapshot.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_17_sync_prep() {
  chain_run_header "Sync prep (18 -> 14 -> 48 -> 8 -> 27)"
  action_18_rescan_intelligent
  action_14_playlists_per_folder
  action_48_cross_platform_sync
  action_8_backup_dj
  action_27_snapshot
  printf "%s[OK]%s Chain done: rescan, playlists, sync, backup, snapshot.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_18_visual_health() {
  chain_run_header "Visual health (V2 -> V6 -> V8 -> V9 -> 8)"
  action_V2_visuals_inventory
  action_V6_visuals_ffprobe_report
  action_V8_visuals_hash_dupes
  action_V9_visuals_optimize_plan
  action_8_backup_dj
  printf "%s[OK]%s Chain done: inventory, ffprobe, visual dupes, optimize plan, backup.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_19_audio_advanced() {
  chain_run_header "Advanced audio organization (31 -> 30 -> 35 -> 45 -> 46)"
  action_31_report_tags
  action_30_plan_tags
  action_35_samples_by_type
  action_45_ml_organization
  action_46_metadata_harmonizer
  printf "%s[OK]%s Chain done: tags, genre plan, samples, ML org, harmonizer.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_20_serato_safe() {
  chain_run_header "Serato safety (7 -> 8 -> 59 -> 12 -> 47)"
  action_7_backup_serato
  action_8_backup_dj
  action_state_health
  action_12_quarantine_manager
  action_47_predictive_backup
  printf "%s[OK]%s Chain done: backups, health-check, quarantine review, predictive plan.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

chain_21_multidisk_dedup() {
  chain_run_header "Multi-disk dedup + mirror (9 -> 10 -> 44 -> 11 -> 61)"
  action_9_hash_index
  action_10_dupes_plan
  action_44_integrated_dedup
  action_11_quarantine_from_plan
  action_mirror_integrity_check
  printf "%s[OK]%s Chain done: hash, dupes plan, quarantine, mirror check.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_69_artist_pages() {
  print_header
  local artist_file="$CONFIG_DIR/artist_pages.tsv"
  default_val() {
    case "$1" in
      Short_Bio) echo "Short bio (1-2 lines)";;
      Long_Bio_URL) echo "https://drive.google.com/your_long_bio.pdf";;
      Press_Quotes) echo "\"Outlet\" - highlight quote";;
      Tech_Rider) echo "/path/to/Tech_Rider.pdf";;
      Stage_Plot) echo "/path/to/Stage_Plot.pdf";;
      DMX_Showfile) echo "/path/to/Showfile.dmx";;
      Ableton_Set) echo "/path/to/LiveSet.als";;
      OBS_Overlays) echo "/path/to/overlays/";;
      Website) echo "https://yourwebsite.com";;
      Linktree) echo "https://linktr.ee/your_user";;
      EPK_PDF) echo "https://drive.google.com/your_epk.pdf";;
      Press_Kit_Assets) echo "https://drive.google.com/presskit_folder";;
      Media_Drive) echo "https://drive.google.com/media_folder";;
      Artwork_Drive) echo "https://drive.google.com/artwork_folder";;
      Booking_Email) echo "booking@youremail.com";;
      Booking_Phone) echo "+1 000 000 0000";;
      Management) echo "Manager Name / email";;
      Label) echo "Your label or distributor";;
      Spotify) echo "https://open.spotify.com/artist/YOURID";;
      Apple_Music) echo "https://music.apple.com/artist/YOURID";;
      YouTube) echo "https://youtube.com/@your_user";;
      YouTube_Music) echo "https://music.youtube.com/channel/YOURID";;
      SoundCloud) echo "https://soundcloud.com/your_user";;
      Beatport) echo "https://www.beatport.com/artist/YOUR-NAME/ID";;
      Traxsource) echo "https://www.traxsource.com/artist/ID/your-name";;
      Bandcamp) echo "https://youruser.bandcamp.com";;
      Bandcamp_Merch) echo "https://youruser.bandcamp.com/merch";;
      Mixcloud) echo "https://www.mixcloud.com/your_user";;
      Audius) echo "https://audius.co/your_user";;
      Tidal) echo "https://tidal.com/browse/artist/ID";;
      Deezer) echo "https://www.deezer.com/artist/ID";;
      Amazon_Music) echo "https://music.amazon.com/artists/ID";;
      Shazam) echo "https://www.shazam.com/artist/ID";;
      JunoDownload) echo "https://www.junodownload.com/artists/Your+Name";;
      Pandora) echo "https://www.pandora.com/artist/YourName/ID";;
      Instagram) echo "https://instagram.com/your_user";;
      TikTok) echo "https://www.tiktok.com/@your_user";;
      Facebook) echo "https://facebook.com/your_user";;
      "Twitter/X") echo "https://twitter.com/your_user";;
      Threads) echo "https://www.threads.net/@your_user";;
      Resident_Advisor) echo "https://ra.co/dj/your_user";;
      Patreon) echo "https://www.patreon.com/your_user";;
      Twitch) echo "https://twitch.tv/your_user";;
      Discord) echo "https://discord.gg/LINK";;
      Telegram) echo "https://t.me/your_user";;
      WhatsApp_Community) echo "https://chat.whatsapp.com/LINK";;
      Merch_Store) echo "https://yourstore.com/your_user";;
      Boiler_Room) echo "https://boilerroom.tv/recording/your_set";;
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
  for p in "${platforms[@]}"; do
    if ! awk -F'\t' -v k="$p" '$1==k{found=1} END{exit !found}' "$artist_file" >/dev/null 2>&1; then
      printf "%s\t%s\n" "$p" "$(default_val "$p")" >>"$artist_file"
    fi
  done

  printf "%s[INFO]%s Artist profiles/links (edit or fill).\n" "$C_CYN" "$C_RESET"
  printf "File: %s\n\n" "$artist_file"
  if [ -s "$artist_file" ]; then
    awk -F'\t' '{printf "- %-18s %s\n",$1,$2}' "$artist_file"
  fi
  printf "\nEdit now? (y/N): "
  read -r ans
  case "$ans" in
    y|Y)
      tmp="$artist_file.tmp"
      : >"$tmp"
      for p in "${platforms[@]}"; do
        current=$(awk -F'\t' -v k="$p" '$1==k{print $2}' "$artist_file")
        def=$(default_val "$p")
        printf "%s (current: %s | default: %s): " "$p" "${current:-empty}" "${def:-empty}"
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
      printf "%s[OK]%s Saved to %s\n" "$C_GRN" "$C_RESET" "$artist_file"
      ;;
    *)
      printf "%s[INFO]%s No changes. You can edit the file manually.\n" "$C_CYN" "$C_RESET"
      ;;
  esac

  printf "\nExport to CSV/HTML/JSON in reports/? (y/N): "
  read -r exp
  case "$exp" in
    y|Y)
      local csv_out="$REPORTS_DIR/artist_pages.csv"
      local html_out="$REPORTS_DIR/artist_pages.html"
      local json_out="$REPORTS_DIR/artist_pages.json"
      if command -v python3 >/dev/null 2>&1; then
        if python3 - "$artist_file" "$csv_out" "$html_out" "$json_out" <<'PY'
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
        then
          printf "%s[OK]%s Exported to %s, %s and %s\n" "$C_GRN" "$C_RESET" "$csv_out" "$html_out" "$json_out"
        else
          printf "%s[WARN]%s Export failed (python3). Check console output.\n" "$C_YLW" "$C_RESET"
        fi
      else
        printf "%s[WARN]%s python3 not available; export manually.\n" "$C_YLW" "$C_RESET"
      fi
      ;;
    *)
      ;;
  esac
  pause_enter
}

submenu_A_chains() {
  while true; do
    clear
    print_header
    printf "%s=== Automated chains ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Safe backup + snapshot (8 -> 27)\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Exact dedup + quarantine (10 -> 11)\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Metadata + names cleanup (39 -> 34)\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s Media health scan (18 -> 14 -> 15)\n" "$C_YLW" "$C_RESET"
    printf "%s5)%s Show prep (8 -> 27 -> 10 -> 11 -> 14 -> 8)\n" "$C_YLW" "$C_RESET"
    printf "%s6)%s Media integrity + corrupts (13 -> 18)\n" "$C_YLW" "$C_RESET"
    printf "%s7)%s Efficiency plan (42 -> 44 -> 43)\n" "$C_YLW" "$C_RESET"
    printf "%s8)%s ML org basics (45 -> 46)\n" "$C_YLW" "$C_RESET"
    printf "%s9)%s Predictive backup (47 -> 8 -> 27)\n" "$C_YLW" "$C_RESET"
    printf "%s10)%s Cross-platform sync (48 -> 39 -> 8 -> 8)\n" "$C_YLW" "$C_RESET"
    printf "%s11)%s Quick diagnostics (1 -> 3 -> 4 -> 5)\n" "$C_YLW" "$C_RESET"
    printf "%s12)%s Serato health (7 -> 59)\n" "$C_YLW" "$C_RESET"
    printf "%s13)%s Hash + mirror check (9 -> 61)\n" "$C_YLW" "$C_RESET"
    printf "%s14)%s Audio prep (31 -> 66 -> 67)\n" "$C_YLW" "$C_RESET"
    printf "%s15)%s Integrity audit (6 -> 9 -> 27 -> 61)\n" "$C_YLW" "$C_RESET"
    printf "%s16)%s Cleanup + safe backup (39 -> 34 -> 10 -> 11 -> 8 -> 27)\n" "$C_YLW" "$C_RESET"
    printf "%s17)%s Library sync prep (18 -> 14 -> 48 -> 8 -> 27)\n" "$C_YLW" "$C_RESET"
    printf "%s18)%s Visual/video health (V2 -> V6 -> V8 -> V9 -> 8)\n" "$C_YLW" "$C_RESET"
    printf "%s19)%s Advanced audio org (31 -> 30 -> 35 -> 45 -> 46)\n" "$C_YLW" "$C_RESET"
    printf "%s20)%s Serato safety hardening (7 -> 8 -> 59 -> 12 -> 47)\n" "$C_YLW" "$C_RESET"
    printf "%s21)%s Multi-disk dedup + mirror (9 -> 10 -> 44 -> 11 -> 61)\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Back\n" "$C_YLW" "$C_RESET"
    printf "%sChoice:%s " "$C_BLU" "$C_RESET"
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
      B|b) break ;;
      *) invalid_option ;;
    esac
  done
}

submenu_L_libraries() {
  while true; do
    clear
    printf "%s=== L) DJ Libraries & Cues ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Configure DJ/Audio paths (L1)\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s Build/update audio catalog (L2)\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Find audio duplicates from master catalog (L3)\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s Extract cues from Rekordbox XML (L4)\n" "$C_YLW" "$C_RESET"
    printf "%s5)%s Generate ableton_locators.csv from dj_cues.tsv (L5)\n" "$C_YLW" "$C_RESET"
    printf "%s6)%s DJ library inventory (Serato/Rekordbox/Traktor/Ableton)\n" "$C_YLW" "$C_RESET"
    printf "%sB)%s Back to main menu\n" "$C_YLW" "$C_RESET"
    printf "%sSelect an option:%s " "$C_BLU" "$C_RESET"
    read -r lop
    case "$lop" in
      1)
        clear
        printf "%s[INFO]%s Configure DJ/Audio paths.\n" "$C_CYN" "$C_RESET"
        printf "Current AUDIO_ROOT: %s\n" "${AUDIO_ROOT:-}"
        printf "New AUDIO_ROOT (ENTER to keep): "
        read -e -r v
        v=$(strip_quotes "$v")
        if [ -n "$v" ]; then
          AUDIO_ROOT="$v"
        fi
        printf "Current GENERAL_ROOT: %s\n" "${GENERAL_ROOT:-}"
        printf "New GENERAL_ROOT (ENTER to keep): "
        read -e -r v
        v=$(strip_quotes "$v")
        if [ -n "$v" ]; then
          GENERAL_ROOT="$v"
        fi
        printf "Current REKORDBOX_XML: %s\n" "${REKORDBOX_XML:-}"
        printf "New REKORDBOX_XML (ENTER to keep): "
        read -e -r v
        v=$(strip_quotes "$v")
        if [ -n "$v" ]; then
          REKORDBOX_XML="$v"
        fi
        printf "Current ABLETON_ROOT: %s\n" "${ABLETON_ROOT:-}"
        printf "New ABLETON_ROOT (ENTER to keep): "
        read -e -r v
        v=$(strip_quotes "$v")
        if [ -n "$v" ]; then
          ABLETON_ROOT="$v"
        fi
        save_conf
        printf "%s[OK]%s DJ/Audio paths saved.\n" "$C_GRN" "$C_RESET"
        pause_enter
        ;;
      2)
        clear
        if [ -z "${AUDIO_ROOT:-}" ] || [ ! -d "$AUDIO_ROOT" ]; then
          printf "%s[ERR]%s AUDIO_ROOT not set or invalid.\n" "$C_RED" "$C_RESET"
          pause_enter
        else
          printf "%s[INFO]%s Building audio catalog from %s\n" "$C_CYN" "$C_RESET" "$AUDIO_ROOT"
          printf "Library/disk identifier (e.g., MAIN_SSD, BACKUP_A): "
          read -r libid
          if [ -z "$libid" ]; then
            libid="LIB"
          fi
          out="$REPORTS_DIR/catalog_audio_${libid}.tsv"
          total=$(find "$AUDIO_ROOT" -type f 2>/dev/null | wc -l | tr -d ' ')
          count=0
          >"$out"
          if [ "$total" -eq 0 ]; then
            printf "%s[WARN]%s No files found in AUDIO_ROOT.\n" "$C_YLW" "$C_RESET"
          else
            find "$AUDIO_ROOT" -type f 2>/dev/null | while IFS= read -r f; do
              count=$((count + 1))
              percent=$((count * 100 / total))
              status_line "CATALOGO_AUDIO" "$percent" "$f"
              printf "%s\t%s\n" "$libid" "$f" >>"$out"
            done
            finish_status_line
          fi
          printf "%s[OK]%s Catalog generated: %s\n" "$C_GRN" "$C_RESET" "$out"
          pause_enter
        fi
        ;;
      3)
        clear
        printf "%s[INFO]%s Find audio duplicates from master catalog.\n" "$C_CYN" "$C_RESET"
        cat_master="$REPORTS_DIR/catalog_audio_MASTER.tsv"
        >"$cat_master"
        for f in "$REPORTS_DIR"/catalog_audio_*.tsv; do
          if [ -f "$f" ] && [ "$f" != "$cat_master" ]; then
            cat "$f" >>"$cat_master"
          fi
        done
        if [ ! -s "$cat_master" ]; then
          printf "%s[WARN]%s No individual catalogs found.\n" "$C_YLW" "$C_RESET"
          pause_enter
        else
          out="$PLANS_DIR/audio_dupes_from_catalog.tsv"
          printf "%s[INFO]%s Generating duplicates plan by basename+size -> %s\n" "$C_CYN" "$C_RESET" "$out"
          awk '
          BEGIN { FS=OFS="\t" }
          {
            if (NF < 2) next
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
          printf "%s[OK]%s Audio duplicates plan generated.\n" "$C_GRN" "$C_RESET"
          pause_enter
        fi
        ;;
      4)
        clear
        printf "%s[INFO]%s Extract cues from Rekordbox XML.\n" "$C_CYN" "$C_RESET"
        if [ -z "${REKORDBOX_XML:-}" ] || [ ! -f "$REKORDBOX_XML" ]; then
          printf "%s[ERR]%s REKORDBOX_XML not set or missing.\n" "$C_RED" "$C_RESET"
          pause_enter
        else
          out="$REPORTS_DIR/dj_cues.tsv"
          printf "REKORDBOX_XML\t%s\n" "$REKORDBOX_XML" >"$out"
          printf "%s[OK]%s Placeholder dj_cues.tsv generated: %s\n" "$C_GRN" "$C_RESET" "$out"
          pause_enter
        fi
        ;;
      5)
        clear
        printf "%s[INFO]%s Generate ableton_locators.csv from dj_cues.tsv.\n" "$C_CYN" "$C_RESET"
        cues="$REPORTS_DIR/dj_cues.tsv"
        out="$REPORTS_DIR/ableton_locators.csv"
        if [ ! -f "$cues" ]; then
          printf "%s[ERR]%s dj_cues.tsv not found.\n" "$C_RED" "$C_RESET"
          pause_enter
        else
          printf "Name,Time,Track\n" >"$out"
          printf "CueFromRekordbox,1.1.1,1\n" >>"$out"
          printf "%s[OK]%s ableton_locators.csv generated: %s\n" "$C_GRN" "$C_RESET" "$out"
          pause_enter
        fi
        ;;
      6)
        clear
        out="$REPORTS_DIR/library_inventory.tsv"
        printf "%s[INFO]%s DJ library inventory -> %s\n" "$C_CYN" "$C_RESET" "$out"
        {
          printf "Platform\tStatus\tPath\n"
          if [ -d "$BASE_PATH/_Serato_" ]; then
            printf "Serato\tFOUND\t%s/_Serato_\n" "$BASE_PATH"
          else
            printf "Serato\tNO\t-\n"
          fi
          if find "$BASE_PATH" -maxdepth 4 -type f -iname "*rekordbox*.xml" 2>/dev/null | head -1 | grep -q .; then
            p=$(find "$BASE_PATH" -maxdepth 4 -type f -iname "*rekordbox*.xml" 2>/dev/null | head -1)
            printf "Rekordbox XML\tFOUND\t%s\n" "$p"
          else
            printf "Rekordbox XML\tNO\t-\n"
          fi
          if find "$BASE_PATH" -maxdepth 4 -type f -iname "*collection*.nml" 2>/dev/null | head -1 | grep -q .; then
            p=$(find "$BASE_PATH" -maxdepth 4 -type f -iname "*collection*.nml" 2>/dev/null | head -1)
            printf "Traktor NML\tFOUND\t%s\n" "$p"
          else
            printf "Traktor NML\tNO\t-\n"
          fi
          if find "$BASE_PATH" -maxdepth 4 -type f -iname "*.als" 2>/dev/null | head -1 | grep -q .; then
            p=$(find "$BASE_PATH" -maxdepth 4 -type f -iname "*.als" 2>/dev/null | head -1)
            printf "Ableton ALS\tFOUND\t%s\n" "$p"
          else
            printf "Ableton ALS\tNO\t-\n"
          fi
          if find "$BASE_PATH" -maxdepth 4 -type f -iname "*.svd" 2>/dev/null | head -1 | grep -q .; then
            p=$(find "$BASE_PATH" -maxdepth 4 -type f -iname "*.svd" 2>/dev/null | head -1)
            printf "Serato Video SVD\tFOUND\t%s\n" "$p"
          else
            printf "Serato Video SVD\tNO\t-\n"
          fi
        } >"$out"
        printf "%s[OK]%s Inventory generated.\n" "$C_GRN" "$C_RESET"
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

submenu_D_dupes_general() {
  while true; do
    clear
    printf "%s=== D) General Duplicates ===%s\n" "$C_CYN" "$C_RESET"
    ensure_general_root_valid
    printf "%s1)%s General catalog per disk (D1)\n" "$C_YLW" "$C_RESET"
    printf "%s2)%s General duplicates by basename+size (D2)\n" "$C_YLW" "$C_RESET"
    printf "%s3)%s Smart report (Deep/ML) on duplicates (D3)\n" "$C_YLW" "$C_RESET"
    printf "%s4)%s Multi-disk consolidation (safe plan) (D4)\n" "$C_YLW" "$C_RESET"
    printf "%s5)%s Exact duplicate plan by hash (all extensions) (D5)\n" "$C_YLW" "$C_RESET"
    printf "%s6)%s Inverse consolidation (extras in sources) (D6)\n" "$C_YLW" "$C_RESET"
    printf "%s7)%s Matrioshka report (duplicate folder structures) (D7)\n" "$C_YLW" "$C_RESET"
    printf "%s8)%s Mirror folders by content (subdir hash) (D8)\n" "$C_YLW" "$C_RESET"
    printf "%s9)%s Audio similarity (YAMNet embeddings, requires TF) (D9)\n" "$C_YLW" "$C_RESET"
    printf "Suggested flow: D1 -> D2 -> D3, then apply 10/11/44 with backup first if SafeMode=0.\n"
    printf "Tip: GENERAL_ROOT is the root cataloged in D1/D2/D3. D4 compares destination vs sources. D5 accepts multiple comma-separated roots. D6 marks extras; D7 structure; D8 content.\n"
    printf "%sB)%s Back to main menu\n" "$C_YLW" "$C_RESET"
    printf "%sH)%s Quick help (paths/flow)\n" "$C_YLW" "$C_RESET"
    printf "%sSelect an option:%s " "$C_BLU" "$C_RESET"
    read -r dop
    : "${GENERAL_ROOT:=$BASE_PATH}"
    case "$dop" in
      1)
        clear
        printf "%s[INFO]%s General catalog per disk.\n" "$C_CYN" "$C_RESET"
        printf "Current GENERAL_ROOT: %s\n" "${GENERAL_ROOT:-}"
        printf "New GENERAL_ROOT (ENTER to keep; empty uses BASE_PATH): "
        read -e -r v
        v=$(strip_quotes "$v")
        if [ -n "$v" ] && [ -d "$v" ]; then
          GENERAL_ROOT="$v"
          save_conf
        elif [ -z "${GENERAL_ROOT:-}" ] || [ ! -d "$GENERAL_ROOT" ]; then
          GENERAL_ROOT="$BASE_PATH"
          save_conf
        fi
        printf "Default exclusions: %s\n" "$DEFAULT_EXCLUDES"
        printf "Max depth (1=root only, 2=subfolders, 3=sub-sub; ENTER no limit): "
        read -e -r max_depth
        printf "Max size (MB, ENTER no limit, e.g., 500): "
        read -e -r max_mb
        out="$REPORTS_DIR/general_catalog.tsv"
        printf "Exclusions (comma patterns, e.g., *.asd,*/Cache/*; ENTER uses default): "
        read -r exclude_patterns
        [ -z "$exclude_patterns" ] && exclude_patterns="$DEFAULT_EXCLUDES"
        total=$(find "$GENERAL_ROOT" -type f 2>/dev/null | wc -l | tr -d ' ')
        count=0
        find_opts=()
        >"$out"
        if [ "$total" -eq 0 ]; then
          printf "%s[WARN]%s No files found.\n" "$C_YLW" "$C_RESET"
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
        printf "%s[OK]%s General catalog generated: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      2)
        clear
        printf "%s[INFO]%s General duplicates by basename+size.\n" "$C_CYN" "$C_RESET"
        cat_file="$REPORTS_DIR/general_catalog.tsv"
        if [ ! -s "$cat_file" ]; then
          printf "%s[WARN]%s general_catalog.tsv missing or empty, generating first.\n" "$C_YLW" "$C_RESET"
          out="$REPORTS_DIR/general_catalog.tsv"
          printf "Exclusions (comma patterns, e.g., *.asd,*/Cache/*; ENTER uses default): "
          read -r exclude_patterns
          [ -z "$exclude_patterns" ] && exclude_patterns="$DEFAULT_EXCLUDES"
          total=$(find "$GENERAL_ROOT" -type f 2>/dev/null | wc -l | tr -d ' ')
          count=0
          >"$out"
          if [ "$total" -eq 0 ]; then
            printf "%s[WARN]%s No files found.\n" "$C_YLW" "$C_RESET"
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
          printf "%s[WARN]%s Catalog empty, nothing to process.\n" "$C_YLW" "$C_RESET"
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
        printf "%s[OK]%s General duplicates plan generated: %s\n" "$C_GRN" "$C_RESET" "$out"
        pause_enter
        ;;
      H|h)
        clear
        printf "%s[INFO]%s Quick guide submenu D (paths/flow):\n" "$C_CYN" "$C_RESET"
        printf "%s\n" "- GENERAL_ROOT: root cataloged in D1/D2/D3; ENTER uses BASE_PATH (current: ${BASE_PATH})."
        printf "%s\n" "- D1: catalogs GENERAL_ROOT."
        printf "%s\n" "- D2/D3: use that catalog for basename+size dupes (and smart report in D3)."
        printf "%s\n" "- D4: consolidation plan. Destination is usually your main library; sources = external disks comma-separated."
        printf "%s\n" "- D5: exact duplicates plan by hash; you can pass several comma-separated roots (main + externals)."
        printf "%s\n" "- D6: inverse consolidation (extras in sources already in destination)."
        printf "%s\n" "- D7: matrioshka report (folders with same structure/names)."
        printf "%s\n" "- D8: mirror folders by content (choose quick name+size or full hash)."
        printf "%s\n" "- D9: audio similarity with YAMNet (TF), threshold >=0.60, top similar pairs."
        printf "%s\n" "- For main menu (9/10/11) to dedupe your official library, set BASE_PATH there before running."
        pause_enter
        ;;
      3)
        maybe_activate_ml_env "D3 (Smart duplicate report)"
        clear
        printf "%s[INFO]%s D3) Smart report (Deep/ML) on duplicates.\n" "$C_CYN" "$C_RESET"
        cat_file="$REPORTS_DIR/general_catalog.tsv"
        plan_dupes="$PLANS_DIR/general_dupes_plan.tsv"
        smart_report="$REPORTS_DIR/general_dupes_smart.txt"
        smart_plan="$PLANS_DIR/general_dupes_smart.tsv"

        # Ensure catalog
        if [ ! -f "$cat_file" ]; then
          printf "%s[WARN]%s general_catalog.tsv missing, generating first.\n" "$C_YLW" "$C_RESET"
          out="$REPORTS_DIR/general_catalog.tsv"
          printf "Exclusions (comma patterns, e.g., *.asd,*/Cache/*; ENTER uses default): "
          read -r exclude_patterns
          [ -z "$exclude_patterns" ] && exclude_patterns="$DEFAULT_EXCLUDES"
          total=$(find "$GENERAL_ROOT" -type f 2>/dev/null | wc -l | tr -d ' ')
          count=0
          >"$out"
          if [ "$total" -eq 0 ]; then
            printf "%s[WARN]%s No files found.\n" "$C_YLW" "$C_RESET"
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
          printf "%s[OK]%s General catalog generated: %s\n" "$C_GRN" "$C_RESET" "$out"
        fi

        # Ensure basic duplicates plan (D2)
        if [ ! -f "$plan_dupes" ]; then
          printf "%s[WARN]%s General duplicates plan missing, generating (D2).\n" "$C_YLW" "$C_RESET"
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
          printf "%s[OK]%s General duplicates plan generated: %s\n" "$C_GRN" "$C_RESET" "$out"
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
                  print k"\t"cnt[k]"\t"sample[k]"\t\"Review with option 10/11/44\""
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
        printf "\nQuick recommendations:\n" >>"$smart_report"
        printf "%s\n" "- 10 -> 11 for exact flow (hash) and quarantine." >>"$smart_report"
        printf "%s\n" "- 44 to consolidate with integrated dedupe." >>"$smart_report"
        printf "%s\n" "- 40/41/42 for analysis + predictor + optimizer before moving." >>"$smart_report"
        printf "%s\n" "- 8/27 for backup + snapshot if SAFE_MODE=0 and DJ_SAFE_LOCK=0." >>"$smart_report"

        printf "%s[OK]%s Smart report: %s\n" "$C_GRN" "$C_RESET" "$smart_report"
        printf "%s[OK]%s Smart plan (top duplicates): %s\n" "$C_GRN" "$C_RESET" "$smart_plan"
        pause_enter
        ;;
      4)
        clear
        printf "%s[INFO]%s D4) Multi-disk consolidation (safe plan, no moves).\n" "$C_CYN" "$C_RESET"
        printf "Destination (ENTER uses current BASE_PATH; accepts drag & drop): "
        read -r dest_root
        if [ -z "$dest_root" ]; then
          dest_root="$BASE_PATH"
        fi
        if [ ! -d "$dest_root" ]; then
          printf "%s[ERR]%s Invalid destination.\n" "$C_RED" "$C_RESET"
          pause_enter
          continue
        fi
        default_sources="${EXTRA_SOURCE_ROOTS:-}"
        printf "Source roots comma-separated (e.g., /Volumes/DiskA,/Volumes/DiskB; ENTER uses detected: %s): " "${default_sources:-NONE}"
        read -e -r src_line
        if [ -z "$src_line" ]; then
          src_line="$default_sources"
        fi
        if [ -z "$src_line" ]; then
          printf "%s[WARN]%s No sources, canceled.\n" "$C_YLW" "$C_RESET"
          pause_enter
          continue
        fi
        IFS=',' read -r -a SRC_ROOTS <<<"$src_line"
        dest_keys="$STATE_DIR/dest_keys_tmp.tsv"
        plan_conso="$PLANS_DIR/consolidation_plan.tsv"
        mkdir -p "$PLANS_DIR"
        >"$dest_keys"
        >"$plan_conso"
        printf "%s[INFO]%s Indexing destination %s\n" "$C_CYN" "$C_RESET" "$dest_root"
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
            printf "%s[WARN]%s Invalid source: %s\n" "$C_YLW" "$C_RESET" "$src_root_trimmed"
            continue
          fi
          printf "%s[INFO]%s Scanning source: %s\n" "$C_CYN" "$C_RESET" "$src_root_trimmed"
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
        printf "%s[OK]%s Consolidation plan generated: %s (unique missing: %s)\n" "$C_GRN" "$C_RESET" "$plan_conso" "$unique_missing"
        rsync_helper="$PLANS_DIR/consolidation_rsync.sh"
        >"$rsync_helper"
        while IFS=$'\t' read -r src target; do
          dest_dir=$(dirname "$target")
          printf "mkdir -p %q\n" "$dest_dir" >>"$rsync_helper"
          printf "rsync -av --progress --protect-args %q %q\n" "$src" "$target" >>"$rsync_helper"
        done <"$plan_conso"
        chmod +x "$rsync_helper" 2>/dev/null || true
        printf "Recommended: review then run helper: %s (SAFE_MODE not enforced; review before running).\n" "$rsync_helper"
        pause_enter
        ;;
      5)
        clear
        printf "%s[INFO]%s D5) Exact duplicates by hash (all extensions).\n" "$C_CYN" "$C_RESET"
        default_roots="${GENERAL_ROOT:-$BASE_PATH}"
        if [ -n "${EXTRA_SOURCE_ROOTS:-}" ]; then
          default_roots="$default_roots,${EXTRA_SOURCE_ROOTS}"
        fi
        printf "Roots comma-separated (e.g., /Volumes/DiskA,/Volumes/DiskB; ENTER uses %s): " "$default_roots"
        read -e -r roots_line
        if [ -z "$roots_line" ]; then
          roots_line="$default_roots"
        fi
        printf "Exclusions (comma patterns, e.g., *.asd,*/Cache/*; ENTER uses default): "
        read -r exclude_patterns
        [ -z "$exclude_patterns" ] && exclude_patterns="$DEFAULT_EXCLUDES"
        printf "Max depth (1=root only, 2=subfolders, 3=sub-sub; ENTER no limit): "
        read -e -r max_depth
        printf "Max size (MB, ENTER no limit, e.g., 500): "
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
            printf "%s[WARN]%s Invalid root: %s\n" "$C_YLW" "$C_RESET" "$r_trim"
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
          printf "%s[WARN]%s No files found in provided roots.\n" "$C_YLW" "$C_RESET"
          pause_enter
          continue
        fi

        count=0
        printf "%s[INFO]%s Calculando hashes SHA-256 (puede tardar)...\n" "$C_CYN" "$C_RESET"
        for r in "${ROOTS[@]}"; do
          r_trim=$(printf "%s" "$r" | xargs)
          [ -d "$r_trim" ] || { printf "%s[WARN]%s Invalid root: %s\n" "$C_YLW" "$C_RESET" "$r_trim"; continue; }
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
          printf "Files processed: %s\n" "$count"
          dupes=$(awk -F'\t' '{print $1}' "$plan_hash" | sort | uniq | wc -l | tr -d ' ')
          printf "Hashes with duplicates: %s\n" "$dupes"
          printf "Recommendation: review %s and apply action 11 (quarantine) with SAFE_MODE=0.\n" "$plan_hash"
        } >"$report_hash"

        printf "%s[OK]%s Exact duplicates plan: %s\n" "$C_GRN" "$C_RESET" "$plan_hash"
        printf "%s[OK]%s Report: %s\n" "$C_GRN" "$C_RESET" "$report_hash"
        pause_enter
        ;;
      6)
        clear
        printf "%s[INFO]%s D6) Inverse consolidation (extras in source, no moves).\n" "$C_CYN" "$C_RESET"
        printf "Destination (ENTER uses current BASE_PATH; accepts drag & drop): "
        read -e -r dest_root
        dest_root=$(strip_quotes "$dest_root")
        if [ -z "$dest_root" ]; then
          dest_root="$BASE_PATH"
        fi
        if [ ! -d "$dest_root" ]; then
          printf "%s[ERR]%s Invalid destination.\n" "$C_RED" "$C_RESET"
          pause_enter
          continue
        fi
        default_sources="${EXTRA_SOURCE_ROOTS:-}"
        printf "Source roots comma-separated (ENTER uses detected: %s): " "${default_sources:-NONE}"
        read -e -r src_line
        if [ -z "$src_line" ]; then
          src_line="$default_sources"
        fi
        if [ -z "$src_line" ]; then
          printf "%s[WARN]%s No sources, canceled.\n" "$C_YLW" "$C_RESET"
          pause_enter
          continue
        fi
        printf "Minimum size (MB) to mark extras (ENTER no threshold, e.g., 500): "
        read -e -r inv_min_mb
        IFS=',' read -r -a SRC_ROOTS <<<"$src_line"
        dest_keys="$STATE_DIR/dest_keys_tmp.tsv"
        plan_inv="$PLANS_DIR/consolidation_inverse_plan.tsv"
        mkdir -p "$PLANS_DIR"
        >"$dest_keys"
        >"$plan_inv"
        printf "%s[INFO]%s Indexing destination %s\n" "$C_CYN" "$C_RESET" "$dest_root"
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
            printf "%s[WARN]%s Invalid source: %s\n" "$C_YLW" "$C_RESET" "$src_root_trimmed"
            continue
          fi
          printf "%s[INFO]%s Scanning source: %s\n" "$C_CYN" "$C_RESET" "$src_root_trimmed"
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
        printf "%s[OK]%s Extras plan generated: %s (candidate files: %s)\n" "$C_GRN" "$C_RESET" "$plan_inv" "$inv_count"
        printf "Recommendation: review before deleting/moving manually.\n"
        pause_enter
        ;;
      7)
        clear
        printf "%s[INFO]%s D7) Matrioshka report (duplicate folder structures).\n" "$C_CYN" "$C_RESET"
        roots_line="$GENERAL_ROOT"
        printf "Roots comma-separated (e.g., /Volumes/DiskA,/Volumes/DiskB; ENTER uses GENERAL_ROOT=%s): " "${GENERAL_ROOT:-$BASE_PATH}"
        read -e -r rl
        [ -n "$rl" ] && roots_line="$rl"
        printf "Max depth to analyze (1=root only, 2=subfolders, 3=sub-sub; ENTER=3): "
        read -e -r md
        [ -z "$md" ] && md=3
        printf "Max files per folder to hash (ENTER=500): "
        read -e -r mf
        [ -z "$mf" ] && mf=500
        IFS=',' read -r -a MROOTS <<<"$roots_line"
        sig_tmp="$STATE_DIR/matrioshka_sig.tmp"
        plan_m="$PLANS_DIR/matrioshka_report.tsv"
        clean_plan="$PLANS_DIR/matrioshka_clean_plan.tsv"
        >"$sig_tmp"
        >"$plan_m"
        >"$clean_plan"
        printf "%s[INFO]%s Generating structure signatures (depth=%s, max_files=%s)...\n" "$C_CYN" "$C_RESET" "$md" "$mf"
        for r in "${MROOTS[@]}"; do
          r_trim=$(printf "%s" "$r" | xargs)
          [ -d "$r_trim" ] || { printf "%s[WARN]%s Invalid root: %s\n" "$C_YLW" "$C_RESET" "$r_trim"; continue; }
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
        # Generate suggested cleanup plan (KEEP/REMOVE) by date/size
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
        printf "%s[OK]%s Matrioshka report: %s (matches: %s)\n" "$C_GRN" "$C_RESET" "$plan_m" "$hits"
        printf "%s[OK]%s Matrioshka cleanup plan: %s\n" "$C_GRN" "$C_RESET" "$clean_plan"
        pause_enter
        ;;
      9)
        clear
        if [ "${ML_ENV_DISABLED:-0}" -eq 1 ]; then
          printf "%s[WARN]%s ML is disabled (use 63 to enable).\n" "$C_YLW" "$C_RESET"
          pause_enter
          continue
        fi
        maybe_activate_ml_env "D9 Audio similarity (YAMNet)" 1 1
        report_sim="$REPORTS_DIR/d9_audio_similarity.tsv"
        plan_sim="$PLANS_DIR/d9_audio_similarity_plan.tsv"
        printf "Model (1=YAMNet, 2=MusicTag NNFP, 3=VGGish, 4=Musicnn) [1]: "
        read -r model_sel
        [ -z "$model_sel" ] && model_sel=1
        printf "Preset (1=fast:100f/0.55/100 pairs, 2=balanced:150f/0.60/200 pairs, 3=strict:150f/0.70/200 pairs) [2]: "
        read -r preset_sim
        [ -z "$preset_sim" ] && preset_sim=2
        if [ "$preset_sim" -eq 1 ]; then max_files=100; sim_thresh=0.55; top_pairs=100; elif [ "$preset_sim" -eq 3 ]; then max_files=150; sim_thresh=0.70; top_pairs=200; else max_files=150; sim_thresh=0.60; top_pairs=200; fi
        printf "%s[INFO]%s D9) Audio similarity (model %s, max %s files, threshold %.2f, top %s pairs, needs TF/tf_hub/soundfile).\n" "$C_CYN" "$C_RESET" "$model_sel" "$max_files" "$sim_thresh" "$top_pairs"
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
    print("[ERR] Failed to generate embeddings (check dependencies).")
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

print(f\"[OK] Report: {report_path}\")
print(f\"[OK] Plan: {plan_path}\")
PY
        rc=$?
        if [ "$rc" -ne 0 ]; then
          printf "%s[ERR]%s Could not generate similarity (check TF/tf_hub/soundfile dependencies). RC=%s\n" "$C_RED" "$C_RESET" "$rc"
        else
          printf "%s[OK]%s Similarity report: %s\n" "$C_GRN" "$C_RESET" "$report_sim"
          printf "%s[OK]%s Plan similitud: %s\n" "$C_GRN" "$C_RESET" "$plan_sim"
        fi
        pause_enter
        ;;
      8)
        clear
        printf "%s[INFO]%s D8) Carpetas espejo por contenido.\n" "$C_CYN" "$C_RESET"
        roots_line="$GENERAL_ROOT"
        printf "Roots comma-separated (e.g., /Volumes/DiskA,/Volumes/DiskB; ENTER uses GENERAL_ROOT=%s): " "${GENERAL_ROOT:-$BASE_PATH}"
        read -e -r rl
        [ -n "$rl" ] && roots_line="$rl"
        printf "Max depth to analyze (1=root only, 2=subfolders, 3=sub-sub; ENTER=3): "
        read -e -r md
        [ -z "$md" ] && md=3
        printf "Max files per folder (ENTER=500): "
        read -e -r mf
        [ -z "$mf" ] && mf=500
        printf "Mode (1=fast name+size, 2=content hash more precise but slower): "
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
        printf "%s[INFO]%s Calculating folder signatures (depth=%s, max_files=%s, mode=%s)...\n" "$C_CYN" "$C_RESET" "$md" "$mf" "$mode"
        for r in "${MROOTS[@]}"; do
          r_trim=$(printf "%s" "$r" | xargs)
          [ -d "$r_trim" ] || { printf "%s[WARN]%s Invalid root: %s\n" "$C_YLW" "$C_RESET" "$r_trim"; continue; }
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
          printf "%s[WARN]%s No mirror folders detected in provided roots.\n" "$C_YLW" "$C_RESET"
        else
          printf "%s[OK]%s Mirror folders report: %s (matches: %s)\n" "$C_GRN" "$C_RESET" "$report_mirror" "$hits"
          printf "%s[OK]%s Mirror cleanup plan: %s\n" "$C_GRN" "$C_RESET" "$clean_mirror"
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
    printf "%s[ERR]%s python3 not found (needed to read .als).\n" "$C_RED" "$C_RESET"
    pause_enter; return
  fi
  mapfile -t als_list < <(find "$BASE_PATH" -type f -iname "*.als" 2>/dev/null | head -200)
  if [ "${#als_list[@]}" -eq 0 ]; then
    printf "%s[WARN]%s No .als files found in base.\n" "$C_YLW" "$C_RESET"
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
  printf "%s[OK]%s Report generated.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_V2_visuals_inventory() {
  print_header
  out="$REPORTS_DIR/visuals_inventory.tsv"
  printf "%s[INFO]%s Video/visual inventory -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  mapfile -t vids < <(find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.m4v" \) 2>/dev/null)
  total=${#vids[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No videos/visuals found.\n" "$C_YLW" "$C_RESET"
    rm -f "$out"
    pause_enter; return
  fi
  count=0
  for f in "${vids[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    size=$({ stat -f %z "$f" 2>/dev/null || echo 0; } | tr -d '[:space:]')
    printf "%s\t%s\t%s\n" "$f" "$(basename "$f")" "$size" >>"$out"
    status_line "Visual inventory" "$percent" "$(basename "$f")"
  done
  finish_status_line
  printf "%s[OK]%s Inventory generated.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_V3_osc_dmx_plan() {
  print_header
  out="$PLANS_DIR/osc_dmx_plan.tsv"
  printf "%s[INFO]%s OSC/DMX placeholder plan -> %s\n" "$C_CYN" "$C_RESET" "$out"
  cat >"$out" <<'EOF'
path\taction\tnotes
(add your OSC/DMX cues)\tTRIGGER\tPlaceholder: adjust channels/cues in your DAW/visual router
EOF
  printf "%s[OK]%s Placeholder plan created.\n" "$C_GRN" "$C_RESET"
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
  printf "%s[INFO]%s Resolution/duration report (ffprobe) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  if ! command -v ffprobe >/dev/null 2>&1; then
    printf "%s[ERR]%s ffprobe not available.\n" "$C_RED" "$C_RESET"
    pause_enter; return
  fi
  >"$out"
  mapfile -t vids < <(find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.m4v" \) 2>/dev/null)
  total=${#vids[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No videos/visuals found.\n" "$C_YLW" "$C_RESET"
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
  printf "%s[OK]%s Report generated.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_V7_visuals_by_resolution() {
  print_header
  out="$PLANS_DIR/visuals_by_resolution.tsv"
  printf "%s[INFO]%s Plan: organize visuals by resolution -> %s\n" "$C_CYN" "$C_RESET" "$out"
  if ! command -v ffprobe >/dev/null 2>&1; then
    printf "%s[ERR]%s ffprobe not available.\n" "$C_RED" "$C_RESET"
    pause_enter; return
  fi
  >"$out"
  mapfile -t vids < <(find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.m4v" \) 2>/dev/null)
  total=${#vids[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No videos/visuals found.\n" "$C_YLW" "$C_RESET"
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
    status_line "Bucket visuals" "$percent" "$(basename "$f")"
  done
  finish_status_line
  printf "%s[OK]%s Plan generated.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_V8_visuals_hash_dupes() {
  print_header
  report="$REPORTS_DIR/visuals_hash_dupes.tsv"
  plan="$PLANS_DIR/visuals_hash_dupes_plan.tsv"
  printf "%s[INFO]%s Visual exact duplicates (hash) -> %s\n" "$C_CYN" "$C_RESET" "$report"
  tmp="$STATE_DIR/visuals_hashes.tmp"
  >"$tmp"
  mapfile -t vids < <(find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.m4v" \) 2>/dev/null)
  total=${#vids[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No visuals or failed to hash.\n" "$C_YLW" "$C_RESET"
    rm -f "$tmp"; pause_enter; return
  fi
  count=0
  for f in "${vids[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    h=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
    [ -n "$h" ] && printf "%s\t%s\n" "$h" "$f" >>"$tmp"
    status_line "Hashing visuals" "$percent" "$(basename "$f")"
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
    printf "%s[WARN]%s No exact duplicates found.\n" "$C_YLW" "$C_RESET"
  else
    printf "%s[OK]%s Dupes report: %s\n" "$C_GRN" "$C_RESET" "$report"
    printf "%s[OK]%s Dupes plan: %s\n" "$C_GRN" "$C_RESET" "$plan"
  fi
  pause_enter
}

action_V9_visuals_optimize_plan() {
  print_header
  out="$PLANS_DIR/visuals_optimize_plan.tsv"
  printf "%s[INFO]%s Visual optimization plan (suggest H.264 1080p) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  if ! command -v ffprobe >/dev/null 2>&1; then
    printf "%s[ERR]%s ffprobe not available.\n" "$C_RED" "$C_RESET"
    pause_enter; return
  fi
  >"$out"
  mapfile -t vids < <(find "$BASE_PATH" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.m4v" \) 2>/dev/null)
  total=${#vids[@]}
  if [ "$total" -eq 0 ]; then
    printf "%s[WARN]%s No videos/visuals found.\n" "$C_YLW" "$C_RESET"
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
    status_line "Optimize visuals" "$percent" "$(basename "$f")"
  done
  finish_status_line
  printf "%s[OK]%s Plan generated (suggestions only).\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_V10_osc_from_playlist() {
  print_header
  default_pl="$BASE_PATH/playlist.m3u8"
  printf "%s[INFO]%s Generate OSC cues from playlist (.m3u/.m3u8).\n" "$C_CYN" "$C_RESET"
  printf "Playlist path (ENTER tries %s): " "$default_pl"
  read -e -r pl_path
  if [ -z "$pl_path" ]; then
    pl_path="$default_pl"
  fi
  pl_path=$(strip_quotes "$pl_path")
  if [ ! -f "$pl_path" ]; then
    printf "%s[ERR]%s Playlist not found.\n" "$C_RED" "$C_RESET"
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
  printf "%s[OK]%s OSC plan generated: %s (edit address/payload to your router).\n" "$C_GRN" "$C_RESET" "$plan"
  pause_enter
}

action_V11_dmx_from_playlist() {
  print_header
  default_pl="$BASE_PATH/playlist.m3u8"
  printf "%s[INFO]%s DMX plan from playlist (basic Intro/Drop/Outro scenes).\n" "$C_CYN" "$C_RESET"
  printf "Playlist path (ENTER tries %s): " "$default_pl"
  read -e -r pl_path
  if [ -z "$pl_path" ]; then
    pl_path="$default_pl"
  fi
  pl_path=$(strip_quotes "$pl_path")
  if [ ! -f "$pl_path" ]; then
    printf "%s[ERR]%s Playlist not found.\n" "$C_RED" "$C_RESET"
    pause_enter; return
  fi
  base_ch=1
  printf "Base channel (ENTER=1): "
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
  printf "%s[OK]%s DMX plan generated: %s (adjust channels/values to your rig).\n" "$C_GRN" "$C_RESET" "$plan"
  pause_enter
}

action_V12_dmx_presets() {
  print_header
  plan="$PLANS_DIR/dmx_presets_beam_laser.tsv"
  printf "%s[INFO]%s DMX presets (Mini LEDs Spider 8x6W + ALIEN 500mw RGB laser) -> %s\n" "$C_CYN" "$C_RESET" "$plan"
  printf "%sHint:%s align channels to your manuals. Suggested:\n" "$C_BLU" "$C_RESET"
  printf "  Spider: CH1 Dimmer, CH2 Pan speed, CH3 Tilt speed, CH4 Macro/Auto, CH5 Strobe, CH6 Color/Macro, CH7 Red, CH8 Green, CH9 Blue, CH10 White.\n"
  printf "  ALIEN laser: CH1 Master/Mode, CH2 Pattern, CH3 Color, CH4 Rotation, CH5 Size/Zoom, CH6 X, CH7 Y, CH8 Strobe/Audio.\n"
  cat >"$plan" <<'EOF'
#scene	label	channel_values	notes
INTRO_SOFT	Soft spider + low laser	"SPIDER:CH1=80,CH2=90,CH3=90,CH4=0,CH5=0,CH6=0,CH7=60,CH8=0,CH9=0,CH10=20; LASER:CH1=60,CH2=PATTERN1,CH3=BLUE,CH4=SLOW,CH5=30,CH6=CENTER,CH7=CENTER,CH8=OFF"	Ambient intro
DROP_FULL	Full spider+laser	"SPIDER:CH1=255,CH2=180,CH3=180,CH4=AUTO,CH5=160,CH6=255,CH7=255,CH8=255,CH9=255,CH10=255; LASER:CH1=255,CH2=PATTERN8,CH3=RGB,CH4=FAST,CH5=120,CH6=SWEEP,CH7=SWEEP,CH8=AUDIO"	Drops/peaks
BREAK_SMOOTH	Smooth break	"SPIDER:CH1=150,CH2=60,CH3=60,CH4=0,CH5=0,CH6=80,CH7=120,CH8=80,CH9=40,CH10=0; LASER:CH1=80,CH2=PATTERN3,CH3=GREEN,CH4=SLOW,CH5=0,CH6=STATIC,CH7=STATIC,CH8=OFF"	Break/bridge
LASER_FOCUS	Laser focus mid	"SPIDER:CH1=0,CH5=0; LASER:CH1=180,CH2=PATTERN5,CH3=RED,CH4=MEDIUM,CH5=40,CH6=CENTER,CH7=CENTER,CH8=AUTO"	Laser forward
PANORAMA_WIDE	Wide sweep + light laser	"SPIDER:CH1=200,CH2=220,CH3=40,CH4=AUTO,CH5=80,CH6=120,CH7=200,CH8=200,CH9=180,CH10=120; LASER:CH1=100,CH2=PATTERN2,CH3=CYAN,CH4=SLOW,CH5=20,CH6=SWEEP,CH7=SWEEP,CH8=OFF"	Room fill without overload
STROBE_FAST	Fast strobe controlled	"SPIDER:CH1=200,CH2=150,CH3=150,CH4=0,CH5=220,CH6=200,CH7=255,CH8=255,CH9=255,CH10=255; LASER:CH1=120,CH2=PATTERN4,CH3=WHITE,CH4=FAST,CH5=60,CH6=CENTER,CH7=CENTER,CH8=AUDIO"	Short risers/climax
BLACKOUT_SAFE	Safe blackout	"SPIDER:CH1=0,CH2=0,CH3=0,CH4=0,CH5=0,CH6=0,CH7=0,CH8=0,CH9=0,CH10=0; LASER:CH1=0,CH2=PATTERN1,CH3=OFF,CH4=0,CH5=0,CH6=CENTER,CH7=CENTER,CH8=OFF"	Clean cut/pause
AUTO_SOUND	Sound/auto light	"SPIDER:CH1=220,CH2=180,CH3=180,CH4=AUTO,CH5=140,CH6=180,CH7=200,CH8=200,CH9=200,CH10=200; LASER:CH1=200,CH2=PATTERN7,CH3=RGB,CH4=MEDIUM,CH5=80,CH6=SWEEP,CH7=SWEEP,CH8=AUDIO"	Light sound-activated mode
EOF
  printf "%s[OK]%s Presets written; adjust names/channels/values to your real mapping before sending to DMX software.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_V13_dmx_fixtures_inventory() {
  print_header
  out="$REPORTS_DIR/dmx_fixtures_inventory.tsv"
  printf "%s[INFO]%s DMX/Laser fixtures inventory -> %s\n" "$C_CYN" "$C_RESET" "$out"
  search_root="$BASE_PATH"
  printf "Search root (ENTER uses BASE_PATH=%s): " "$BASE_PATH"
  read -e -r v
  v=$(strip_quotes "$v")
  if [ -n "$v" ] && [ -d "$v" ]; then
    search_root="$v"
  fi
  printf "%s[INFO]%s Scanning fixtures (.ift, .qxf, .ssl, .d4) in %s\n" "$C_CYN" "$C_RESET" "$search_root"
  printf "File\tName\tPath\n" >"$out"
  find "$search_root" -type f \( -iname "*.ift" -o -iname "*.qxf" -o -iname "*.ssl" -o -iname "*.d4" \) 2>/dev/null | head -200 | while IFS= read -r f; do
    base=$(basename "$f")
    name="${base%.*}"
    printf "%s\t%s\t%s\n" "$base" "$name" "$f" >>"$out"
  done
  printf "%s[OK]%s Inventory generated (max 200 results). Adjust root if you need more.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

action_V14_visuals_transcode_adv() {
  print_header
  out="$PLANS_DIR/visuals_transcode_adv.tsv"
  printf "%s[INFO]%s Advanced transcode plan (ffmpeg suggestions) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  printf "Target codec (ENTER=libx264, options: libx264/libx265/libvpx-vp9): "
  read -r codec
  [ -z "$codec" ] && codec="libx264"
  printf "Target bitrate (ENTER=15M): "
  read -r br
  [ -z "$br" ] && br="15M"
  printf "Target resolution (ENTER=1920x1080): "
  read -r res
  [ -z "$res" ] && res="1920x1080"
  printf "Extensions to include (comma, ENTER=mp4,mov,mkv): "
  read -r exts
  [ -z "$exts" ] && exts="mp4,mov,mkv"
  IFS=',' read -r -a arr_exts <<<"$exts"
  printf "Input\tOutput\tSuggested_cmd\n" >"$out"
  find "$BASE_PATH" -type f \( $(printf -- '-iname \"*.%s\" -o ' "${arr_exts[@]}" | sed 's/ -o $//') \) 2>/dev/null | head -100 | while IFS= read -r f; do
    dir=$(dirname "$f")
    base=$(basename "$f")
    out_name="${base%.*}_h264.mp4"
    cmd="ffmpeg -i \"$f\" -c:v $codec -b:v $br -vf scale=$res -c:a aac -b:a 192k \"$dir/$out_name\""
    printf "%s\t%s\t%s\n" "$f" "$dir/$out_name" "$cmd" >>"$out"
  done
  printf "%s[OK]%s Plan generated (up to 100 files). Review commands before running.\n" "$C_GRN" "$C_RESET"
  pause_enter
}

submenu_V_visuals() {
  while true; do
    clear
    printf "%s=== V) Visuals / DAW / OSC ===%s\n" "$C_CYN" "$C_RESET"
    printf "%s1)%s Ableton .als quick report (samples/plugins)\n" "$C_GRN" "$C_RESET"
    printf "%s2)%s Video/visual inventory -> TSV\n" "$C_GRN" "$C_RESET"
    printf "%s3)%s OSC/DMX placeholder plan\n" "$C_GRN" "$C_RESET"
    printf "%s4)%s Serato Video: report\n" "$C_GRN" "$C_RESET"
    printf "%s5)%s Serato Video: transcode plan\n" "$C_GRN" "$C_RESET"
    printf "%s6)%s Resolution/duration report (ffprobe)\n" "$C_GRN" "$C_RESET"
    printf "%s7)%s Plan organize visuals by resolution\n" "$C_GRN" "$C_RESET"
    printf "%s8)%s Visual exact dupes by hash\n" "$C_GRN" "$C_RESET"
    printf "%s9)%s Visual optimization plan (suggest H.264 1080p)\n" "$C_GRN" "$C_RESET"
    printf "%s10)%s OSC plan from playlist (.m3u/.m3u8)\n" "$C_GRN" "$C_RESET"
    printf "%s11)%s DMX plan from playlist (Intro/Drop/Outro scenes)\n" "$C_GRN" "$C_RESET"
    printf "%s12)%s DMX presets beam+laser (editable template)\n" "$C_GRN" "$C_RESET"
    printf "%s13)%s DMX/Laser fixtures inventory (.ift/.qxf/.ssl/.d4)\n" "$C_GRN" "$C_RESET"
    printf "%s14)%s Advanced visuals transcode plan (ffmpeg suggestion)\n" "$C_GRN" "$C_RESET"
    printf "%sB)%s Back to main menu\n" "$C_YLW" "$C_RESET"
    printf "%sSelect an option:%s " "$C_BLU" "$C_RESET"
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
  printf "%sMain block 1-39:%s\n" "$C_YLW" "$C_RESET"
  printf "  1) Status / paths / locks: shows BASE_PATH and safety flags.\n"
  printf "  2) Change Base Path: sets the working root (affects reports/plans).\n"
  printf "  3) Volume summary: size + recent reports.\n"
  printf "  4) Top folders by size: finds storage hotspots.\n"
  printf "  5) Top large files: heaviest files in the base.\n"
  printf "  6) Scan workspace -> workspace_scan.tsv (full file listing).\n"
  printf "  9) SHA-256 index -> hash_index.tsv (foundation for exact dupes).\n"
  printf " 10) Dupes plan -> dupes_plan.json/tsv (uses hash_index).\n"
  printf " 11) Quarantine from dupes_plan.tsv (applies plan; honors SafeMode/Lock).\n"
  printf " 12) Quarantine Manager: list / restore / delete quarantine content.\n"
  printf " 13) ffprobe -> media_corrupt.tsv (find corrupt media files).\n"
  printf " 27) Integrity snapshot with progress bar (quick hash sample).\n"
  printf " 30) Organize by TAGS (genre) -> TSV plan.\n"
  printf " 31) Genre report and counts.\n"
  printf " 32-33) Video: report + transcode plan (Serato Video).\n"
  printf " 34-35) Rename plans and samples by type.\n"
  printf " 36-39) WEB submenu & tools (whitelist + cleaning tags/playlists).\n\n"

  printf "%sAdvanced block 40-52 (Deep Thinking / ML):%s\n" "$C_YLW" "$C_RESET"
  printf "  40) Smart Analysis: file/audio/video summary + quick tips.\n"
  printf "  41) ML Predictor: local heuristics (long names, empties, odd paths) with suggested action.\n"
  printf "  42) Optimizer: priority checklist (duplication, metadata, backup, snapshot).\n"
  printf "  43) Smart flow: recommended order (analysis -> backup -> dedupe -> cleanup).\n"
  printf "  44) Integrated dedupe: exact + fuzzy summary.\n"
  printf "  45-48) Metadata harmony, predictive backup, cross-platform sync.\n"
  printf "  49-52) Deep analysis, integration engine, recommendations, cleanup pipeline.\n"
  printf "  What it does: local inspection (hashes, sizes, names, tags) to prioritize cleanup/sync.\n"
  printf "  Examples: 40 gives quick tips; 41 flags suspicious paths; 44 mixes exact + fuzzy; 49 adds metrics.\n"
  printf "  Note: all analysis is local; nothing is sent out. Basic mode uses rules/stats; in 62 you can train a light local model.\n"
  printf "  Downloads: basic ~%s MB (numpy/pandas); evolutive ~%s MB (adds scikit-learn/joblib). TensorFlow optional (+%s MB) for advanced audio embeddings/auto-tagging.\n\n" "$ML_PKG_BASIC_MB" "$ML_PKG_EVO_MB" "$ML_PKG_TF_MB"

  printf "%sExtra tools 53-67:%s\n" "$C_YLW" "$C_RESET"
  printf "  53) Reset state / clean extras: delete _DJProducerTools or clean extra sources.\n"
  printf "  54) Profile manager (BASE/GENERAL/AUDIO roots): save/load path profiles.\n"
  printf "  55) Ableton Tools: quick .als report (samples/plugins used).\n"
  printf "  56) Rekordbox/Traktor importers: cues to TSV / NML summary.\n"
  printf "  57) Exclusion manager: view/save/load exclusion pattern profiles.\n"
  printf "  58) Compare hash_index across disks: find missing/extra files without re-hashing.\n"
  printf "  59) Health-check: _DJProducerTools space, quarantine/log sizes, cleanup hints.\n"
  printf "  60) Export/Import config only: move your setup without dragging reports/plans.\n"
  printf "  61) Mirror check: compare two hash_index by path and flag missing or differing hashes.\n"
  printf "  62) Evolutive ML: train a local model with your dupe plans and predict suspects without sending data.\n"
  printf "  63) Toggle ML ON/OFF: disable/enable all ML venv usage (Deep/ML/62).\n"
  printf "  64) Optional TensorFlow: install TF (+%s MB download) to unlock advanced embeddings/auto-tagging ideas.\n"
  printf "  65) TensorFlow Lab: auto-tagging (models: YAMNet/NNFP/VGGish/musicnn; 150 files, top3), similarity (presets: fast/balanced/strict), loops/suspects (placeholder), music tagging multi-label (150). Requires TF/tf_hub/soundfile.\n"
  printf "  66) LUFS plan (analysis, no normalization) – needs python3+pyloudnorm+soundfile.\n"
  printf "  67) Auto-cues via onsets (librosa) – needs python3+librosa.\n\n" "$ML_PKG_TF_MB"

  printf "%sSubmenu V) Visuals / DAW / OSC / DMX:%s\n" "$C_YLW" "$C_RESET"
  printf "  V1-V2: Ableton .als report and visuals inventory.\n"
  printf "  V4-V5: Serato Video (report + transcode plan).\n"
  printf "  V6-V9: ffprobe for resolution/duration, buckets by resolution, hash dupes, H.264 1080p suggestions.\n"
  printf "  V10-V11: build OSC/DMX plan from playlist (.m3u/.m3u8) to sync clips/scenes.\n"
  printf "  V12: DMX presets for Spider 8x6W + ALIEN laser; adjust channels/values to your mapping.\n"
  printf "  V13: DMX/laser fixtures inventory (.ift/.qxf/.ssl/.d4) – helps map models.\n"
  printf "  V14: advanced transcode plan with suggested ffmpeg (choose codec/bitrate/resolution).\n"
  printf "  Note: TSV outputs are templates; review before sending to DMX/OSC software or running ffmpeg.\n\n"

  printf "%sProcess quick-notes (what each does internally):%s\n" "$C_YLW" "$C_RESET"
  printf "  D4: indexes destination by name+size and lists missing from sources → TSV plan + rsync helper.\n"
  printf "  D6: marks extras in sources that already exist in destination (optional threshold) → TSV plan.\n"
  printf "  D7: fingerprints folder structures, suggests KEEP/REMOVE by date/size → cleanup plan.\n"
  printf "  D8: compares folders by content (hash of listings) to find mirrors → KEEP/REMOVE plan.\n"
  printf "  D9: builds YAMNet embeddings and lists similar audio pairs (sim>=0.60) → REVIEW plan.\n"
  printf "  10/11: use hash_index/dupes_plan; 11 applies quarantine (moves into _DJProducerTools/quarantine).\n"
  printf "  62: trains a light model (scikit-learn) with your plans; then predicts suspects (max 5000).\n"
  printf "  64: installs TensorFlow in the venv (not by default); 65 uses TF Hub (YAMNet/music tagging) if present.\n"
  printf "  66: calculates LUFS per file and suggests gain (does not modify audio).\n"
  printf "  67: finds onsets and proposes initial cue (does not write tags, TSV only).\n\n"

  printf "%sSubmenu A) Automations (chains):%s\n" "$C_YLW" "$C_RESET"
  printf "  A1-A10: predefined flows (backup+snapshot, dedup+quarantine, metadata/name cleanup, health scan, show prep, integrity, efficiency, basic ML, predictive backup, cross-platform sync).\n"
  printf "  A11-A14: quick diagnostics, Serato health, hash+mirror check, audio prep (tags+LUFS+cues).\n"
  printf "  A15-A20: integrity audit, cleanup+backup, sync prep, visuals health, advanced audio org, Serato safety.\n"
  printf "  Tip: SafeMode/DJ_SAFE_LOCK still apply (quarantine/ops stay protected).\n\n"

  printf "%sTF models available (pros/cons + approx first download size):%s\n" "$C_YLW" "$C_RESET"
  printf "  YAMNet (~40MB): fast, general (events/ambience), good for basic similarity.\n"
  printf "  Music Tagging NNFP (~70MB): music-oriented, better for genres/styles; slightly heavier.\n"
  printf "  VGGish (~70MB): classic embeddings, light; less music-focused than musicnn/NNFP.\n"
  printf "  Musicnn (~80-100MB): music-focused, strong tagging/similarity; heavier.\n"
  printf "  Note: sizes are approximate; downloaded once at first use.\n\n"

  printf "%sSubmenu L) DJ Libraries & Cues:%s\n" "$C_YLW" "$C_RESET"
  printf "  L1) Configure Serato/Rekordbox/Traktor/Ableton paths.\n"
  printf "  L2) Audio catalog across DJ libraries.\n"
  printf "  L3) Duplicates by basename+size.\n"
  printf "  L4) Rekordbox XML cues -> dj_cues.tsv (placeholder).\n"
  printf "  L5) dj_cues.tsv -> ableton_locators.csv (placeholder).\n"
  printf "  L6) Library inventory (Serato/Traktor/Rekordbox/Ableton/Serato Video).\n\n"

  printf "%sSubmenu D) General duplicates:%s\n" "$C_YLW" "$C_RESET"
  printf "  D1) General catalog per disk.\n"
  printf "  D2) General duplicates by basename+size.\n"
  printf "  D3) Smart report (Deep/ML) on duplicates.\n"
  printf "  D4) Multi-disk consolidation (safe plan, add missing files).\n"
  printf "  D5) Exact duplicate plan by hash (all extensions).\n"
  printf "  D6) Inverse consolidation: extras in sources already in destination (optional threshold).\n"
  printf "  D7) Matrioshkas: duplicate folder structures (suggest KEEP/REMOVE).\n"
  printf "  D8) Mirror folders: duplicates by content (name+size or full hash).\n"
  printf "  D9) Audio similarity (YAMNet embeddings, requires TF).\n\n"

  printf "%sOptional ML environment (for 40-52 and D3):%s\n" "$C_YLW" "$C_RESET"
  printf "  Lives in: %s/venv\n" "$STATE_DIR"
  printf "  Suggested once:\n"
  printf "    python3 -m venv \"%s\"\n" "$VENV_DIR"
  printf "    source \"%s/bin/activate\" && pip install --upgrade pip\n" "$VENV_DIR"
  printf "  Keeps system clean and portable across Macs/disks.\n\n"

  printf "%sInfrastructure:%s\n" "$C_YLW" "$C_RESET"
  printf "  Config:   %s\n" "$CONF_FILE"
  printf "  State:    %s\n" "$STATE_DIR"
  printf "  Reports:  %s\n" "$REPORTS_DIR"
  printf "  Plans:    %s\n" "$PLANS_DIR"
  printf "  ML venv:  %s (basic: numpy/pandas ~%s MB; evolutive adds scikit-learn/joblib ~%s MB). Always asks before installing.\n" "$VENV_DIR" "$ML_PKG_BASIC_MB" "$ML_PKG_EVO_MB"
  pause_enter
}

main_loop() {
  while true; do
    print_header
    print_menu
    printf "%sOption:%s " "$C_BLU" "$C_RESET"
    if ! read -r op </dev/tty 2>/dev/null; then
      printf "%s[WARN]%s Input unavailable (double click / no keyboard). Press ENTER to close.\n" "$C_YLW" "$C_RESET"
      pause_enter
      break
    fi
    # Ignore pyenv noise or empty lines in non-interactive shells
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
      68) submenu_A_chains ;;
      69) action_69_artist_pages ;;
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

# If GENERAL_ROOT is set and valid, prefer it as BASE_PATH
if [ -n "${GENERAL_ROOT:-}" ] && [ -d "$GENERAL_ROOT" ] && [ "$BASE_PATH" != "$GENERAL_ROOT" ]; then
  BASE_PATH="$GENERAL_ROOT"
  init_paths
  load_conf
fi

# If launched from a different path than BASE_PATH, add it as an extra source
if [ -n "$LAUNCH_PATH" ] && [ "$LAUNCH_PATH" != "$BASE_PATH" ] && [ -d "$LAUNCH_PATH" ]; then
  append_extra_root "$LAUNCH_PATH"
fi

init_paths
save_conf
main_loop
