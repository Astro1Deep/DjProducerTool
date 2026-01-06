# DJProducerTools – Advanced Guide (EN)

Version: 1.0.0 (2024-01-04)  
Scope: CLI for catalog/hash, duplicate planning + quarantine, DJ metadata backups, TSV reports. DMX/Video/OSC/API/ML remain placeholders/roadmap (plans/reports only).

## Safety Defaults
- `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE=0`.  
- Reports/plans/quarantine live in `BASE_PATH/_DJProducerTools/{reports,plans,quarantine,logs,config,venv}`.  
- `--dry-run` forces DRY mode for moves/rsync.  
- Use `HOME_OVERRIDE=/path ./scripts/DJProducerTools_MultiScript_EN.sh` to sandbox.

## Core Menu (1–12)
- **1 Status**: Shows BASE_PATH, state dirs, logs, safety flags. No writes.  
- **2 Change Base**: Updates BASE_PATH; re-inits state dirs. No content moves.  
- **3 Volume summary**: `du -sh` BASE + last reports list.  
- **4 Top dirs**: Depth 2, sorted by size. Read-only.  
- **5 Top files**: Largest files via `find|ls -lhS`. Read-only.  
- **6 Scan workspace**: Full file listing -> `reports/workspace_scan.tsv`. Warns on very large trees.  
- **7 Serato backup**: rsync `_Serato_` / `_Serato_Backup` -> `state/serato_backup`. Obeys DRY/Safe.  
- **8 DJ metadata backup**: Finds Serato/Traktor/Rekordbox/Ableton folders -> rsync to `state/dj_metadata_backup`. Obeys DRY/Safe.  
- **9 Hash index (SHA-256)**: Generates `reports/hash_index.tsv` (hash, rel, full). Heavy on big trees.  
- **10 Dupes plan (exact)**: Uses hash_index -> `plans/dupes_plan.tsv/json` (KEEP/QUARANTINE).  
- **11 Apply quarantine**: Moves QUARANTINE entries to `quarantine/<hash>/file` unless Safe/Lock/DRY. Confirmation required.  
- **12 Quarantine manager**: List / restore all / delete all. Restore/delete blocked by Safe/Lock.

## Media / Organization (13–24)
- **13 ffprobe corrupt**: `media_corrupt.tsv` (files failing ffprobe).  
- **14 Playlists per folder**: Creates `playlist.m3u8` in each dir (audio extensions).  
- **15 Relink helper**: `relink_helper.tsv` (rel path + full).  
- **16 Mirror by genre (plan)**: `plans/mirror_by_genre.tsv` stub (GENRE_UNKNOWN).  
- **17 Find DJ libs**: Lists dirs matching Serato/Traktor/Rekordbox/Ableton.  
- **18 Intelligent rescan**: TSV listing all files with progress.  
- **19 Tools diag**: Presence of ffprobe/shasum/rsync/find/ls/du.  
- **20 Fix ownership/flags (plan)**: `plans/fix_ownership_flags.tsv` (chown/chmod KEEP).  
- **21 Install cmd**: Symlink `djproducertool` to script (blocked if Safe).  
- **22 Uninstall cmd**: Remove symlink (blocked if Safe).  
- **23 Toggle SafeMode**, **24 Toggle DJ_SAFE_LOCK**: Flip flags, persist to config.

## Processes / Cleanup (25–39)
- **25 Quick help**: Suggested flows.  
- **26 State export/import**: Tar.gz of state dir (`DJPT_state_bundle.tar.gz`).  
- **27 Snapshot hash fast**: `reports/snapshot_hash_fast.tsv` (hash, path).  
- **28 Logs viewer**: Lists state logs.  
- **29 Toggle DRYRUN_FORCE**: Flip DRY global flag.  
- **30 Tags organize plan**: `plans/organize_by_tags.tsv` (genre placeholder).  
- **31 Tags report**: TSV counts of genres (placeholder).  
- **32/33 Serato Video report/plan**: Placeholders generating TSV/plan (no transcode).  
- **34 Normalize names plan**: TSV with target names.  
- **35 Samples by type plan**: TSV bucketed by extension/type.  
- **36 Web clean submenu**: URL cleaning tools for playlists/tags.  
- **37 Web whitelist manager**: Manage allowed domains.  
- **38 Clean web in playlists**: Strip URLs in `.m3u/.m3u8` -> plan.  
- **39 Clean web in tags**: Plan to remove URLs from tags (no writes).

## Deep / ML (40–52, 62–67)
Status: Heuristic/plan generators; venv optional at `state/venv`.  
- **40 Smart analysis**: JSON summary (files/audio/video counts, size, quick recs).  
- **41 ML predictor**: TSV heuristic flags (long names, zero-size).  
- **42 Efficiency optimizer**: TSV checklist (dupes, tags, backup, snapshot).  
- **43 Smart workflow**: Text sequence of recommended actions.  
- **44 Integrated dedup**: TSV summary combining exact/fuzzy placeholders.  
- **45–48**: Plans for organization, metadata harmony, predictive backup, cross-platform sync.  
- **49**: Audio BPM (tags/librosa) -> TSV (`lib/bpm_analyzer.py`).  
- **50**: API/OSC server start/stop (`lib/osc_api_server.py`, HTTP /status,/reports; OSC /djpt/ping). PID stored in `_DJProducerTools/osc_api_server.pid`.  
- **51–52**: Advanced recommendations/pipeline (plans).  
- **62 ML evolutive**: Optional scikit-learn install; train/predict from your dupes plans.  
- **63 Toggle ML**: Disable/enable ML usage globally.  
- **64 TensorFlow manager**: Optional TF install (downloads).  
- **65 TensorFlow Lab**: Auto-tag/similarity/anomalies/segments (TF si disponible; fallback offline).  
- **66 LUFS plan**: Loudness analysis plan (requires python3+pyloudnorm+soundfile).  
- **67 Auto-cues**: Onset-based cue plan (requires python3+librosa).

## Extras / Utilities (53–67)
- **53 Reset state/cleanup extras**: Deletes `_DJProducerTools` (blocked by Safe/Lock).  
- **54 Profiles manager**: Save/load path profiles for BASE/GENERAL/AUDIO.  
- **55 Ableton Tools**: Quick `.als` report (samples/plugins).  
- **56 Importers cues**: Rekordbox/Traktor cue placeholders to TSV.  
- **57 Exclusions manager**: Manage exclude patterns (profiles).  
- **58 Compare hash_index**: Diff two hash indexes (no rehash).  
- **59 State health**: Checks size/log/quarantine hints.  
- **60 Export/import config**: Moves only config/profiles.  
- **61 Mirror integrity check**: Compares hash indexes for missing/corrupt.

## Submenu L (DJ Libraries & Cues)
- **L1** Configure AUDIO/GENERAL/REKORDBOX_XML/ABLETON roots (saved to config).  
- **L2** Catalog audio for a library ID -> `reports/catalog_audio_<ID>.tsv`.  
- **L3** Duplicate plan by basename+size across catalogs -> `plans/audio_dupes_from_catalog.tsv`.  
- **L4** Rekordbox XML cues -> `reports/dj_cues.tsv` (placeholder).  
- **L5** dj_cues -> `ableton_locators.csv` (placeholder).

## Submenu D (General Duplicates)
- **D1** General catalog (respect excludes/depth) -> `reports/general_catalog.tsv`.  
- **D2** Duplicates by basename+size -> `plans/general_dupes_plan.tsv`.  
- **D3** Smart dupes report/plan (counts/top keys).  
- **D4** Multi-disk consolidation plan (adds missing to destination).  
- **D5** Exact dupes by hash across roots (comma-separated).  
- **D6** Inverse consolidation (mark source extras vs destination).  
- **D7** Matrioshka folders (structure hash; KEEP/REMOVE suggestions).  
- **D8** Mirror folders by content (name+size or full hash).  
- **D9** Audio similarity (requires TF/YAMNet; plan only).

## Submenu V (Visuals / DAW / OSC / DMX)
Status: now generates timed plans; DMX sending soportado con dry-run por defecto.  
- **V1** Ableton `.als` quick report (samples/plugins used).  
- **V2** Visuals inventory (ffprobe) -> TSV.  
- **V3** Enviar plan DMX via ENTTEC DMX USB Pro (SAFE/LOCK/DRY → dry-run).  
- **V4/V5** Serato Video: inventory + transcode plan (ffmpeg suggested H.264 1080p).  
- **V6** Resolution/duration report via ffprobe.  
- **V7** Organize visuals by resolution (plan).  
- **V8** Exact dupes (hash) for visuals.  
- **V9** Optimize plan suggesting H.264 1080p.  
- **V10** OSC plan from playlist (`.m3u/.m3u8`) with start times (ffprobe durations).  
- **V11** DMX plan from playlist (Intro/Drop/Outro timed, CH map editable).  
- **V12** DMX presets template (editable channels/values).

## Outputs & Paths
- Reports: `BASE_PATH/_DJProducerTools/reports`
- Plans: `BASE_PATH/_DJProducerTools/plans`
- Quarantine: `BASE_PATH/_DJProducerTools/quarantine`
- Logs: `BASE_PATH/_DJProducerTools/logs`
- Config: `BASE_PATH/_DJProducerTools/config/djpt.conf`
- ML venv: `BASE_PATH/_DJProducerTools/venv` (optional)

## Suggested Safe Flows
- **Dedup safe**: 6 → 9 → 10 → (manual review dupes_plan) → 11 (only if Safe/Lock=0) → 12 for restore.  
- **Backup + integrity**: 7 → 8 → 27 (snapshot) → 3 to verify.  
- **General dupes (multi-disk)**: D1 → D2 → D3 (review) → D4/D6 plans → 10/11 if exact hash needed.  
- **Visuals prep**: V2 → V6 → V7/V9 plans; transcode manually based on plan.

## TensorFlow Lab (opción 65)
- Requiere TF+tf_hub+soundfile (instalar con opción 64). Si no quieres descargar, usa `DJPT_TF_MOCK=1` para modo offline (fallback hash).
- Modelos soportados: `yamnet` (default), `musicnn`, `musictag` (nnfp). Selecciona en opción 65.1/65.2.
- Salidas:
  - `reports/audio_embeddings.tsv` / `reports/audio_tags.tsv`
  - `reports/audio_similarity.tsv` (umbral 0.60, top 200)
  - `reports/audio_anomalies.tsv` (silencio/clipping)
  - `reports/audio_segments.tsv` (onsets/segmentos)
- Consejos: limita a ~150 archivos, `DJPT_TF_MOCK=1` para CI/offline; borra/recachea venv desde opción 64 si hay problemas.
- Modelos ONNX/TFLite reales: activa venv (`source _DJProducerTools/venv/bin/activate`), pon `DJPT_OFFLINE=0` y elige `clap_onnx/clip_vitb16_onnx/sentence_t5_tflite` en 65. Se intentará instalar `onnxruntime`; si no está, se usa fallback con aviso. En macOS ARM no hay wheel `tflite-runtime`; usa TensorFlow (64) o un entorno con wheel compatible; MusicGen_tflite cae a fallback seguro.

## Why these deps and what you gain
- **ffprobe/ffmpeg**: media integrity, video inventory, keyframes for tagging. Beneficio: detección temprana de archivos corruptos y planes de transcode sin modificar nada.
- **sox/librosa**: BPM/onsets/segmentation sin tocar tags. Beneficio: cues preliminares y consistencia de tempos.
- **onnxruntime / tensorflow**: embeddings y tagging locales (yamnet/musicnn/musictag/CLIP/CLAP) sin subir audio. Beneficio: recomendaciones/similitud sin perder privacidad.
- **pyloudnorm**: planes de normalización LUFS sin aplicar ganancia. Beneficio: preparar lotes homogéneos antes de masterizar.
- **pyserial/python-osc/fastapi**: DMX/OSC/API locales. Beneficio: controlar luces/estado sin exponer servicios externos.
- **Seguridad**: `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE` y `DJPT_OFFLINE` mantienen todo en simulación/heurísticos por defecto; cualquier dependencia faltante genera warning y fallback, nunca aborta la sesión.

## Uso detallado y ajustes por módulo
- **Video 32/33:** Plan de transcode H.264 1080p ahora permite códec `auto/videotoolbox/nvenc/libx264`; auto detecta hw accel. Tras generar el plan, puedes ejecutar ffmpeg (pregunta y respeta `DRYRUN_FORCE`) y se indica el códec usado. Útil para Apple Silicon (videotoolbox) y PCs con NVIDIA (nvenc).
- **API/OSC (50):** HTTP `/status,/reports,/dupes/summary,/logs/tail` con Bearer token opcional; OSC `/djpt/ping` y `/djpt/status` devuelven “unauthorized” si el token no coincide. Mantiene compatibilidad sin token en local.
- **BPM/segmentation (49/67):** Flags `--tempo-min/--tempo-max` y `--max-duration`; salida incluye `beat_count` y `first_beat_sec` para cues. Ajusta rangos si tu música tiene BPM atípicos o hardware limitado.
- **TF Lab (65):** Elige modelo según recursos: TF (`yamnet/musicnn/musictag`) si tienes TF; ONNX (`clap_onnx/clip_vitb16_onnx/sentence_t5_tflite`) si solo hay onnxruntime; `DJPT_OFFLINE=1` fuerza heurísticos si no quieres descargas. Ventaja: mismo flujo sirve offline/online y CPU/GPU.
- **DMX (V3):** Dry-run automático si Safe/Lock/DRY activos; logs en `logs/dmx_*.log`. Usa pyserial si hay hardware; si no, sigue en simulación sin fallar.
- **Auto-tagging vídeo (8) y music tags (9):** Heurísticos ligeros (no mutan archivos); sirven como pre-etiquetado y para pruebas en entornos sin modelos pesados.
