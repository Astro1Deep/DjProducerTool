#!/bin/bash
#
# generate_html_report.sh
# Genera un informe de estado del proyecto en formato HTML
# a partir de los resultados de check_consistency.sh.

set -e

SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

CONSISTENCY_SCRIPT="tests/check_consistency.sh"
REPORT_FILE="project_status_report.html"
TMP_OUTPUT="/tmp/consistency_output.txt"

echo "📊 Generando informe de estado del proyecto..."

# 1. Ejecutar el script de consistencia y capturar su salida
echo "   -> Ejecutando check_consistency.sh..."
# Usamos '|| true' para que el script no se detenga si check_consistency.sh falla
bash "$CONSISTENCY_SCRIPT" > "$TMP_OUTPUT" 2>&1 || true

# 2. Parsear la salida
PASS_COUNT=$(grep -c "✅ PASS:" "$TMP_OUTPUT" || true)

# Separar fallos de TODOs de otros fallos
OTHER_FAILS=$(grep "❌ FAIL:" "$TMP_OUTPUT" | grep -v "TODOs o FIXMEs pendientes" || true)
OTHER_FAIL_COUNT=$(echo "$OTHER_FAILS" | wc -l | tr -d ' ' || true)

# Extraer específicamente los TODOs y FIXMEs
TODO_LINES=$(awk '/Se encontraron TODOs o FIXMEs pendientes/{flag=1;next}/✅ PASS:|❌ FAIL:/{flag=0}flag' "$TMP_OUTPUT" | grep -E "^\s*-\s*")
TODO_COUNT=$(echo "$TODO_LINES" | wc -l | tr -d ' ' || true)

FAIL_COUNT=$((OTHER_FAIL_COUNT + (TODO_COUNT > 0 ? 1 : 0) ))

OVERALL_STATUS="✅ PASSED"
STATUS_COLOR="#2ecc71" # Green
if [ "$FAIL_COUNT" -gt 0 ]; then
    OVERALL_STATUS="❌ FAILED"
    STATUS_COLOR="#e74c3c" # Red
fi

# 3. Generar el informe HTML
echo "   -> Creando archivo HTML: $REPORT_FILE..."

{
    # --- Cabecera HTML y estilos ---
    cat <<EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Informe de Estado del Proyecto - DJProducerTools</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: #1a1a1a; color: #e0e0e0; margin: 0; padding: 2em; }
        .container { max-width: 900px; margin: auto; background-color: #2c2c2c; padding: 2em; border-radius: 8px; box-shadow: 0 4px 8px rgba(0,0,0,0.3); }
        h1, h2 { color: #3498db; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        .summary { background-color: #333; padding: 1.5em; border-radius: 8px; margin-bottom: 2em; }
        .summary h2 { border: none; }
        .status { font-size: 1.5em; font-weight: bold; }
        .pass { color: #2ecc71; }
        .fail { color: #e74c3c; }
        ul { list-style-type: none; padding: 0; }
        li { background-color: #383838; margin-bottom: 8px; padding: 12px; border-radius: 4px; font-family: "Menlo", "Courier New", monospace; font-size: 0.9em; white-space: pre-wrap; word-break: break-all; }
        .fail-item { border-left: 5px solid #e74c3c; }
        .pass-item { border-left: 5px solid #2ecc71; }
        .warn-item { border-left: 5px solid #f1c40f; background-color: #444033; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Informe de Consistencia del Proyecto</h1>
        <div class="summary">
            <h2>Resumen General</h2>
            <p><strong>Estado:</strong> <span class="status" style="color:${STATUS_COLOR};">${OVERALL_STATUS}</span></p>
            <p><span class="pass">✅ ${PASS_COUNT}</span> comprobaciones pasadas</p>
            <p><span class="fail">❌ ${FAIL_COUNT}</span> comprobaciones fallidas</p>
        </div>
EOF

    if [ "$OTHER_FAIL_COUNT" -gt 0 ]; then
        echo "<h2>Detalles de Fallos</h2><ul>"
        echo "$OTHER_FAILS" | sed -e 's/❌ FAIL: /<li class="fail-item">/' -e 's/$/<\/li>/'
        echo "</ul>"
    fi

    if [ "$TODO_COUNT" -gt 0 ]; then
        echo "<h2>Tareas Pendientes (TODOs/FIXMEs)</h2><ul>"
        echo "$TODO_LINES" | sed -e 's/^\s*-\s*/<li class="warn-item">/' -e 's/$/<\/li>/'
        echo "</ul>"
    fi

    if [ "$PASS_COUNT" -gt 0 ]; then
        echo "<h2>Comprobaciones Pasadas</h2><ul>"
        grep "✅ PASS:" "$TMP_OUTPUT" | sed -e 's/✅ PASS: /<li class="pass-item">/' -e 's/$/<\/li>/'
        echo "</ul>"
    fi

    cat <<EOF
    </div>
</body>
</html>
EOF

} > "$REPORT_FILE"

# 4. Limpieza y finalización
rm "$TMP_OUTPUT"
echo "✨ ¡Informe completado!"
echo "   -> Abriendo $REPORT_FILE en tu navegador..."
open "$REPORT_FILE"