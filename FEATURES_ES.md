# DJProducerTools - Resumen de Funcionalidades y Capacidades (v1.3.0)

DJProducerTools es una suite ecléctica y profesional de ingeniería de audio para macOS, diseñada para DJs, productores de música electrónica y diseñadores de sonido que gestionan librerías multi-terabyte a través de discos externos y hardware standalone.

---

## ⚡ 1. Motor Acústico Resiliente ShazamIO
- **Huella Acústica de Alta Precisión**: Identificación asíncrona de canciones, remixes y artistas mediante el motor acústico oficial ShazamIO.
- **Backoff Exponencial y Jitter**: Mecanismo inteligente de reintentos en red para tolerar límites de tasa (rate limits) y micro-cortes de conexión.
- **Fallback Automático con FFmpeg**: Transcodificación y normalización transparente (extracción de fragmentos limpios PCM a 16-bit 44.1kHz) para archivos de audio exóticos, dañados o en punto flotante de 24/32 bits que los motores estándar rechazan.
- **Caché Persistente SQLite**: Almacena las firmas acústicas en `_DJProducerTools/state/shazam_cache.sqlite` evitando peticiones duplicadas y acelerando las consultas masivas.

---

## 🧠 2. Integración con Cerebro OS y Servidor MCP
- **Servidor Canónico MCP (Model Context Protocol)** (`core/mcp_server_fixed.py`):
  - Interfaz estándar JSON-RPC que expone 10 herramientas profesionales de audio para agentes de IA:
    1. `djpt_system_status`: Telemetría completa del sistema y hardware.
    2. `djpt_scan_library`: Escaneo recursivo por streaming para colecciones masivas.
    3. `djpt_query_library`: Búsqueda profunda en la base de datos SQLite.
    4. `djpt_audit_disks`: Verificación de integridad y espacio multi-disco.
    5. `djpt_recognize_audio`: Reconocimiento acústico resiliente vía ShazamIO.
    6. `djpt_deduplicate_plan`: Planificación de desduplicación segura en 2 fases.
    7. `djpt_export_playlist`: Generador de listas en múltiples formatos (M3U, TSV, XML).
    8. `djpt_ai_health`: Diagnóstico del motor de IA y modelos locales.
    9. `djpt_mpc_sync`: Enlace con hardware Akai MPC y Roland SP-404MK2.
    10. `djpt_clean_metadata`: Limpieza de archivos fantasma AppleDouble (`._*`) y `.DS_Store`.
- **Compatibilidad Dual Nativa**: Funciona tanto con la librería oficial `mcp` instalada como mediante el protocolo estándar stdio JSON-RPC en Python puro sin dependencias externas.

---

## 💾 3. Arquitectura Multi-Disco y Hardware Autónomo
- **Gestión Multi-Volumen Nativa**: Optimizado para el ecosistema de discos del productor:
  - **Realtek RTL9210B Media**: Librerías de Native Instruments Kontakt y Reaktor.
  - **Samsung PSSDT7**: Proyectos de Ableton Live, master samples y tarjeta de Roland SP-404MK2.
  - **SanDisk SSD**: Crates de Serato DJ Pro, historial, puntos CUE y loops de vídeo para VJ.
  - **Akai MPC MicroSD (`/Volumes/MPCSMPL`)**: Base de datos SQLite standalone, expansiones y auditoría de proyectos `.xpj`.
- **Cero Archivos Fantasma**: Purgado automático de metadatos de macOS (`._*`) garantizando que los navegadores de pantalla de la MPC y SP-404 no muestren archivos corruptos.

---

## 🛡️ 4. Seguridad Garantizada y Desduplicación
- **Motor Safe-Mode**: Variables `SAFE_MODE=1` y `DJ_SAFE_LOCK=1` activadas por defecto para impedir pérdidas accidentales de pistas.
- **Desduplicación en Dos Etapas**: Primero genera un plan de diferencias aislado; jamás borra directamente, aislando los duplicados en cuarentena.
- **Blindaje de Metadatos de Serato**: Copias de seguridad automáticas de subcarpetas `_Serato_`, beatgrids y estructuras de crates antes de cualquier sincronización.

---

## 🔬 5. Laboratorio de IA Local y Machine Learning
- **Embeddings de Audio Locales**: Similitud acústica rápida, detección de anomalías, segmentación y normalización de sonoridad (LUFS).
- **Etiquetado Multimodal con IA**:
  - `music_tags`: Clasificación acústica de género y vibra (CLAP / MusicGen).
  - `video_tags`: Etiquetado semántico de vídeo (CLIP) para sets visuales de DJ/VJ.
- **100% Local y Privado**: Optimizado para el Neural Engine y GPU de Apple Silicon (M4 Pro / M-series) sin enviar tu música a la nube.

---

## 🌐 6. Catálogos Visuales y Streaming Web
- **Explorador Interactivo HTML5**: Catálogo web con búsqueda instantánea, filtrado musical por Key/Camelot/BPM y pre-escucha sin restricciones locales mediante el servidor de streaming RFC 7233 Range (`serve_mpc.py`).
- **Diseño Editorial Premium**: Banners vectoriales de alta definición con las identidades oficiales de **Astro1Deep** y **WaxSpaceship**.
