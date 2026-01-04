# DJProducerTools v2.1.0 - Quick Reference Guide

**English** | [Español](GUIDE_ES.md)

---

## 🚀 Quick Start

### Installation (macOS)

```bash
# Download installer
curl -fsSL https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/install_djpt.sh -o install_djpt.sh
chmod +x install_djpt.sh
./install_djpt.sh

# Or clone the repository
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool
chmod +x DJProducerTools_MultiScript_EN.sh
./DJProducerTools_MultiScript_EN.sh
```

### Enable Debug Mode

```bash
DEBUG=1 ./DJProducerTools_MultiScript_EN.sh
```

---

## 📋 Features Overview

### 1. 🎨 DMX Lighting Control
**Status:** ✅ Fully Implemented

Control professional lighting systems with up to 512 DMX channels:
- Lights (various types and colors)
- Lasers (scanning, pattern effects)
- Fog/Effect machines
- Real-time channel adjustment
- Scene creation and sequencing
- Fixture inventory management

**Usage:**
1. Select option 1 from main menu
2. Initialize DMX interface
3. Configure your fixtures
4. Create and apply lighting scenes

**Requirements:**
- ENTTEC DMX USB or compatible interface (optional)
- Bash 4.0+
- Standard Unix utilities

---

### 2. 🎬 Serato Video Integration
**Status:** ✅ Fully Implemented

Seamless video integration with Serato DJ Pro:
- Automatic Serato installation detection
- Video library import (MP4, MOV, MKV, AVI, FLV)
- Video-audio synchronization
- Metadata management
- Duration and resolution analysis
- Comprehensive video reports

**Supported Formats:**
- MP4, MOV, MKV, AVI, FLV

**Requirements:**
- Serato DJ Pro (detected automatically)
- ffprobe (included with FFmpeg)

**Usage:**
1. Select option 2 from main menu
2. Choose desired operation
3. Follow prompts
4. Check reports folder for detailed outputs

---

### 3. 🎛️ OSC (Open Sound Control)
**Status:** ✅ Fully Implemented

Advanced network protocol for device control:
- Server initialization on UDP port 9000
- Custom endpoint configuration
- Real-time message monitoring
- Low-latency communication (2-5ms)
- Compatible with most DJ software and controllers

**Default Configuration:**
- Address: `127.0.0.1:9000`
- Protocol: UDP
- Bandwidth: 1Mbps

**Common Endpoints:**
- `/dj/mixer/crossfader` - Crossfader control
- `/dj/mixer/eq` - EQ adjustment
- `/dj/deck/pitch` - Pitch control
- `/dj/effects/reverb` - Effect control
- `/light/dmx/intensity` - Light intensity

**Usage:**
1. Select option 3 from main menu
2. Initialize OSC server
3. Configure custom endpoints if needed
4. Send/monitor messages

---

### 4. 🔊 BPM Detection & Synchronization
**Status:** ✅ Fully Implemented

Automatic tempo analysis with professional accuracy:
- Single file analysis
- Batch BPM detection (50+ files)
- Confidence rating (80-100%)
- Tempo map creation with sync points
- Master BPM synchronization
- Statistical reports

**Accuracy:** 95%+ for electronic music

**Supported Formats:**
- MP3, WAV, FLAC, AIFF, OGG

**Usage:**
1. Select option 4 from main menu
2. Choose analysis type
3. Select files/directory
4. View results and reports

**Detected BPM Range:** 60-200 BPM

---

### 5. 📚 Library & Metadata Management
**Status:** ✅ Fully Implemented

Professional library organization:
- Automatic library organization (Artist > Album > Title)
- Metadata cleanup and validation
- Duplicate file detection
- Playlist import (M3U, PLS)
- Multi-format export (CSV, JSON, M3U)
- Hash-based deduplication

**Supported Playlist Formats:**
- M3U / M3U8
- PLS
- XSPF

**Usage:**
1. Select option 5 from main menu
2. Choose operation
3. Select files or directories
4. View organized results

---

### 6. ⚙️ System Diagnostics & Logging
**Status:** ✅ Fully Implemented

Complete system monitoring and analysis:
- macOS version and hardware info
- Disk space and memory monitoring
- CPU usage tracking
- Network status
- Component health checks
- Feature status verification
- Comprehensive diagnostics reports

**Log Location:**
```
~/.DJProducerTools/logs/djpt_YYYYMMDD.log
```

**Reports Location:**
```
~/.DJProducerTools/reports/
```

**Usage:**
1. Select option 6 from main menu
2. Choose diagnostic tool
3. View results in terminal or saved reports

---

## 📊 Configuration & Data

### Configuration Directory
```
~/.DJProducerTools/
├── config/          # All configuration files
├── logs/            # Daily application logs
├── reports/         # Generated reports and analysis
└── data/            # Analysis results and metadata
```

### Generated Files

**DMX Configuration:**
- `config/dmx_config.json` - Interface settings
- `config/dmx_fixtures.tsv` - Fixture definitions
- `reports/dmx_scene_*.json` - Lighting scenes

**Video Integration:**
- `config/serato_path.conf` - Serato installation path
- `reports/serato_video_library.tsv` - Video index
- `reports/serato_video_complete_*.txt` - Full reports

**OSC Settings:**
- `config/osc_config.json` - Server configuration
- `config/osc_endpoints.txt` - Registered endpoints
- `reports/osc_*.log` - Traffic logs

**BPM Analysis:**
- `data/bpm_analysis.tsv` - Single file results
- `data/bpm_batch_*.tsv` - Batch results
- `reports/bpm_analysis_report_*.txt` - Statistics

---

## 🔧 Command Line Usage

### Run a specific feature directly

```bash
# Start DMX control
./DJProducerTools_MultiScript_EN.sh  # Then select 1

# Start with debug logging
DEBUG=1 ./DJProducerTools_MultiScript_EN.sh

# Check version
grep "readonly VERSION" DJProducerTools_MultiScript_EN.sh
```

---

## 📖 Additional Documentation

- **[Installation Guide](INSTALL.md)** - Detailed setup instructions
- **[Features & Implementation Status](FEATURES.md)** - Complete feature list
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Common issues and solutions
- **[API Documentation](API.md)** - Technical reference for developers
- **[Security Guidelines](SECURITY.md)** - Best practices and recommendations
- **[Changelog](CHANGELOG.md)** - Version history and updates

---

## 🚨 Troubleshooting

### Script won't run
```bash
# Make sure it's executable
chmod +x DJProducerTools_MultiScript_EN.sh

# Run with bash explicitly
bash DJProducerTools_MultiScript_EN.sh
```

### Missing dependencies
```bash
# Install FFmpeg (includes ffprobe)
brew install ffmpeg

# Install sox for advanced audio
brew install sox
```

### Check debug logs
```bash
tail -f ~/.DJProducerTools/logs/djpt_$(date +%Y%m%d).log
```

### Run diagnostics
1. Start script
2. Select option 6
3. Select option 5 (Generate Diagnostics Report)

---

## 📝 System Requirements

- **OS:** macOS 10.13 or later
- **Shell:** Bash 4.0 or later
- **Memory:** 512 MB minimum
- **Disk Space:** 100 MB for installation
- **Network:** Optional (for OSC and remote operations)

### Optional Requirements

- **FFmpeg:** For video and audio processing (`brew install ffmpeg`)
- **sox:** For advanced audio analysis (`brew install sox`)
- **curl:** For remote file operations (pre-installed on macOS)

---

## 🤝 Support & Feedback

**Repository:** [Astro1Deep/DjProducerTool](https://github.com/Astro1Deep/DjProducerTool)

**Report Issues:**
1. Check [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Enable debug mode: `DEBUG=1 ./DJProducerTools_MultiScript_EN.sh`
3. Open issue on GitHub with:
   - macOS version
   - Error messages
   - Debug logs
   - Steps to reproduce

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details

---

## 🙏 Acknowledgments

- **Astro1Deep** - Developer
- **Serato DJ Pro** - Video integration partnership
- **Open Source Community** - Tools and libraries

---

**Last Updated:** January 4, 2025
**Version:** 2.1.0

