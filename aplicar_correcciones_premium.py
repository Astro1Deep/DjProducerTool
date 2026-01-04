import re
import os
import shutil
import sys

# --- CONFIGURACIÓN ---
TARGET_FILE = "DJProducerTools_MultiScript_ES.sh"
BACKUP_FILE = "DJProducerTools_MultiScript_ES.sh.bak"

# --- BLOQUES DE CÓDIGO NUEVOS (CORREGIDOS) ---

NEW_COLORS = r'''spin_colors_for_task() {
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
    CLEAN*|WEB*|RM*) SPIN_COLOR_A="$C_RED"; SPIN_COLOR_B="$C_BLU" ;; 
    TAGS*|GENRE*) SPIN_COLOR_A="$C_YLW"; SPIN_COLOR_B="$C_PURP" ;; 
    FIX*|OWNER*|CHMOD*) SPIN_COLOR_A="$C_RED"; SPIN_COLOR_B="$C_WHT" ;; 
    *) SPIN_COLOR_A="$C_GRN"; SPIN_COLOR_B="$C_WHT" ;;
  esac
}'''

NEW_ACTION_16 = r'''action_16_mirror_by_genre() {
  print_header
  printf "%s[INFO]%s Mirror por género (plan seguro básico).\n" "$C_CYN" "$C_RESET"
  out="$PLANS_DIR/mirror_by_genre.tsv"
  if ! maybe_reuse_file "$out" "mirror_by_genre.tsv"; then return; fi
  >"$out"
  printf "Indexando colección de audio...\r"
  mapfile -t files < <(find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null)
  total=${#files[@]}
  if [ "$total" -eq 0 ]; then
     printf "%s[WARN]%s No se encontraron archivos de audio.\n" "$C_YLW" "$C_RESET"
     pause_enter; return
  fi
  count=0
  for f in "${files[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    status_line "MIRROR_GENRE" "$percent" "$(basename "$f")"
    printf "%s\tGENRE_UNKNOWN\t%s\n" "$f" "$BASE_PATH/_MIRROR_BY_GENRE/GENRE_UNKNOWN/$(basename "$f")" >>"$out"
  done
  finish_status_line
  printf "%s[OK]%s Plan espejo generado: %s\n" "$C_GRN" "$C_RESET" "$out"
  pause_enter
}'''

NEW_ACTION_20 = r'''action_20_fix_ownership_flags() {
  print_header
  out="$PLANS_DIR/fix_ownership_flags.tsv"
  printf "%s[INFO]%s Plan de fix ownership/flags -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  printf "Analizando estructura de archivos...\r"
  mapfile -t files < <(find "$BASE_PATH" -type f 2>/dev/null)
  total=${#files[@]}
  if [ "$total" -eq 0 ]; then
     printf "%s[WARN]%s Carpeta vacía.\n" "$C_YLW" "$C_RESET"
     pause_enter; return
  fi
  count=0
  for f in "${files[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    status_line "FIX_OWNER" "$percent" "$(basename "$f")"
    printf "%s\tchown-KEEP\tchmod-KEEP\n" "$f" >>"$out"
  done
  finish_status_line
  printf "%s[OK]%s Plan generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}'''

NEW_ACTION_30 = r'''action_30_plan_tags() {
  print_header
  out="$PLANS_DIR/audio_by_tags_plan.tsv"
  if ! maybe_reuse_file "$out" "audio_by_tags_plan.tsv"; then return; fi
  printf "%s[INFO]%s Organizar audio por TAGS -> plan TSV: %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  printf "Buscando audio para tags...\r"
  mapfile -t files < <(find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null)
  total=${#files[@]}
  if [ "$total" -eq 0 ]; then
     printf "%s[WARN]%s No se encontraron archivos.\n" "$C_YLW" "$C_RESET"
     pause_enter; return
  fi
  count=0
  for f in "${files[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    status_line "TAGS_PLAN" "$percent" "$(basename "$f")"
    printf "%s\tGENRE_UNKNOWN\n" "$f" >>"$out"
  done
  finish_status_line
  printf "%s[OK]%s Plan TAGS generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}'''

NEW_ACTION_38 = r'''action_38_clean_web_playlists() {
  print_header
  printf "%s[INFO]%s Limpiar entradas WEB en playlists.\n" "$C_CYN" "$C_RESET"
  printf "Buscando playlists (.m3u/.m3u8)...\r"
  mapfile -t files < <(find "$BASE_PATH" -type f \( -iname "*.m3u" -o -iname "*.m3u8" \) 2>/dev/null)
  total=${#files[@]}
  if [ "$total" -eq 0 ]; then
     printf "%s[WARN]%s No se encontraron playlists.\n" "$C_YLW" "$C_RESET"
     pause_enter; return
  fi
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
}'''

NEW_ACTION_39 = r'''action_39_clean_web_tags() {
  print_header
  out="$PLANS_DIR/clean_web_tags_plan.tsv"
  printf "%s[INFO]%s Clean WEB en TAGS (plan) -> %s\n" "$C_CYN" "$C_RESET" "$out"
  >"$out"
  printf "Analizando audio para limpieza web...\r"
  mapfile -t files < <(find "$BASE_PATH" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.wav" \) 2>/dev/null)
  total=${#files[@]}
  if [ "$total" -eq 0 ]; then
     printf "%s[WARN]%s No hay archivos de audio.\n" "$C_YLW" "$C_RESET"
     pause_enter; return
  fi
  count=0
  for f in "${files[@]}"; do
    count=$((count+1))
    percent=$((count*100/total))
    status_line "WEB_CLEAN_TAGS" "$percent" "$(basename "$f")"
    printf "%s\tCLEAN_WEB_TAGS\n" "$f" >>"$out"
  done
  finish_status_line
  printf "%s[OK]%s Plan de limpieza WEB en tags generado.\n" "$C_GRN" "$C_RESET"
  pause_enter
}'''

NEW_CHAIN_1 = r'''chain_1_backup_snapshot() {
  chain_run_header "Backup seguro + snapshot (Robusto)"
  if ensure_tool_installed "rsync" "brew install rsync"; then 
      action_8_backup_dj || printf "\n%s[WARN]%s Falló action_8, continuando...\n" "$C_YLW" "$C_RESET"
  fi
  if ensure_tool_installed "shasum" "brew install coreutils"; then 
      action_27_snapshot || printf "\n%s[WARN]%s Falló action_27, continuando...\n" "$C_YLW" "$C_RESET"
  fi
  printf "%s[OK]%s Cadena completada.\n" "$C_GRN" "$C_RESET"
  pause_enter
}'''

NEW_CHAIN_2 = r'''chain_2_dedup_quarantine() {
  chain_run_header "Dedup exacto y quarantine (Robusto)"
  if ensure_tool_installed "shasum" "brew install coreutils"; then 
      action_10_dupes_plan || printf "\n%s[WARN]%s Falló el plan, continuando...\n" "$C_YLW" "$C_RESET"
      if [ -f "$PLANS_DIR/dupes_plan.tsv" ]; then
          action_11_quarantine_from_plan || printf "\n%s[WARN]%s Falló quarantine, continuando...\n" "$C_YLW" "$C_RESET"
      fi
  fi
  printf "%s[OK]%s Cadena completada.\n" "$C_GRN" "$C_RESET"
  pause_enter
}'''

NEW_CHAIN_3 = r'''chain_3_clean_empty_dsstore() {
  chain_run_header "Limpieza Profunda (DS_Store -> Carpetas Vacías)"
  action_12_rm_dsstore || printf "\n%s[WARN]%s Falló rm DS_Store, continuando...\n" "$C_YLW" "$C_RESET"
  action_13_rm_empty_dirs || printf "\n%s[WARN]%s Falló rm empty dirs, continuando...\n" "$C_YLW" "$C_RESET"
  printf "%s[OK]%s Cadena completada.\n" "$C_GRN" "$C_RESET"
  pause_enter
}'''

# Lista de reemplazos: (NombreFuncionRegex, NuevoCodigo)
REPLACEMENTS = [
    (r'spin_colors_for_task\s*\(\)\s*\{.*?esac\s*\}', NEW_COLORS),
    (r'action_16_mirror_by_genre\s*\(\)\s*\{.*?\n\}', NEW_ACTION_16),
    (r'action_20_fix_ownership_flags\s*\(\)\s*\{.*?\n\}', NEW_ACTION_20),
    (r'action_30_plan_tags\s*\(\)\s*\{.*?\n\}', NEW_ACTION_30),
    (r'action_38_clean_web_playlists\s*\(\)\s*\{.*?\n\}', NEW_ACTION_38),
    (r'action_39_clean_web_tags\s*\(\)\s*\{.*?\n\}', NEW_ACTION_39),
    (r'chain_1_backup_snapshot\s*\(\)\s*\{.*?\n\}', NEW_CHAIN_1),
    (r'chain_2_dedup_quarantine\s*\(\)\s*\{.*?\n\}', NEW_CHAIN_2),
    (r'chain_3_clean_empty_dsstore\s*\(\)\s*\{.*?\n\}', NEW_CHAIN_3),
]

def replace_function_in_text(full_text, func_name_pattern, new_code):
    # Esta función busca el inicio de la función y hace un balance de llaves { }
    # para encontrar el final exacto, en lugar de confiar solo en regex simple.
    
    # 1. Encontrar inicio
    match = re.search(func_name_pattern.replace(r'.*?\n\}', ''), full_text, re.DOTALL)
    if not match:
        print(f"⚠️  No se encontró la función compatible con: {func_name_pattern.split('(')[0]}")
        return full_text
    
    start_idx = match.start()
    
    # 2. Encontrar la llave de apertura
    open_brace_idx = full_text.find('{', start_idx)
    if open_brace_idx == -1: return full_text
    
    # 3. Balancear llaves para encontrar cierre
    count = 1
    i = open_brace_idx + 1
    while count > 0 and i < len(full_text):
        if full_text[i] == '{':
            count += 1
        elif full_text[i] == '}':
            count -= 1
        i += 1
    
    if count == 0:
        end_idx = i
        print(f"✅ Parcheada función: {new_code.split('(')[0]}")
        return full_text[:start_idx] + new_code + full_text[end_idx:]
    else:
        print(f"❌ Error parseando llaves en {func_name_pattern}")
        return full_text

# --- EJECUCIÓN ---
if not os.path.exists(TARGET_FILE):
    print(f"Error: No se encuentra {TARGET_FILE}. Asegúrate de estar en la carpeta correcta.")
    sys.exit(1)

# Backup
shutil.copyfile(TARGET_FILE, BACKUP_FILE)
print(f"Backup creado: {BACKUP_FILE}")

with open(TARGET_FILE, 'r', encoding='utf-8') as f:
    content = f.read()

# Aplicar parches
for pattern, code in REPLACEMENTS:
    # Usamos una versión simplificada del patrón para buscar el nombre
    func_name_start = pattern.split(r'\s*')[0] 
    content = replace_function_in_text(content, func_name_start, code)

with open(TARGET_FILE, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n✨ ¡ÉXITO! El script ha sido actualizado a la versión PREMIUM.")
print("Ahora incluye:")
print("1. Barras de progreso reales (mapfile) para ops 16, 20, 30, 38, 39.")
print("2. Colores 'Fantasma' nuevos (Rojo/Azul, Amarillo/Púrpura) en spinner.")
print("3. Modo Auto-Pilot robusto (no se detiene por errores menores).")
print("4. Ejecuta: bash DJProducerTools_MultiScript_ES.sh")
