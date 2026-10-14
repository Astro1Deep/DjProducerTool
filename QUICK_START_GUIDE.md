# Quick Start Guide - DJProducerTools (v1.3.0)

## Objetivo
Arrancar y operar la suite oficial **DJProducerTools v1.3.0** en macOS con soporte para reconocimiento acústico ShazamIO, servidor MCP para Cerebro OS y ecosistema multi-disco.

---

## Puntos de Entrada Canónicos

| Comando / Script | Descripción |
| :--- | :--- |
| `./bin/djpt` | Lanzador unificado de terminal (menús interactivos, escaneo, análisis y audio IA). |
| `./launch.sh` | Lanzador rápido con auto-detección de entorno virtual y dependencias. |
| `python3 core/mcp_server_fixed.py` | Servidor de protocolo MCP (10 herramientas para Cerebro OS y agentes de IA). |
| `python3 lib/shazam_recognizer.py <audio>` | Reconocedor acústico por terminal con reintentos y fallback FFmpeg. |
| `python3 cli.py --help` | Interfaz de línea de comandos estructurada en Python. |
| `python3 lib/djpt_chat_cli.py` | Asistente conversacional interactivo para producción musical. |

---

## Configuración y Estado del Sistema

- **Configuración Persistente**: `config/ai_model_params.toml`
- **Caché ShazamIO**: `_DJProducerTools/state/shazam_cache.sqlite`
- **Estado y Bases de Datos**: `_DJProducerTools/state/db/djpt.sqlite`
- **Planes de Desduplicación**: `_DJProducerTools/plans/`
- **Reportes de Auditoría**: `_DJProducerTools/reports/`

---

## Comprobación Rápida de Salud (Health Check)

1. **Verificar Estado del Sistema**:
   ```bash
   ./bin/djpt
   ```
   - Opción `70`: Health general de IA y dependencias.
   - Opción `71`: Gestor multi-backend (Ollama, MLX, Whisper, ShazamIO).
   - Opción `74`: Hub centralizado de afinación y rendimiento.

2. **Probar el Servidor MCP para Cerebro OS**:
   ```bash
   python3 -c "import core.mcp_server_fixed as s; print('MCP Server Tools:', len(s.TOOLS))"
   ```
   *(Debe retornar `10` herramientas registradas).*

3. **Probar el Reconocimiento Acústico Resiliente**:
   ```bash
   python3 -c "from lib.shazam_recognizer import recognize_track_sync; print('ShazamIO Engine Listo')"
   ```

4. **Validación de la Suite Completa**:
   ```bash
   bash tests/run_smoke.sh
   ```

---

## Integración con Discos Externos y Cerebro OS

DJProducerTools v1.3.0 interactúa de forma nativa con los discos externos del productor:
- **Realtek RTL9210B Media**: Native Instruments & Reaktor.
- **Samsung PSSDT7**: Ableton Live & Roland SP-404MK2.
- **SanDisk SSD**: Serato DJ Pro & VJ Loops.
- **Akai MPC MicroSD (`/Volumes/MPCSMPL`)**: Base de datos SQLite y expansiones.

Para sincronizar y auditar el ecosistema completo:
```bash
python3 "/Users/ivan/.gemini/antigravity/scratch/sync_master_dashboard.py"
```

---

## Modo Seguro (Safe-First)
- Por defecto, `SAFE_MODE=1` y `DJ_SAFE_LOCK=1` están habilitados para evitar cualquier alteración irreversible en tus colecciones de audio.
- Los duplicados detectados nunca se eliminan automáticamente: se aíslan en una carpeta de cuarentena para tu confirmación explícita.
