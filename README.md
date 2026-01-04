<img width="1536" height="1024" alt="20260103_1357_Futuristic DJ Tool Banner_remix_01ke22aqhxe2r9n8vcsd71a4a3" src="https://github.com/user-attachments/assets/ec237d17-0aa3-4363-baea-fb9f08528714" />


# 🎛️ DJProducerTool

**Advanced toolkit for auditing, cleaning, organizing, and managing music libraries for DJs and Producers on macOS.**

!Bash
!Python
!Platform
!License

---

## 📖 Description

**DJProducerTools** is an automation suite designed to keep your music library pristine, safe, and organized. Compatible with **Serato, Traktor, Rekordbox, and Ableton Live** ecosystems, this toolkit offers everything from exact deduplication via hashing (SHA-256) to intelligent metadata and audio content analysis using local Machine Learning.

It includes two versions of the main script:
- 🇪🇸 `DJProducerTools_MultiScript_ES.sh` (Spanish)
- 🇺🇸 `DJProducerTools_MultiScript_EN.sh` (English)

### 📸 Quick Look

!Menú ES

!Menú EN

## ✨ Características Principales

### 🛡️ Security and Backups

- **Auto-Detection**: Automatically finds your project root (`BASE_PATH`) and other library locations.
- **Smart Backups**: Specific backups for Serato, Traktor, Rekordbox, and Ableton metadata.
- **Integrity Snapshots**: Quickly generate hashes to verify that your files have not been corrupted.
- **Safe Quarantine**: Duplicate or problematic files are moved to a reversible quarantine, never deleted directly without review.

### ♻️ Deduplication and Cleanup

- **Exact Deduplication**: Bit-by-bit detection (SHA-256) to eliminate identical copies.
- **"Fuzzy" Deduplication**: Detection by name and size to clean up repeated downloads.
- **Matrioshka Hunter**: Finds structurally identical folders (e.g., duplicate project folders) and suggests a safe cleanup plan.
- **Metadata Cleanup**: Removes junk URLs from tags, normalizes filenames, and detects strange characters.
- **Audio Conversion**: Integrated tool (Option 71) to convert WAV to MP3 (320kbps CBR) with automatic backup of originals.

### 🧠 AI and Machine Learning (Local)

- **Smart Analysis**: Deep library scan to suggest cleanup actions.
- **Smart Ingest**: Automatically analyzes, tags (Key/BPM), and organizes new music from an `INBOX` folder.
- **Auto-Pilot**: Automation chains (A23-A28) that run diagnostics, cleanup, and backups in sequence.
- **Audio Classification**: Automatic organization of samples (Kicks, Snares, etc.) and genre detection.
- **Isolated Environment**: All ML runs in a local virtual environment (`venv`), without sending data to the cloud.

---

## 🚀 Installation

### Quick Install (User)

For a user installation, run this command in your terminal. It will download the main scripts and make them executable:

```bash
curl -sL https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/install_djpt.sh | bash
```

### Entorno de Desarrollo (Completo)
Para obtener el proyecto completo, incluyendo los scripts de build, tests y documentación, clona el repositorio:

```bash
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool
```

## Uso básico
```bash
./DJProducerTools_MultiScript_ES.sh   # o EN para inglés
./build_macos_pkg.sh                  # Para crear un instalador .pkg para distribuir
./build_release_pack.sh               # Para empaquetar una nueva versión para GitHub
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
 
