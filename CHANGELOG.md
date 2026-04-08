# Changelog - Refactoring v2.0

## Architectual Changes
- **Monolith to Modular**: Split `DJProducerTools_MultiScript_ES.sh` into a Python-based core (`scripts/core`).
- **Portable Launcher**: New entry point `bin/djpt` automatically handles environment variables and virtualenv.
- **Data Isolation**:
  - `scans/`: Immutable scan packs.
  - `state/`: Mutable database and logs.
  - `ai/`: Model storage and config.

## New Features
- **Streaming Scanner**: Low-memory footprint scanning for TB-scale libraries.
- **SQLite Backend**: Centralized `state/db/djpt.sqlite` for fast querying.
- **Safe Dedupe**: Two-stage deduplication (Plan -> Apply) with Quarantine default.

## Legacy
- Old scripts moved to `scripts/legacy/` for reference.
