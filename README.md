# DJProducerTools v2.0.0

**Professional Music Library Management Tool for DJs on macOS**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-2.0.0-blue.svg)](VERSION)
![Language](https://img.shields.io/badge/Languages-EN%20%7C%20ES-brightgreen)
![macOS](https://img.shields.io/badge/macOS-10.15%2B-lightgrey)

## 🎯 Quick Start

### Run the Tool

```bash
# English version
bash scripts/DJProducerTools_MultiScript_EN.sh

# Spanish version - Versión en Español
bash scripts/DJProducerTools_MultiScript_ES.sh
```

### Installation

```bash
bash scripts/install_djpt.sh
```

## 📚 Documentation

### English Docs
- [Getting Started](docs/en/README.md)
- [Installation Guide](docs/en/INSTALL.md)
- [User Guide](guides/GUIDE_en.md)
- [API Reference](docs/en/API.md)
- [Debugging](docs/en/DEBUG_GUIDE.md)
- [Security](docs/en/SECURITY.md)
- [Contributing](docs/en/CONTRIBUTING.md)
- [Changelog](docs/en/CHANGELOG.md)
- [Roadmap](docs/en/ROADMAP.md)

### Documentación en Español
- [Primeros Pasos](docs/es/README_ES.md)
- [Guía de Instalación](docs/es/INSTALL_ES.md)
- [Guía de Usuario](guides/GUIDE_es.md)
- [Referencia API](docs/es/API_ES.md)
- [Depuración](docs/es/DEBUG_GUIDE_ES.md)
- [Seguridad](docs/es/SECURITY_ES.md)
- [Contribuir](docs/es/CONTRIBUTING_ES.md)
- [Registro de Cambios](docs/es/CHANGELOG_ES.md)
- [Hoja de Ruta](docs/es/ROADMAP_ES.md)

## ✨ Features

- 🔍 **Workspace Scanning** - Complete library analysis
- 🎵 **Deduplication** - SHA-256 audio hashing
- 📊 **ML Analysis** - Smart recommendations
- 🛡️ **Safe Mode** - Quarantine system for protection
- 💾 **Metadata Backup** - Serato, Traktor, Rekordbox, Ableton
- ⚡ **Progress Tracking** - Real-time feedback
- 🐛 **Debug Mode** - Detailed diagnostics
- 🌍 **Bilingual** - Full English/Spanish support

## 📦 Repository Structure

```
DJProducerTools/
├── scripts/                    # Main scripts
│   ├── DJProducerTools_MultiScript_EN.sh
│   ├── DJProducerTools_MultiScript_ES.sh
│   └── install_djpt.sh
├── docs/                       # Documentation
│   ├── en/                     # English docs
│   └── es/                     # Spanish docs
├── guides/                     # User guides
├── tests/                      # Test suite
├── lib/                        # Libraries
├── _DJProducerTools/          # Internal structure
├── .github/                    # GitHub workflows
├── LICENSE                     # MIT License
└── VERSION                     # Version file
```

## 🚀 System Requirements

- macOS 10.15+
- Bash 4.0+
- Python 3.8+ (optional, for ML features)

## 💡 Usage Examples

### Basic Scan
```bash
bash scripts/DJProducerTools_MultiScript_EN.sh
# Select: 1 (Scan Workspace)
```

### Find Duplicates
```bash
bash scripts/DJProducerTools_MultiScript_EN.sh
# Select: 2 (Find Duplicates)
```

### ML Analysis
```bash
bash scripts/DJProducerTools_MultiScript_EN.sh
# Select: 5 (ML Features)
```

## 🛡️ Safety

- **Safe Mode**: Enabled by default - no files deleted without confirmation
- **Quarantine**: Suspicious files isolated before removal
- **Backup**: Automatic metadata backup before operations
- **Dry Run**: Test operations before applying changes

## 📞 Support

For issues, questions, or contributions:
- [GitHub Issues](../../issues)
- [Security Concerns](docs/en/SECURITY.md)
- [Contributing Guide](docs/en/CONTRIBUTING.md)

## 📄 License

MIT License - See [LICENSE](LICENSE) for details

## 👨‍💻 Author

**Astro1Deep** - DJ Production Tools

---

**Current Version**: v2.0.0  
**Last Updated**: January 4, 2024
