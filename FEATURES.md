# DJProducerTools - Core Features & System Capabilities (v1.3.0)

DJProducerTools is an eclectic, professional macOS audio engineering suite designed for DJs, music producers, and sound designers managing multi-terabyte libraries across external drives and standalone hardware.

---

## ⚡ 1. Resilient Acoustic Recognition Core (ShazamIO)
- **High-Precision Fingerprinting**: Asynchronous song, remix, and artist recognition powered by the official ShazamIO acoustic engine.
- **Exponential Backoff & Jitter**: Automated network retry mechanism with exponential delay to handle rate limits and transient connection drops.
- **FFmpeg Transcode Fallback**: Automatic on-the-fly audio normalization and conversion (extracting clean 16-bit 44.1kHz PCM chunks) for corrupted, exotic, or 24/32-bit float audio files that raw recognizers reject.
- **Persistent SQLite Cache**: Stores acoustic signatures in `_DJProducerTools/state/shazam_cache.sqlite` to prevent unnecessary repeated requests.

---

## 🧠 2. Cerebro OS & MCP Protocol Server
- **Canonical Model Context Protocol Server** (`core/mcp_server_fixed.py`):
  - Standardized JSON-RPC interface exposing 10 specialized audio tools to AI agents:
    1. `djpt_system_status`: Complete system and hardware telemetry.
    2. `djpt_scan_library`: Streaming recursive audio scanning.
    3. `djpt_query_library`: SQLite-based deep library search.
    4. `djpt_audit_disks`: Multi-disk storage and integrity check.
    5. `djpt_recognize_audio`: Resilient Shazam acoustic recognition.
    6. `djpt_deduplicate_plan`: Two-stage quarantine deduplication.
    7. `djpt_export_playlist`: Multi-format playlist builder (M3U, TSV, XML).
    8. `djpt_ai_health`: Local AI engine status and diagnostic.
    9. `djpt_mpc_sync`: Bridge to Akai MPC and Roland SP-404 hardware.
    10. `djpt_clean_metadata`: Purges AppleDouble (`._*`) and `.DS_Store` metadata.
- **Zero-Dependency Native Python Fallback**: Runs smoothly whether the official `mcp` library is installed or via native JSON-RPC stdio.

---

## 💾 3. Multi-Disk Architecture & Hardware Integrations
- **Autonomous Multi-Volume Management**: Native compatibility with the complete producer storage array:
  - **Realtek RTL9210B Media**: Native Instruments Kontakt & Reaktor libraries.
  - **Samsung PSSDT7**: Ableton Live projects, master audio samples & Roland SP-404MK2 storage.
  - **SanDisk SSD**: Serato DJ Pro crates, history, cue-points & VJ video loops.
  - **Akai MPC MicroSD (`/Volumes/MPCSMPL`)**: SQLite standalone library, expansions, and `.xpj` project health audit.
- **Zero Ghost-File Policy**: Enforces automated purging of macOS AppleDouble (`._*`) files to ensure standalone hardware stability.

---

## 🛡️ 4. Safety-First Architecture & Deduplication
- **Safe Mode Engine**: `SAFE_MODE=1` and `DJ_SAFE_LOCK=1` prevent accidental file loss.
- **Two-Stage Deduplication**: Generates an isolated diff plan first; never deletes directly, defaulting to quarantine isolation.
- **Serato Integrity Protection**: Automated backups of `_Serato_` subfolders, cue points, beatgrids, and crate structures before any modification.

---

## 🔬 5. Local AI & Machine Learning Lab
- **Local Audio Embeddings**: Fast musical similarity analysis, outlier/anomaly detection, segment clustering, and loudness normalization.
- **Multimodal AI Tagging**:
  - `music_tags`: Acoustic genre and mood tagging (CLAP / MusicGen).
  - `video_tags`: Semantic video tagging (CLIP) for VJ sets and visual projection loops.
- **Privacy & Local-First**: Runs offline on Apple Silicon (M-series Neural Engine & GPU) without transmitting private tracks to external clouds.

---

## 🌐 6. Visual Catalogs & Web Streaming
- **HTML5 Universal Audio Explorer**: Standalone interactive catalog with instant search, key/BPM filtering, and zero-restriction local audio playback via dedicated RFC 7233 Range streaming server (`serve_mpc.py`).
- **Editorial Design System**: High-resolution responsive banners featuring the official identities of **Astro1Deep** and **WaxSpaceship**.
