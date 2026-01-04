#!/bin/bash

# 🧪 TEST SUITE PARA LOS SCRIPTS

echo "════════════════════════════════════════════════════════════"
echo "🧪 PRUEBAS DE INTEGRIDAD DE SCRIPTS"
echo "════════════════════════════════════════════════════════════"
echo ""

PASS=0
FAIL=0

# Test 1: Verificar sintaxis bash
echo "✓ Test 1: Validar sintaxis Bash"
if bash -n DJProducerTools_MultiScript_EN.sh 2>/dev/null; then
    echo "   ✅ EN: Sintaxis válida"
    ((PASS++))
else
    echo "   ❌ EN: Error de sintaxis"
    ((FAIL++))
fi

if bash -n DJProducerTools_MultiScript_ES.sh 2>/dev/null; then
    echo "   ✅ ES: Sintaxis válida"
    ((PASS++))
else
    echo "   ❌ ES: Error de sintaxis"
    ((FAIL++))
fi

# Test 2: Verificar permisos de ejecución
echo ""
echo "✓ Test 2: Verificar permisos de ejecución"
if [ -x DJProducerTools_MultiScript_EN.sh ]; then
    echo "   ✅ EN: Ejecutable"
    ((PASS++))
else
    echo "   ❌ EN: No ejecutable"
    ((FAIL++))
fi

if [ -x DJProducerTools_MultiScript_ES.sh ]; then
    echo "   ✅ ES: Ejecutable"
    ((PASS++))
else
    echo "   ❌ ES: No ejecutable"
    ((FAIL++))
fi

# Test 3: Verificar líneas de código
echo ""
echo "✓ Test 3: Verificar cantidad de líneas"
EN_LINES=$(wc -l < DJProducerTools_MultiScript_EN.sh)
ES_LINES=$(wc -l < DJProducerTools_MultiScript_ES.sh)

if [ "$EN_LINES" -eq "$ES_LINES" ]; then
    echo "   ✅ Paridad: EN ($EN_LINES) = ES ($ES_LINES)"
    ((PASS++))
else
    echo "   ⚠️  Diferencia: EN ($EN_LINES) vs ES ($ES_LINES)"
    if [ $((EN_LINES - ES_LINES)) -lt 5 ]; then
        echo "   ℹ️  Diferencia aceptable (< 5 líneas)"
        ((PASS++))
    else
        ((FAIL++))
    fi
fi

# Test 4: Verificar funciones clave
echo ""
echo "✓ Test 4: Verificar funciones clave"
FUNCTIONS=("#!/bin/bash" "set -e" "function" "progress_spinner" "debug_mode")
EN_CHECKS=0
ES_CHECKS=0

for func in "${FUNCTIONS[@]}"; do
    grep -q "$func" DJProducerTools_MultiScript_EN.sh && ((EN_CHECKS++))
    grep -q "$func" DJProducerTools_MultiScript_ES.sh && ((ES_CHECKS++))
done

if [ "$EN_CHECKS" -gt 2 ]; then
    echo "   ✅ EN: Estructura válida ($EN_CHECKS elementos encontrados)"
    ((PASS++))
else
    echo "   ❌ EN: Estructura incompleta"
    ((FAIL++))
fi

if [ "$ES_CHECKS" -gt 2 ]; then
    echo "   ✅ ES: Estructura válida ($ES_CHECKS elementos encontrados)"
    ((PASS++))
else
    echo "   ❌ ES: Estructura incompleta"
    ((FAIL++))
fi

# Test 5: Verificar documentación
echo ""
echo "✓ Test 5: Verificar documentación"
EN_DOCS=$(ls -1 *.md | grep -v "_ES" | grep -v "_es" | wc -l)
ES_DOCS=$(ls -1 *.md | grep -E "_ES|_es" | wc -l)

if [ "$EN_DOCS" -gt 0 ] && [ "$ES_DOCS" -gt 0 ]; then
    echo "   ✅ EN: $EN_DOCS documentos"
    echo "   ✅ ES: $ES_DOCS documentos"
    ((PASS++))
    ((PASS++))
else
    echo "   ❌ Documentación incompleta"
    ((FAIL++))
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "📊 RESULTADOS DE PRUEBAS"
echo "════════════════════════════════════════════════════════════"
echo "   ✅ Pasadas: $PASS"
echo "   ❌ Fallidas: $FAIL"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "🎉 ¡TODAS LAS PRUEBAS PASARON!"
    exit 0
else
    echo "⚠️  Algunas pruebas fallaron"
    exit 1
fi

