# DJProducerTools – Extended Manual (EN)

Full guide of menu actions/options (version 1.0.0). Use as detailed reference for the multiscript.

## Basics
- **State & paths:** `BASE_PATH/_DJProducerTools/{reports,plans,logs,config,quarantine,venv}`. `BASE_PATH` is the cwd when launching (don’t point to system disk). `HOME_OVERRIDE=/path` to isolate.
- **Safety:** `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE=0`. `--dry-run` forces simulation. Confirm heavy ops with `confirm_heavy`.
- **Minimum deps:** `bash`, `python3`, `ffprobe`, `sox`, `jq`. Optional: `ffmpeg`, `librosa`, `python-osc`, `pyserial`, `onnxruntime`, `tensorflow`.
- **ML offline:** `DJPT_OFFLINE=1` forces heuristics/mocks; `DJPT_TF_MOCK=1` avoids TF downloads.

## Core Menu (1–12)
- **1 Status:** Shows BASE/STATE, safety flags, recent reports/logs. Read-only.
- **2 Change Base:** Updates `BASE_PATH`, re-inits state (no file moves).
- **3 Volume summary:** `du -sh` BASE + recent reports list.
- **4 Top dirs / 5 Top files:** Size rankings. Read-only.
- **6 Scan workspace:** Full listing -> `reports/workspace_scan.tsv` (warn on huge trees).
- **7 Backup Serato / 8 Backup DJ metadata:** rsync `_Serato_` and DJ libs to `state/serato_backup` and `state/dj_metadata_backup` (respects Safe/Lock/DRY). Uses `confirm_heavy`.
- **9 Hash index (SHA-256):** `reports/hash_index.tsv`. Heavy on large libraries (confirmation).
- **10 Exact dupes plan:** Uses hash_index -> `plans/dupes_plan.tsv/json` (KEEP/QUARANTINE).
- **11 Apply quarantine:** Moves QUARANTINE entries to `quarantine/<hash>/file` if Safe/Lock allow. Confirmation required.
- **12 Quarantine manager:** List / restore all / delete all (blocked by Safe/Lock).

## Media / Organization (13–24)
- **13 ffprobe corrupt:** `media_corrupt.tsv` for files failing ffprobe.
- **14 Playlists per folder:** `playlist.m3u8` in each audio dir.
- **15 Relink helper:** `relink_helper.tsv` (relative + full path).
- **16 Mirror by genre (plan):** Placeholder `plans/mirror_by_genre.tsv`.
- **17 Find DJ libs:** Detect Serato/Traktor/Rekordbox/Ableton roots.
- **18 Smart rescan:** Full TSV with progress.
- **19 Tools diag:** Presence of ffprobe/shasum/rsync/find/ls/du.
- **20 Fix ownership/flags (plan):** `plans/fix_ownership_flags.tsv` (suggested chown/chmod).
- **21/22 Install/Uninstall cmd:** symlink `dj`, `dj-en`, `dj-es` (blocked if Safe).
- **23 Toggle SAFE_MODE / 24 Toggle DJ_SAFE_LOCK:** Flip flags and persist config.

## Processes / Cleanup (25–39)
- **25 Quick help:** Suggested flows.
- **26 Export/Import state:** `DJPT_state_bundle.tar.gz` (state only).
- **27 Fast hash snapshot:** `reports/snapshot_hash_fast.tsv`.
- **28 Logs viewer:** Lists state logs.
- **29 Toggle DRYRUN_FORCE:** Enable/disable global simulation.
- **30 Organize-by-tags plan / 31 Tags report:** Placeholders (GENRE_UNKNOWN).
- **32 Serato Video REPORT:** ffprobe inventory -> `reports/serato_video_report.tsv/json`.
- **33 Serato Video PREP:** Transcode plan H.264 1080p with codec selection (auto/videotoolbox/nvenc/libx264) -> `plans/serato_video_transcode_plan.tsv/json`; asks to run ffmpeg (respects DRY and confirmation).
- **34 Normalize names (plan):** TSV rename plan.
- **35 Samples by type (plan):** Classifies kicks/snares/hats/bass.
- **36–39 Web clean:** Clean URLs in playlists/tags and manage whitelist.

## ML / Deep (40–52, 62–67)
- **40 Smart analysis:** JSON summary of counts/recs.
- **41 ML predictor:** Heuristic (long names, zero-size).
- **42 Efficiency optimizer:** Checklist (dupes, tags, backup, snapshot).
- **43 Smart workflow:** Suggested sequence.
- **44 Integrated dedup:** Exact/fuzzy summary (placeholder).
- **45–48** Organization/metadata harmony/predictive backup/cross-platform sync plans.
- **49 BPM/onsets:** `lib/bpm_analyzer.py` -> TSV with BPM, confidence, key, energy, beat_count, first_beat_sec; flags `--max-duration`, `--tempo-min/max`.
- **50 API/OSC server:** HTTP `/status,/reports,/dupes/summary,/logs/tail`; OSC `/djpt/ping,/djpt/status`; supports Bearer token; pid in `_DJProducerTools/osc_api_server.pid`.
- **51–52** Recommendations/pipeline plans (placeholders).
- **62 ML evolutive:** Optional scikit-learn; train with dupes plans.
- **63 Toggle ML:** Disable/enable ML globally.
- **64 TensorFlow:** Optional TF install (download).
- **65 TensorFlow Lab:** Auto-tag/similarity/anomalies/segments. Model selector (yamnet/musicnn/musictag/clap_onnx/clip_vitb16_onnx/musicgen_tflite/sentence_t5_tflite). `DJPT_OFFLINE` for mocks; uses onnxruntime/tflite if present. Outputs: `audio_embeddings.tsv`, `audio_tags.tsv`, `audio_similarity.tsv`, `audio_anomalies.tsv`, `audio_segments.tsv`, `audio_loudness.tsv`, `audio_matching.tsv`, `video_tags.tsv`, `music_tags.tsv`, `audio_mastering.tsv`.
- **66 LUFS plan:** Loudness analysis (pyloudnorm+soundfile optional) with target/tolerance.
- **67 Auto-cues:** Onsets/segments (librosa if available).

## Visuals / DAW / OSC / DMX (submenu V)
- **V1 Ableton `.als`:** Quick report (samples/plugins).
- **V2 Visuals inventory:** ffprobe -> TSV/JSON.
- **V3 Send DMX plan:** ENTTEC DMX USB Pro; respects Safe/Lock/DRY; DMX logs in `logs/dmx_*.log`.
- **V4/V5 Serato Video:** Inventory + transcode plan (same as 32/33).
- **V6 Resolution/duration:** ffprobe -> TSV.
- **V7 Organize visuals by resolution (plan).**
- **V8 Visuals exact dupes (hash).**
- **V9 Optimize plan (suggest H.264 1080p).**
- **V10 OSC plan from playlist:** `.m3u/.m3u8` with timings (ffprobe durations).
- **V11 DMX plan from playlist:** Intro/Drop/Outro timed, editable channel map.
- **V12 DMX presets template:** Editable JSON.

## TF Lab (65) – recommended flow
1) Install deps (option 64) or rely on onnxruntime/tflite if already installed.  
2) In 65.1/65.2 pick a model; `DJPT_OFFLINE=1` for mocks, `DJPT_OFFLINE=0` for real models.  
3) Review outputs in `reports/` and plans in `plans/`.  
4) Use `--offline` or auth token for API/OSC if exposing remotely.

## Packaging & hygiene
- Clean package: `git archive -o ../DJProducerTools_WAX.zip HEAD` and include `djpt_icon.icns`.  
- `docs/internal/` marked `export-ignore` (collaborator material).  
- Do not run as root or point `BASE_PATH` to system disk. Confirm heavy ops with `confirm_heavy`.  
- Review default excludes before scanning large media volumes.
