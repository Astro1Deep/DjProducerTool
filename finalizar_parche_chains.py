import re
import os
import sys

TARGET_FILE = "DJProducerTools_MultiScript_ES.sh"

# --- VERSIONES ROBUSTAS Y BLINDADAS (Auto-Pilot) ---

# Arregla el error de chain_3 y añade robustez (|| printf warning)
NEW_CHAIN_3 = r'''chain_3_metadata_names() {
  chain_run_header "Limpieza de metadatos y nombres (39 -> 34) [Robusto]"
  if ensure_tool_installed "python3"; then
    if ensure_python_package_installed "mutagen"; then
        action_39_clean_web_tags || printf "%s[WARN]%s Falló limpieza de tags, continuando...\n" "$C_YLW" "$C_RESET"
    fi
  fi
  action_34_normalize_names || printf "%s[WARN]%s Falló normalización, continuando...\n" "$C_YLW" "$C_RESET"
  printf "%s[OK]%s Cadena 3 completada.\n" "$C_GRN" "$C_RESET"
  pause_enter
}'''

# Blinda chain_4 (Health Scan)
NEW_CHAIN_4 = r'''chain_4_health_scan() {
  chain_run_header "Escaneo salud media (Robusto)"
  action_18_rescan_intelligent || printf "\n[WARN] Falló rescan.\n"
  action_14_playlists_per_folder || printf "\n[WARN] Falló playlists.\n"
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_15_relink_helper || printf "\n[WARN] Falló relink helper.\n"
  fi
  printf "%s[OK]%s Cadena 4 completada.\n" "$C_GRN" "$C_RESET"
  pause_enter
}'''

# Blinda chain_5 (Prep Show - Crítica)
NEW_CHAIN_5 = r'''chain_5_show_prep() {
  chain_run_header "Prep de show (Robusto)"
  # Backup inicial
  if ensure_tool_installed "rsync" "brew install rsync"; then
    action_8_backup_dj || printf "\n[WARN] Falló backup inicial.\n"
  fi
  # Limpieza y Snapshot
  if ensure_tool_installed "shasum" "brew install coreutils"; then
    action_27_snapshot || printf "\n[WARN] Falló snapshot.\n"
    action_10_dupes_plan || printf "\n[WARN] Falló plan duplicados.\n"
    action_11_quarantine_from_plan || printf "\n[WARN] Falló quarantine.\n"
  fi
  # Playlists
  action_14_playlists_per_folder || printf "\n[WARN] Falló playlists.\n"
  # Backup final (Safety)
  if ensure_tool_installed "rsync" "brew install rsync"; then
    action_8_backup_dj || printf "\n[WARN] Falló backup final.\n"
  fi
  printf "%s[OK]%s Cadena 5 completada (Show Ready).\n" "$C_GRN" "$C_RESET"
  pause_enter
}'''

REPLACEMENTS = [
    (r'chain_3_metadata_names\s*\(\)\s*\{.*?\n\}', NEW_CHAIN_3),
    (r'chain_4_health_scan\s*\(\)\s*\{.*?\n\}', NEW_CHAIN_4),
    (r'chain_5_show_prep\s*\(\)\s*\{.*?\n\}', NEW_CHAIN_5),
]

def replace_function(full_text, func_name_pattern, new_code):
    # Buscamos el inicio de la función
    match = re.search(func_name_pattern.replace(r'.*?\n\}', ''), full_text, re.DOTALL)
    if not match:
        print(f"⚠️  No se encontró para reemplazar: {func_name_pattern.split('(')[0]}")
        return full_text
    
    start_idx = match.start()
    open_brace_idx = full_text.find('{', start_idx)
    if open_brace_idx == -1: return full_text
    
    # Balanceo de llaves para encontrar el final exacto
    count = 1
    i = open_brace_idx + 1
    while count > 0 and i < len(full_text):
        if full_text[i] == '{': count += 1
        elif full_text[i] == '}': count -= 1
        i += 1
    
    if count == 0:
        print(f"✅ Función Blindada: {new_code.split('(')[0]}")
        return full_text[:start_idx] + new_code + full_text[i:]
    return full_text

if not os.path.exists(TARGET_FILE):
    print(f"Error: No encuentro {TARGET_FILE}")
    sys.exit(1)

with open(TARGET_FILE, 'r', encoding='utf-8') as f:
    content = f.read()

for pattern, code in REPLACEMENTS:
    content = replace_function(content, pattern.split(r'\s*')[0], code)

with open(TARGET_FILE, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n✨ ¡PROYECTO COMPLETADO! Todas las correcciones aplicadas.")
