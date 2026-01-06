# Advanced Modules Implementation Plan

Version: draft (aligned with CLI 2.0.0)  
Status: Video inventory/transcode plan + playlist→OSC/DMX + DMX send (dry-run) + HTTP/OSC status server + BPM (tags/librosa) implemented parcialmente. Items abajo siguen como roadmap/mejora.  
Goal: turn remaining placeholders into real features with safety and test coverage.

## Principles
- Preserve safety defaults (`SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE=0`); destructive actions gated by confirmation.
- Keep all writes inside `BASE_PATH/_DJProducerTools` unless user-confirmed export.
- Prefer plan/report-first flows; only mutate audio/media when explicitly requested.
- Bilingual parity (EN/ES menus, docs, help).

## Modules & Deliverables

### 1) DMX / Lights
- **Scope**: basic DMX output via configurable adapter (e.g., ENTTEC DMX USB Pro) with channel mapping presets.
- **Deliverables**:
  - CLI subcommands to load DMX config (universe, port, channel map) and send test scenes.
  - Plan generator → `plans/dmx_scenes.tsv` with channel/value timelines; optional “apply” to send live with dry-run preview.
  - Preset manager for fixtures (JSON) in `config/dmx_presets.json`.
  - Logging of sent frames to `logs/dmx_*.log`.
- **Deps**: `python3` + `pyserial` (isolated venv); optional `ola` CLI for testing.
- **Tests**: unit tests for packet formatting; integration stub that mocks serial port.

### 2) Serato Video / Transcode Prep
- **Scope**: real media inspection and transcode plan for Serato-friendly formats.
- **Deliverables**:
  - Video catalog with ffprobe (resolution, codec, duration, bitrate) → TSV/JSON.
  - Transcode plan generator (target: H.264, 1080p, AAC) with estimated size/time.
  - Optional “dry-run ffmpeg command list” export.
- **Deps**: ffprobe/ffmpeg.
- **Tests**: sample fixtures (.mp4/.mov) to validate parsing and command generation.

### 3) OSC / API
- **Scope**: lightweight local OSC server + HTTP status for automation.
- **Deliverables**:
  - OSC server (UDP, default 127.0.0.1:9000) exposing ping/status/events.
  - HTTP minimal API (FastAPI/Flask-lite) with `/status`, `/dupes/summary`, `/logs/tail`.
  - CLI toggles: start/stop server, port selection, auth token for remote use.
- **Deps**: `python3` + `python-osc` + `fastapi`/`uvicorn` in venv.
- **Tests**: loopback OSC send/recv; HTTP 200 for status; config reload.

### 4) BPM / Audio Analysis
- **Scope**: BPM/energy/key estimation for audio files with batch mode.
- **Deliverables**:
  - Analyzer script (python) using `librosa`/`essentia` fallback to sox+ffmpeg for tempo.
  - CLI options to run on BASE_PATH or list file; outputs `reports/audio_analysis.tsv` (path, bpm, confidence, key?, energy?).
  - Plan for re-tagging (TSV only; no writes by default).
- **Deps**: `python3`, `librosa` (or `essentia` if available), `ffmpeg`.
- **Tests**: fixtures with known BPM; tolerance ±1 BPM.

### 5) ML / Auto-tagging
- **Scope**: opt-in embeddings and tagging; respect offline mode.
- **Deliverables**:
  - Venv installer step separated by model family (YAMNet, musicnn, nnfp).
  - Batch embedding extractor → `reports/audio_embeddings.tsv` (path, vector path).
  - Similarity report (top-N pairs, threshold) → TSV/JSON.
  - Tagging report using chosen model → `reports/audio_tags.tsv`.
- **Deps**: TensorFlow + `tensorflow_hub`, `soundfile`, `numpy`, `pandas`.
- **Tests**: mock to ensure pipeline runs without downloading in CI; golden-size checks.

### 6) Playlist → OSC/DMX bridge
- **Scope**: convert `.m3u/.m3u8` to OSC cues / DMX scene timelines.
- **Deliverables**:
  - Parser that extracts intro/drop/outro markers (configurable offsets).
  - Outputs `plans/osc_from_playlist.tsv` / `plans/dmx_from_playlist.tsv`.
  - Optional sender that replays timeline in real time (dry-run default).
- **Deps**: python3, reuse OSC/DMX modules.
- **Tests**: synthetic playlists to validate offsets and ordering.

## Cross-Cutting Tasks
- Config schema updates (`config/*.json` with sample templates).
- Help/README updates (EN/ES) after each module lands.
- Tests: add to `tests/` with `bash` wrappers to exercise python entrypoints in dry-run.
- Packaging: ensure `VERIFY_AND_TEST.sh` skips network/model downloads unless flagged.

## Execution Order (suggested)
1) Serato Video prep (ffprobe + transcode plan) – minimal deps.  
2) OSC/API scaffold – enables remote control/testing.  
3) BPM/Audio analysis – builds toward ML features.  
4) Playlist → OSC/DMX bridge – uses OSC scaffold.  
5) DMX output – hardware-focused; requires careful dry-run.  
6) ML/Auto-tagging – heaviest deps, opt-in last.

## Testing Strategy
- Unit: python modules with mocks for serial/OSC/ffprobe.  
- Integration: bash wrappers running on sample fixtures under `_DJProducerTools/tests_fixtures`.  
- Safety: enforce `SAFE_MODE`/`DJ_SAFE_LOCK` gating on any write/move/send.  
- CI-friendly: provide `--offline` to skip downloads; cache venvs in `_DJProducerTools/venv`.
