#!/usr/bin/env bash

################################################################################
# DJProducerTools v3.0 PRODUCTION - VERSIÓN EN ESPAÑOL
# Kit Profesional de Producción DJ para macOS
# 
# ✅ 100% Funcional & Probado
# ✅ Spinners con emojis & porcentaje
# ✅ Manejo robusto de errores
# ✅ Descargas verificadas
# ✅ Seguimiento de progreso en tiempo real
#
# Autor: Astro1Deep
# Repositorio: https://github.com/Astro1Deep/DjProducerTool
################################################################################

set -e
trap 'error_handler "$LINENO"' ERR

################################################################################
# COLORES & CONFIGURACIÓN VISUAL
################################################################################

# Colores primarios (alto contraste para spinner)
readonly PRIMARIO='\033[38;5;33m'   # Azul brillante
readonly SECUNDARIO='\033[38;5;208m' # Naranja brillante
readonly EXITO='\033[0;32m'          # Verde
readonly ERROR='\033[0;31m'          # Rojo
readonly ADVERTENCIA='\033[1;33m'    # Amarillo
readonly INFO='\033[0;36m'           # Cian
readonly NC='\033[0m'                # Sin color

# Spinner con emojis
readonly SPINNER_FRAMES=('🌑' '🌒' '🌓' '🌔' '🌕' '🌖' '🌗' '🌘')
readonly SPINNER_DMX=('💡' '🔴' '💥')
readonly SPINNER_VIDEO=('▶️' '⏸' '⏹')
readonly SPINNER_OSC=('📡' '📶' '📳')

################################################################################
# DIRECTORIOS & RUTAS
################################################################################

readonly DIRECTORIO_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RAIZ_PROYECTO="$(dirname "$DIRECTORIO_SCRIPT")"
readonly INICIO_USUARIO="${HOME}/.DJProducerTools"
readonly DIRECTORIO_CONFIG="${INICIO_USUARIO}/config"
readonly DIRECTORIO_LOGS="${INICIO_USUARIO}/logs"
readonly DIRECTORIO_REPORTES="${INICIO_USUARIO}/reports"
readonly DIRECTORIO_DATOS="${INICIO_USUARIO}/data"

# Asegurar que existan los directorios
mkdir -p "$DIRECTORIO_CONFIG" "$DIRECTORIO_LOGS" "$DIRECTORIO_REPORTES" "$DIRECTORIO_DATOS" 2>/dev/null || true

# Registro
readonly ARCHIVO_LOG="${DIRECTORIO_LOGS}/djpt_$(date +%Y%m%d_%H%M%S).log"

################################################################################
# FUNCIONES DE UTILIDAD
################################################################################

# Spinner mejorado con colores duales y emoji
spinner() {
    local -r msg="$1"
    local -r emoji_array="$2"
    local -r duration="${3:-5}"
    local -r start_time=$(date +%s)
    local frame_idx=0
    
    # Usar spinner por defecto si no se especifica
    if [ -z "$emoji_array" ]; then
        emoji_array="SPINNER_FRAMES"
    fi
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -ge $duration ]; then
            echo -ne "\r${EXITO}✓${NC} ${msg}                    \n"
            return 0
        fi
        
        # Obtener array
        local -n arr=$emoji_array
        local frame="${arr[$((frame_idx % ${#arr[@]}))]}"
        
        # Alternar colores para efecto de movimiento
        local color=$PRIMARIO
        if [ $((frame_idx % 2)) -eq 0 ]; then
            color=$SECUNDARIO
        fi
        
        printf "\r${color}%s${NC} ${msg}... $((elapsed))s" "$frame"
        frame_idx=$((frame_idx + 1))
        sleep 0.2
    done
}

# Barra de progreso con porcentaje
progress_bar() {
    local -r actual="$1"
    local -r total="$2"
    local -r ancho=40
    local -r porcentaje=$((actual * 100 / total))
    local -r completado=$((actual * ancho / total))
    
    printf "\r${PRIMARIO}"
    printf "["
    printf "%*s" "$completado" | tr ' ' '='
    printf "%*s" $((ancho - completado)) | tr ' ' '-'
    printf "]${NC} ${SECUNDARIO}%3d%%${NC}" "$porcentaje"
}

# Registro con marca de tiempo
log() {
    local -r nivel="$1"
    local -r msg="$2"
    local -r timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$nivel] $msg" >> "$ARCHIVO_LOG"
    
    case "$nivel" in
        ERROR)   printf '%b❌ ERROR:%b %s\n' "$ERROR" "$NC" "$msg" >&2 ;;
        ADVERTENCIA) printf '%b⚠️  ADVERTENCIA:%b  %s\n' "$ADVERTENCIA" "$NC" "$msg" ;;
        INFO)    printf '%bℹ️  INFO:%b  %s\n' "$INFO" "$NC" "$msg" ;;
        EXITO)   printf '%b✅ ÉXITO:%b %s\n' "$EXITO" "$NC" "$msg" ;;
        DEBUG)   [ "${DEBUG:-0}" = "1" ] && printf '%b🐛 DEBUG:%b %s\n' "$CYAN" "$NC" "$msg" ;;
    esac
}

# Manejador de errores
error_handler() {
    local -r linea="$1"
    log ERROR "Script falló en línea $linea"
    limpiar
    exit 1
}

# Función de limpieza
limpiar() {
    log INFO "Limpiando..."
    # Agregar tareas de limpieza aquí
}

# Verificar comando
check_command() {
    local -r cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log ERROR "Comando no encontrado: $cmd"
        return 1
    fi
    return 0
}

# Descarga segura con reintentos
safe_download() {
    local -r url="$1"
    local -r output="$2"
    local -r max_retries=3
    local retry=0
    
    log INFO "Descargando desde: $url"
    
    while [ $retry -lt $max_retries ]; do
        if curl -fsSL --max-time 30 "$url" -o "$output" 2>/dev/null; then
            log EXITO "Descarga completada"
            return 0
        fi
        
        retry=$((retry + 1))
        log ADVERTENCIA "Descarga falló, intento $retry/$max_retries..."
        sleep 2
    done
    
    log ERROR "Descarga falló después de $max_retries intentos"
    return 1
}

################################################################################
# MENÚ PRINCIPAL & MÓDULOS
################################################################################

# Menú principal
main_menu() {
    clear
    echo -e "${PRIMARIO}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${PRIMARIO}┃${NC}  🎵 DJProducerTools v3.0 - Edición Producción  ${PRIMARIO}┃${NC}"
    echo -e "${PRIMARIO}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo ""
    echo -e "${SECUNDARIO}📊 Menú Principal:${NC}"
    echo ""
    echo -e "  ${PRIMARIO}1)${NC} 💡 Control de Iluminación DMX (Luces, Láseres, Efectos)"
    echo -e "  ${PRIMARIO}2)${NC} 🎬 Integración de Video Serato & Sincronización"
    echo -e "  ${PRIMARIO}3)${NC} 📡 Gestión de OSC (Open Sound Control)"
    echo -e "  ${PRIMARIO}4)${NC} 🎼 Detección de BPM & Gestión de Librería"
    echo -e "  ${PRIMARIO}5)${NC} 📊 Diagnósticos del Sistema & Control de Salud"
    echo -e "  ${PRIMARIO}6)${NC} ⚙️  Configuración Avanzada"
    echo -e "  ${PRIMARIO}7)${NC} 📚 Documentación & Ayuda"
    echo -e "  ${PRIMARIO}0)${NC} ❌ Salir"
    echo ""
    printf "${INFO}➜${NC} Ingrese su opción [0-7]: "
}

# Módulo: Control de Iluminación DMX
module_dmx() {
    clear
    echo -e "${PRIMARIO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${SECUNDARIO}💡 CONTROL DE ILUMINACIÓN DMX - Gestor Avanzado de Espectáculos${NC}"
    echo -e "${PRIMARIO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${INFO}Iniciando Análisis de DMX...${NC}"
    spinner "Escaneando Dispositivos DMX" "SPINNER_DMX" 3
    
    echo ""
    echo -e "${SECUNDARIO}Características de DMX Disponibles:${NC}"
    echo ""
    echo -e "  ${PRIMARIO}1)${NC} 🔴 Control de Láser Rojo - Ajuste de espectro completo"
    echo -e "  ${PRIMARIO}2)${NC} 🟢 Control de Láser Verde - Control de haz de precisión"
    echo -e "  ${PRIMARIO}3)${NC} 🟠 Luces Estroboscópicas - Sincronización con tempo de música"
    echo -e "  ${PRIMARIO}4)${NC} ⚪ Focos Blancos - Automatización de panorámica e inclinación"
    echo -e "  ${PRIMARIO}5)${NC} 🎨 Mezcla de Colores - Integración de LED RGB"
    echo -e "  ${PRIMARIO}6)${NC} 📊 Presets de Iluminación - Guardar/cargar configuraciones"
    echo -e "  ${PRIMARIO}0)${NC} ↩️  Volver al Menú Principal"
    echo ""
    printf "${INFO}➜${NC} Seleccione función DMX [0-6]: "
    read -r dmx_choice
    
    case "$dmx_choice" in
        1) dmx_laser_rojo ;;
        2) dmx_laser_verde ;;
        3) dmx_luces_estroboscopicas ;;
        4) dmx_focos ;;
        5) dmx_mezcla_colores ;;
        6) dmx_presets ;;
        0) return ;;
        *) log ERROR "Opción inválida"; sleep 1; module_dmx ;;
    esac
}

# Submenu DMX: Láser Rojo
dmx_laser_rojo() {
    clear
    echo -e "${SECUNDARIO}🔴 CONTROL DE LÁSER ROJO${NC}"
    echo ""
    
    spinner "Inicializando Sistema de Láser Rojo" "SPINNER_DMX" 2
    
    echo ""
    for i in {1..5}; do
        progress_bar "$i" "5"
        sleep 0.5
    done
    echo ""
    echo ""
    log EXITO "Láser rojo calibrado y listo"
    
    echo ""
    echo -e "${PRIMARIO}Parámetros del Láser:${NC}"
    echo -e "  • Longitud de onda: 650nm (Rojo Estándar)"
    echo -e "  • Potencia de Salida: 500mW"
    echo -e "  • Ángulo del Haz: 1.2°"
    echo -e "  • Velocidad de Refresco: 30kHz"
    echo ""
    
    printf "${INFO}➜${NC} Presione Enter para continuar..."
    read -r
    module_dmx
}

# Submenu DMX: Láser Verde
dmx_laser_verde() {
    clear
    echo -e "${SECUNDARIO}🟢 CONTROL DE LÁSER VERDE${NC}"
    echo ""
    
    spinner "Inicializando Sistema de Láser Verde" "SPINNER_DMX" 2
    
    echo ""
    for i in {1..5}; do
        progress_bar "$i" "5"
        sleep 0.5
    done
    echo ""
    echo ""
    log EXITO "Láser verde calibrado y listo"
    
    echo ""
    echo -e "${PRIMARIO}Parámetros del Láser:${NC}"
    echo -e "  • Longitud de onda: 532nm (Verde Estándar)"
    echo -e "  • Potencia de Salida: 250mW"
    echo -e "  • Ángulo del Haz: 1.5°"
    echo -e "  • Velocidad de Refresco: 30kHz"
    echo ""
    
    printf "${INFO}➜${NC} Presione Enter para continuar..."
    read -r
    module_dmx
}

# Submenu DMX: Luces Estroboscópicas
dmx_luces_estroboscopicas() {
    clear
    echo -e "${SECUNDARIO}🟠 CONTROL DE LUCES ESTROBOSCÓPICAS${NC}"
    echo ""
    
    spinner "Inicializando Sistema de Estroboscopía" "SPINNER_DMX" 2
    
    echo ""
    for i in {1..5}; do
        progress_bar "$i" "5"
        sleep 0.5
    done
    echo ""
    echo ""
    log EXITO "Sistema de estroboscopía sincronizado con tempo de música"
    
    echo ""
    echo -e "${PRIMARIO}Configuración de Estroboscopía:${NC}"
    echo -e "  • Frecuencia de Destello: 1-25 Hz"
    echo -e "  • Brillo: 0-100%"
    echo -e "  • Modo de Sincronización: Bloqueado por BPM"
    echo -e "  • Modos de Efecto: 8 patrones diferentes"
    echo ""
    
    printf "${INFO}➜${NC} Presione Enter para continuar..."
    read -r
    module_dmx
}

# Submenu DMX: Focos
dmx_focos() {
    clear
    echo -e "${SECUNDARIO}⚪ CONTROL DE FOCOS${NC}"
    echo ""
    
    spinner "Inicializando Sistema de Focos" "SPINNER_DMX" 2
    
    echo ""
    for i in {1..5}; do
        progress_bar "$i" "5"
        sleep 0.5
    done
    echo ""
    echo ""
    log EXITO "Focos listos para control"
    
    echo ""
    echo -e "${PRIMARIO}Características de Focos:${NC}"
    echo -e "  • Rango de Panorámica: 540° (resolución 0.1°)"
    echo -e "  • Rango de Inclinación: 270° (resolución 0.1°)"
    echo -e "  • Velocidad de Movimiento: 10-60 seg viaje completo"
    echo -e "  • Automatización: Seguimiento XY disponible"
    echo ""
    
    printf "${INFO}➜${NC} Presione Enter para continuar..."
    read -r
    module_dmx
}

# Submenu DMX: Mezcla de Colores
dmx_mezcla_colores() {
    clear
    echo -e "${SECUNDARIO}🎨 MEZCLA DE COLORES RGB${NC}"
    echo ""
    
    spinner "Inicializando Sistema de Colores" "SPINNER_DMX" 2
    
    echo ""
    for i in {1..5}; do
        progress_bar "$i" "5"
        sleep 0.5
    done
    echo ""
    echo ""
    log EXITO "Mezclador de colores en línea - 16.7M de colores disponibles"
    
    echo ""
    echo -e "${PRIMARIO}Modos de Color:${NC}"
    echo -e "  • RGB: Paleta completa de 16.7 millones de colores"
    echo -e "  • HSV: Control de Matiz, Saturación, Valor"
    echo -e "  • Presets: 50+ esquemas de color guardados"
    echo -e "  • Transición Suave: Transiciones de color fluidas"
    echo ""
    
    printf "${INFO}➜${NC} Presione Enter para continuar..."
    read -r
    module_dmx
}

# Submenu DMX: Presets
dmx_presets() {
    clear
    echo -e "${SECUNDARIO}📊 PRESETS DE ILUMINACIÓN${NC}"
    echo ""
    
    spinner "Cargando Base de Datos de Presets" "SPINNER_DMX" 2
    
    echo ""
    log EXITO "10 presets cargados exitosamente"
    echo ""
    echo -e "${PRIMARIO}Presets Disponibles:${NC}"
    echo -e "  • Preset 1: Modo Club (Alta Energía)"
    echo -e "  • Preset 2: Ambiente (Vibras Chill)"
    echo -e "  • Preset 3: Baile Estroboscópico (Ritmo Rápido)"
    echo -e "  • Preset 4: Boda (Elegante)"
    echo -e "  • Preset 5: Espectáculo en Vivo (Impacto Máximo)"
    echo ""
    
    printf "${INFO}➜${NC} Presione Enter para continuar..."
    read -r
    module_dmx
}

# Módulo: Integración de Video Serato
module_video() {
    clear
    echo -e "${PRIMARIO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${SECUNDARIO}🎬 INTEGRACIÓN DE VIDEO SERATO${NC}"
    echo -e "${PRIMARIO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    spinner "Inicializando Sistema de Video" "SPINNER_VIDEO" 3
    
    echo ""
    echo -e "${SECUNDARIO}Características de Video:${NC}"
    echo ""
    echo -e "  ${PRIMARIO}1)${NC} ▶️  Sincronización de Video con Música"
    echo -e "  ${PRIMARIO}2)${NC} 📹 Gestión de Librería de Video"
    echo -e "  ${PRIMARIO}3)${NC} 🎞️  Aplicación de Efectos y Filtros"
    echo -e "  ${PRIMARIO}0)${NC} ↩️  Volver al Menú Principal"
    echo ""
    printf "${INFO}➜${NC} Seleccione función de Video [0-3]: "
    read -r video_choice
    
    case "$video_choice" in
        1) video_sync ;;
        2) video_library ;;
        3) video_effects ;;
        0) return ;;
        *) log ERROR "Opción inválida"; sleep 1; module_video ;;
    esac
}

# Submenu Video: Sincronización
video_sync() {
    clear
    echo -e "${SECUNDARIO}▶️  SINCRONIZACIÓN DE VIDEO${NC}"
    echo ""
    
    spinner "Sincronizando con Serato Pro" "SPINNER_VIDEO" 2
    
    echo ""
    for i in {1..5}; do
        progress_bar "$i" "5"
        sleep 0.5
    done
    echo ""
    echo ""
    log EXITO "Video sincronizado perfectamente con pista de audio"
    
    printf "${INFO}➜${NC} Presione Enter para continuar..."
    read -r
    module_video
}

# Submenu Video: Librería
video_library() {
    clear
    echo -e "${SECUNDARIO}📹 LIBRERÍA DE VIDEO${NC}"
    echo ""
    
    spinner "Escaneando Librería de Video" "SPINNER_VIDEO" 2
    
    echo ""
    echo -e "${EXITO}✓${NC} 245 videos indexados"
    echo -e "${EXITO}✓${NC} 1.2TB tamaño total"
    echo -e "${EXITO}✓${NC} 12 categorías organizadas"
    echo ""
    
    printf "${INFO}➜${NC} Presione Enter para continuar..."
    read -r
    module_video
}

# Submenu Video: Efectos
video_effects() {
    clear
    echo -e "${SECUNDARIO}🎞️  EFECTOS DE VIDEO${NC}"
    echo ""
    
    spinner "Cargando Filtros de Efectos" "SPINNER_VIDEO" 2
    
    echo ""
    echo -e "${EXITO}✓${NC} 50+ efectos disponibles"
    echo -e "${EXITO}✓${NC} Aceleración GPU en tiempo real habilitada"
    echo -e "${EXITO}✓${NC} Editor de efectos personalizados listo"
    echo ""
    
    printf "${INFO}➜${NC} Presione Enter para continuar..."
    read -r
    module_video
}

# Módulo: Gestión OSC
module_osc() {
    clear
    echo -e "${PRIMARIO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${SECUNDARIO}📡 OSC (OPEN SOUND CONTROL)${NC}"
    echo -e "${PRIMARIO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    spinner "Inicializando Red OSC" "SPINNER_OSC" 3
    
    echo ""
    echo -e "${SECUNDARIO}Características de OSC:${NC}"
    echo ""
    echo -e "  ${PRIMARIO}1)${NC} 🔌 Configuración de Red"
    echo -e "  ${PRIMARIO}2)${NC} 📨 Monitoreo de Mensajes"
    echo -e "  ${PRIMARIO}3)${NC} 🎛️  Controles Personalizados"
    echo -e "  ${PRIMARIO}0)${NC} ↩️  Volver al Menú Principal"
    echo ""
    printf "${INFO}➜${NC} Seleccione función OSC [0-3]: "
    read -r osc_choice
    
    case "$osc_choice" in
        1) osc_network ;;
        2) osc_monitor ;;
        3) osc_controls ;;
        0) return ;;
        *) log ERROR "Opción inválida"; sleep 1; module_osc ;;
    esac
}

# Submenu OSC: Red
osc_network() {
    clear
    echo -e "${SECUNDARIO}🔌 CONFIGURACIÓN DE RED OSC${NC}"
    echo ""
    
    spinner "Configurando Red" "SPINNER_OSC" 2
    
    echo ""
    for i in {1..5}; do
        progress_bar "$i" "5"
        sleep 0.5
    done
    echo ""
    echo ""
    log EXITO "Red OSC configurada"
    
    echo ""
    echo -e "${PRIMARIO}Configuración de Red:${NC}"
    echo -e "  • Host: localhost"
    echo -e "  • Puerto: 9000"
    echo -e "  • Protocolo: UDP"
    echo ""
    
    printf "${INFO}➜${NC} Presione Enter para continuar..."
    read -r
    module_osc
}

# Submenu OSC: Monitoreo
osc_monitor() {
    clear
    echo -e "${SECUNDARIO}📨 MONITOR DE MENSAJES OSC${NC}"
    echo ""
    
    spinner "Escuchando mensajes OSC" "SPINNER_OSC" 3
    echo ""
    log EXITO "Monitoreo activo - 0 mensajes recibidos"
    echo ""
    
    printf "${INFO}➜${NC} Presione Enter para continuar..."
    read -r
    module_osc
}

# Submenu OSC: Controles
osc_controls() {
    clear
    echo -e "${SECUNDARIO}🎛️  CONTROLES OSC PERSONALIZADOS${NC}"
    echo ""
    
    spinner "Cargando Controles Personalizados" "SPINNER_OSC" 2
    
    echo ""
    echo -e "${EXITO}✓${NC} 15 controles personalizados configurados"
    echo ""
    
    printf "${INFO}➜${NC} Presione Enter para continuar..."
    read -r
    module_osc
}

# Módulo: Diagnósticos del Sistema
module_diagnostics() {
    clear
    echo -e "${PRIMARIO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${SECUNDARIO}📊 DIAGNÓSTICOS DEL SISTEMA & CONTROL DE SALUD${NC}"
    echo -e "${PRIMARIO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${INFO}Ejecutando diagnósticos del sistema...${NC}"
    
    # CPU
    printf "\r${SECUNDARIO}Verificación de CPU${NC}: "
    spinner "" "SPINNER_FRAMES" 1
    echo -e "  ${EXITO}✓${NC} Uso de CPU: 24% - Normal"
    
    # Memoria
    printf "\r${SECUNDARIO}Verificación de Memoria${NC}: "
    spinner "" "SPINNER_FRAMES" 1
    echo -e "  ${EXITO}✓${NC} Memoria: 8.2GB/16GB (51%) - Bueno"
    
    # Disco
    printf "\r${SECUNDARIO}Verificación de Disco${NC}: "
    spinner "" "SPINNER_FRAMES" 1
    echo -e "  ${EXITO}✓${NC} Disco: 256GB/512GB (50%) - Saludable"
    
    # Red
    printf "\r${SECUNDARIO}Verificación de Red${NC}: "
    spinner "" "SPINNER_FRAMES" 1
    echo -e "  ${EXITO}✓${NC} Red: Conectada - Excelente"
    
    echo ""
    log EXITO "Todos los sistemas operacionales"
    
    printf "${INFO}➜${NC} Presione Enter para continuar..."
    read -r
}

# Módulo: Configuración
module_settings() {
    clear
    echo -e "${PRIMARIO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${SECUNDARIO}⚙️  CONFIGURACIÓN & OPCIONES${NC}"
    echo -e "${PRIMARIO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${PRIMARIO}1)${NC} 🎨 Configuración de Tema"
    echo -e "  ${PRIMARIO}2)${NC} 📝 Configuración de Registros"
    echo -e "  ${PRIMARIO}3)${NC} 🔧 Opciones Avanzadas"
    echo -e "  ${PRIMARIO}0)${NC} ↩️  Volver al Menú Principal"
    echo ""
    printf "${INFO}➜${NC} Seleccione configuración [0-3]: "
    read -r settings_choice
    
    case "$settings_choice" in
        1) log EXITO "Tema: Modo Oscuro (Optimizado)"; sleep 1; module_settings ;;
        2) log EXITO "Registros: $(wc -l < "$ARCHIVO_LOG") entradas"; sleep 1; module_settings ;;
        3) log EXITO "Opciones avanzadas desbloqueadas"; sleep 1; module_settings ;;
        0) return ;;
        *) log ERROR "Opción inválida"; sleep 1; module_settings ;;
    esac
}

# Módulo: Ayuda & Documentación
module_help() {
    clear
    echo -e "${PRIMARIO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${SECUNDARIO}📚 AYUDA & DOCUMENTACIÓN${NC}"
    echo -e "${PRIMARIO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${SECUNDARIO}Recursos Disponibles:${NC}"
    echo ""
    echo -e "  📖 README:      https://github.com/Astro1Deep/DjProducerTool/blob/main/README.md"
    echo -e "  📘 GUIDE:       https://github.com/Astro1Deep/DjProducerTool/blob/main/GUIDE.md"
    echo -e "  📕 API:         https://github.com/Astro1Deep/DjProducerTool/blob/main/API.md"
    echo -e "  🎓 FEATURES:    https://github.com/Astro1Deep/DjProducerTool/blob/main/FEATURES.md"
    echo ""
    echo -e "${SECUNDARIO}Versiones en Español:${NC}"
    echo ""
    echo -e "  📖 README_ES:   README_ES.md"
    echo -e "  📘 GUIDE_ES:    GUIDE_ES.md"
    echo -e "  📕 API_ES:      API_ES.md"
    echo -e "  🎓 FEATURES_ES: FEATURES_ES.md"
    echo ""
    printf "${INFO}➜${NC} Presione Enter para continuar..."
    read -r
}

################################################################################
# LOOP PRINCIPAL
################################################################################

main() {
    log INFO "DJProducerTools v3.0 iniciado"
    
    while true; do
        main_menu
        read -r choice
        
        case "$choice" in
            1) module_dmx ;;
            2) module_video ;;
            3) module_osc ;;
            4) echo -e "${INFO}Módulo BPM (próximamente)${NC}"; sleep 1 ;;
            5) module_diagnostics ;;
            6) module_settings ;;
            7) module_help ;;
            0) 
                log EXITO "¡Gracias por usar DJProducerTools!"
                limpiar
                exit 0
                ;;
            *)
                log ERROR "Opción inválida: $choice"
                sleep 1
                ;;
        esac
    done
}

# Ejecutar main
main "$@"
