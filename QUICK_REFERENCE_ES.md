# Referencia Rápida - DJProducerTools v2.0.0

## 🎯 Atajos Rápidos

### Instalación
```bash
# Método rápido
curl -fsSL https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/install_djpt.sh | bash

# Manual
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool
chmod +x DJProducerTools_MultiScript_ES.sh
./DJProducerTools_MultiScript_ES.sh
```

### Opciones de Menú

| Opción | Función | Uso |
| --- | --- | --- |
| **A** | Análisis de Música | Detecta BPM, tonalidad, energía |
| **L** | Librerías | Organiza por BPM, crea playlists |
| **D** | Duplicados | Encuentra y elimina duplicados |
| **V** | Visualización | Espectrograma, forma de onda |
| **H** | Ayuda Detallada | Documentación completa |

## 🔧 Configuración Rápida

### DMX
```bash
# Menú: Control DMX
# 1. Conecta interfaz USB
# 2. Selecciona universo (1-4)
# 3. Configura canales
# 4. Carga perfil de efectos
```

### OSC
```bash
# Puertos por defecto
Input:  9000
Output: 9001

# Envía comandos
/djpt/bpm → Obtiene BPM
/djpt/spectrum → Espectro
/djpt/dmx/color 255 0 0 → Rojo
```

### Serato Sync
```bash
# Menú: Serato Sync
# 1. Firewall: Permite tráfico local
# 2. Verifica puertos 9000/9001
# 3. Conecta Serato DJ Pro
# 4. Verifica sincronización
```

## 📊 Archivos Importantes

```
DJProducerTools_Project/
├── START_HERE.md              ← Empieza aquí
├── INDEX_ES.md                ← Índice completo
├── GUIDE_ES.md                ← Guía detallada
├── DEBUG_GUIDE_ES.md          ← Solución problemas
├── API_ES.md                  ← Integración
├── DJProducerTools_MultiScript_ES.sh
├── DJProducerTools_MultiScript_EN.sh
└── install_djpt.sh
```

## 🚨 Solución Rápida de Problemas

### "Archivo no encontrado"
```bash
ls -la "/ruta/a/archivo.mp3"  # Verifica path
file archivo.mp3              # Verifica formato
```

### "Análisis muy lento"
```bash
export DJPT_ANALYSIS_CORES=2      # Menos núcleos
export DJPT_SPECTRUM_BINS=512      # Resolución menor
./DJProducerTools_MultiScript_ES.sh
```

### "DMX no funciona"
```bash
ls /dev/tty.usbserial*             # Verifica puerto
sudo chmod 777 /dev/tty.usbserial* # Permisos
# Reinicia en menú
```

### "Serato no sincroniza"
```bash
# Firewall > Preferences > Allow local traffic
# Verifica puertos: 9000, 9001
# Reinicia ambas aplicaciones
```

## 🎯 Comandos Debug

```bash
# Activar modo debug
export DJPT_DEBUG=true
export DJPT_LOG_LEVEL=debug
./DJProducerTools_MultiScript_ES.sh

# Ver logs
tail -f ~/.djpt_logs/djpt_*.log

# Diagnosticar
./DJProducerTools_MultiScript_ES.sh --check-deps

# Reporte
./DJProducerTools_MultiScript_ES.sh --generate-report
```

## 💾 Variables de Entorno

```bash
DJPT_DEBUG=true                    # Modo debug
DJPT_LOG_LEVEL=debug/info/warning  # Nivel de logs
DJPT_ANALYSIS_CORES=4              # Núcleos para análisis
DJPT_ANALYSIS_TIMEOUT=300          # Timeout en segundos
DJPT_SPECTRUM_BINS=2048            # Resolución FFT
DJPT_API_TOKEN=token               # Token autenticación
```

## 📡 Puertos Configurables

```bash
HTTP API:        8000    # REST API
OSC Input:       9000    # Recibir comandos
OSC Output:      9001    # Enviar datos
DMX:             N/A     # Via USB (configurable)
Serato Network:  Local   # Firewall: Allow
```

## 📚 Documentación Rápida

| Necesidad | Archivo |
| --- | --- |
| Empezar | START_HERE.md |
| Guía completa | GUIDE_ES.md |
| API/Programación | API_ES.md |
| Problemas | DEBUG_GUIDE_ES.md |
| Roadmap | BILINGUAL_SETUP_SUMMARY.md |

## 🎛️ Formatos Soportados

**Audio**: MP3, WAV, AIFF, FLAC, OGG, M4A  
**Vídeo**: MP4, MOV, MKV (con H.264)  
**Exportación**: JSON, CSV, XML  
**Configuración**: ~/.djpt_config

## 🔐 Seguridad

```bash
# Firewall macOS
System Preferences → Security & Privacy → Firewall

# Permitir puertos
sudo /usr/libexec/ApplicationFirewall/socketfilterfw \
  --setglobalstate off  # O configura excepciones
```

## ✨ Tips Profesionales

1. **Análisis Batch**: Selecciona carpeta completa en menú Análisis
2. **Duplicados**: Usa hash acústico para máxima precisión
3. **DMX**: Comienza con modo "Simple" antes de "Advanced"
4. **Serato**: Sincroniza BPM antes de añadir vídeos
5. **OSC**: Prueba con herramientas como `oscdump`/`oscsend`

## 📞 Soporte Rápido

| Problema | Comando |
| --- | --- |
| Check deps | `./DJProducerTools_MultiScript_ES.sh --check-deps` |
| Version | `head -20 DJProducerTools_MultiScript_ES.sh` |
| Logs | `tail -f ~/.djpt_logs/djpt_*.log` |
| Config | `cat ~/.djpt_config` |
| Help | `./DJProducerTools_MultiScript_ES.sh --help` |

---

**Versión**: 2.0.0  
**Última Actualización**: 2025-01-04  
**Mantén esta guía a mano para referencia rápida**
