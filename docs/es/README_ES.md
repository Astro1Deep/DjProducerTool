# 🎛️ DJProducerTools

**Herramienta avanzada para auditar, limpiar, organizar y gestionar bibliotecas de música para DJs y productores en macOS.**

[![Bash](https://img.shields.io/badge/Bash-4.0%2B-brightgreen)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-macOS%2010.15%2B-blue)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-DJProducerTools-green)](LICENSE.md)
[![Version](https://img.shields.io/badge/Version-1.0.0-blue)](VERSION)

---

## 📖 Descripción

**DJProducerTools** es un conjunto de automatización diseñado para mantener tu biblioteca de música pristina, segura y organizada. Compatible con ecosistemas de **Serato, Traktor, Rekordbox y Ableton Live**, este conjunto de herramientas ofrece todo, desde deduplicación exacta mediante hash (SHA-256) hasta análisis inteligente de metadatos y contenido de audio usando aprendizaje automático local.

Incluye dos versiones del script principal:
- 🇪🇸 `DJProducerTools_MultiScript_ES.sh` (Español)
- 🇺🇸 `DJProducerTools_MultiScript_EN.sh` (Inglés)

---

## ✨ Características Principales

### 🛡️ Seguridad y Copias de Seguridad

- **Auto-Detección**: Encuentra automáticamente la raíz de tu proyecto y otras ubicaciones de bibliotecas.
- **Copias de Seguridad Inteligentes**: Copias de seguridad específicas para metadatos de Serato, Traktor, Rekordbox y Ableton.
- **Snapshots de Integridad**: Genera rápidamente hashes para verificar que tus archivos no se han corrompido.
- **Cuarentena Segura**: Los archivos duplicados o problemáticos se mueven a una cuarentena reversible, nunca se eliminan directamente sin revisión.

### ♻️ Deduplicación y Limpieza

- **Deduplicación Exacta**: Detección bit a bit (SHA-256) para eliminar copias idénticas.
- **Deduplicación "Difusa"**: Detección por nombre y tamaño para limpiar descargas repetidas.
- **Cazador de Matrioskas**: Encuentra carpetas estructuralmente idénticas y sugiere un plan de limpieza seguro.
- **Limpieza de Metadatos**: Elimina URLs basura de etiquetas, normaliza nombres de archivos y detecta caracteres extraños.
- **Conversión de Audio**: Herramienta integrada para convertir WAV a MP3 (320kbps CBR) con backup automático de originales.

### 🧠 IA y Aprendizaje Automático (Local)

- **Análisis Inteligente**: Escaneo profundo de la biblioteca para sugerir acciones de limpieza.
- **Ingesta Inteligente**: Analiza, etiqueta (Key/BPM) y organiza automáticamente música nueva de una carpeta `INBOX`.
- **Auto-Piloto**: Cadenas de automatización que ejecutan diagnósticos, limpieza y copias de seguridad en secuencia.
- **Clasificación de Audio**: Organización automática de muestras y detección de géneros.
- **Entorno Aislado**: Todos los procesos ML ejecutados en un entorno virtual local (`venv`), sin enviar datos a la nube.

---

## 🚀 Instalación

### Instalación Rápida (Usuario)

Para una instalación de usuario, ejecuta este comando en tu terminal. Descargará los scripts principales y los hará ejecutables:

```bash
curl -sL https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/install_djpt.sh | bash
```

### Entorno de Desarrollo (Completo)

Para obtener el proyecto completo, incluyendo los scripts de construcción, pruebas y documentación, clona el repositorio:

```bash
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool
```

## 💻 Uso Básico

```bash
./DJProducerTools_MultiScript_ES.sh   # Para español
./DJProducerTools_MultiScript_EN.sh   # Para inglés
./build_macos_pkg.sh                  # Para crear un instalador .pkg
./build_release_pack.sh               # Para empaquetar una nueva versión
```

Menú Principal:
- Opción 2: Fija tu BASE_PATH (la raíz donde está `_DJProducerTools` o tu música)  
- Menú 9→10→11: Dedup exacto (hash_index → plan → cuarentena)
- Menú 27: Snapshot rápido
- Menú 59: Super doctor (espacio, artefactos, herramientas, venv ML)

## 🗂️ Estructura de Archivos

El estado se guarda en `BASE_PATH/_DJProducerTools/` (config, reports, planes, cuarentena, venv). El script auto-detecta `_DJProducerTools` cercano y normaliza BASE_PATH.

## ML/TF Lab desde cero (modelos reales onnx/tflite)

1. Activa el venv local o deja que el menú lo cree: `source _DJProducerTools/venv/bin/activate` (estado bajo BASE_PATH, nunca en el sistema).
2. En TF Lab (menú 65), pon `DJPT_OFFLINE=0` para permitir modelos reales. Si eliges ONNX (clap_onnx/clip_vitb16_onnx/sentence_t5_tflite), pedirá instalar `onnxruntime`; si falta, usa fallback/mock con aviso.
3. TFLite en macOS ARM: no hay wheel oficial `tflite-runtime`; usa TensorFlow (opción 64) o un entorno con wheel compatible. Mientras tanto, MusicGen_tflite opera en fallback seguro.
4. `DJPT_OFFLINE=1` fuerza heurísticos/mocks en todas las opciones ML. Los avisos no bloquean y las protecciones siguen activas.

### Ejemplos prácticos rápidos
- **Duplicados exactos + cuarentena (seguro):** Menú 9 → 10 (revisar `plans/dupes_plan.tsv`) → 11 (solo si Safe/Lock=0).  
- **Preparar video:** Menú V2/V6 para inventario ffprobe; V4/V5 para plan de transcode H.264 1080p (solo lista, no ejecuta).  
- **BPM/onsets:** Menú 49 (reporte BPM) + 67 (auto-cues/onsets) para marcar pistas; usa `librosa` si está.  
- **DMX en dry-run:** Menú V3 con `DRYRUN_FORCE=1` para registrar frames sin enviar al hardware.  
- **Embeddings/tags en TF Lab:** Menú 65.1/65.2 con `DJPT_OFFLINE=0`, modelo `clap_onnx`; genera `audio_embeddings.tsv` / `audio_tags.tsv` para similitud/matching.  
- **Plan de loudness:** Menú 66 o 65.5, fija objetivo/tolerancia LUFS; produce `audio_loudness.tsv` con ganancia sugerida (sin escribir audio).

## 📚 Documentación

- **[INSTALL_ES.md](INSTALL_ES.md)** - Guía de instalación detallada
- **[GUIDE_es.md](GUIDE_es.md)** - Guía completa del usuario
- **API (dev)**: material para desarrolladores en `docs/internal/API_ES.md`
- **[DEBUG_GUIDE.md](DEBUG_GUIDE.md)** - Guía de depuración y barras de progreso
- **[SECURITY.md](SECURITY.md)** - Políticas de seguridad
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Guía de contribución

## 📋 Requisitos

- **macOS** con bash; acceso de lectura/escritura a tus volúmenes de música/proyectos.
- **Dependencias opcionales** (se auto-detectan y preguntan): ffmpeg/ffprobe, sox/flac, jq, python3.
- **Perfil IA local** (opción 70):
  - **LIGHT (recomendado)**: numpy+pandas+scikit-learn+joblib+librosa
  - **TF_ADV (opcional, Apple Silicon)**: LIGHT + tensorflow-macos + tensorflow-metal

## 📄 Licencia

DJProducerTools License (Atribución + Participación de Ingresos). Consulta [LICENSE.md](LICENSE.md).

## 🤝 Contribución

¿Tienes ideas? ¿Encontraste un error? ¿Quieres ayudar?

- **GitHub Issues**: [Reporta errores](https://github.com/Astro1Deep/DjProducerTool/issues)
- **GitHub Discussions**: [Únete a la comunidad](https://github.com/Astro1Deep/DjProducerTool/discussions)
- **Seguridad**: security@astro1deep.com

---

**Creado por**: Astro1Deep 🎵  
**GitHub**: https://github.com/Astro1Deep/DjProducerTool  
**Versión**: 1.0.0  
**Estado**: Production Ready ✅

---

*"Gestión segura, inteligente y transparente de bibliotecas de música"* ✨
