# Guía Completa de DJProducerTools

## Índice

- [Introducción](#introducción)
- [Requisitos del Sistema](#requisitos-del-sistema)
- [Instalación](#instalación)
- [Primeros Pasos](#primeros-pasos)
- [Opciones Principales](#opciones-principales)
- [Características Avanzadas](#características-avanzadas)
- [Solución de Problemas](#solución-de-problemas)
- [Preguntas Frecuentes](#preguntas-frecuentes)

---

## Introducción

**DJProducerTools** es una suite completa de herramientas profesionales diseñadas para productores y DJs. Proporciona funcionalidades avanzadas para:

- ✅ Gestión de bibliotecas de audio
- ✅ Análisis BPM profesional
- ✅ Control DMX para luces y efectos
- ✅ Integración OSC (Open Sound Control)
- ✅ Sincronización de vídeo Serato
- ✅ Visualización avanzada
- ✅ Detección automática de características de audio

---

## Requisitos del Sistema

### Mínimos

- **macOS**: 10.14 o superior
- **Memoria RAM**: 4GB (recomendado 8GB+)
- **Espacio en disco**: 500MB libres mínimo
- **Procesador**: Intel Core i5 o equivalente

### Recomendados

- **macOS**: 12.0 o superior
- **RAM**: 16GB+
- **Almacenamiento**: SSD con 2GB+ libres
- **Procesador**: Intel Core i7 o Apple Silicon (M1/M2+)

### Dependencias

```bash
brew install ffmpeg libsndfile sox imagemagick
```

---

## Instalación

### Método 1: Instalación Rápida

```bash
curl -fsSL https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/install_djpt.sh | bash
```

### Método 2: Instalación Manual

1. Clona el repositorio:
```bash
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool
```

2. Haz el script ejecutable:
```bash
chmod +x DJProducerTools_MultiScript_ES.sh
```

3. Ejecuta la instalación:
```bash
./DJProducerTools_MultiScript_ES.sh
```

### Método 3: Como Aplicación Instalada

```bash
./DJProducerTools_MultiScript_ES.sh
# Selecciona opción: Instalación > Instalar como Aplicación
```

---

## Primeros Pasos

### Inicio Básico

```bash
./DJProducerTools_MultiScript_ES.sh
```

Esto abre un menú interactivo con:

- 📊 Panel de análisis
- 🎵 Gestión de bibliotecas
- 🎚️ Control de funciones
- ⚙️ Configuración avanzada

### Tu Primer Análisis

1. **Selecciona**: Análisis de Música (Opción A)
2. **Ingresa**: Ruta de tu archivo de audio
3. **Espera**: El sistema analiza BPM, tonalidad, energía
4. **Visualiza**: Resultados detallados con gráficos

---

## Opciones Principales

### A - Análisis de Música

Analiza archivos de audio en profundidad:

- 🔍 Detección BPM (±2 BPM de precisión)
- 🎼 Análisis de tonalidad
- 📈 Energía y dinámica
- 🎵 Características espectrales
- 🌐 Compatibilidad Camelot Wheel

**Uso:**
```bash
./DJProducerTools_MultiScript_ES.sh
# Opción: A (Análisis)
# Ingresa ruta: /ruta/a/cancion.mp3
```

### L/D - Librerías y Duplicados

**Librerías (L)**:
- Organiza canciones por BPM
- Crea playlists inteligentes
- Deduplica por contenido hash
- Exporta metadatos

**Duplicados (D)**:
- Encuentra canciones duplicadas
- Análisis acústico
- Comparación visual
- Fusión segura

### V/H - Visualización Avanzada

**Visualización (V)**:
- Espectrograma en tiempo real
- Forma de onda 3D
- Análisis de frecuencias
- Exportación de gráficos

**Ayuda Detallada (H)**:
- Documentación completa
- Ejemplos paso a paso
- Solución de problemas
- Contacto de soporte

---

## Características Avanzadas

### Control DMX - Luces y Efectos

Controla iluminación profesional sincronizada con audio:

```
Tipo de Control:
├── PAR LED (RGB/RGBA)
├── Moving Heads
├── Strobes y Efectos
├── Dimmers
└── Sistemas Inteligentes
```

**Configuración DMX**:
```bash
# En el menú: Selecciona "DMX Control"
# Configura:
1. Universo DMX (1-4)
2. Direcciones de dispositivos
3. Perfiles de efectos
4. Sincronización BPM
```

### OSC - Control Remoto

Open Sound Control para integración con otros software:

**Puertos por defecto**:
- Entrada: 9000
- Salida: 9001

**Ejemplos OSC**:
```
/djpt/bpm → Obtiene BPM actual
/djpt/spectrum → Espectro en tiempo real
/djpt/effects/strobe → Activa estroboscopio
/djpt/lighting/color 255 0 0 → Rojo
```

### Sincronización Serato Video

Integración completa con Serato DJ Pro:

- Sincronización de pistas
- Control de vídeos
- Sincronización BPM automática
- Marcadores y cue points

**Requisitos**:
- Serato DJ Pro 2.4.0+
- Audio Interface Serato compatible

### Análisis de Características

Detección automática profesional:

| Característica | Descripción | Precisión |
| --- | --- | --- |
| **BPM** | Tempo en latidos por minuto | ±2 BPM |
| **Tonalidad** | Escala musical (Camelot) | 99.2% |
| **Energía** | Intensidad relativa | 1-10 |
| **Dinámica** | Variación temporal | 0-100% |
| **Frecuencias** | Distribución espectral | 20Hz-20kHz |

---

## Solución de Problemas

### Problema: "Archivo no encontrado"

**Solución**:
```bash
# Verifica la ruta
ls -la "/ruta/al/archivo.mp3"

# Usa ruta absoluta
./DJProducerTools_MultiScript_ES.sh
# Ingresa: /Users/usuario/Música/cancion.mp3
```

### Problema: "Análisis muy lento"

**Opciones**:
1. Reduce calidad: Análisis Rápido (60s máximo)
2. Usa archivo más pequeño para pruebas
3. Cierra otras aplicaciones
4. Aumenta RAM disponible

### Problema: "Error en DMX"

**Pasos**:
```bash
# 1. Verifica conexión USB
ls -la /dev/tty.* | grep -i usb

# 2. Verifica permisos
sudo chmod 777 /dev/tty.usbserial*

# 3. Reconfigura DMX
# En menú: Opciones > DMX > Reiniciar
```

### Problema: "Serato no sincroniza"

1. Verifica puerto OSC (9000/9001)
2. Firewall: Permite tráfico local
3. Reinicia ambas aplicaciones
4. Comprueba versiones compatibles

---

## Preguntas Frecuentes

### ¿Cuánto espacio requiere el análisis de una pista?

**Respuesta**: ~2-5MB temporal por canción, sin guardar.

### ¿Puedo usar esto sin Serato?

**Respuesta**: ✅ Sí, todas las funciones son independientes.

### ¿Funciona con formatos sin comprimir?

**Respuesta**: ✅ WAV, AIFF, FLAC, MP3, AAC y más.

### ¿Puedo controlar múltiples universos DMX?

**Respuesta**: ✅ Hasta 4 universos simultáneamente (512 canales c/u).

### ¿Qué precisión tiene el análisis BPM?

**Respuesta**: ±2 BPM en la mayoría de géneros. Mejor en tempo estable.

### ¿Cómo integro con mi controlador MIDI?

**Respuesta**: Via OSC custom o scripts AppleScript.

### ¿Hay modo batch para analizar múltiples archivos?

**Respuesta**: ✅ Selecciona carpeta completa en "Análisis Batch".

### ¿Puedo exportar los datos de análisis?

**Respuesta**: ✅ JSON, CSV, XML disponibles en Opciones > Exportar.

---

## Configuración Avanzada

### Archivo de Configuración

Ubicación: `~/.djpt_config`

```bash
[Analysis]
bpm_precision=2
spectrum_bins=2048
analysis_timeout=300

[DMX]
universe_count=1
auto_sync=true

[OSC]
input_port=9000
output_port=9001
local_only=false

[Export]
format=json
include_spectrum=true
```

### Variables de Entorno

```bash
export DJPT_ANALYSIS_CORES=4
export DJPT_DEBUG=true
export DJPT_LOG_LEVEL=info
./DJProducerTools_MultiScript_ES.sh
```

---

## Contacto y Soporte

- 🌐 **GitHub**: https://github.com/Astro1Deep/DjProducerTool
- 📧 **Email**: support@astro1deep.dev
- 💬 **Issues**: GitHub Issues
- 📚 **Wiki**: Documentación completa en línea

---

**Última actualización**: 2025-01-04
**Versión**: 2.0.0
