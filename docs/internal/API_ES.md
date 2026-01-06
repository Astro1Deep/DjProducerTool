# Documentación API - DJProducerTools

## Índice

- [Introducción](#introducción)
- [Autenticación](#autenticación)
- [Endpoints Principales](#endpoints-principales)
- [Formatos de Datos](#formatos-de-datos)
- [Códigos de Error](#códigos-de-error)

---

## Introducción

API RESTful y OSC para integrarse con DJProducerTools.

### Puertos por Defecto

```
HTTP API: 8000
OSC Input: 9000
OSC Output: 9001
```

---

## Autenticación

No se requiere autenticación para uso local.

Para uso remoto:

```bash
export DJPT_API_TOKEN=tu_token_aqui
curl -H "Authorization: Bearer $DJPT_API_TOKEN" http://localhost:8000/api/status
```

---

## Endpoints Principales

### Análisis de Audio

**POST** `/api/analyze`

```json
{
  "file": "/ruta/a/audio.mp3",
  "options": {
    "precision": "high",
    "include_spectrum": true
  }
}
```

**Respuesta**:

```json
{
  "bpm": 120.5,
  "key": "Am",
  "energy": 7.5,
  "spectrum": [...]
}
```

### Control DMX

**POST** `/api/dmx/set`

```json
{
  "universe": 1,
  "channel": 1,
  "value": 255
}
```

### OSC

**Mensajes disponibles**:

```
/djpt/bpm → Obtiene BPM actual
/djpt/spectrum → Espectro en tiempo real
/djpt/key → Tonalidad detectada
/djpt/energy → Energía (0-10)
/djpt/dmx/strobe → Activa estroboscopio
/djpt/dmx/color r g b → Establece color RGB
/djpt/sync/serato → Sincroniza con Serato
```

---

## Formatos de Datos

### Audio

Formatos soportados:
- MP3, WAV, AIFF
- FLAC, OGG, M4A
- Mono y estéreo
- 8-48 kHz (recomendado 44.1/48 kHz)

### Espectro

```json
{
  "bins": 2048,
  "frequencies": [20, 50, 100, ...],
  "magnitudes": [0.1, 0.5, 0.8, ...]
}
```

---

## Códigos de Error

| Código | Significado | Solución |
| --- | --- | --- |
| 200 | OK | Éxito |
| 400 | Bad Request | Verifica parámetros |
| 404 | Not Found | Archivo no existe |
| 500 | Server Error | Reinicia servicio |

---

**Versión API**: 2.0
