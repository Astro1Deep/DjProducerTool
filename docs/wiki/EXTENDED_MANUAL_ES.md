# DJProducerTools – Manual Extendido (ES)

Guía completa de opciones/acciones del multiscript (versión 1.0.0). Úsala como referencia detallada de cada menú.

## Fundamentos
- **Estado y rutas:** `BASE_PATH/_DJProducerTools/{reports,plans,logs,config,quarantine,venv}`. `BASE_PATH` es el cwd al lanzar (no uses disco del sistema). `HOME_OVERRIDE=/ruta` para aislar.
- **Seguridad:** `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE=0`. `--dry-run` fuerza simulación. Confirmaciones para acciones pesadas con `confirm_heavy`.
- **Dependencias mínimas:** `bash`, `python3`, `ffprobe`, `sox`, `jq`. Opcionales: `ffmpeg`, `librosa`, `python-osc`, `pyserial`, `onnxruntime`, `tensorflow`.
- **ML offline:** `DJPT_OFFLINE=1` fuerza heurísticos/mocks; `DJPT_TF_MOCK=1` evita descargas TF.

## Menú Core (1–12)
- **1 Estado:** Muestra BASE/STATE, flags de seguridad, últimos reports/logs. Solo lectura.
- **2 Cambiar Base:** Ajusta `BASE_PATH`, re-inicializa estado (no mueve archivos).
- **3 Resumen volumen:** `du -sh` BASE + listado de reports recientes.
- **4 Top carpetas / 5 Top archivos:** Ranking por tamaño. Solo lectura.
- **6 Scan workspace:** Listado completo -> `reports/workspace_scan.tsv` (avisos en árboles grandes).
- **7 Backup Serato / 8 Backup metadatos DJ:** rsync de `_Serato_` y otras libs a `state/serato_backup` y `state/dj_metadata_backup` (respeta Safe/Lock/DRY). Usa `confirm_heavy`.
- **9 Hash index (SHA-256):** `reports/hash_index.tsv`. Pesado en grandes colecciones (confirmación).
- **10 Plan duplicados exactos:** Usa hash_index -> `plans/dupes_plan.tsv/json` (KEEP/QUARANTINE).
- **11 Aplicar quarantine:** Mueve entradas QUARANTINE a `quarantine/<hash>/file` si Safe/Lock permiten. Confirmación obligatoria.
- **12 Gestor de quarantine:** Listar / restaurar todo / borrar todo (bloqueado por Safe/Lock).

## Media / Organización (13–24)
- **13 ffprobe corruptos:** `media_corrupt.tsv` con archivos que fallan ffprobe.
- **14 Playlists por carpeta:** `playlist.m3u8` en cada dir de audio.
- **15 Relink helper:** `relink_helper.tsv` (ruta relativa + completa).
- **16 Mirror por género (plan):** Placeholder `plans/mirror_by_genre.tsv`.
- **17 Buscar librerías DJ:** Detecta dirs Serato/Traktor/Rekordbox/Ableton.
- **18 Rescan inteligente:** TSV completo con progreso.
- **19 Diagnóstico herramientas:** Presencia de ffprobe/shasum/rsync/find/ls/du.
- **20 Fix ownership/flags (plan):** `plans/fix_ownership_flags.tsv` (chown/chmod sugerido).
- **21/22 Instalar/Desinstalar comando:** symlink `dj`, `dj-en`, `dj-es` (bloqueado si Safe).
- **23 Toggle SAFE_MODE / 24 Toggle DJ_SAFE_LOCK:** Cambian flags y guardan config.

## Procesos / Limpieza (25–39)
- **25 Ayuda rápida:** Flujos recomendados.
- **26 Export/Import estado:** `DJPT_state_bundle.tar.gz` (solo estado).
- **27 Snapshot hash rápido:** `reports/snapshot_hash_fast.tsv`.
- **28 Visor de logs:** Lista logs en estado.
- **29 Toggle DRYRUN_FORCE:** Activa/Desactiva simulación global.
- **30 Plan organizar por tags / 31 Reporte de tags:** Placeholders (GENRE_UNKNOWN).
- **32 Serato Video REPORT:** ffprobe inventario -> `reports/serato_video_report.tsv/json`.
- **33 Serato Video PREP:** Plan de transcode H.264 1080p -> `plans/serato_video_transcode_plan.tsv/json`; pregunta si ejecutar ffmpeg (respeta DRY y confirmación).
- **34 Normalizar nombres (plan):** TSV de renombrado.
- **35 Samples por tipo (plan):** Clasifica kicks/snares/hats/bass.
- **36–39 Web clean:** Limpieza de URLs en playlists/tags y whitelist de dominios.

## ML / Deep (40–52, 62–67)
- **40 Análisis inteligente:** JSON resumen de conteos/recs.
- **41 Predictor ML:** Heurístico (nombres largos, tamaño cero).
- **42 Optimizador eficiencia:** Checklist (duplicados, tags, backup, snapshot).
- **43 Flujo inteligente:** Secuencia sugerida.
- **44 Deduplicación integrada:** Resumen exactos/fuzzy (placeholder).
- **45–48** Planes de organización/metadata/backup predictivo/sync cross-platform.
- **49 BPM/onsets:** `lib/bpm_analyzer.py` -> TSV con BPM, confianza, key, energía, beat_count, first_beat_sec; flags `--max-duration`, `--tempo-min/max`.
- **50 API/OSC server:** HTTP `/status,/reports,/dupes/summary,/logs/tail`; OSC `/djpt/ping,/djpt/status`; soporta Bearer token; pid en `_DJProducerTools/osc_api_server.pid`.
- **51–52** Planes de recomendaciones/pipeline (placeholders).
- **62 ML evolutivo:** Opción scikit-learn; entrena con planes de duplicados.
- **63 Toggle ML:** Desactiva/activa ML global.
- **64 TensorFlow:** Instala TF opcional (descarga).
- **65 TensorFlow Lab:** Auto-tagging/similitud/anomalías/segmentos. Selector de modelo (yamnet/musicnn/musictag/clap_onnx/clip_vitb16_onnx/musicgen_tflite/sentence_t5_tflite). `DJPT_OFFLINE` para mocks; usa onnxruntime/tflite si está. Salidas: `audio_embeddings.tsv`, `audio_tags.tsv`, `audio_similarity.tsv`, `audio_anomalies.tsv`, `audio_segments.tsv`, `audio_loudness.tsv`, `audio_matching.tsv`, `video_tags.tsv`, `music_tags.tsv`, `audio_mastering.tsv`.
- **66 Plan LUFS:** Análisis de loudness (pyloudnorm+soundfile opcional) con objetivo/tolerancia.
- **67 Auto-cues:** Onsets/segmentos (librosa si está).

## Visuales / DAW / OSC / DMX (submenú V)
- **V1 Ableton `.als`:** Reporte rápido (samples/plugins).
- **V2 Inventario de visuales:** ffprobe -> TSV/JSON.
- **V3 Enviar plan DMX:** ENTTEC DMX USB Pro; respeta Safe/Lock/DRY; logs DMX en `logs/dmx_*.log`.
- **V4/V5 Serato Video:** Inventario + plan transcode (igual que 32/33).
- **V6 Resolución/duración:** ffprobe -> TSV.
- **V7 Organizar visuales por resolución (plan).**
- **V8 Duplicados exactos de visuales (hash).**
- **V9 Plan optimización (sugerir H.264 1080p).**
- **V10 OSC plan desde playlist:** `.m3u/.m3u8` con tiempos (ffprobe duraciones).
- **V11 DMX plan desde playlist:** Intro/Drop/Outro temporizado, CH map editable.
- **V12 Plantilla de presets DMX:** JSON editable.

## TF Lab (65) – flujo recomendado
1) Instala deps (opción 64) o usa `onnxruntime`/`tflite` ya instalados.  
2) En 65.1/65.2 elige modelo; `DJPT_OFFLINE=1` para mocks, `DJPT_OFFLINE=0` para reales.  
3) Revisa salidas en `reports/` y planes en `plans/`.  
4) Usa `--offline` o token en API/OSC si expones remotamente.

## Empaquetado y limpieza
- Paquete limpio: `git archive -o ../DJProducerTools_WAX.zip HEAD` e incluye `djpt_icon.icns`.  
- `docs/internal/` está marcado como `export-ignore` (material de colaboradores).  
- No ejecutes como root ni apuntes `BASE_PATH` a disco del sistema. Confirma operaciones grandes con `confirm_heavy`.  
- Revisa exclusiones por defecto antes de escanear discos con mucho media.
