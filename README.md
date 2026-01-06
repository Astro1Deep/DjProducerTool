<img width="1536" height="1024" alt="20260103_1357_Futuristic DJ Tool Banner_remix_01ke22aqhxe2r9n8vcsd71a4a3" src="https://github.com/user-attachments/assets/4fa57953-682f-4209-a5db-612c7b8fb812" />






# DJProducerTool 🎵

Bilingual CLI for safe DJ library management on macOS. Spanish version: [README_ES.md](./README_ES.md).

## 📌 Status

- **Current version:** 2.0.0 (2024-01-04)
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
- **[FEATURES_ES.md](./FEATURES_ES.md)** — Alcance y estado (ES)
- **[guides/GUIDE.md](./guides/GUIDE.md)** — Quick guide (EN)
- **[guides/GUIDE_es.md](./guides/GUIDE_es.md)** — Quick guide (ES)
- **[guides/ADVANCED_GUIDE.md](./guides/ADVANCED_GUIDE.md)** — Advanced action/menu guide (EN)
- **[guides/ADVANCED_GUIDE_es.md](./guides/ADVANCED_GUIDE_es.md)** — Advanced guide (ES)
- **[docs/ADVANCED_MODULES_PLAN.md](./docs/ADVANCED_MODULES_PLAN.md)** — Advanced modules plan/status
- **[API_ES.md](./API_ES.md)** — API/OSC draft (ES, placeholder)
- **[DEBUG_GUIDE_ES.md](./DEBUG_GUIDE_ES.md)** — Debug guide (ES)
- **TF Lab (65):** Instala TF con opción 64 (venv aislado). `DJPT_TF_MOCK=1` evita descargas y usa modo offline. Salidas: `reports/audio_embeddings.tsv`, `reports/audio_tags.tsv`, `reports/audio_similarity.tsv`, `reports/audio_anomalies.tsv`, `reports/audio_segments.tsv`.

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

- **v2.0.0** (Jan 2024)
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
