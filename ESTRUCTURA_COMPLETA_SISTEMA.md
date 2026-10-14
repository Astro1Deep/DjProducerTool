# Estructura Completa Del Sistema - DJProducerTools (v1.3.0)

## Superficie Canónica
- **Lanzador Shell**: `bin/djpt` (gestor unificado con resolución de variables y venv).
- **Lanzador Rápido**: `launch.sh`.
- **CLI Python**: `cli.py` y `lib/djpt_chat_cli.py`.
- **Servidor MCP**: `core/mcp_server_fixed.py` (con wrapper compatible en `mcp_server.py`).
- **Motor Acústico**: `lib/shazam_recognizer.py` (ShazamIO + FFmpeg + SQLite).
- **Configuración IA**: `config/ai_model_params.toml`.
- **Contratos Públicos**: `core/*`.

---

## Capas Principales del Sistema

| Directorio / Archivo | Propósito y Responsabilidad |
| :--- | :--- |
| `bin/djpt` | Punto de entrada CLI estándar para macOS. |
| `core/mcp_server_fixed.py` | Servidor del protocolo MCP con 10 herramientas para Cerebro OS. |
| `lib/shazam_recognizer.py` | Motor de reconocimiento musical resiliente con reintentos y fallback. |
| `lib/*` | Módulos operativos de escaneo, análisis, metadatos y deduplicación. |
| `scripts/DJProducerTools_MultiScript_ES.sh` | Menú interactivo TUI canónico en español. |
| `scripts/DJProducerTools_MultiScript_EN.sh` | Menú interactivo TUI canónico en inglés. |
| `scripts/sync_wiki.sh` | Script de sincronización bidireccional con la GitHub Wiki. |
| `docs/assets/branding/` | Banners SVG dual-cell, portadas editoriales y logos vectoriales. |
| `tests/*` | Suite de tests automatizados (smoke, audio recognition, contratos). |

---

## Estado y Directorios Runtime
- `_DJProducerTools/state/db/djpt.sqlite`: Base de datos SQLite unificada.
- `_DJProducerTools/state/shazam_cache.sqlite`: Caché de huellas acústicas.
- `_DJProducerTools/plans/`: Planes de desduplicación en dos fases.
- `_DJProducerTools/reports/`: Informes técnicos, TSV y auditorías.

---

## Ecosistema Multi-Disco
- `/Volumes/Realtek RTL9210B-CG Media`: Native Instruments & Reaktor.
- `/Volumes/samsung PSSDT7`: Producción, Ableton Live & Roland SP-404MK2.
- `/Volumes/SanDisk SSD`: Serato DJ Pro & VJ Loops.
- `/Volumes/MPCSMPL`: Akai MPC MicroSD (Base de datos SQLite, Expansiones y Catálogo Web).
