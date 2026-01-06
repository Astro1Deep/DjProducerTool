
<img src="https://github.com/user-attachments/assets/0fed1bb5-a36f-41d7-8021-5596bbc69004" alt="DJProducerTools banner" style="max-width: 100%; height: auto;" />


# DJProducerTool 🎵

Bilingual CLI for safe DJ library management on macOS. Spanish version: [README_ES.md](./README_ES.md).

## 📌 Status

- **Current version:** 1.0.0 (2024-01-04)
- **Implemented (CLI):** file catalog, SHA-256 index and duplicate plan, quarantine manager, `_Serato_`/DJ metadata backups, fast hash snapshot, TSV reports (ffprobe, relink helper, rescan), per-folder playlists, safety toggles (`SAFE_MODE`, `DJ_SAFE_LOCK`, `DRYRUN_FORCE`), ffprobe video inventory + transcode plan (H.264 1080p suggested), playlist→OSC/DMX plans, DMX send (dry-run by default), local API/OSC server, BPM/librosa TSV analysis.
- **Roadmap/placeholders:** advanced ML auto-tagging and TensorFlow Lab ideas (only documented/plan output for now); richer HTML/PDF exports.

## ✨ Features (current)

- 📂 **Catalog + hash**: inventory and SHA-256 TSV for exact duplicate detection.
- 🛡️ **Quarantine & safety**: TSV/JSON plans and optional quarantine moves; `SAFE_MODE`/`DJ_SAFE_LOCK` enabled by default; `--dry-run` forces simulation.
- 💾 **Fast backups**: rsync of `_Serato_` and DJ metadata (Serato/Traktor/Rekordbox/Ableton) into `_DJProducerTools/`.
- 🔍 **Reports**: fast hash snapshot, ffprobe corruption scan, relink helper, smart rescan, per-folder `.m3u8` playlists.
- 🎥 **Video prep**: ffprobe inventory + suggested transcode plan (H.264 1080p).
- 🎛️ **Playlists → OSC/DMX**: plans with timing from `.m3u/.m3u8`; optional DMX send via ENTTEC honoring Safe/Lock/dry-run.
- 🔌 **Local API/OSC**: lightweight HTTP (/status,/reports) + OSC (/djpt/ping) start/stop from menu.
- 🧭 **Progress & state**: spinners/bars, route history, log viewer, exclusion/profile manager.
- 🌐 **Bilingual**: menus and messages in EN/ES.
- 🔄 **Shared corpus**: sync reports/plans (hash, ML, playlists) across disks via menu 69 to reuse analyses.

## 🚧 Roadmap / Placeholders

- ML auto-tagging, TensorFlow Lab, and advanced exports remain in roadmap (plans only, no audio mutation).

## 🚀 Quick Start

### One-line installation

```bash
curl -fsSL https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/INSTALL.sh | bash
```

### Manual installation

```bash
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool
chmod +x scripts/*.sh
# English
./scripts/DJProducerTools_MultiScript_EN.sh
# Spanish
./scripts/DJProducerTools_MultiScript_ES.sh
```

## 🛠️ Usage

- CLI flags: `--help | --version | --test | --dry-run`
  - `--test` checks core deps (bash, find, awk, sed, xargs, python3, ffprobe, sox, jq).
  - `--dry-run` forces `DRYRUN_FORCE=1` while keeping backups/quarantine safe.
- State lives in `BASE_PATH/_DJProducerTools` (defaults to current working directory). Use `HOME_OVERRIDE=/custom` to isolate state.
- Safe defaults: `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`.

Quick commands (after creating the optional symlink via menu 21):
```bash
dj       # auto language
dj-en    # force English
dj-es    # force Spanish
```

## 📚 Documentation

- **[FEATURES.md](./FEATURES.md)** — Scope and status (EN)
- **Características:** ver README_ES para resumen en español.
- **[guides/GUIDE.md](./guides/GUIDE.md)** — Quick guide (EN)
- **[guides/GUIDE_es.md](./guides/GUIDE_es.md)** — Quick guide (ES)
- **[guides/ADVANCED_GUIDE.md](./guides/ADVANCED_GUIDE.md)** — Advanced action/menu guide (EN)
- **[guides/ADVANCED_GUIDE_es.md](./guides/ADVANCED_GUIDE_es.md)** — Advanced guide (ES)
- **TF Lab (65):** Instala TF con opción 64 (venv aislado). `DJPT_TF_MOCK=1` evita descargas y usa modo offline. Salidas: `reports/audio_embeddings.tsv`, `reports/audio_tags.tsv`, `reports/audio_similarity.tsv`, `reports/audio_anomalies.tsv`, `reports/audio_segments.tsv`.
- **Colaboradores:** planes/roadmap/API/seguridad (incluye FEATURES/DEBUG/API/VERSION) en `docs/internal/` (no necesario para usuarios).
- **Wiki (manual extendido):** `docs/wiki/WIKI_EXTENDED_MANUAL_ES.md` (ES) y `docs/wiki/WIKI_EXTENDED_MANUAL_EN.md` (EN) con todas las opciones/acciones en detalle.

### Novedades (1.0.0)
- Plan de transcode: permite elegir códec (auto/videotoolbox/nvenc/libx264) y ejecutar ffmpeg con confirmación; respeta `DRYRUN_FORCE`.
- API/OSC: soporta Bearer token; `/djpt/ping` y `/djpt/status` responden “unauthorized” sin token.

## Safety & Packaging (recordatorios rápidos)
- No ejecutes el script como root ni apuntes `BASE_PATH` al disco del sistema. Usa `confirm_heavy_action` para operaciones grandes y revisa exclusiones por defecto antes de escanear discos con mucho media.
- Dependencias mínimas: `bash`, `python3`, `ffprobe`, `sox`, `jq`. Ejemplo macOS: `brew install ffmpeg sox jq`.
- Paquete limpio: `git archive -o ../DJProducerTools_WAX.zip HEAD` e incluye `djpt_icon.icns` para el icono del Dock.

### ML/TF Lab desde cero (modelos reales onnx/tflite)

1. Activa el venv local o deja que el menú lo cree: `source _DJProducerTools/venv/bin/activate` (se aloja en la carpeta donde arrancas el script, nunca en el sistema).
2. En TF Lab (menú 65), pon `DJPT_OFFLINE=0` para permitir modelos reales. Si eliges modelos ONNX (clap_onnx/clip_vitb16_onnx/sentence_t5_tflite), se pedirá instalar `onnxruntime`; si falta, se usa fallback mock con aviso.
3. TFLite en macOS ARM: no hay wheel oficial `tflite-runtime`; usa TensorFlow (opción 64) o un entorno con wheel compatible. Mientras tanto, MusicGen_tflite opera en modo fallback seguro.
4. `DJPT_OFFLINE=1` fuerza heurísticos/mocks en todas las opciones ML. Los avisos son no bloqueantes y el script permanece en modo seguro.

## ⚙️ System Requirements

- macOS 10.13+ (10.15+ recommended)
- bash 4.0+ or zsh
- Dependencies:
  - `ffmpeg`/`ffprobe`
  - `jq`
  - `curl`
  - `python3`
  - Optional: `pyserial` (DMX send), `python-osc` (API/OSC), `librosa` + `soundfile` (BPM/auto-cues)

## 🧪 Testing

```bash
bash scripts/VERIFY_AND_TEST.sh --fast   # smoke tests
./scripts/DJProducerTools_MultiScript_EN.sh --test
./scripts/DJProducerTools_MultiScript_ES.sh --test
```

## 📊 Project Structure

```
DJProducerTools_Project/
├── scripts/            # Main menus and helpers
├── lib/                # Python helpers (video, playlist→OSC/DMX, BPM, DMX, API/OSC)
├── docs/               # Plans and module notes
├── guides/             # Quick and advanced guides (EN/ES)
├── _DJProducerTools/   # State (reports/plans/logs/venv)
└── build_pkg_staging/  # Packaging assets (optional)
```

## 📝 Version History

- **v1.0.0** (Jan 2024)
  - Hash index + duplicate plan with optional quarantine
  - `_Serato_`/DJ metadata backups; fast hash snapshot
  - EN/ES menus, safety defaults, TSV reports
- **v1.9.5** (2023)
  - First automation prototypes (stabilized)

## 📄 License

MIT - see [LICENSE](./LICENSE).

## 👨‍💻 Author

**Astro1Deep**  
GitHub: [@Astro1Deep](https://github.com/Astro1Deep)  
Project: [DjProducerTool](https://github.com/Astro1Deep/DjProducerTool)

**Made with ❤️ for DJ Producers.**
