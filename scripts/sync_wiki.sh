#!/usr/bin/env bash
# ==============================================================================
# sync_wiki.sh - Sincronizador Automático de la Wiki de DjProducerTool a GitHub
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WIKI_DIR="${TMPDIR:-/tmp}/djpt_wiki_sync_$$"

WIKI_REPO="https://github.com/Astro1Deep/DjProducerTool.wiki.git"

echo "=== Sincronizando Wiki de DjProducerTool ==="
echo "Origen: $ROOT_DIR/docs/wiki"

# Obtener URL autenticada de origin si existe
ORIGIN_URL="$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || echo "$WIKI_REPO")"
if [[ "$ORIGIN_URL" =~ ^https://([^@]+)@github\.com/Astro1Deep/DjProducerTool(\.git)?$ ]]; then
  AUTH_PART="${BASH_REMATCH[1]}"
  TARGET_WIKI_URL="https://${AUTH_PART}@github.com/Astro1Deep/DjProducerTool.wiki.git"
else
  TARGET_WIKI_URL="$WIKI_REPO"
fi

trap 'rm -rf "$WIKI_DIR"' EXIT

echo "[1/4] Clonando repositorio de la wiki..."
git clone --depth 1 "$TARGET_WIKI_URL" "$WIKI_DIR" >/dev/null 2>&1 || {
  echo "[ERR] No se pudo clonar la wiki remota. Verifica conexión o permisos." >&2
  exit 1
}

echo "[2/4] Copiando manuales extendidos bilingües..."
cp "$ROOT_DIR/docs/wiki/WIKI_EXTENDED_MANUAL_ES.md" "$WIKI_DIR/Manual-Extendido-ES.md"
cp "$ROOT_DIR/docs/wiki/WIKI_EXTENDED_MANUAL_EN.md" "$WIKI_DIR/Extended-Manual-EN.md"

echo "[3/4] Generando navegación de Sidebar, Footer y Home..."
cat << 'EOF' > "$WIKI_DIR/_Sidebar.md"
### 🎛️ DJProducerTools

- [🏠 Inicio / Home](Home)
- [📘 Manual Extendido (ES)](Manual-Extendido-ES)
- [📗 Extended Manual (EN)](Extended-Manual-EN)

---

### 🎧 Ecosistema Multi-Disco
- **Akai MPC Sample**: `/Volumes/MPCSMPL`
- **Serato DJ Pro**: `/Volumes/SanDisk SSD`
- **Producción / Ableton**: `/Volumes/samsung PSSDT7`

---

### ⚙️ Enlaces Oficiales
- [Código en GitHub](https://github.com/Astro1Deep/DjProducerTool)
- [README (Español)](https://github.com/Astro1Deep/DjProducerTool/blob/main/README_ES.md)
- [README (English)](https://github.com/Astro1Deep/DjProducerTool/blob/main/README.md)
- [Reportar un Issue](https://github.com/Astro1Deep/DjProducerTool/issues)
EOF

cat << 'EOF' > "$WIKI_DIR/_Footer.md"
---
DJProducerTools v1.0.0 · [GitHub Repo: Astro1Deep/DjProducerTool](https://github.com/Astro1Deep/DjProducerTool) · macOS Audio Suite
EOF

cat << 'EOF' > "$WIKI_DIR/Home.md"
# 🎛️ DJProducerTools – Wiki Oficial

Bienvenido a la documentación y wiki técnica oficial de **DJProducerTools (DJPT)**.

---

## 📚 Documentación Técnica Completa

- 📘 **[Manual Extendido en Español (Manual-Extendido-ES)](Manual-Extendido-ES)**: Guía detallada de cada una de las opciones del menú, flujos automatizados (A1–A28), laboratorio Deep/ML, submenús de duplicados (D), visuales/DMX (V) y opciones de integración.
- 📗 **[Extended Manual in English (Extended-Manual-EN)](Extended-Manual-EN)**: Full English reference manual covering all menu entries, automated chains, local Machine Learning workflows, and integration diagnostics.

---

## 🎧 Novedad: Motor Acústico Resiliente ShazamIO (Opción 9)

El sistema integra un motor de huella acústica con ShazamIO desacoplado y blindado contra fallos de red o archivos corruptos, diseñado para operar sobre tres sistemas:
1. **Akai MPC Sample** (`/Volumes/MPCSMPL`): Identificación acústica de vinilos y samples huérfanos.
2. **Serato DJ Pro** (`/Volumes/SanDisk SSD/00_SERATO_MUSICA`): Resolución de pistas sin ID3, directos y archivos `Track 01`.
3. **Producción & Ableton** (`/Volumes/samsung PSSDT7`): Trazabilidad de stems y sample clearance.

### Arquitectura de Resiliencia en 5 Capas
- **Capa 1 (Filtro Heurístico)**: Ignora one-shots percusivos diminutos (<150 KB o <3.2s).
- **Capa 2 (Caché SQLite)**: `~/.DJProducerTools/shazam_cache.db` con hash instantáneo. Respuestas en 0.001 ms ante consultas repetidas.
- **Capa 3 (Control Asíncrono)**: `asyncio.Semaphore(3)` y timeout estricto de 8.0s por pista.
- **Capa 4 (Sanitizador FFmpeg)**: Extrae un fragmento limpio PCM 16-bit 44.1 kHz si el contenedor está roto.
- **Capa 5 (Fallback Offline)**: Extrae artista, título limpio y mix/versión de la ruta local sin lanzar errores no controlados.

---

## 🚀 Instalación Rápida

```bash
curl -fsSL https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/install_djpt.sh -o install_djpt.sh
chmod +x install_djpt.sh
./install_djpt.sh
```

O clonando el repositorio directamente:
```bash
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool
chmod +x scripts/*.sh

# Lanzador en Español
./scripts/DJProducerTools_MultiScript_ES.sh

# Lanzador en Inglés
./scripts/DJProducerTools_MultiScript_EN.sh
```

---

## 🛡️ Seguridad y Buenas Prácticas

- **Modo Seguro Activo**: `SAFE_MODE=1` y `DJ_SAFE_LOCK=1` están habilitados por defecto. Ningún archivo se mueve o elimina sin confirmación explícita.
- **Cuarentena Reversible**: Los duplicados confirmados se mueven a `_DJProducerTools/quarantine/`, permitiendo restaurar cualquier archivo en cualquier momento.
- **Pruebas en Seco**: Usa `--dry-run` para simular operaciones pesadas antes de ejecutarlas.
EOF

echo "[4/4] Comprobando cambios y subiendo a GitHub Wiki..."
cd "$WIKI_DIR"
git add -A
if git diff --cached --quiet; then
  echo "✔ La Wiki ya estaba sincronizada al 100%. No hay cambios pendientes."
else
  git commit -m "docs(wiki): sync bilingual manuals, sidebar and home"
  git push origin master
  echo "✔ Wiki sincronizada y publicada con éxito en GitHub."
fi
