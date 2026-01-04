<img width="1536" height="1024" alt="20260103_1357_Futuristic DJ Tool Banner_remix_01ke22aqhxe2r9n8vcsd71a4a3" src="https://github.com/user-attachments/assets/4fa57953-682f-4209-a5db-612c7b8fb812" />






# DJProducerTool 🎵

**Multi-language professional DJ production suite for macOS**

English | [Español](#versión-en-español)

## ✨ Features

- 🎚️ **Library Management** - Organize and sync DJ libraries
- 🎵 **Audio Processing** - BPM detection, key analysis, waveform generation
- 🎥 **Serato Video** - Integration with Serato video features
- 💡 **Lighting Control** - DMX support for lights, lasers, and effects
- 🎙️ **OSC Support** - Open Sound Control for advanced automation
- 📊 **Visualization** - Advanced waveform and frequency analysis
- 🔊 **Audio Analysis** - Comprehensive audio metadata extraction

## 🚀 Quick Start

### One-line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/INSTALL.sh | bash
```

### Manual Installation

1. Clone or download the repository
2. Navigate to the project directory
3. Run the main script:

```bash
# English version
./scripts/DJProducerTools_MultiScript_EN.sh

# Spanish version  
./scripts/DJProducerTools_MultiScript_ES.sh
```

## 📋 Main Menu Options

### Library & Duplicates (L/D)
- Scan and analyze music libraries
- Find and remove duplicate files
- Merge cue points and metadata

### Video & OSC (V/O)
- Serato video integration
- OSC protocol support
- Real-time sync with controllers

### Lights & Effects (L/E)
- DMX lighting control
- Laser effect management
- Real-time synchronization

### Advanced (A)
- BPM analysis and correction
- Key detection and mixing recommendations
- Batch processing capabilities

## 📚 Documentation

- **[GUIDE.md](./GUIDE.md)** - Comprehensive user guide
- **[FEATURES.md](./FEATURES.md)** - Detailed feature documentation  
- **[API.md](./API.md)** - API reference for developers
- **[INSTALL.md](./INSTALL.md)** - Installation guide

### En Español
- **[GUIA_ES.md](./GUIDE_ES.md)** - Guía completa del usuario
- **[FEATURES_ES.md](./FEATURES_ES.md)** - Documentación detallada de características
- **[INSTALL_ES.md](./INSTALL_ES.md)** - Guía de instalación

## 🛠️ Usage

### Quick Commands

```bash
# After installation, use global command
dj           # Auto-detects system language
dj-en        # Force English
dj-es        # Force Spanish (Fuerza español)

# Or run directly
~/DJProducerTools/scripts/DJProducerTools_MultiScript_EN.sh
~/DJProducerTools/scripts/DJProducerTools_MultiScript_ES.sh
```

### From Project Directory

```bash
# Make sure you're in the project root
cd DJProducerTools_Project

# Run English version
./scripts/DJProducerTools_MultiScript_EN.sh

# Run Spanish version
./scripts/DJProducerTools_MultiScript_ES.sh
```

## ⚙️ System Requirements

- **OS**: macOS 10.13+
- **Shell**: bash 4.0+ or zsh
- **Dependencies**:
  - `ffmpeg` (audio processing)
  - `jq` (JSON parsing)
  - `curl` (downloads)

### Install Dependencies

```bash
# Using Homebrew
brew install ffmpeg jq
```

## 🔧 Configuration

All settings are stored in `~/.djproducertools/config`:

```bash
# Library paths
LIBRARY_PATH="/path/to/music"
BACKUP_PATH="/path/to/backup"

# Audio processing
FFMPEG_OPTS="-q:a 9"  # Quality settings
```

## 📊 Project Structure

```
DJProducerTools_Project/
├── scripts/
│   ├── DJProducerTools_MultiScript_EN.sh  (1000 lines)
│   └── DJProducerTools_MultiScript_ES.sh  (1000 lines)
├── docs/
│   ├── README.md, GUIDE.md, FEATURES.md
│   ├── README_ES.md, GUIDE_ES.md, FEATURES_ES.md
│   └── API.md, INSTALL.md (bilingual)
├── INSTALL.sh  (Universal installer)
└── VERSION     (Current: v2.1.0)
```

## 🧪 Testing

Run test suite:

```bash
# From project directory
bash ./scripts/DJProducerTools_MultiScript_EN.sh --test

# Or Spanish version
bash ./scripts/DJProducerTools_MultiScript_ES.sh --test
```

## 🐛 Troubleshooting

### Scripts not found (404 error)

Make sure you're in the correct directory:

```bash
cd ~/DJProducerTools_Project  # Project root
./scripts/DJProducerTools_MultiScript_EN.sh
```

### Permission denied

Make scripts executable:

```bash
chmod +x ~/DJProducerTools/scripts/*.sh
```

### Missing dependencies

Install required tools:

```bash
brew install ffmpeg jq curl
```

## 📝 Version History

- **v2.1.0** (Jan 2025)
  - ✓ Complete bilingual support (EN/ES)
  - ✓ DMX lighting integration
  - ✓ Serato Video support
  - ✓ OSC protocol support
  - ✓ Advanced progress indicators with spinners
  - ✓ Comprehensive error handling

- **v2.0.0** (Jan 2025)
  - Initial production release
  - Core feature implementation
  - Bilingual documentation

## 🤝 Contributing

To contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open a Pull Request

See [CONTRIBUTING.md](./CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see [LICENSE](./LICENSE) file for details.

Commercial use attribution to **Astro1Deep**.

## 👨‍💻 Author

**Astro1Deep** - DJ Producer Tools Creator

- GitHub: [@Astro1Deep](https://github.com/Astro1Deep)
- Project: [DjProducerTool](https://github.com/Astro1Deep/DjProducerTool)

---

## Versión en Español

# DJ Producer Tools 🎵

**Suite de producción para DJ de nivel profesional para macOS**

## 🚀 Instalación Rápida

```bash
curl -fsSL https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/INSTALL.sh | bash
```

Luego usa:

```bash
dj            # Detecta idioma automáticamente
dj-es         # Versión en español
dj-en         # Versión en inglés
```

## 📚 Documentación en Español

- **[GUIA_ES.md](./GUIDE_ES.md)** - Guía del usuario completa
- **[FEATURES_ES.md](./FEATURES_ES.md)** - Características detalladas
- **[INSTALL_ES.md](./INSTALL_ES.md)** - Guía de instalación

## ✨ Características

- 🎚️ Gestión de Librerías
- 🎵 Procesamiento de Audio
- 🎥 Integración Serato Video
- 💡 Control de Iluminación DMX
- 🎙️ Soporte OSC
- 📊 Visualización Avanzada

## 🔧 Requisitos

- macOS 10.13+
- bash 4.0+ o zsh
- ffmpeg, jq, curl

```bash
brew install ffmpeg jq
```

Para más información, consulta [INSTALL_ES.md](./INSTALL_ES.md)

---

**Made with ❤️ for DJ Producers | Hecho con ❤️ para Productores DJ**
