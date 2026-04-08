#!/usr/bin/env bash
# 🛡️ DJProducerTools ROBUSTNESS CORE
# Autor: IA Architect (Genius Mode)
# Propósito: Funciones de red blindadas, manejo de errores y UX sublime.

# Configuración de Tiempos
TIMEOUT_CONNECT=5
TIMEOUT_MAX=30
RETRIES=3

# Colores de Alta Fidelidad
C_GOLD='\033[38;5;220m'
C_SLATE='\033[38;5;60m'
C_ERROR='\033[38;5;196m'
C_OK='\033[38;5;46m'
C_WARN='\033[38;5;208m'
C_RESET='\033[0m'

# ==============================================================================
# 🛡️ EJECUCIÓN SEGURA (SAFE EXECUTION)
# ==============================================================================

safe_run() {
    local description="$1"
    shift

    printf "${C_GOLD}🔒 Ejecutando operación crítica: %s${C_RESET}\n" "$description"

    # Run strict mode in a subshell so failures return cleanly to caller.
    (
      set -euo pipefail
      "$@"
    )
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        printf "${C_OK}✅ Operación completada exitosamente: %s${C_RESET}\n" "$description"
        return 0
    else
        printf "${C_ERROR}❌ Falló operación crítica: %s (código %d)${C_RESET}\n" "$description" "$exit_code"
        return $exit_code
    fi
}

# ==============================================================================
# 🌐 CONECTIVIDAD BLINDADA (IRONCLAD NETWORK)
# ==============================================================================

check_connectivity() {
    printf "${C_SLATE}📡 Verificando enlace neuronal con la red...${C_RESET} "
    if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        printf "${C_OK}CONECTADO${C_RESET}\n"
        return 0
    else
        printf "${C_ERROR}SIN SEÑAL${C_RESET}\n"
        return 1
    fi
}

secure_download() {
    local url="$1"
    local output="$2"
    local desc="$3"
    
    printf "${C_GOLD}⬇️  Descargando: %s${C_RESET}\n" "$desc"
    
    local attempt=1
    while [ $attempt -le $RETRIES ]; do
        if curl -L --fail --connect-timeout $TIMEOUT_CONNECT --max-time $TIMEOUT_MAX --progress-bar -o "$output" "$url"; then
            printf "${C_OK}✅ Descarga completada e íntegra.${C_RESET}\n"
            return 0
        else
            printf "${C_WARN}⚠️  Fallo en intento %d/%d. Reintentando en 2s...${C_RESET}\n" "$attempt" "$RETRIES"
            sleep 2
            attempt=$((attempt + 1))
        fi
    done
    
    printf "${C_ERROR}❌ Error fatal: No se pudo descargar el recurso tras %d intentos.${C_RESET}\n" "$RETRIES"
    return 1
}

# ==============================================================================
# 🧠 PUENTE NEURAL IA (CIRCUIT BREAKER)
# ==============================================================================

safe_ai_execution() {
    local script_path="$1"
    shift
    local args="$@"
    
    # 1. Verificación de Existencia
    if [ ! -f "$script_path" ]; then
        printf "${C_ERROR}🧠 Error Lobular: El script de IA no existe en: %s${C_RESET}\n" "$script_path"
        return 1
    fi
    
    # 2. Verificación de Entorno
    if ! command -v python3 &> /dev/null; then
         printf "${C_ERROR}🧠 Fallo Sináptico: Python3 no detectado.${C_RESET}\n"
         return 1
    fi
    
    # 3. Ejecución Controlada con safe_run
    printf "${C_SLATE}🔮 Invocando Inteligencia Artificial...${C_RESET}\n"
    
    safe_run "Ejecución de script IA" python3 "$script_path" $args
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        return 0
    else
        printf "\n${C_ERROR}💥 La IA encontró una anomalía (Código %d).${C_RESET}\n" "$exit_code"
        printf "${C_SLATE}💡 Sugerencia: Revisa tu conexión a internet o las API Keys.${C_RESET}\n"
        if [ -t 0 ] && [ "${DJPT_NO_INTERACTIVE:-0}" -ne 1 ]; then
            read -n 1 -s -r -p "Presiona cualquier tecla para volver al modo manual..."
        fi
        return $exit_code
    fi
}

# ==============================================================================
# 🎨 DISEÑO ELOCUENTE (ELOQUENT UX)
# ==============================================================================

draw_option() {
    local key="$1"
    local title="$2"
    local desc="$3"
    
    # Diseño de dos líneas: Título brillante, descripción sutil
    printf "  ${C_GOLD}%-4s${C_RESET} ${C_BOLD}%-30s${C_RESET}\n" "$key)" "$title"
    printf "       ${C_SLATE}└─ %s${C_RESET}\n" "$desc"
}

draw_section_header() {
    local title="$1"
    echo ""
    printf "${C_SLATE}─── %s ───${C_RESET}\n" "$title"
}

# Auto-verificación al cargar
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Robustness Core Loaded."
fi
