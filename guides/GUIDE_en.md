# DJProducerTools – Complete Wiki

Extensive documentation for using the library cleaning and organization toolkit for DJs and Producers on macOS.

## 1) What It Is and Who It's For

- Cleaning and organization of Serato/Rekordbox/Traktor/Ableton libraries (audio, video, visuals, DMX).
- Secure backups and integrity snapshots.
- Duplicate detection and management (exact matches and advanced plans).
- Optional Deep/ML tools (recommendations, organization, similarity).
- Creation of `.pkg` installers and automation of development tasks.

## 2) Main Files

- `DJProducerTools_MultiScript_ES.sh` – Spanish interface.
- `DJProducerTools_MultiScript_EN.sh` – English interface.
- `install_djpt.sh` – simple installer (downloads the latest version).

## 3) Quick Installation

```bash
cat <<'EOF' > install_djpt.sh
#!/usr/bin/env bash
set -e
for f in DJProducerTools_MultiScript_ES.sh DJProducerTools_MultiScript_EN.sh; do
  url="https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/$f"
  curl -fsSL "$url" -o "$f"
  chmod +x "$f"
done
echo "Done. Run ./DJProducerTools_MultiScript_ES.sh or ./DJProducerTools_MultiScript_EN.sh"
EOF
chmod +x install_djpt.sh
./install_djpt.sh
```

## 4) Requirements

- macOS + bash (the script re-runs with bash if you open it by double-clicking).
- `python3` recommended for ffprobe/librosa and optional ML features.
- Free space for `_DJProducerTools/` (config, logs, plans, quarantine).
- Optional ML: basic download ~300 MB (numpy/pandas); evolutionary ~450 MB (scikit-learn/joblib); optional TensorFlow +600 MB.
- Local AI Profile (option 59): LIGHT recommended (numpy+pandas+scikit-learn+joblib+librosa). TF_ADV optional for Apple Silicon (tensorflow-macos + tensorflow-metal).

## 5) Basic Usage

```bash
./DJProducerTools_MultiScript_ES.sh   # Spanish version
./DJProducerTools_MultiScript_EN.sh   # English version
```

- Double-click: the window remains open after finishing to display final messages.
- The script creates `_DJProducerTools/` in the `BASE_PATH` (config/logs/plans/quarantine).
- Auto-detection: if `_DJProducerTools` is found near the current directory, that root is used as the `BASE_PATH`.

## 6) Disk Structure

- `_DJProducerTools/config/`: `djpt.conf` (BASE_PATH, roots, SafeMode/Lock/DryRun flags), exclusion profiles, path history.
- `_DJProducerTools/reports/`: `hash_index.tsv`, `media_corrupt.tsv`, `workspace_scan.tsv`, `serato_video_report.tsv`, `playlists_per_folder.m3u8`, `ml_predictions_*.tsv`, etc.
- `_DJProducerTools/plans/`: `dupes_plan.tsv/json`, `cleanup_pipeline_*.txt`, `workflow_*.txt`, `integration_engine_*.txt`, `efficiency_*.tsv`, `ml_organization_*.tsv`, `predictive_backup_*.txt`, `cross_platform_*.txt`, `mirror_integrity_*.tsv`, etc.
- `_DJProducerTools/quarantine/`: files moved by option 11 or chains that use it.
- `_DJProducerTools/logs/`: executions, ML installations; viewer in option 28.
- `_DJProducerTools/venv/`: virtual environment for optional ML.

## 7) Security and Modes

- `SAFE_MODE` and `DJ_SAFE_LOCK` block dangerous actions (quarantine/moves). Disable both if you want to apply plans.
- `DRYRUN_FORCE` forces simulation in some actions.
- The script always asks for confirmation before moving/quarantining.
- `DEBUG_MODE`: If a task gets "stuck" with the spinning logo, you can edit the script and set `DEBUG_MODE=1` at the top. This will disable animations and show real-time command output to help you diagnose the issue.

## 8) Menus and Advantages (Grouped View)

- **Core (1-12)**: status, change base, summary, top dirs/files, backups, hash_index, exact duplicate plan, quarantine.
  *Advantage:* a secure foundation for any workflow (hashes + backups before touching anything).
- **Media/Organization (13-24)**: ffprobe for corrupt files, playlists per folder, relink helper, mirrors by genre, smart rescan, tool diagnostics, permissions/flags, install CLI.
  *Advantage:* prepares paths and playlists for DJs and VJs.
- **Processes/Cleanup (25-39)**: quick snapshot, log viewer, normalize names, samples by type, web cleanup in playlists/tags, Serato Video (report/plan).
  *Advantage:* clean tags/names and prepare libraries without modifying audio.
- **Deep/ML (42-59)**: analysis, predictor, optimizer, integrated dedup, ML organization, metadata harmonizer, predictive backup, cross-platform sync, advanced analysis, optional TensorFlow.
  *Advantage:* guided decisions and automatic plans; optional and local ML.
- **Extras (60-72)**: reset state, path profiles, Ableton tools, import cues, exclusion manager, compare hash_index, health-check, LUFS, auto-cues.
  *Advantage:* configuration portability and quick diagnostics.
- **Automations (A/71)**: Over 20 predefined chains for backup/snapshot, dedup, cleanup, show prep, integrity, efficiency, ML, sync, visuals, Serato security, multi-disk dedup.
- **Local AI Auto-pilot (A23–A28)**: complete workflows without intervention (all-in-one, clean+backup, deep/ML, safe with reuse and unique list).
  *Advantage:* run complete workflows with a single number/letter.
- **Submenus L/D/V/H**: libraries and cues, advanced duplicates, visuals/OSC/DMX, detailed help.

## 9) Automated Chains (Summary)

1) Secure backup + snapshot (8 -> 27)
2) Exact dedup + quarantine (10 -> 11)
3) Metadata + names cleanup (39 -> 34)
4) Media health: rescan + playlists + relink (18 -> 14 -> 15)
5) Show prep: backup/snapshot/dup/playlist (8 -> 27 -> 10 -> 11 -> 14 -> 8)
6) Integrity + corrupt files (13 -> 18)
7) Efficiency plan (42 -> 44 -> 43)
8) Basic ML organization (45 -> 46)
9) Predictive backup (49 -> 8 -> 27)
10) Cross-platform sync (50 -> 39 -> 8 -> 8)
11) Quick diagnosis (1 -> 3 -> 4 -> 5)
12) Serato health (7 -> 59)
13) Hash + mirror check (9 -> 68)
14) Audio prep (31 -> 69 -> 70)
15) Integrity audit (6 -> 9 -> 27 -> 68)
16) Cleanup + safe backup (39 -> 34 -> 10 -> 11 -> 8 -> 27)
17) Library sync prep (18 -> 14 -> 50 -> 8 -> 27)
18) Visuals health (V2 -> V6 -> V8 -> V9 -> 8)
19) Advanced audio organization (31 -> 30 -> 35 -> 45 -> 46)
20) Reinforced Serato security (7 -> 8 -> 59 -> 12 -> 49)
21) Multi-disk dedup + mirror (9 -> 10 -> 46 -> 11 -> 68)

## 10) Outputs and Location

- Plans: `_DJProducerTools/plans/` (dupes, cleanup, workflows, integrations, sync, efficiency).
- Reports: `_DJProducerTools/reports/` (hashes, corrupt files, catalogs, playlists, cues, ML).
- Quarantine: `_DJProducerTools/quarantine/` (applied by option 11 or chains that use it).
- Logs: `_DJProducerTools/logs/` (viewer in option 28).

## 11) ML/TensorFlow Notes

- Basic/evolutionary ML is optional and local. Confirmation is required before installing packages (~300–450 MB).
- TensorFlow (64/65) is optional (+600 MB) for advanced auto-tagging/embeddings/similarity.
- You can disable ML with option 56 (Toggle ML ON/OFF) to avoid using the venv.

## 12) Best Practices

- Before moving/quarantining: generate `hash_index` (9) and `dupes_plan` (10); disable SafeMode/Lock if you want to apply changes (11).
- Create a snapshot (27) and a DJ backup (8) before major changes.
- Use the exclusion manager (64) to avoid heavy caches/projects in scans.
- For multi-disk dedup, use 68 (mirror check) with the source/destination hash_index.

## 13) Visual Resources

- Full menu captures: `docs/menu_es_full.svg` and `docs/menu_en_full.svg`.
- To regenerate the SVG captures automatically, run: `bash docs/generate_menu_svgs.sh`.
- Add them to your README (already linked) or GitHub issues/wikis.

## 14) Professional Management Strategies

### The 3-2-1 Backup Rule for DJs

To avoid disasters before a gig, follow this rule using the script's tools:

1. **3 Copies**: Your library on the laptop, a copy on an external drive (Time Machine or clone), and a "cold" copy elsewhere.
2. **2 Media**: Use an SSD for live performance and an HDD for cold storage.
3. **1 Off-site**: A copy outside your studio (cloud or a friend's house).
*Script Usage*: Run the **A9 (Predictive Backup)** chain weekly.

### Audio Quality Management

- **Conversion (Option 40)**: If you buy WAV/AIFF but need to save space on a USB for CDJs, use option 40. It converts to 320kbps MP3 (CBR) using the LAME codec at maximum quality (`-q:a 0`). The script automatically moves the heavy WAVs to a `_WAV_Backup` folder so you can archive them on your studio drive and only carry the lightweight MP3s.
- **Normalization (Option 69)**: Analyzes the LUFS of your tracks. Do not destructively normalize your original files. Use the mixer's gain or ReplayGain tags.

### Metadata Cleanup for CDJs

Older CDJs can fail with strange characters or very large artworks.

- Use **Option 34** to normalize filenames (removes illegal characters).
- Use **Option 39** to clean up junk comments (download URLs) that clutter the CDJ screen.

## 15) Artist Profiles and Distribution (Option 72)

- Option 72 creates/uses `artist_pages.tsv` (in `config/`) with templates for bio, press kit, rider/stage plot, DMX/OBS/Ableton showfiles, and links to platforms/networks (Spotify, Apple, YouTube, SoundCloud, Beatport, Traxsource, Bandcamp, Mixcloud, Audius, Tidal, Deezer, Amazon, Shazam, Juno, Pandora, Instagram, TikTok, Facebook, Twitter/X, Threads, RA, Patreon, Twitch, Discord, Telegram, WhatsApp, Merch, Boiler Room…). You can edit it inline and export to CSV/HTML/JSON (`reports/`).
- Artist registration (quick summary):
  - **Digital Distribution**: upload music through aggregators (DistroKid, TuneCore, CD Baby, Record Union, Amuse). Beatport/Traxsource often require a distributor/label. Bandcamp/SoundCloud/Mixcloud are direct uploads.
  - **Claim Profiles**: Spotify for Artists, Apple Music for Artists, YouTube (Channel + Content ID), SoundCloud/Beatport/Traxsource (via distributor), Instagram/Facebook Music (via distributor for Content ID).
  - **Identifiers**: use UPC for releases and ISRC per track (aggregators usually generate them; otherwise, get your local ISRC prefix).
  - **Key Metadata**: artist, ISRC, UPC, composers, split percentages, genre, BPM, key, cover art (min. 3000x3000), 16/24-bit WAV audio, 44.1/48 kHz sample rate.
  - **Rights and Royalties**: register compositions with your PRO (ASCAP/BMI/SOCAN, etc.), and for global publishing admin, use services like Songtrust. For digital performance in the US, register with SoundExchange. Set up payment methods for your aggregator (PayPal/bank transfer) and direct stores (Bandcamp/Patreon/Twitch/merch).
  - **EPK/Press**: prepare a PDF EPK, press kit assets (HQ photos, logo, banners, rider/stage plot), links to clips/sets (YouTube/Boiler Room), and add them to the template.

## 16) License

- DJProducerTools License (Attribution + Revenue Share). Mandatory credit.
- Commercial use or derivatives: notify and share 20% of gross revenue (see `LICENSE.md`).

## 17) Support

- Author: Astro One Deep — <onedeep1@gmail.com>
- Issues/suggestions: open an issue on GitHub or send an email.

## 18) Testing and Development

The project includes a basic unit test suite to verify the functionality of the main utility functions.

### Running the Tests

1. **Open a terminal** and navigate to your project's root directory. Use quotes if the path contains spaces:

    ```bash
    cd "/Users/ivan/Desktop/0 SERATO BIBLIOTECA/DJProducerTools_Project "
    ```

2. **Give execution permissions** to the test script (you only need to do this once):

    ```bash
    chmod +x tests/test_runner.sh
    ```

3. **Run the tests**:

    ```bash
    bash tests/test_runner.sh
    ```

The runner will automatically discover and run all test functions, showing a summary of passed and failed tests.

### How It Works

- `tests/test_runner.sh` loads the main script (`DJProducerTools_MultiScript_EN.sh`).
- It uses a series of "mock" functions to override behaviors unsuitable for testing (like user input, clearing the screen, or modifying configuration files).
- Each test function (`test_*`) validates a specific piece of logic using simple helpers like `assert_equals`.
- This allows for isolated testing of functions like `strip_quotes` and `should_exclude_path`.

### Adding New Tests

To add a new test, open `tests/test_runner.sh` and create a new function whose name starts with `test_`. The runner will detect it automatically.

### Development Scripts

- **`build_macos_pkg.sh`**: Creates a native macOS `.pkg` installer that installs the application in `/Applications`. Ideal for simple distribution.
- **`generate_menu_svgs.sh`**: Automatically generates SVG screenshots of the menus. Requires `termtosvg` (`pip install termtosvg`).
- **`test_runner.sh`**: Runs the unit test suite to ensure code quality.
- **`tests/check_consistency.sh`**: Verifies the project's internal consistency. It checks menus, functions, chains, documentation existence, looks for pending `TODOs`/`FIXMEs`, validates the syntax of all `.sh` scripts using `shellcheck` (if installed), and scans for hardcoded secrets. Essential to run before a commit.
- **`build_release_pack.sh`**: Prepares a complete package for a GitHub release. It generates a draft `CHANGELOG.md` by grouping commits by type (e.g., `feat`, `fix`) from the git history. It can also optionally publish the release automatically to GitHub if you configure an access token.
- **`generate_html_report.sh`**: Runs the `check_consistency.sh` script and generates a visual status report in HTML format (`project_status_report.html`), with separate sections for failures, pending tasks (TODOs), and successful checks.

These scripts automate the development lifecycle, from testing to final product creation and documentation updates.
