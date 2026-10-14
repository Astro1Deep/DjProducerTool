# Changelog - DJProducerTools

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.3.0] - 2026-10-14 • Resilient Acoustic Engine & Multi-Disk Ecosystem

### 🚀 Added
- **ShazamIO Resilient Acoustic Engine** (`lib/shazam_recognizer.py`):
  - Robust audio fingerprinting with exponential backoff and jitter retry mechanism.
  - Automatic FFmpeg audio normalization fallback for non-standard, corrupted, or 24/32-bit float audio files.
  - Persistent SQLite fingerprint cache (`_DJProducerTools/state/shazam_cache.sqlite`) to eliminate duplicate API requests.
- **Canonical MCP Protocol Server** (`core/mcp_server_fixed.py`):
  - 10 full-featured tools for AI agents (Cerebro OS, MLX Local Agent, Claude, Codex, Gemini).
  - Native operations: `djpt_system_status`, `djpt_scan_library`, `djpt_query_library`, `djpt_audit_disks`, `djpt_recognize_audio`, `djpt_deduplicate_plan`, `djpt_export_playlist`, `djpt_ai_health`, `djpt_mpc_sync`, `djpt_clean_metadata`.
- **Editorial Visual Branding**:
  - High-resolution SVG banners with dual compact cyberpunk cells:
    - Left Cell: Original **Astro1Deep** Eye with Tear symbol (responsive Retina scaling).
    - Right Cell: Original **WaxSpaceship** Cosmic Rocket symbol (responsive Retina scaling).
    - Central Priority Zone: 760px wide clean navigation area for suite menus and metadata.
  - Hero artwork and visual assets stored in `docs/assets/branding/`.
- **Multi-Disk Ecosytem Architecture**:
  - Native indexing, synchronization, and health checks across external drives:
    - Realtek RTL9210B Media (Native Instruments & Reaktor)
    - Samsung PSSDT7 (Production, Ableton Live & Roland SP-404MK2)
    - SanDisk SSD (Serato DJ Pro & VJ Loops)
    - Akai MPC MicroSD (`/Volumes/MPCSMPL`)
- **Automated Wiki Sync Tool** (`scripts/sync_wiki.sh`):
  - Seamless two-way push to GitHub Wiki (`https://github.com/Astro1Deep/DjProducerTool/wiki`).

### 🛡️ Changed & Hardened
- Enhanced `mcp_server.py` compatibility wrapper to route directly to `core/mcp_server_fixed.py`.
- Comprehensive bilingual documentation rewrite (`README.md` and `README_ES.md`).
- Strict macOS AppleDouble (`._*`) and `.DS_Store` sanitizer integrated into all external disk operations.

---

## [1.2.0] - 2026-04-09 • Strict Release Certification & Local ML
- **TensorFlow / ML Evolution Lab**: Local embeddings, similarity, anomaly detection, CLAP music tags and CLIP video tags.
- **Sanctuary & Safety Modes**: Hardened `SAFE_MODE=1` quarantine workflow preventing destructive file loss.
- **Fresh Install Certification Suite**: Zero-dependency installer test harness.

---

## [1.1.0] - 2026-04-08 • Modular Architecture Refactoring
- **Modular Core**: Split monolithic bash logic into Python modular packages (`core/`, `lib/`).
- **Portable Launcher**: Entry points via `bin/djpt` and `launch.sh`.
- **Central SQLite Storage**: Low-memory footprint database for massive multi-terabyte audio collections.

---

## [1.0.0] - 2026-01-08 • Initial Release
- Initial public release of DJProducerTools suite.
