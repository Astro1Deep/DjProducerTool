# 🎛️ DJProducerTools

**Toolkit avanzado para auditoría, limpieza, organización y gestión de librerías musicales para DJs y Productores en macOS.**

!Bash
!Python
!Platform
!License

---

## 📖 Descripción

**DJProducerTools** es una suite de automatización diseñada para mantener tu biblioteca musical impecable, segura y organizada. Compatible con los ecosistemas de **Serato, Traktor, Rekordbox y Ableton Live**, este toolkit ofrece desde deduplicación exacta por hash (SHA-256) hasta análisis inteligente de metadatos y contenido de audio mediante Machine Learning local.

Incluye dos versiones del script principal:
- 🇪🇸 `DJProducerTools_MultiScript_ES.sh` (Español)
- 🇺🇸 `DJProducerTools_MultiScript_EN.sh` (English)

### 📸 Vistazo Rápido
!Menú ES

---

## ✨ Características Principales

### 🛡️ Seguridad y Backups
- **Backups Inteligentes**: Copias de seguridad específicas para metadatos de Serato, Traktor, Rekordbox y Ableton.
- **Snapshots de Integridad**: Generación rápida de hashes para verificar que tus archivos no se han corrompido.
- **Quarantine Segura**: Los archivos duplicados o problemáticos se mueven a una cuarentena reversible, nunca se borran directamente sin revisión.

### ♻️ Deduplicación y Limpieza
- **Deduplicación Exacta**: Detección bit a bit (SHA-256) para eliminar copias idénticas.
- **Deduplicación "Fuzzy"**: Detección por nombre y tamaño para limpiar descargas repetidas.
- **Limpieza de Metadatos**: Eliminación de URLs basura en tags, normalización de nombres de archivo y detección de caracteres extraños.
- **Conversión de Audio**: Herramienta integrada (Opción 71) para convertir WAV a MP3 (320kbps CBR) con backup automático de originales.

### 🧠 IA y Machine Learning (Local)
- **Smart Analysis**: Escaneo profundo de la librería para sugerir acciones de limpieza.
- **Auto-Pilot**: Cadenas de automatización (A23-A28) que ejecutan diagnósticos, limpieza y backups en secuencia.
- **Clasificación de Audio**: Organización automática de samples (Kicks, Snares, etc.) y detección de género.
- **Entorno Aislado**: Todo el ML corre en un entorno virtual (`venv`) local, sin enviar datos a la nube.

---

## 🚀 Instalación

Puedes instalar o actualizar los scripts ejecutando el siguiente bloque en tu terminal:

```bash
# Crear script de instalación
cat <<'EOF' > install_djpt.sh
#!/usr/bin/env bash
set -e
echo "⬇️ Descargando DJProducerTools..."
for f in DJProducerTools_MultiScript_ES.sh DJProducerTools_MultiScript_EN.sh; do
  url="https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/$f"
  curl -fsSL "$url" -o "$f"
  chmod +x "$f"
done
echo "✅ ¡Listo! Ejecuta ./DJProducerTools_MultiScript_ES.sh para empezar."
EOF

# Ejecutar instalador
chmod +x install_djpt.sh && ./install_djpt.sh
```

## Uso básico
```bash
./DJProducerTools_MultiScript_ES.sh   # o EN para inglés
```
- Opción 2: fija tu BASE_PATH (la raíz donde está `_DJProducerTools` o tu música).  
- Menú 9→10→11: dedup exacto (hash_index → plan → quarantine).  
- Menú 27: snapshot rápido.  
- Menú 59: super doctor (espacio, artefactos, herramientas, venv ML).
- Menú A (A23–A26): auto-pilot de flujos completos.

## Rutas y estado
El estado vive en `BASE_PATH/_DJProducerTools/` (config, reports, planes, quarantine, venv). El script auto-detecta `_DJProducerTools` cercano y normaliza BASE_PATH (evita rutas duplicadas).

## Cadenas automatizadas (68 / tecla A)
- 21 flujos predefinidos (backup+snapshot, dedup+quarantine, limpieza, health scan, prep show, integridad/corruptos, eficiencia, ML básica, backup predictivo, sync multi, etc.).
## Auto-pilot IA local
- Auto-pilot (IA local / sin intervención):  
  - 23) Prep show + clean/backup + dedup multi-disco  
  - 24) Todo en uno (hash → dupes → quarantine → snapshot → doctor)  
  - 25) Limpieza + backup seguro (rescan → dupes → quarantine → backup → snapshot)  
  - 26) Relink doctor + super doctor + export estado  
  - 27) Deep/ML (hash → Smart Analysis → Predictor → Optimizer → Integrated dedup → snapshot)
  - 28) Auto-pilot seguro (reusar análisis previos + únicos + snapshot + doctor)

## Ayuda y wiki
- `GUIDE.md`: guía extensa (flujos, exclusiones, snapshots, tips).
- Menús completos: `docs/menu_es_full.svg` y `docs/menu_en_full.svg` (visibles en GitHub).

## Requisitos
- macOS con bash; acceso lectura/escritura a tus volúmenes de música/proyectos.
- Dependencias opcionales (se auto-detectan y te preguntan): ffmpeg/ffprobe, sox/flac, jq, python3.
- Perfil IA local (opción 70):  
  - **LIGHT (recomendado)**: numpy+pandas+scikit-learn+joblib+librosa.  
  - **TF_ADV (opcional, Apple Silicon)**: LIGHT + tensorflow-macos + tensorflow-metal (descarga grande).

## Licencia
DJProducerTools License (Attribution + Revenue Share). Consulta `LICENSE`.
