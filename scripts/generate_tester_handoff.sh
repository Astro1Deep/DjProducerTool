#!/usr/bin/env bash
set -euo pipefail

ZIP_PATH=""
CHECKSUM=""
REPORT_PATH=""
OUTPUT_PATH=""
RELEASE_NAME=""

usage() {
  cat <<'USAGE'
Uso: generate_tester_handoff.sh --zip PATH --checksum SHA256 --report PATH --output PATH
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --zip)
      ZIP_PATH="$2"
      shift 2
      ;;
    --checksum)
      CHECKSUM="$2"
      shift 2
      ;;
    --report)
      REPORT_PATH="$2"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[ERR] Opción no reconocida: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$ZIP_PATH" ] || [ -z "$CHECKSUM" ] || [ -z "$REPORT_PATH" ] || [ -z "$OUTPUT_PATH" ]; then
  usage >&2
  exit 2
fi

RELEASE_NAME="$(basename "$ZIP_PATH" .zip)"
ZIP_FILE="$(basename "$ZIP_PATH")"
SHA_FILE="$(basename "$ZIP_PATH").sha256"
REPORT_FILE="$(basename "$REPORT_PATH")"

mkdir -p "$(dirname "$OUTPUT_PATH")"

cat >"$OUTPUT_PATH" <<EOF
# DJProducerTools Tester Handoff

## Artefactos
- ZIP: \`$ZIP_FILE\`
- SHA256: \`$CHECKSUM\`
- Fichero checksum: \`$SHA_FILE\`
- Certificación fresh-install: \`$REPORT_FILE\`

## Verificación de integridad

\`\`\`bash
ACTUAL="\$(shasum -a 256 $ZIP_FILE | awk '{print \$1}')"
EXPECTED="\$(awk '{print \$1}' $SHA_FILE)"
[ "\$ACTUAL" = "\$EXPECTED" ] && echo "CHECKSUM OK" || echo "CHECKSUM FAIL"
\`\`\`

## Instalación limpia recomendada

\`\`\`bash
unzip $ZIP_FILE
cd _DJProducerTools
bash scripts/bootstrap_djpt_venv.sh --core --with-dev
\`\`\`

## Arranque

\`\`\`bash
./DJProducerTools_MultiScript_ES.sh
\`\`\`

Alternativa CLI:

\`\`\`bash
./bin/djpt
\`\`\`

## Smoke mínimo obligatorio

\`\`\`bash
bash tests/run_smoke.sh
bash tests/test_startup_home_and_double_click.sh
python3 scripts/menu_contract_tools.py validate-json
\`\`\`

## Certificación recomendada en máquina destino

\`\`\`bash
bash tests/VERIFY_AND_TEST.sh --root "\$PWD" --full-inventory
\`\`\`

Si quieres usar exactamente el mismo estándar que el release oficial:

\`\`\`bash
bash scripts/certify_fresh_install.sh --zip ../$ZIP_FILE
\`\`\`

## Backends opcionales
- MLX, TensorFlow, Ollama, Transformers local y OpenAI local no son requisito para que el núcleo funcione.
- Si un tester quiere ese backend concreto, debe instalarlo/configurarlo en su máquina.
- El health local-first no debe marcar degradación solo por faltar esos stacks opcionales.

## Qué debe enviar un tester si algo falla
- Sistema operativo y versión.
- Salida exacta del comando que falló.
- \`state/reports/ai_health.json\`
- último archivo de \`tests/logs/\`
- si el fallo es de arranque: salida de \`bash tests/test_startup_home_and_double_click.sh\`

## Release
- Release: \`$RELEASE_NAME\`
- Documento generado automáticamente junto al release para testers.
EOF

echo "[OK] Tester handoff generated: $OUTPUT_PATH"
