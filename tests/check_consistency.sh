#!/bin/bash
#
# check_consistency.sh
# Verifica la consistencia interna de los scripts (menús, funciones, cadenas).

set -e

SCRIPT_DIR="$(cd -- "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 1

FAIL_COUNT=0

C_RESET="\033[0m"
C_RED="\033[1;31m"
C_GRN="\033[1;32m"
C_YLW="\033[1;33m"
C_CYN="\033[1;36m"

fail() {
    echo -e "${C_RED}❌ FAIL: $1${C_RESET}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

pass() {
    echo -e "${C_GRN}✅ PASS: $1${C_RESET}"
}

info() {
    echo -e "${C_CYN}🔎 $1${C_RESET}"
}

get_template_for_file() {
    local missing_file="$1"
    case "$missing_file" in
        "README_es.md") echo "README_en.md" ;;
        "README_en.md") echo "README_es.md" ;;
        "GUIDE_es.md") echo "GUIDE_en.md" ;;
        "GUIDE_en.md") echo "GUIDE_es.md" ;;
        "LICENSE_es.md") echo "LICENSE_en.md" ;;
        "LICENSE_en.md") echo "LICENSE_es.md" ;;
        "GUIDE.md") echo "GUIDE_en.md" ;;
        "LICENSE.md") echo "LICENSE_en.md" ;;
        "README.md") echo "" ;; # No good template for the main README
        *) echo "" ;;
    esac
}

check_script() {
    local script_file="$1"
    info "Verificando consistencia para: $script_file"

    # 1. Extraer todas las opciones del menú principal
    local menu_options
    menu_options=$(grep -E "printf \".*%s[0-9]+\)%" "$script_file" | sed -E 's/.*%s([0-9]+)\)%.*/\1/')

    # 2. Extraer todas las entradas 'case' del bucle principal
    local case_options
    case_options=$(awk '/case "\$op" in/,/esac/' "$script_file" | grep -E '^[[:space:]]*[0-9]+\)' | sed 's/)\s*.*//' | tr -d ' ')

    # 3. Extraer todas las funciones 'action_' definidas
    local defined_actions
    defined_actions=$(grep -E "^action_[a-zA-Z0-9_]+\(\)" "$script_file" | sed 's/() {//' | tr -d ' ')

    # --- CHECK 1: Opciones de menú vs. entradas 'case' ---
    info "Check 1: Opciones de menú tienen una entrada 'case'..."
    local all_ok=1
    for opt in $menu_options; do
        if ! echo "$case_options" | grep -q -w "$opt"; then
            fail "La opción de menú '$opt' no tiene una entrada 'case' en main_loop."
            all_ok=0
        fi
    done
    [ "$all_ok" -eq 1 ] && pass "Todas las opciones del menú están en el 'case'."

    # --- CHECK 2: Entradas 'case' vs. opciones de menú ---
    info "Check 2: Entradas 'case' tienen una opción de menú..."
    all_ok=1
    for opt in $case_options; do
        if ! echo "$menu_options" | grep -q -w "$opt"; then
            fail "La entrada 'case' para '$opt' no tiene una opción de menú correspondiente."
            all_ok=0
        fi
    done
    [ "$all_ok" -eq 1 ] && pass "Todas las entradas 'case' tienen un menú."

    # --- CHECK 3: Entradas 'case' llaman a funciones existentes ---
    info "Check 3: Entradas 'case' llaman a funciones 'action_' que existen..."
    all_ok=1
    local case_actions
    case_actions=$(awk '/case "\$op" in/,/esac/' "$script_file" | grep ';;' | sed -E 's/.*(action_[a-zA-Z0-9_]+|submenu_[a-zA-Z0-9_]+).*/\1/')

    for action in $case_actions; do
        if [[ "$action" == action_* ]] || [[ "$action" == submenu_* ]]; then
            if ! echo "$defined_actions" | grep -q -w "$action"; then
                fail "La función '$action' llamada en 'case' no está definida."
                all_ok=0
            fi
        fi
    done
    [ "$all_ok" -eq 1 ] && pass "Todas las funciones llamadas en 'case' existen."

    # --- CHECK 4: Cadenas automatizadas ---
    info "Check 4: Consistencia de las cadenas automatizadas (menú A)..."
    all_ok=1
    local chain_defs
    chain_defs=$(grep -E 'printf ".*%s[0-9]+\)%' "$script_file" | grep '->')

    while IFS= read -r line; do
        # Extraer: chain_X, descripción (Y -> Z), y la función chain_X_...
        local chain_num=$(echo "$line" | sed -E 's/.*%s([0-9]+)\)%.*/\1/')
        local chain_desc=$(echo "$line" | sed -E 's/.*(\([0-9V ]+->[0-9V ->]+\)).*/\1/')
        local chain_func_body
        chain_func_body=$(awk "/^chain_${chain_num}_.*\(.*\)/,/\}/" "$script_file")

        # Extraer números de la descripción
        local nums_in_desc=$(echo "$chain_desc" | grep -o -E '[0-9]+')

        for num in $nums_in_desc; do
            # Verificar si la función action_NUM... es llamada en el cuerpo de la cadena
            if ! echo "$chain_func_body" | grep -q "action_${num}_"; then
                fail "Cadena A)$chain_num: la descripción dice '-> $num' pero no se llama a 'action_${num}_...' en la función."
                all_ok=0
            fi
        done
    done <<< "$chain_defs"
    [ "$all_ok" -eq 1 ] && pass "Las descripciones de las cadenas parecen consistentes con sus llamadas."

    echo ""
}

# --- Ejecutar verificaciones ---
check_script "DJProducerTools_MultiScript_ES.sh"
check_script "DJProducerTools_MultiScript_EN.sh"

# --- CHECK 5: Archivos de documentación ---
info "Verificando existencia de archivos de documentación..."
all_ok=1
doc_files=(
    "README.md" "README_ES.md"
    "guides/GUIDE.md" "guides/GUIDE_es.md"
    "guides/ADVANCED_GUIDE.md" "guides/ADVANCED_GUIDE_es.md"
    "LICENSE" "LICENSE.md"
)
for doc_file in "${doc_files[@]}"; do
    if [ ! -f "$doc_file" ]; then
        template=$(get_template_for_file "$doc_file")
        if [ -n "$template" ] && [ -f "$template" ]; then
            read -p "🤔 El archivo '$doc_file' no se encuentra. ¿Crearlo a partir de '$template'? (y/N): " ans
            if [[ "$ans" =~ ^[yY]$ ]]; then
                if [[ "$doc_file" == *_es.md ]]; then
                    (
                        echo "> **AVISO: TRADUCCIÓN PENDIENTE**"
                        echo ""
                        cat "$template"
                    ) > "$doc_file"
                elif [[ "$doc_file" == *_en.md ]]; then
                    (
                        echo "> **NOTICE: TRANSLATION PENDING**"
                        echo ""
                        cat "$template"
                    ) > "$doc_file"
                fi
                echo -e "${C_GRN}   -> Creado '$doc_file' a partir de '$template' con aviso de traducción.${C_RESET}"
            else
                fail "El archivo de documentación '$doc_file' no se encuentra."
                all_ok=0
            fi
        elif [ "$doc_file" == "README.md" ]; then
             read -p "🤔 El archivo principal 'README.md' no se encuentra. ¿Crear uno básico? (y/N): " ans
            if [[ "$ans" =~ ^[yY]$ ]]; then
                echo "# DJProducerTools" > "$doc_file"
                echo "Welcome! See README_en.md or README_es.md for details." >> "$doc_file"
                echo -e "${C_GRN}   -> Creado 'README.md' básico.${C_RESET}"
            fi
        else
            fail "El archivo de documentación '$doc_file' no se encuentra y no hay plantilla disponible."
            all_ok=0
        fi
    fi
done
[ "$all_ok" -eq 1 ] && pass "Todos los archivos de documentación requeridos existen."

# --- CHECK 5b: Paridad de versión (VERSION vs SCRIPT_VERSION) ---
info "Verificando paridad de versión..."
version_file=$(awk -F= '/^VERSION=/{print $2}' VERSION 2>/dev/null | tr -d '[:space:]')
script_version_en=$(awk -F= '/^SCRIPT_VERSION=/{print $2}' scripts/DJProducerTools_MultiScript_EN.sh 2>/dev/null | tr -d '\"[:space:]')
script_version_es=$(awk -F= '/^SCRIPT_VERSION=/{print $2}' scripts/DJProducerTools_MultiScript_ES.sh 2>/dev/null | tr -d '\"[:space:]')

if [ -z "$version_file" ] || [ -z "$script_version_en" ] || [ -z "$script_version_es" ]; then
    fail "No se pudieron leer las versiones (VERSION=${version_file:-<vacío>}, EN=${script_version_en:-<vacío>}, ES=${script_version_es:-<vacío>})."
else
    if [ "$version_file" != "$script_version_en" ] || [ "$version_file" != "$script_version_es" ]; then
        fail "VERSION (${version_file}) no coincide con SCRIPT_VERSION EN (${script_version_en}) o ES (${script_version_es})."
    else
        pass "VERSION y SCRIPT_VERSION coinciden (${version_file})."
    fi
fi

# --- CHECK 6: Check for pending TODOs or FIXMEs ---
info "Verificando si hay TODOs o FIXMEs pendientes..."
todo_hits=$(grep -rniE "TODO|FIXME" --exclude-dir={.git,_DJProducerTools,build_pkg_staging,release,docs,venv} . 2>/dev/null || true)

if [ -n "$todo_hits" ]; then
    fail "Se encontraron TODOs o FIXMEs pendientes. Revisa antes del release:"
    echo "$todo_hits" | while IFS= read -r line; do
        echo "  - $line"
    done
else
    pass "No se encontraron TODOs o FIXMEs pendientes."
fi

# --- CHECK 7: Validación de sintaxis con shellcheck ---
info "Verificando sintaxis de scripts con shellcheck..."
if ! command -v shellcheck &> /dev/null; then
    echo -e "${C_YLW}⚠️  ADVERTENCIA: 'shellcheck' no está instalado. Saltando validación de sintaxis.${C_RESET}"
    echo -e "${C_YLW}   Para habilitar esta comprobación, ejecuta: brew install shellcheck${C_RESET}"
else
    all_ok=1
    # Usamos find para buscar todos los scripts .sh en el directorio del proyecto
    while IFS= read -r sh_file; do
        # Ignoramos SC1090/SC1091 porque los scripts se cargan dinámicamente
        if ! shellcheck --exclude SC1090,SC1091 "$sh_file"; then
            fail "Shellcheck encontró problemas en '$sh_file'."
            all_ok=0
        fi
    done < <(find . -name "*.sh")
    [ "$all_ok" -eq 1 ] && pass "Todos los scripts .sh pasaron la validación de shellcheck."
fi

# --- CHECK 8: Scan for hardcoded secrets ---
info "Verificando si hay secretos hardcodeados..."
all_ok=1
# Patterns for secrets. Add more as needed.
# ghp_ for GitHub tokens, _KEY, _TOKEN, _SECRET, _PASSWORD common suffixes/substrings
secret_patterns='ghp_[a-zA-Z0-9]{36}|[A-Z_]+_(KEY|TOKEN|SECRET|PASSWORD)'
secret_hits=$(grep -rniE "$secret_patterns" --exclude-dir={.git,_DJProducerTools,build_pkg_staging,release,docs,venv,tests} . 2>/dev/null || true)

# Filter out false positives from the build script's configuration section
secret_hits=$(echo "$secret_hits" | grep -vE "build_macos_pkg.sh:.*# APPLE_ID_APP_PASSWORD|build_release_pack.sh:.*# GITHUB_TOKEN")

if [ -n "$secret_hits" ]; then
    fail "Se encontraron posibles secretos hardcodeados. Revisa antes del release:"
    echo "$secret_hits" | while IFS= read -r line; do
        echo "  - $line"
    done
    all_ok=0
else
    pass "No se encontraron secretos hardcodeados."
fi

# --- Resumen final ---
echo "-------------------------------------"
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${C_GRN}🎉 ¡Verificación de consistencia completada! Todo parece estar en orden.${C_RESET}"
    exit 0
else
    echo -e "${C_RED}🔥 Se encontraron $FAIL_COUNT problemas de consistencia. Por favor, revisa los errores de arriba.${C_RESET}"
    exit 1
fi
