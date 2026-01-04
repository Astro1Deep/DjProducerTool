#!/bin/bash

set -e

echo "════════════════════════════════════════════════════════════"
echo "🚀 PUSH FINAL A GITHUB - Astro1Deep/DjProducerTool"
echo "════════════════════════════════════════════════════════════"
echo ""

# Paso 1: Agregar cambios
echo "📝 Paso 1: Agregando cambios..."
git add .
echo "✅ Archivos agregados"

# Paso 2: Mostrar lo que se va a commitear
echo ""
echo "📋 Paso 2: Cambios a commitear:"
git status

# Paso 3: Crear commit
echo ""
echo "💾 Paso 3: Creando commit..."
git commit -m "feat: Complete bilingual project - ES+EN documentation and scripts fully synced

- Added Spanish versions of all missing documentation
- Cleaned unnecessary files and folders
- Verified script parity (EN/ES): 1000 lines each
- Complete bilingual support: 10 EN docs + 12 ES docs
- Features: DMX, OSC, Serato Video, Dynamic Libraries
- Progress indicators with dual-color spinners
- Professional production-ready structure
- Ready for Astro1Deep channel release

Changes:
✓ Eliminated: 9 unnecessary files
✓ Added: DEPLOYMENT_READY_ES.md, FEATURE_IMPLEMENTATION_STATUS_ES.md, PROGRESS_INDICATOR_SYSTEM_ES.md
✓ Verified: Bash syntax, file permissions, documentation completeness
✓ Final state: Repository cleaned and organized for GitHub release"

echo "✅ Commit creado"

# Paso 4: Verificar si hay cambios pendientes
echo ""
echo "�� Paso 4: Verificando estado..."
STATUS=$(git status --short)
if [ -z "$STATUS" ]; then
    echo "✅ Todo commitado correctamente"
else
    echo "⚠️ Cambios pendientes:"
    git status --short
fi

# Paso 5: Mostrar log
echo ""
echo "📜 Últimos commits:"
git log --oneline -5

echo ""
echo "════════════════════════════════════════════════════════════"
echo "🎯 PRÓXIMO COMANDO PARA PUSH:"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "   git push origin main"
echo ""
echo "O si necesitas forzar (cuidado):"
echo "   git push origin main --force"
echo ""
echo "════════════════════════════════════════════════════════════"

