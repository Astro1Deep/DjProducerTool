# DJProducerTools – Guía Avanzada (ES)

Versión: 1.0.0 (2024-01-04)  
Alcance: CLI para catálogo/hash, plan de duplicados + quarantine, backups de metadatos DJ y reportes TSV. DMX/Video/OSC/API/ML siguen como placeholders/roadmap (generan planes/reportes, no controlan hardware).

## Seguridad por defecto
- `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE=0`.  
- Estado en `BASE_PATH/_DJProducerTools/{reports,plans,quarantine,logs,config,venv}`.  
- `--dry-run` fuerza modo simulación.  
- Para aislar pruebas: `HOME_OVERRIDE=/ruta ./scripts/DJProducerTools_MultiScript_ES.sh`.

## Menú Core (1–12)
- **1 Estado**: Muestra BASE_PATH, rutas de estado, flags. Solo lectura.  
- **2 Cambiar Base**: Ajusta BASE_PATH y reinicia rutas de estado.  
- **3 Resumen volumen**: `du -sh` + últimos reports.  
- **4 Top carpetas**: Profundidad 2 por tamaño.  
- **5 Top archivos**: Más pesados en la base.  
- **6 Scan workspace**: Listado completo -> `reports/workspace_scan.tsv` (avisa en árboles enormes).  
- **7 Backup Serato**: rsync `_Serato_`/_Backup -> `state/serato_backup` (respeta DRY/Safe).  
- **8 Backup metadatos DJ**: Busca Serato/Traktor/Rekordbox/Ableton -> rsync a `state/dj_metadata_backup`.  
- **9 Índice hash (SHA-256)**: `reports/hash_index.tsv` (hash, rel, full).  
- **10 Plan duplicados exactos**: Usa hash_index -> `plans/dupes_plan.tsv/json` (KEEP/QUARANTINE).  
- **11 Aplicar quarantine**: Mueve QUARANTINE a `quarantine/<hash>/file` si Safe/Lock/DRY lo permiten. Confirmación obligatoria.  
- **12 Quarantine manager**: Listar / restaurar todo / borrar todo (bloqueado por Safe/Lock).

## Media / Organización (13–24)
- **13 ffprobe corruptos**: `media_corrupt.tsv` con archivos que fallan ffprobe.  
- **14 Playlists por carpeta**: `playlist.m3u8` en cada dir (audio).  
- **15 Relink helper**: `relink_helper.tsv` (ruta relativa + completa).  
- **16 Mirror por género (plan)**: `plans/mirror_by_genre.tsv` placeholder (GENRE_UNKNOWN).  
- **17 Buscar librerías DJ**: Lista dirs Serato/Traktor/Rekordbox/Ableton.  
- **18 Rescan inteligente**: TSV de todos los archivos con progreso.  
- **19 Diagnóstico herramientas**: ffprobe/shasum/rsync/find/ls/du.  
- **20 Fix ownership/flags (plan)**: `plans/fix_ownership_flags.tsv` (chown/chmod KEEP).  
- **21 Instalar comando**: Symlink `djproducertool` (bloqueado si Safe).  
- **22 Desinstalar comando**: Quita symlink (bloqueado si Safe).  
- **23 Toggle SAFE_MODE**, **24 Toggle DJ_SAFE_LOCK**: Cambian flags y guardan config.

## Procesos / Limpieza (25–39)
- **25 Ayuda rápida**: Flujos sugeridos.  
- **26 Export/Import estado**: Tar.gz de `_DJProducerTools` (`DJPT_state_bundle.tar.gz`).  
- **27 Snapshot hash rápido**: `reports/snapshot_hash_fast.tsv`.  
- **28 Visor de logs**: Lista logs del estado.  
- **29 Toggle DRYRUN_FORCE**: Cambia flag global de simulación.  
- **30 Plan organizar por tags**: `plans/organize_by_tags.tsv` (placeholder).  
- **31 Reporte de tags**: TSV de géneros (placeholder).  
- **32/33 Serato Video**: Reporte + plan de transcode (placeholders, no transcodifica).  
- **34 Normalizar nombres (plan)**: TSV de renombrado.  
- **35 Samples por tipo (plan)**: TSV agrupado por extensión/tipo.  
- **36 Web clean submenu**: Herramientas URL en playlists/tags.  
- **37 Web whitelist manager**: Gestiona dominios permitidos.  
- **38 Limpiar web en playlists**: Quita URLs en `.m3u/.m3u8` -> plan.  
- **39 Limpiar web en tags**: Plan para quitar URLs en tags (sin escribir).

## Deep / ML (40–52, 62–67)
Estado: planes/heurísticas; venv opcional en `state/venv`.  
- **40 Análisis inteligente**: JSON resumen (conteos y recomendaciones).  
- **41 Predictor ML**: TSV heurístico (nombres largos, tamaño cero).  
- **42 Optimizador eficiencia**: Checklist (duplicados, tags, backup, snapshot).  
- **43 Flujo inteligente**: Secuencia recomendada.  
- **44 Deduplicación integrada**: Resumen exactos/fuzzy (placeholder).  
- **45–48**: Planes de organización, armonía metadata, backup predictivo, sync multiplataforma.  
- **49**: Audio BPM (tags/librosa) -> TSV (`lib/bpm_analyzer.py`).  
- **50**: API/OSC server start/stop (`lib/osc_api_server.py`, HTTP /status,/reports; OSC /djpt/ping). PID en `_DJProducerTools/osc_api_server.pid`.  
- **51–52**: Planes de recomendaciones/pipeline.  
- **62 ML evolutivo**: Opción de instalar scikit-learn; entrena con tus planes y predice sospechosos.  
- **63 Toggle ML**: Desactiva/activa ML global.  
- **64 TensorFlow**: Instala TF opcional (descarga).  
- **65 TensorFlow Lab**: Auto-tagging/similitud/anomalías/segmentos (TF si disponible; fallback offline).  
- **66 Plan LUFS**: Análisis de loudness (requiere python3+pyloudnorm+soundfile).  
- **67 Auto-cues**: Plan de cues por onsets (requiere python3+librosa).

## Extras / Utilidades (53–67)
- **53 Reset estado**: Borra `_DJProducerTools` (bloqueado por Safe/Lock).  
- **54 Gestor de perfiles**: Guarda/carga perfiles de rutas BASE/GENERAL/AUDIO.  
- **55 Ableton Tools**: Reporte rápido de `.als` (samples/plugins).  
- **56 Importers cues**: Placeholders Rekordbox/Traktor -> TSV.  
- **57 Gestor de exclusiones**: Maneja patrones de exclusión.  
- **58 Comparar hash_index**: Diff entre dos índices sin rehash.  
- **59 Health-check estado**: Tamaños/quarantine/logs, hints de limpieza.  
- **60 Export/Import config**: Solo configuración/perfiles.  
- **61 Mirror integrity check**: Compara hash_index para detectar faltantes/corrupción.

## Submenú L (Librerías DJ & Cues)
- **L1** Configurar AUDIO/GENERAL/REKORDBOX_XML/ABLETON (se guarda en config).  
- **L2** Catálogo de audio por ID -> `reports/catalog_audio_<ID>.tsv`.  
- **L3** Plan de duplicados por basename+tamaño entre catálogos -> `plans/audio_dupes_from_catalog.tsv`.  
- **L4** Cues Rekordbox -> `reports/dj_cues.tsv` (placeholder).  
- **L5** dj_cues -> `ableton_locators.csv` (placeholder).

## Submenú D (Duplicados generales)
- **D1** Catálogo general (respeta excluidos/profundidad) -> `reports/general_catalog.tsv`.  
- **D2** Duplicados por basename+tamaño -> `plans/general_dupes_plan.tsv`.  
- **D3** Reporte inteligente de duplicados (conteos/top claves).  
- **D4** Plan de consolidación multi-disco (añadir faltantes al destino).  
- **D5** Plan de duplicados exactos por hash entre raíces (coma).  
- **D6** Consolidación inversa: sobrantes en orígenes vs destino.  
- **D7** Matrioshkas: carpetas duplicadas por estructura (KEEP/REMOVE).  
- **D8** Carpetas espejo por contenido (nombre+tamaño o hash completo).  
- **D9** Similitud audio (requiere TF/YAMNet; plan).

## Submenú V (Visuales / DAW / OSC / DMX)
Estado: planes con tiempos y envío DMX opcional (dry-run por defecto).  
- **V1** Reporte rápido de `.als` (samples/plugins).  
- **V2** Inventario de visuales (ffprobe) -> TSV.  
- **V3** Enviar plan DMX vía ENTTEC DMX USB Pro (SAFE/LOCK/DRY → solo dry-run).  
- **V4/V5** Serato Video: inventario + plan transcode sugerido (H.264 1080p).  
- **V6** Reporte resolución/duración (ffprobe).  
- **V7** Plan organizar visuales por resolución.  
- **V8** Duplicados exactos de visuales (hash).  
- **V9** Plan optimización (sugerir H.264 1080p).  
- **V10** Plan OSC desde playlist (`.m3u/.m3u8`) con tiempos (duraciones ffprobe).  
- **V11** Plan DMX desde playlist (Intro/Drop/Outro temporizado, mapa de canales editable).  
- **V12** Plantilla de presets DMX (editar canales/valores).

## Rutas clave
- Reports: `BASE_PATH/_DJProducerTools/reports`  
- Plans: `BASE_PATH/_DJProducerTools/plans`  
- Quarantine: `BASE_PATH/_DJProducerTools/quarantine`  
- Logs: `BASE_PATH/_DJProducerTools/logs`  
- Config: `BASE_PATH/_DJProducerTools/config/djpt.conf`  
- Venv ML: `BASE_PATH/_DJProducerTools/venv` (opcional)

## Flujos seguros sugeridos
- **Deduplicación segura**: 6 → 9 → 10 (revisar `dupes_plan`) → 11 si Safe/Lock=0 → 12 para restaurar si hace falta.  
- **Backup + integridad**: 7 → 8 → 27 → 3 para validar.  
- **Duplicados multi-disco**: D1 → D2 → D3 (revisar) → D4/D6 planes → 10/11 si se requiere hash exacto.  
- **Visuales**: V2 → V6 → V7/V9 (planes); transcodifica manualmente según el plan.

## TensorFlow Lab (opción 65)
- Requiere TF+tf_hub+soundfile (instala con opción 64). Si no quieres descargas, usa `DJPT_TF_MOCK=1` para modo offline (hash fallback).
- Modelos soportados: `yamnet` (por defecto), `musicnn`, `musictag` (nnfp). Selecciona en 65.1/65.2.
- Salidas:
  - `reports/audio_embeddings.tsv` / `reports/audio_tags.tsv`
- `reports/audio_similarity.tsv` (umbral 0.60, top 200)
- `reports/audio_anomalies.tsv` (silencio/clipping)
- `reports/audio_segments.tsv` (onsets/segmentos)
- Tips: limita ~150 archivos; usa `DJPT_TF_MOCK=1` en CI/offline; limpia/recachea venv desde 64 si falla.
- Modelos ONNX/TFLite reales: activa el venv (`source _DJProducerTools/venv/bin/activate`), pon `DJPT_OFFLINE=0` y elige `clap_onnx/clip_vitb16_onnx/sentence_t5_tflite` en 65. Se intentará instalar `onnxruntime`; si no está, se usa fallback mock con aviso. En macOS ARM no hay wheel `tflite-runtime`; usa TensorFlow (64) o un entorno con wheel compatible; MusicGen_tflite se mantiene en fallback seguro mientras tanto.

## Por qué estas dependencias y qué ganamos
- **ffprobe/ffmpeg**: integridad de media, inventario de vídeo y keyframes para tagging. Beneficio: detectar corrupción temprano y generar planes de transcode sin tocar archivos.
- **sox/librosa**: BPM/onsets/segmentación sin modificar tags. Beneficio: cues preliminares y tempos consistentes.
- **onnxruntime / tensorflow**: embeddings y tagging locales (yamnet/musicnn/musictag/CLIP/CLAP) sin subir audio. Beneficio: similitud/recomendaciones preservando privacidad.
- **pyloudnorm**: planes de normalización LUFS sin aplicar ganancia. Beneficio: lotes homogéneos listos para masterizar.
- **pyserial/python-osc/fastapi**: DMX/OSC/API locales. Beneficio: control de luces/estado sin exponer servicios externos.
- **Seguridad**: `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE` y `DJPT_OFFLINE` mantienen simulación/heurísticos por defecto; si falta una dependencia, se avisa y se usa fallback, nunca se aborta el flujo.
