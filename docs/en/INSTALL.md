# Installation Guide

## Quick Install

### For End Users
```bash
curl -sL https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/install_djpt.sh | bash
```

This downloads and installs the latest stable version.

### For Developers
```bash
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool
source .venv/bin/activate  # Optional Python environment
```

## System Requirements

- **OS**: macOS 10.15 (Catalina) or later
- **Shell**: bash 4.0+ (macOS includes 3.2, but auto-upgrades)
- **Space**: 2GB free (for virtual environment)
- **Permissions**: Read/write access to music libraries

## Optional Dependencies

The tool auto-detects and installs these as needed:

| Tool | Purpose | Installation |
|------|---------|--------------|
| `ffmpeg` | Audio detection | `brew install ffmpeg` |
| `ffprobe` | Media analysis | `brew install ffmpeg` |
| `sox` | Audio conversion | `brew install sox` |
| `jq` | JSON processing | `brew install jq` |
| `python3` | ML features | `brew install python3` |

## Installation Methods

### Method 1: Automated Script
```bash
bash install_djpt.sh
```

### Method 2: Manual Git Clone
```bash
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool
chmod +x DJProducerTools_MultiScript_*.sh
```

### Method 3: macOS Installer Package
```bash
./build_macos_pkg.sh
# Follow installer GUI
```

## Configuration

### First Run
1. Run the script: `./DJProducerTools_MultiScript_EN.sh` or `_ES.sh`
2. Select Option 2: Change Base Path
3. Point to your music library root
4. Tool auto-creates `_DJProducerTools` config directory

### Configuration Files
Located in `BASE_PATH/_DJProducerTools/config/`:
- `djpt.conf` - Main configuration
- `profiles/` - Custom analysis profiles
- `audio_history.txt` - Audio library history

## Verification

After installation, verify:
```bash
# Check scripts are executable
ls -l DJProducerTools_MultiScript_*.sh

# Run tests
bash tests/test_runner_fixed.sh

# Test help menu
./DJProducerTools_MultiScript_EN.sh --help
```

## Uninstallation

### Remove User Installation
```bash
rm -f /usr/local/bin/djproducertool
rm -rf ~/.djproducertool
```

### Remove Git Clone
```bash
cd /path/to/DjProducerTool
rm -rf .git _DJProducerTools .venv
```

## Troubleshooting

### Script Won't Run
```bash
# Ensure correct permissions
chmod +x DJProducerTools_MultiScript_*.sh

# Verify bash version
bash --version  # Should be 4.0+
```

### Python Dependencies Missing
```bash
# Install required Python packages
python3 -m pip install numpy pandas scikit-learn joblib librosa

# Or use auto-setup from menu option 70
```

### Permission Errors
```bash
# Fix file ownership
sudo chown -R $(whoami) /path/to/music/library
```

## Getting Help

- **Documentation**: See `GUIDE.md` or `GUIDE_es.md`
- **Issues**: [GitHub Issues](https://github.com/Astro1Deep/DjProducerTool/issues)
- **Contributing**: See `CONTRIBUTING.md`

## Next Steps

1. Read the [Quick Start Guide](GUIDE.md)
2. Run Status Check (Option 1) to see your library
3. Create your first backup (Option 7)
4. Try Smart Analysis (Option 59)
