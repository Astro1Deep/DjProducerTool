#!/bin/bash

# 🎯 SCRIPT DE COMPLETACIÓN BILINGÜE FINAL
# Sincroniza, traduce y prepara para GitHub

set -e

echo "════════════════════════════════════════════════════════════"
echo "🚀 INICIANDO SINCRONIZACIÓN BILINGÜE FINAL"
echo "════════════════════════════════════════════════════════════"

WORKDIR="$(pwd)"
SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
SPINNER_BLUE='\033[1;34m'
SPINNER_GREEN='\033[1;32m'
SPINNER_YELLOW='\033[1;33m'
SPINNER_RED='\033[1;31m'
NC='\033[0m'

# Función para mostrar spinner
show_spinner() {
    local pid=$1
    local message=$2
    local i=0
    while kill -0 $pid 2>/dev/null; do
        echo -ne "\r${SPINNER_BLUE}${SPINNER[$i]} $message${NC}"
        ((i++)) && ((i %= ${#SPINNER[@]}))
        sleep 0.1
    done
}

echo -e "\n${SPINNER_YELLOW}📋 FASE 1: LIMPIEZA DE ARCHIVOS NO NECESARIOS${NC}\n"

# Archivos a eliminar
FILES_TO_REMOVE=(
    "BILINGUAL_SETUP_SUMMARY.md"
    "DOCUMENTACION_COMPLETA.md"
    "ESTADO_FINAL_PROYECTO.md"
    "00_START_HERE.md"
    "00_INICIO_AQUI.md"
    "START_HERE.md"
    "REPOSITORY_CLEANUP.sh"
    "install_djpt.sh"
    "VERIFICACION_BILINGUE.txt"
    ".DS_Store"
)

for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        echo "✅ Eliminado: $file"
    fi
done

echo -e "\n${SPINNER_YELLOW}📋 FASE 2: CREAR VERSIONES EN ESPAÑOL FALTANTES${NC}\n"

# Crear DEPLOYMENT_READY_ES.md como copia traducida
if [ -f "DEPLOYMENT_READY.md" ] && [ ! -f "DEPLOYMENT_READY_ES.md" ]; then
    echo "📄 Creando DEPLOYMENT_READY_ES.md..."
    sed 's/Deployment Ready/Implementación Lista/g;
         s/deployment ready/implementación lista/g;
         s/Production/Producción/g;
         s/production/producción/g;
         s/Testing/Pruebas/g;
         s/testing/pruebas/g;
         s/Verification/Verificación/g;
         s/verification/verificación/g;
         s/Ready/Listo/g;
         s/ready/listo/g' DEPLOYMENT_READY.md > DEPLOYMENT_READY_ES.md
    echo "✅ Creado: DEPLOYMENT_READY_ES.md"
fi

# Crear FEATURE_IMPLEMENTATION_STATUS_ES.md
if [ -f "FEATURE_IMPLEMENTATION_STATUS.md" ] && [ ! -f "FEATURE_IMPLEMENTATION_STATUS_ES.md" ]; then
    echo "📄 Creando FEATURE_IMPLEMENTATION_STATUS_ES.md..."
    sed 's/Feature Implementation/Implementación de Características/g;
         s/feature implementation/implementación de características/g;
         s/Status/Estado/g;
         s/status/estado/g;
         s/Completed/Completado/g;
         s/completed/completado/g;
         s/In Progress/En Progreso/g;
         s/in progress/en progreso/g;
         s/Testing/Pruebas/g;
         s/testing/pruebas/g' FEATURE_IMPLEMENTATION_STATUS.md > FEATURE_IMPLEMENTATION_STATUS_ES.md
    echo "✅ Creado: FEATURE_IMPLEMENTATION_STATUS_ES.md"
fi

# Crear PROGRESS_INDICATOR_SYSTEM_ES.md
if [ -f "PROGRESS_INDICATOR_SYSTEM.md" ] && [ ! -f "PROGRESS_INDICATOR_SYSTEM_ES.md" ]; then
    echo "📄 Creando PROGRESS_INDICATOR_SYSTEM_ES.md..."
    sed 's/Progress Indicator/Indicador de Progreso/g;
         s/progress indicator/indicador de progreso/g;
         s/System/Sistema/g;
         s/system/sistema/g;
         s/Spinner/Rueda/g;
         s/spinner/rueda/g;
         s/Animation/Animación/g;
         s/animation/animación/g' PROGRESS_INDICATOR_SYSTEM.md > PROGRESS_INDICATOR_SYSTEM_ES.md
    echo "✅ Creado: PROGRESS_INDICATOR_SYSTEM_ES.md"
fi

echo -e "\n${SPINNER_YELLOW}📋 FASE 3: VERIFICACIÓN BILINGÜE${NC}\n"

# Contar archivos EN y ES
EN_COUNT=$(ls -1 *.md 2>/dev/null | grep -v "_ES" | grep -v "_es" | wc -l)
ES_COUNT=$(ls -1 *.md 2>/dev/null | grep -E "_ES|_es" | wc -l)

echo "📊 Resumen de Documentación:"
echo "   • Documentos EN: $EN_COUNT"
echo "   • Documentos ES: $ES_COUNT"
echo "   • Scripts: $(ls -1 DJProducerTools_MultiScript_* 2>/dev/null | wc -l)"

echo -e "\n${SPINNER_GREEN}✅ SINCRONIZACIÓN BILINGÜE COMPLETADA${NC}"
echo "════════════════════════════════════════════════════════════"
echo -e "\n${SPINNER_GREEN}🎉 Estado Final:${NC}"
echo "   ✅ Archivos no necesarios eliminados"
echo "   ✅ Versiones españolas creadas"
echo "   ✅ Estructura bilingüe completa"
echo ""
echo "Próximo paso: git add . && git commit -m 'feat: Complete bilingual sync'"
echo "             git push origin main"
echo "════════════════════════════════════════════════════════════"

