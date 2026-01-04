# 📘 Project Best Practices

## 1. Project Purpose
DJProducerTools is a macOS-focused toolkit (primarily Bash) for professional DJ library management. It scans and audits workspaces, builds SHA-256 indexes, detects exact duplicates and corruption, manages quarantine workflows, generates playlists, backs up DJ metadata (Serato/Traktor/Rekordbox/Ableton), and offers optional ML-assisted analysis. The UX emphasizes real-time feedback with spinners, ghost indicators, and emojis to clearly communicate long-running operations.

## 2. Project Structure
- Root entry:
  - scripts/
    - DJProducerTools_MultiScript_EN.sh (main menu + actions, EN)
    - DJProducerTools_MultiScript_ES.sh (main menu + actions, ES)
    - install_djpt.sh (setup helper)
  - lib/
    - progress.sh (shared progress bar, spinner, debug utilities)
  - docs/ (English and Spanish documentation: API, install, debug, security, roadmap)
  - guides/ (user guides EN/ES)
  - tests/ (shell-based runners and validations)
  - VERSION, LICENSE, README.md

- Runtime state layout (dynamic, under user-selected BASE_PATH):
  - _DJProducerTools/
    - config/ (persistent config, profiles, history)
    - reports/ (scan outputs, indexes, snapshots)
    - plans/ (actions to apply, e.g., dupes_plan.tsv)
    - logs/ (auxiliary logs)
    - quarantine/ (non-destructive duplicate isolation)
    - venv/ (optional ML environment)

- Entry points & configuration:
  - Launch scripts from scripts/, which initialize colors, environment, paths, and state; load/save config at STATE_DIR/config/djpt.conf.
  - Menu "action_*" functions are the canonical expansion points for new features.
  - Global toggles: SAFE_MODE, DJ_SAFE_LOCK, DRYRUN_FORCE, ML_PROFILE, ML_ENV_DISABLED.

## 3. Test Strategy
- Framework: shell-based tests (bash/zsh compatible).
- Location: tests/ with runners (test_runner.sh, test_runner_fixed.sh) and scenario checks (stability_check.sh, check_consistency.sh, comprehensive_test.sh).
- Philosophy:
  - Focus on integration and flow validation of menu actions and artifacts (reports/, plans/, quarantine/).
  - Prefer dry-run modes and state isolation under _DJProducerTools/ for deterministic checks.
  - Validate idempotency: re-running actions should reuse or prompt to regenerate artifacts.
- Mocking/fixtures:
  - Use temporary directories and sample files; avoid altering user data.
  - Prefer DRYRUN_FORCE=1 where destructive behavior is guarded by SAFE_MODE/DJ_SAFE_LOCK.
- Coverage expectations:
  - Critical flows: catalog/scan, hash_index build, dupes plan, quarantine manager, snapshot integrity, backups.

## 4. Code Style
- Language: POSIX/Bash with macOS compatibility. Keep compatibility for older Bash on macOS (3.2) via polyfills (e.g., mapfile).
- Safety:
  - Use set -u; avoid unbound variables; guard array usage.
  - Prefer quoting all variables ("$var").
  - Use functions for side-effectful operations and centralize prompts and prints.
  - Never perform destructive operations unless SAFE_MODE=0 and DJ_SAFE_LOCK=0 and user confirmed.
- Naming:
  - UPPER_SNAKE for constants and global toggles (SAFE_MODE, STATE_DIR).
  - lower_snake for functions (action_*, status_line, run_with_spinner).
  - action_NN_* for menu entries; keep consistent numbering and grouping.
- Errors & tracing:
  - Use debug_print from lib/progress.sh (INFO/SUCCESS/WARN/ERROR/DEBUG) gated by DEBUG_MODE.
  - Wrap long-running commands with run_with_spinner or time_function.
- Documentation:
  - Keep user-facing prompts bilingual where applicable.
  - Add inline comments for non-obvious awk/sed/join pipelines.

## 5. Common Patterns
- State/artifacts:
  - All outputs go under STATE_DIR (reports/, plans/, logs/, quarantine/). Never write to source folders directly.
  - Use maybe_reuse_file for large artifact regeneration prompts.
- Progress & UX (mandatory for analysis-type tasks):
  - Use status_line or lib/progress.sh utilities for all iterative/long operations.
  - Provide percent where possible; otherwise show spinner with contextual detail.
  - Always finish with finish_status_line to end carriage-return lines cleanly.
- Spinners/ghost/emoji:
  - status_line(task, percent, current [, emoji]) maps task to colors via spin_colors_for_task and to emoji via status_emoji_for_task.
  - For new tasks, extend status_emoji_for_task and spin_colors_for_task with an appropriate, consistent emoji/color scheme.
  - lib/progress.sh offers start_ghost_spinner/stop_spinner and progress_bar for standardized feedback; prefer these for reusable loops in new helpers.
- Non-destructive pipelines:
  - Generate TSV/JSON plans first; apply later with explicit confirmation.
  - Use quarantine for duplicate handling; preserve originals unless user explicitly confirms.
- Tool detection:
  - Use ensure_tool_installed and ensure_python_package_installed for runtime dependencies.

## 6. Do's and Don'ts
- ✅ Do
  - Use status_line/progress_bar for every analysis/scan loop.
  - Use a matching emoji per submenu category (e.g., 🔍 SCAN, 🔐 HASH, ♻️ DUPES, 📸 SNAP, 💾 BACKUP, 🩺 DOCTOR, 🧠 ML, 🎥 VIDEO, 🎵 PLAYLISTS).
  - Always guard file operations by SAFE_MODE, DJ_SAFE_LOCK, and DRYRUN_FORCE.
  - Place all generated files under STATE_DIR.
  - Prompt to reuse existing artifacts for heavy tasks.
  - Validate available disk space before moves (e.g., quarantine) and offer mark-only mode.
  - Keep bilingual prompts/messages consistent in EN/ES scripts.

- ❌ Don’t
  - Don’t write to user media folders directly without plan/confirmation.
  - Don’t print partial control codes or forget to call finish_status_line (prevents broken lines).
  - Don’t assume tools exist; check and offer install hints.
  - Don’t bypass quarantine flows for deletes.
  - Don’t introduce new menu actions without updating emoji/color mappings and groups.

## 7. Tools & Dependencies
- Required/used CLI tools: shasum, rsync, find, ls/du/df, awk/sed/join, bc (for size calcs), ffmpeg/ffprobe, sox, flac/metaflac, id3v2/mid3v2, shntool, jq.
- Optional: Python 3.x for ML flows; pip packages: numpy, pandas, scikit-learn, joblib, librosa; TensorFlow (macOS metal variant when applicable).
- Installation: via Homebrew where possible (brew install ffmpeg sox flac id3v2 shntool jq bc).
- Setup: run scripts/install_djpt.sh or directly execute scripts/DJProducerTools_MultiScript_*.sh.

## 8. Other Notes
- Progress & UX enforcement (per request): all “analysis” processes must display a progress bar AND/OR spinner with ghost effect and a context-appropriate emoji. Prefer:
  - For per-file loops with known totals: status_line with percent, or lib/progress.sh progress_bar(current,total,label).
  - For background commands: run_with_spinner(task, detail, command...); ensure finish_status_line after completion.
  - For generic waits or indeterminate tasks: start_ghost_spinner "Message"; always call stop_spinner in traps/exit.
- Consistency across EN/ES scripts:
  - When adding action_* in one language, mirror in the other and reuse the same task keys for emoji/color mapping.
- State hygiene:
  - Use init_paths -> ensure_dirs -> save_conf to keep STATE_DIR consistent.
  - Store profiles/history under config/ and avoid hard-coded user paths.
- ML environment:
  - Respect ML_ENV_DISABLED and profile selection; verify Python version constraints (e.g., TF with 3.11 on macOS) before prompting installs.
- LLM codegen hint:
  - When generating new actions, scaffold with: print_header -> refresh_artifact_state -> output path -> reuse prompt -> iterative loop with status_line/progress_bar -> finish_status_line -> result summary -> pause_enter.
