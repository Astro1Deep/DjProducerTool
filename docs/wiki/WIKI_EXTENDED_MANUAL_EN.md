# DJProducerTools – Extended Manual (v1.0.0, EN)

## Fundamentals
- State: `BASE_PATH/_DJProducerTools/{reports,plans,logs,config,quarantine,venv}`. Use `HOME_OVERRIDE=/path` to isolate; avoid system disk and root.
- Safety: `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE=0`. `--dry-run` forces simulation. `confirm_heavy` for heavy ops.
- Minimal deps: bash, python3, ffprobe, sox, jq. Optional: ffmpeg (transcode/keyframes), librosa (BPM/onsets), python-osc, pyserial, onnxruntime/tensorflow (ML).
- Offline: `DJPT_OFFLINE=1` forces heuristics/mocks; `DJPT_TF_MOCK=1` avoids TF downloads.

## Quick CLI usage & global flags
- Run: `./scripts/DJProducerTools_MultiScript_EN.sh` (or `_ES.sh`). Use `--help`, `--version`, `--test` for quick checks.
- Override base: `HOME_OVERRIDE=/path ./scripts/DJProducerTools_MultiScript_EN.sh` to keep `_DJProducerTools` away from system disk.
- Force offline ML: `DJPT_OFFLINE=1 ./scripts/DJProducerTools_MultiScript_EN.sh` (applies across TF Lab flows).
- Force mock TF: `DJPT_TF_MOCK=1` to skip TF downloads.
- Safe toggles (default on): `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`; DRY global: `DRYRUN_FORCE=1` for commands that support dry-run (ffmpeg/rsync helpers).
- General roots: `GENERAL_ROOT=/path` for duplicate submenus; `EXTRA_SOURCE_ROOTS=/pathA,/pathB` for consolidation.

## Safety workflow (step by step)
1) Ensure `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE=0` (default). Menu re-prompts to restore if set to 0.
2) Scan/catalog (6, 9, 10) before moving anything. Review TSVs.
3) Backups: 7/8 (rsync) and snapshot 27. Do this before quarantine/moves.
4) Apply moves only with Safe/Lock off and after manual confirmation (11, DMX send, etc.).
5) Use `DJPT_OFFLINE=1` for labs when you cannot download models. Use `--dry-run` flags when offered.

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

## Duplicates / Consolidation (D submenu)
- D1 General catalog (uses `GENERAL_ROOT`), D2 Duplicates by basename+size, D3 Smart report (ML hints).
- D4 Multi-disk consolidation plan (destination vs sources) → `plans/consolidation_plan.tsv` + helper `consolidation_rsync.sh`.
- D5 Exact dupes by hash (multi-root), D6 inverse consolidation (mark leftovers in sources), D7 matrioshka folders, D8 mirror folders by content, D9 audio similarity (YAMNet, TF).
- D10 Batch rsync helpers: splits `consolidation_plan.tsv` into `consolidation_rsync_batchXX.sh` (default 50 GB per batch), uses real file size, skips missing with warnings, prints per-batch summary (files + GB) and total; only generates scripts (Safe/Lock informative).

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

---
## Legacy wiki summary (merged)
- What/for whom: Clean/organize Serato/Rekordbox/Traktor/Ableton libs (audio/video/DMX), safe backups, exact dupes + advanced plans, optional local ML.
- Main files: `DJProducerTools_MultiScript_ES.sh` / `_EN.sh`; `install_djpt.sh` for quick download.
- Quick install: `install_djpt.sh` snippet with `curl` (downloads EN/ES and chmod +x).
- Requirements: macOS + bash; `python3`; space in `_DJProducerTools/`; optional ML (300–600 MB depending on stack).
- Basic use: run EN/ES script (double-click keeps window); creates `_DJProducerTools/` in BASE_PATH.
- Disk layout: config/reports/plans/quarantine/logs/venv under `_DJProducerTools/` (detailed above).
- Safety/modes: Safe/Lock/DRY; confirmations; no destructive actions without prompt.
- Grouped menus: Core, Media/Org, Processes/Cleanup, Deep/ML, Extras, Automations (21 chains A/68), submenus L/D/V/H.
- Automated chains: 21 predefined flows (backup+snapshot, dedupe/quarantine, cleanup, show prep, integrity, efficiency, ML, sync, visuals, etc.).
- Outputs/plans: `reports/` (hashes, corrupt, catalogs, playlists, ML), `plans/` (dupes, workflows, sync, integration), `quarantine/`, `logs/`.
- ML notes: optional installs; TF only if chosen; ML can be disabled (63). Venv isolated in `_DJProducerTools/venv`.
- Best practices: hash+plan before moves; backup/snapshot first; exclude caches/heavy dirs; mirror check (61) for multi-disk.
- Visual assets: menu SVG/PNG, banners; can be linked in README/wiki.
- License: DJProducerTools License (Attribution + Revenue Share 20%); see `LICENSE`.

---
## Option-by-option details (extended)

### Core (1–12)
- 1 Status: shows BASE_PATH, SAFE/LOCK/DRY, recent reports/logs (read-only).
- 2 Change Base: re-init `_DJProducerTools` under new BASE_PATH (creates if missing). Does not move media.
- 3 Volume summary: `du -sh` on BASE_PATH/state; lists recent plans/reports.
- 4/5 Top dirs/files: size ranking; read-only.
- 6 Workspace scan: full listing -> `reports/workspace_scan.tsv`; use exclusions in `config/djpt.conf` to skip caches.
- 7/8 Backups: rsync `_Serato_` and DJ metadata. Safe/Lock respected; `confirm_heavy` on large runs; DRY prints commands.
- 9 Hash index: SHA-256 under BASE_PATH -> `reports/hash_index.tsv`; can be slow.
- 10 Exact dupes plan: consumes hash_index -> `plans/dupes_plan.tsv/json` with KEEP/QUARANTINE.
- 11 Apply quarantine: moves to `_DJProducerTools/quarantine/<hash>/file`; blocked if Safe/Lock=1; asks confirmation.
- 12 Quarantine manager: list/restore/delete; Safe/Lock gates destructive actions.

### Media / Organization (13–24)
- 13 ffprobe corrupt -> `media_corrupt.tsv` (path|error); needs ffprobe.
- 14 Playlists per folder -> `playlist.m3u8` per audio dir.
- 15 Relink helper: relative/full paths TSV for DAWs.
- 16 Mirror-by-genre plan: placeholder TSV (no writes).
- 17 Find DJ libs: detect Serato/Traktor/Rekordbox/Ableton roots.
- 18 Smart rescan: TSV with size/mtime/type; progress bar.
- 19 Tools diag: ffprobe/shasum/rsync/find/ls/du presence.
- 20 Ownership/flags plan: chown/chmod TSV (does not apply).
- 21/22 Symlink cmd install/remove `dj`/`dj-en`/`dj-es`; blocked by Safe/Lock.
- 23/24 Toggle SAFE_MODE / DJ_SAFE_LOCK with confirmation.

### Processes / Cleanup (25–39)
- 26 Export/Import state bundle `DJPT_state_bundle.tar.gz` (config/reports/plans/logs/quarantine).
- 27 Fast hash snapshot -> `reports/hash_snapshot.tsv`.
- 28 Logs viewer: tails `_DJProducerTools/logs/*`.
- 29 Toggle DRYRUN_FORCE (forces dry-run when supported).
- 30/31 Tags plan/report: placeholders (TSV only).
- 32 Video report: ffprobe inventory -> TSV/JSON (codec, resolution, duration, bitrate).
- 33 Video prep: choose codec `auto/videotoolbox/nvenc/libx264`; writes plan TSV/JSON, asks to run ffmpeg; honours DRYRUN_FORCE.
- 34 Normalize names plan; 35 Samples by type; 36–39 Web clean/whitelist TSVs.

### Duplicates / Consolidation (D)
- D1 Catalog general (uses `GENERAL_ROOT`).
- D2 Duplicates by basename+size -> `general_dupes_plan.tsv/json`.
- D3 Smart report with ML hints (text + TSV).
- D4 Multi-disk consolidation: destination vs sources, outputs `consolidation_plan.tsv` + `consolidation_rsync.sh` (plan only).
- D5 Exact dupes by hash (multi-root, optional max depth/size + excludes).
- D6 Inverse consolidation: mark leftovers in sources already present in destination (size threshold optional).
- D7 Matrioshka folders (structure duplicates) -> TSV KEEP/REMOVE suggestions.
- D8 Mirror folders by content (hash listings) -> TSV.
- D9 Audio similarity (YAMNet TF) with presets (fast/balanced/strict).
- D10 Batch rsync helpers: input `consolidation_plan.tsv`, batch size GB (default 50), min free GB check (default 20), optional `--remove-source-files`. Generates `consolidation_rsync_batchXX.sh` with space check, rsync version autodetect (drops `--protect-args` if unsupported), logs to `_DJProducerTools/logs`, skips missing with warning, shows per-batch files/GB and totals. Safe/Lock informative; generation no mueve archivos.

### ML / Deep (40–52, 62–67)
- 40 Smart analysis JSON; 41 heuristic predictor; 42 efficiency checklist TSV; 43 smart workflow TSV; 44 integrated dedup placeholder.
- 45 Org plan; 46 Metadata harmonizer; 47 Predictive backup; 48 Cross-platform sync (TSV/JSON).
- 49 BPM/onsets: `--tempo-min/--tempo-max --max-duration`; outputs bpm/conf/key/energy/beat_count/first_beat_sec (librosa).
- 50 API/OSC: start/stop server; set port/token. HTTP `/status,/reports,/dupes/summary,/logs/tail`; OSC `/djpt/ping,/djpt/status`; unauthorized if token missing; PID stored.
- 62 ML evolutive (scikit-learn opt-in); 63 toggle ML; 64 install TF.
- 65 TF Lab: models yamnet/musicnn/musictag/clap_onnx/clip_vitb16_onnx/musicgen_tflite/sentence_t5_tflite; respects `DJPT_OFFLINE`/`DJPT_TF_MOCK`; outputs embeddings/tags/similarity/anomalies/segments/loudness/matching/video_tags/music_tags/mastering TSV. Warns and falls back if runtime missing.
- 66 LUFS plan (pyloudnorm+soundfile optional); 67 Auto-cues (librosa onsets/segments).

### Visuals / OSC / DMX (V)
- V1 Ableton .als quick report; V2 Visuals inventory; V3 DMX send plan (ENTTEC dry-run by default, logs frames); V4/V5 video report/plan; V6 resolution/duration; V7 visuals by resolution; V8 visuals dupes; V9 optimize plan; V10 playlist→OSC; V11 playlist→DMX timed; V12 DMX presets template (edit channels/values for your rig).

### Automation (A/68)
- 21 predefined chains (backup+snapshot, dedupe/quarantine, cleanup, show prep, integrity, efficiency, ML, sync, visuals, etc.). Safe/Lock/DRY are respected. Option 68 installs Python deps in venv.

### Safety and modes
- Defaults: `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE=0`. Do not disable without reviewing plans.
- Offline: `DJPT_OFFLINE=1` forces heuristics; `DJPT_TF_MOCK=1` avoids TF downloads; applies across TF Lab flows.
- Avoid root/system disk; heavy actions prompt via `confirm_heavy_action`.

### Install / venv / deps
- Minimal deps: bash, python3, ffprobe, sox, jq. Optional: ffmpeg, librosa, python-osc, pyserial, onnxruntime/tflite-runtime, tensorflow.
- Venv path: `_DJProducerTools/venv` (BASE_PATH-local). To rebuild: `python3 -m venv _DJProducerTools/venv && source _DJProducerTools/venv/bin/activate && pip install --upgrade pip`.
- Fresh install: use `install_djpt.sh` snippet (downloads EN/ES, chmod +x).

### Outputs and logs
- Plans: `_DJProducerTools/plans/*.tsv/json`; reports: `_DJProducerTools/reports/*`; logs: `_DJProducerTools/logs/*`; quarantine: `_DJProducerTools/quarantine/`; batch helpers: `_DJProducerTools/plans/consolidation_rsync_batchXX.sh`.

### Practical recipes
- Safe dedupe: 6 → 9 → 10 (review) → disable Safe/Lock if applying → 11 quarantine.
- Multi-disk merge: D4 plan → D10 batches (50 GB chunks) → run helpers manually.
- Video prep: 32 report → 33 codec auto → confirm ffmpeg (or DRY print).
- BPM cues (no tag writes): 49 with `--tempo-min 70 --tempo-max 180 --max-duration 600`; use beat_count/first_beat_sec.
- API with token: menu 50 set token; curl `-H "Authorization: Bearer TOKEN" http://127.0.0.1:9000/status`.
- CLI one-liners:
  - Minimal dry run (offline ML): `DJPT_OFFLINE=1 DRYRUN_FORCE=1 ./scripts/DJProducerTools_MultiScript_EN.sh --test`
  - Base override sandbox: `HOME_OVERRIDE=/tmp/djpt_sandbox ./scripts/DJProducerTools_MultiScript_EN.sh`
  - TF Lab mock: `DJPT_TF_MOCK=1 ./scripts/DJProducerTools_MultiScript_EN.sh` then go to 65.
  - Fast video plan from terminal (no menu): `BASE_PATH=/your/base ./scripts/DJProducerTools_MultiScript_EN.sh --dry-run` then pick 33 and answer N to run.

### Advanced adjustments & tuning (per section)
- **Safety & state:** keep Safe/Lock=1 unless applying a reviewed plan; DRYRUN_FORCE=1 for ffmpeg/rsync helpers when testing. Prefer `HOME_OVERRIDE` to isolate state and avoid mixing with legacy `~/.DJProducerTools`.
- **Exclusions:** edit `config/djpt.conf` or use menu 57 to skip caches (`*/Cache/*`, `*.asd`, DAW temp). Reduces false positives in dupes and speeds scans.
- **Hash/dupe plans:** for huge trees set max depth/size in D5; for hashed dupes set exclusions to avoid large video/stems if not needed. Always review `plans/dupes_plan.tsv` before option 11.
- **Consolidation (D4/D10):** set batch size to fit free space (20–50 GB recommended). Use min free GB guard (default 20). Paths with trailing spaces are preserved—run helpers from terminal to keep quoting. Logs in `_DJProducerTools/logs/*.log`. Add `--remove-source-files` only when you’re sure copies succeeded and want to clean sources.
- **Video prep (33/V5):** codec `auto` will prefer hardware (`videotoolbox`) if available; fall back to `libx264`. DRYRUN_FORCE prints ffmpeg commands only. Plans include codec used; audio defaults to AAC 160 kbps unless you override inside script settings.
- **BPM (49):** narrow `--tempo-min/--tempo-max` for speed/accuracy; `--max-duration` caps long files. Outputs beats/first beat for cueing; no tag writes.
- **API/OSC (50):** set token for shared networks; HTTP is local-only by default. OSC unauthorized if token missing. PID saved; use menu to stop cleanly.
- **TF Lab (65):** choose model based on resources (ONNX/TFLite for light CPU, TF for full). Use `DJPT_OFFLINE=1` to avoid downloads; `DJPT_TF_MOCK=1` to force mocks. Outputs: embeddings/tags/similarity/anomalies/segments/loudness/matching/video_tags/music_tags/mastering TSV under `reports/`.
- **DMX/OSC send (V3/V10/V11):** Safe/Lock/DRY block live send; logs frames. Review presets (V12) and adjust channel maps before use.
- **Automation (A/68):** each chain honors Safe/Lock/DRY when applicable. For big moves, run chains with DRYRUN_FORCE=1 first to inspect.
- **Space checks:** use option 59 (health) and D10 min-free guard. For staging to an external disk, regenerate plan or edit batch scripts to point to the staging path.

### Performance, troubleshooting, and best practices
- **Rsync compatibility:** older macOS rsync may not support `--protect-args`; D10 auto-detects. If you run manual rsync, prefer `rsync -av --info=progress2 source dest` and keep paths quoted.
- **Disks with low space:** run D10 with smaller batches (10–20 GB) and high min-free threshold. Use option 59 to watch free space; stop batches if <15–20 GB remain.
- **Paths with spaces/trailing spaces:** avoid trimming; drag&drop is safe. D10 preserves quoting; run helpers from terminal, not copy/paste without quotes.
- **Legacy state:** if `~/.DJProducerTools` exists, use `HOME_OVERRIDE=/new/state` to avoid mixing. The menu warns if legacy state is found.
- **Logs and noise control:** D10 logs per batch in `_DJProducerTools/logs`. For ffmpeg-heavy runs, keep DRYRUN_FORCE on to inspect commands first.
- **Testing quick checks:** `./scripts/VERIFY_AND_TEST.sh --fast` for syntax/structure; `--fast` skips network/URLs. For TF/ML, ensure venv is active and runtimes installed.
- **When Safe/Lock are 0:** the menu will ask to restore to 1/1. Keep them off only while applying a reviewed plan (e.g., option 11) and re-enable afterwards.
- **ffmpeg availability:** if ffmpeg is missing, video plan still generates TSV/JSON but won’t run transcodes; install ffmpeg for full flow.
- **OSC/API security:** set a token when on shared networks; endpoints are minimal and local-only by default.
- **DMX hardware:** ENTTEC/serial send is guarded by Safe/Lock/DRY. Always test dry-run and confirm channel maps before live use.

### License
- DJProducerTools License (Attribution + 20% revenue share on derivatives/commercial). Keep credit; see `LICENSE`.
