# Manual de Depuración - DJProducerTools

## Índice

- [Introducción](#introducción)
- [Modo de Depuración](#modo-de-depuración)
- [Tabla de Diagnóstico](#tabla-de-diagnóstico)
- [Solución de Problemas Específicos](#solución-de-problemas-específicos)
- [Logs y Reportes](#logs-y-reportes)

---

## Introducción

Este manual proporciona herramientas profesionales para diagnosticar y resolver problemas en DJProducerTools.

---

## Modo de Depuración

### Activar Modo Debug

```bash
export DJPT_DEBUG=true
export DJPT_LOG_LEVEL=debug
./DJProducerTools_MultiScript_ES.sh
```

### Niveles de Depuración

| Nivel | Información | Uso |
| --- | --- | --- |
| **error** | Solo errores | Producción |
| **warning** | Advertencias + errores | Normal |
| **info** | Información general | Desarrollo |
| **debug** | Detalles completos | Diagnóstico |
| **trace** | Cada operación | Investigación profunda |

---

## Tabla de Diagnóstico

### Análisis de Audio

| Síntoma | Causa Probable | Solución |
| --- | --- | --- |
| Análisis no inicia | Archivo corrupto | Verifica: `file -b audio.mp3` |
| BPM incorrecto | Tempo variable | Usa análisis de fase mejorada |
| Sin espectro | FFT fallida | Reinstala libsndfile |
| Timeout en análisis | Archivo muy grande | Reduce resolución espectral |

### Control DMX

| Síntoma | Causa Probable | Solución |
| --- | --- | --- |
| Dispositivos no detectados | Puerto USB incorrecto | Verifica: `ls /dev/tty.usbserial*` |
| Canales bloqueados | Permisos insuficientes | `sudo chmod 777 /dev/tty.usbserial*` |
| Sin respuesta | Interfaz defectuosa | Reinicia dispositivo |
| Flickering | Conflicto de protocolo | Ajusta velocidad baud |

### Serato Sync

| Síntoma | Causa Probable | Solución |
| --- | --- | --- |
| No conecta | Puertos OSC cerrados | Verifica firewall local |
| Lag en sync | Latencia red | Aumenta buffer size |
| BPM no actualiza | Serato muted | Activa pista en Serato |
| Vídeo fuera de sync | Codec incompatible | Convierte a H.264 |

---

## Solución de Problemas Específicos

### Error: "No se puede abrir el archivo"

```bash
# Diagnóstico
file /ruta/a/archivo.mp3
hexdump -C /ruta/a/archivo.mp3 | head

# Soluciones
# 1. Convierte el archivo
ffmpeg -i archivo.mp3 -codec:a libmp3lame -b:a 320k archivo_nuevo.mp3

# 2. Verifica permisos
chmod +r /ruta/a/archivo.mp3
```

### Error: "Timeout en análisis"

```bash
# Opción 1: Modo rápido
./DJProducerTools_MultiScript_ES.sh
# Selecciona: Análisis > Modo Rápido

# Opción 2: Aumenta timeout
export DJPT_ANALYSIS_TIMEOUT=600  # 10 minutos
./DJProducerTools_MultiScript_ES.sh

# Opción 3: Procesa en paralelo
for archivo in *.mp3; do
  ./DJProducerTools_MultiScript_ES.sh --analyze "$archivo" &
done
wait
```

### Error: "Memoria insuficiente"

```bash
# Reduce núcleos de procesamiento
export DJPT_ANALYSIS_CORES=2
./DJProducerTools_MultiScript_ES.sh

# O reduce resolución
export DJPT_SPECTRUM_BINS=512  # Default: 2048
./DJProducerTools_MultiScript_ES.sh
```

### Problema: DMX sin respuesta

```bash
# Paso 1: Verifica conexión física
system_profiler SPUSBDataType | grep -i "FTDI\|Serial"

# Paso 2: Configura permisos
sudo chown $USER /dev/tty.usbserial*
chmod 644 /dev/tty.usbserial*

# Paso 3: Reinicia interfaz
./DJProducerTools_MultiScript_ES.sh
# Selecciona: Control DMX > Diagnosticar > Reiniciar
```

---

## Logs y Reportes

### Ubicación de Logs

```bash
# Logs del sistema
~/.djpt_logs/

# Ver logs recientes
tail -f ~/.djpt_logs/djpt_$(date +%Y%m%d).log

# Buscar errores
grep "ERROR\|WARN" ~/.djpt_logs/*.log
```

### Generar Reporte de Diagnóstico

```bash
# Script automático
./DJProducerTools_MultiScript_ES.sh
# Selecciona: Ayuda > Diagnosticar > Generar Reporte

# O manual
{
  echo "=== Sistema ==="
  uname -a
  echo "=== Versión Script ==="
  head -20 DJProducerTools_MultiScript_ES.sh | grep VERSION
  echo "=== Dependencias ==="
  which ffmpeg sox sox imagemagick
  echo "=== Últimos Errores ==="
  grep ERROR ~/.djpt_logs/djpt_*.log | tail -20
} > djpt_diagnostico.txt
```

### Enviar Reporte

```bash
# Preparar archivo
tar czf djpt_debug_$(date +%s).tar.gz \
  ~/.djpt_logs/ \
  djpt_diagnostico.txt \
  ~/.djpt_config

# Enviar a soporte
# Email: support@astro1deep.dev
# Asunto: [DEBUG] DJProducerTools - Descripción del problema
```

---

## Herramientas de Depuración

### Verificar Dependencias

```bash
# Script de verificación
./DJProducerTools_MultiScript_ES.sh --check-deps

# O manual
for cmd in ffmpeg sox flac imagemagick; do
  if command -v $cmd &> /dev/null; then
    echo "✓ $cmd: $(which $cmd)"
  else
    echo "✗ Falta: $cmd"
  fi
done
```

### Prueba de Análisis de Audio

```bash
# Prueba BPM detection
sox test_audio.mp3 -t raw | \
  ffmpeg -f s16le -ar 44100 -ac 1 -i - -f wav - | \
  ./analyze_bpm.sh

# Prueba espectro
sox test_audio.mp3 -n stat -freq

# Prueba tonalidad
sox test_audio.mp3 -n remix - | ffmpeg -i - -f f32le -
```

### Verificar OSC

```bash
# Instala herramientas
brew install osc-tools

# Prueba recepción
oscdump osc.udp://127.0.0.1:9000

# Envía comando de prueba
oscsend localhost 9000 /djpt/ping s "test"
```

---

**Versión**: 2.0.0  
**Última actualización**: 2025-01-04
