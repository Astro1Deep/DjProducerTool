# DJProducerTools API Documentation

## Overview
This document describes the internal functions and interfaces of DJProducerTools.

## Core Functions

### Path Management

#### `init_paths()`
Initialize working directories and configuration paths.
```bash
init_paths
# Sets up: CONFIG_DIR, REPORTS_DIR, PLANS_DIR, QUAR_DIR, VENV_DIR
```

#### `ensure_base_path_valid()`
Validate that BASE_PATH exists and contains expected structure.
```bash
ensure_base_path_valid
# Exit status: 0 if valid, 1 if invalid
```

### Analysis Functions

#### `scan_workspace()`
Scan music library and generate catalog.
```bash
scan_workspace [--dry-run] [--verbose]
# Produces: catalog.tsv in REPORTS_DIR
```

#### `generate_hash_index()`
Generate SHA-256 hashes for all audio files.
```bash
generate_hash_index [--force] [--pattern "*.mp3"]
# Produces: hash_index.json
```

#### `find_exact_duplicates()`
Find bit-identical audio files.
```bash
find_exact_duplicates [--output FORMAT]
# Formats: json, tsv, txt
# Produces: dupes_plan.json
```

### Backup Functions

#### `backup_serato()`
Backup Serato-specific metadata.
```bash
backup_serato [--destination PATH]
# Creates timestamped backup in _DJProducerTools/backups/
```

#### `backup_metadata()`
Backup DJ software metadata (Serato, Traktor, Rekordbox, Ableton).
```bash
backup_metadata [--format FORMAT]
```

### Safety Functions

#### `quarantine_files()`
Safely move files to quarantine for review.
```bash
quarantine_files FILE1 FILE2 [--reason "duplicate"]
# Files preserved in _DJProducerTools/quarantine/ with restore capability
```

#### `restore_quarantine()`
Restore files from quarantine.
```bash
restore_quarantine FILE_ID [--destination PATH]
```

## Configuration

### Configuration File Format
Located at `_DJProducerTools/config/djpt.conf`

```bash
BASE_PATH="/path/to/music"
AUDIO_ROOT="/path/to/music/audio"
SERATO_ROOT="/Users/username/Music/_Serato_"
SAFE_MODE=1
DEBUG_MODE=0
```

### Profile Configuration
Custom analysis profiles in `_DJProducerTools/config/profiles/`

## Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `DJ_SAFE_LOCK` | Enable safety protections | `1` or `0` |
| `DEBUG_MODE` | Enable verbose output | `0` (default), `1` |
| `DRYRUN_FORCE` | Force dry-run mode | `0` (default), `1` |
| `ML_ENV_DISABLED` | Disable ML features | `0` (default), `1` |

## Return Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Permission denied |
| 4 | File not found |
| 5 | Directory not found |

## Exit Codes

```bash
exit 0   # Successful execution
exit 1   # General error
exit 2   # Invalid path
exit 3   # Missing dependencies
```

## File Formats

### Hash Index (JSON)
```json
{
  "generated": "2024-01-04T08:30:00Z",
  "hashes": {
    "sha256_hash": {
      "path": "/path/to/file.mp3",
      "size": 5242880,
      "modified": "2024-01-04"
    }
  }
}
```

### Duplicates Plan (JSON)
```json
{
  "timestamp": "2024-01-04T08:30:00Z",
  "duplicates": [
    {
      "hash": "abc123...",
      "count": 2,
      "files": [
        {"path": "/path/to/file1.mp3", "size": 5242880},
        {"path": "/path/to/file2.mp3", "size": 5242880}
      ]
    }
  ]
}
```

## Error Handling

All functions follow standard error handling:
```bash
function_name() {
    if [ ! -d "$1" ]; then
        printf "%s[ERROR] Directory not found: %s%s\n" "$C_RED" "$1" "$C_RESET" >&2
        return 1
    fi
    # ... function logic ...
    return 0
}
```

## Testing

Test suite: `tests/test_runner_fixed.sh`

Run all tests:
```bash
bash tests/test_runner_fixed.sh
```

## Debugging

Enable debug output:
```bash
DEBUG_MODE=1 ./DJProducerTools_MultiScript_EN.sh
```

## Version

Current version: 2.0.0
See `VERSION` file for details.

## Contributing

See `CONTRIBUTING.md` for development guidelines.
