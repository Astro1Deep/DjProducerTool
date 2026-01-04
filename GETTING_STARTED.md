# Getting Started - DJ Producer Tools 🎵

**Get up and running in 2 minutes!**

[English](#english) | [Español](#español)

---

## English

### 🚀 Quick Start (Choose One)

#### Option 1: One-Line Installation (Recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/INSTALL.sh | bash
```

Then:
```bash
dj              # Auto-detect your system language
# or
dj-en          # Force English
dj-es          # Force Spanish
```

#### Option 2: Manual Installation
```bash
# Clone repository
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool

# Run directly
./scripts/DJProducerTools_MultiScript_EN.sh
# or
./scripts/DJProducerTools_MultiScript_ES.sh
```

### ✅ Requirements

- macOS 10.13+
- bash 4.0+ or zsh
- Internet connection (for installation)

**Dependencies** (install if needed):
```bash
brew install ffmpeg jq
```

### 🎮 What Can You Do?

1. **Library Management** - Organize and analyze DJ libraries
2. **Audio Analysis** - BPM detection, key analysis, metadata
3. **Video Integration** - Serato video support
4. **Lighting Control** - DMX, lasers, effects
5. **Advanced Features** - OSC, visualization, batch processing

### 📚 Next Steps

1. **Read the guide**: `README.md` or `GUIDE.md`
2. **Explore features**: Check `FEATURES.md`
3. **Need help?** See `DEBUG_GUIDE.md`

### 💡 Troubleshooting

**"Command not found: dj"**
```bash
# Add to ~/.zprofile or ~/.bash_profile:
export PATH="$HOME/DJProducerTools/bin:$PATH"
```

**"Permission denied"**
```bash
chmod +x ~/DJProducerTools/scripts/*.sh
```

**Missing dependencies**
```bash
brew install ffmpeg jq curl
```

---

## Español

### 🚀 Inicio Rápido (Elige Una Opción)

#### Opción 1: Instalación en Una Línea (Recomendada)
```bash
curl -fsSL https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/INSTALL.sh | bash
```

Luego:
```bash
dj              # Detecta automáticamente tu idioma del sistema
# o
dj-en          # Fuerza inglés
dj-es          # Fuerza español
```

#### Opción 2: Instalación Manual
```bash
# Clonar repositorio
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool

# Ejecutar directamente
./scripts/DJProducerTools_MultiScript_ES.sh
# o
./scripts/DJProducerTools_MultiScript_EN.sh
```

### ✅ Requisitos

- macOS 10.13+
- bash 4.0+ o zsh
- Conexión a Internet (para instalación)

**Dependencias** (instala si es necesario):
```bash
brew install ffmpeg jq
```

### 🎮 ¿Qué Puedes Hacer?

1. **Gestión de Librerías** - Organiza y analiza librerías DJ
2. **Análisis de Audio** - Detección de BPM, análisis de tonalidad, metadatos
3. **Integración de Video** - Soporte Serato video
4. **Control de Iluminación** - DMX, láseres, efectos
5. **Características Avanzadas** - OSC, visualización, procesamiento por lotes

### 📚 Próximos Pasos

1. **Lee la guía**: `README_ES.md` o `GUIDE_ES.md`
2. **Explora características**: Consulta `FEATURES_ES.md`
3. **¿Necesitas ayuda?** Ve a `DEBUG_GUIDE_ES.md`

### 💡 Solución de Problemas

**"Comando no encontrado: dj"**
```bash
# Añade a ~/.zprofile o ~/.bash_profile:
export PATH="$HOME/DJProducerTools/bin:$PATH"
```

**"Permiso denegado"**
```bash
chmod +x ~/DJProducerTools/scripts/*.sh
```

**Dependencias faltantes**
```bash
brew install ffmpeg jq curl
```

---

## 📚 Documentation | Documentación

| Language | Quick Start | Full Guide | Features |
|----------|-------------|-----------|----------|
| **English** | [README.md](./README.md) | [GUIDE.md](./GUIDE.md) | [FEATURES.md](./FEATURES.md) |
| **Español** | [README_ES.md](./README_ES.md) | [GUIDE_ES.md](./GUIDE_ES.md) | [FEATURES_ES.md](./FEATURES_ES.md) |

---

## 🔗 Links

- **GitHub**: [Astro1Deep/DjProducerTool](https://github.com/Astro1Deep/DjProducerTool)
- **Issues**: [Report bugs](https://github.com/Astro1Deep/DjProducerTool/issues)
- **Discussions**: [Ask questions](https://github.com/Astro1Deep/DjProducerTool/discussions)

---

**Ready to go?** Start with: `dj` 🎵
