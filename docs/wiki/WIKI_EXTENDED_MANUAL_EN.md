# DJProducerTools – Extended Manual (v1.0.0, EN)

## Fundamentals
- State: `BASE_PATH/_DJProducerTools/{reports,plans,logs,config,quarantine,venv}`. Use `HOME_OVERRIDE=/path` to isolate; avoid system disk and root.
- Safety: `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE=0`. `--dry-run` forces simulation. `confirm_heavy` for heavy ops.
- Minimal deps: bash, python3, ffprobe, sox, jq. Optional: ffmpeg (transcode/keyframes), librosa (BPM/onsets), python-osc, pyserial, onnxruntime/tensorflow (ML).
- Offline: `DJPT_OFFLINE=1` forces heuristics/mocks; `DJPT_TF_MOCK=1` avoids TF downloads.

## Core (1–12)
- 1 Status: base/state, flags, recent reports/logs (read-only).
- 2 Change Base: reinit state; no file moves.
- 3 Volume summary: `du -sh` + recent reports.
- 4/5 Top dirs/files: size ranking (read-only).
- 6 Scan workspace: full listing -> `reports/workspace_scan.tsv` (warn on huge trees).
- 7/8 Backups: rsync `_Serato_` and DJ metadata (respect Safe/Lock/DRY; `confirm_heavy`).
- 9 Hash index (SHA-256): `reports/hash_index.tsv` (heavy).
- 10 Exact dupes plan: `plans/dupes_plan.tsv/json` (KEEP/QUARANTINE).
- 11 Apply quarantine: reversible moves to `quarantine/<hash>/file` (confirm required).
- 12 Quarantine manager: list/restore/delete (blocked by Safe/Lock).

**Example safe flow:** 6 → 9 → 10 (review TSV) → 11 only if Safe/Lock=0 and not DRY.

## Media / Organization (13–24)
- 13 ffprobe corrupt: `media_corrupt.tsv`.
- 14 Playlists per folder: `playlist.m3u8` per audio dir.
- 15 Relink helper: rel/full paths -> TSV.
- 16 Mirror-by-genre plan: placeholder.
- 17 Find DJ libs: detect Serato/Traktor/Rekordbox/Ableton.
- 18 Smart rescan: full TSV with progress.
- 19 Tools diag: ffprobe/shasum/rsync/find/ls/du presence.
- 20 Ownership/flags plan: chown/chmod TSV.
- 21/22 Symlink cmd: `dj`, `dj-en`, `dj-es` (blocked if Safe).
- 23/24 Toggle SAFE_MODE / DJ_SAFE_LOCK.

## Processes / Cleanup (25–39)
- 26 Export/Import state: `DJPT_state_bundle.tar.gz`.
- 27 Fast hash snapshot: quick hash TSV.
- 28 Logs viewer.
- 29 Toggle DRYRUN_FORCE.
- 30/31 Tags plans/reports: placeholders.
- 32 Video REPORT: ffprobe -> `reports/serato_video_report.tsv/json`.
- 33 Video PREP: transcode plan H.264 1080p -> `plans/serato_video_transcode_plan.tsv/json`; choose codec `auto/videotoolbox/nvenc/libx264`; can run ffmpeg (asks, respects DRY). Codec recorded in plan.
- 34 Normalize names plan; 35 Samples by type; 36–39 web clean/whitelist.

**Example transcode (hw accel):** Menu 33 → codec `auto` → run ffmpeg? `y` → if DRYRUN_FORCE=1, prints commands only.

## ML / Deep (40–52, 62–67)
- 40 Smart analysis (JSON), 41 heuristic predictor, 42 efficiency checklist, 43 smart workflow, 44 integrated dedup (placeholder), 45–48 org/metadata/backup/sync plans.
- 49 BPM/onsets: flags `--tempo-min/--tempo-max`, `--max-duration`; outputs BPM, confidence, key, energy, beat_count, first_beat_sec.
- 50 API/OSC server: HTTP `/status,/reports,/dupes/summary,/logs/tail`; OSC `/djpt/ping,/djpt/status`; optional Bearer token (unauthorized if missing); pid `_DJProducerTools/osc_api_server.pid`.
- 62 ML evolutive (opt-in scikit-learn), 63 Toggle ML, 64 Install TF.
- 65 TF Lab: models `yamnet/musicnn/musictag/clap_onnx/clip_vitb16_onnx/musicgen_tflite/sentence_t5_tflite`; `DJPT_OFFLINE=1` for mocks. Outputs: embeddings, tags, similarity, anomalies, segments, loudness, matching, video_tags, music_tags, mastering (TSV).
- 66 LUFS plan: target/tolerance (pyloudnorm optional).
- 67 Auto-cues: onsets/segments (librosa if present).

**Example TF Lab offline:** `DJPT_OFFLINE=1` + model `clap_onnx` in 65.1/65.2 (uses onnxruntime if present, else mock).
**Example API with token:** Menu 50 → set token → curl with `Authorization: Bearer <token>`; OSC `/djpt/ping` with token arg returns “pong”.

## Visuals / OSC / DMX (V submenu)
- V1 Ableton .als report; V2 Visuals inventory (ffprobe); V3 Send DMX plan (ENTTEC; Safe/Lock/DRY ⇒ dry-run; logs in `logs/dmx_*.log`).
- V4/V5 Video report+plan (same as 32/33); V6 resolution/duration; V7 visuals by resolution (plan); V8 visuals dupes; V9 optimize plan; V10 playlist→OSC; V11 playlist→DMX timed; V12 DMX presets template.

## Why & Advantages
- SHA-256 + quarantine: exact dedupe, reversible, low risk.
- rsync backups: incremental, rollback-friendly.
- Video transcode: H.264 1080p compatibility; hw accel if available; ffmpeg opt-in/DRY-aware.
- API/OSC token: lightweight guard on shared nets; minimal endpoints avoid exposing data.
- BPM/librosa: tempo bounds + duration balance speed vs accuracy; beats help cueing without writing tags.
- ML local: privacy (no cloud); `DJPT_OFFLINE` guarantees fallback; ONNX/TFLite for lighter setups.
- DMX/OSC dry-run: simulation always possible; logs help validate without hardware.
- Packaging: `git archive -o ../DJProducerTools_WAX.zip HEAD` (include `djpt_icon.icns`); `docs/internal` export-ignore keeps collaborator material out.
