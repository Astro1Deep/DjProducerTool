# DJProducerTools – Manual Extendido (v1.0.0, ES)

## Fundamentos
- Estado: `BASE_PATH/_DJProducerTools/{reports,plans,logs,config,quarantine,venv}`; `HOME_OVERRIDE=/ruta` para aislar; no uses disco del sistema ni root.
- Seguridad: `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE=0`; `--dry-run` fuerza simulación; `confirm_heavy` en acciones pesadas.
- Mínimos: bash, python3, ffprobe, sox, jq. Opcionales: ffmpeg (transcode/keyframes), librosa (BPM/onsets), python-osc, pyserial, onnxruntime, tensorflow.
- Offline: `DJPT_OFFLINE=1` fuerza heurísticos; `DJPT_TF_MOCK=1` evita descargas TF.

## Core (1–12)
- 1 Estado, 2 Cambiar Base, 3 Resumen volumen, 4/5 Top dirs/files.
- 6 Scan workspace -> `reports/workspace_scan.tsv`.
- 7/8 Backups (rsync) de `_Serato_` y metadatos DJ (Safe/Lock/DRY; `confirm_heavy`).
- 9 Índice hash (SHA-256) -> `reports/hash_index.tsv`; 10 Plan duplicados exactos -> `plans/dupes_plan.tsv/json`.
- 11 Aplicar quarantine (reversible); 12 Gestor de quarantine.

**Ejemplo flujo seguro:** 6 → 9 → 10 (revisar TSV) → 11 solo si Safe/Lock=0 y sin DRY.

## Media/Organización (13–24)
- 13 ffprobe corruptos, 14 playlist.m3u8 por carpeta, 15 relink helper, 16 plan género (placeholder).
- 17 Buscar librerías DJ, 18 Rescan inteligente, 19 Diagnóstico herramientas, 20 plan ownership/flags.
- 21/22 instalar/desinstalar comando (dj/dj-en/dj-es), 23/24 toggles Safe/Lock.

## Procesos/Limpieza (25–39)
- 26 Export/Import estado, 27 Snapshot hash rápido, 28 visor de logs, 29 toggle DRY.
- 30 plan organizar por tags / 31 reporte de tags (placeholders).
- 32 Video REPORT (ffprobe) -> `reports/serato_video_report.tsv/json`.
- 33 Video PREP: plan transcode H.264 1080p con códec `auto/videotoolbox/nvenc/libx264`; opcional ejecutar ffmpeg (pregunta; respeta DRY) -> TSV/JSON.
- 34 plan renombrado; 35 samples por tipo; 36–39 limpieza web/whitelist.

**Ejemplo transcode (hw accel):** Menú 33 → códec `auto` → “¿Ejecutar ffmpeg?” Y → con DRYRUN_FORCE=1 solo imprime comandos.

## ML / Deep (40–52, 62–67)
- 40 Análisis inteligente, 41 predictor heurístico, 42 optimizador eficiencia, 43 flujo inteligente, 44 dedupe integrado (placeholder), 45–48 planes org/metadata/backup/sync.
- 49 BPM/onsets: flags `--tempo-min/--tempo-max`, `--max-duration`; salida BPM/conf/key/energy/beat_count/first_beat_sec.
- 50 API/OSC: HTTP `/status,/reports,/dupes/summary,/logs/tail`; OSC `/djpt/ping,/djpt/status`; token Bearer opcional (unauthorized si falta); PID `_DJProducerTools/osc_api_server.pid`.
- 62 ML evolutivo (scikit-learn opt-in), 63 toggle ML, 64 instalar TF.
- 65 TF Lab: modelos `yamnet/musicnn/musictag/clap_onnx/clip_vitb16_onnx/musicgen_tflite/sentence_t5_tflite`; `DJPT_OFFLINE=1` para mocks. Salidas: embeddings/tags/similitud/anomalías/segmentos/loudness/matching/video_tags/music_tags/mastering (TSV). Elige modelo según recursos (TF vs ONNX vs TFLite).
- 66 plan LUFS (objetivo/tolerancia), 67 auto-cues (onsets/librosa).

**Ejemplo TF Lab offline:** `DJPT_OFFLINE=1` + modelo `clap_onnx` en 65.1/65.2 (usa onnxruntime si está, si no mock).
**Ejemplo API con token:** Menú 50 → token `seguro123` → curl con `Authorization: Bearer seguro123`; OSC `/djpt/ping` con token arg devuelve “pong”.

## Submenú V (Visuales/OSC/DMX)
- V1 Ableton .als, V2 inventario visuales (ffprobe), V3 enviar plan DMX (ENTTEC; Safe/Lock/DRY => dry-run; logs), V4/V5 video (igual que 32/33), V6 resolución/duración, V7 visuales por resolución (plan), V8 duplicados visuales, V9 plan optimizar, V10 playlist→OSC, V11 playlist→DMX, V12 presets DMX.

## Opciones ampliadas y ventajas
- Dedupe + cuarentena: SHA-256 exacto; cuarentena reversible; `confirm_heavy` evita ejecutarlo sin querer en discos enormes.
- Backups: rsync incremental de `_Serato_` y metadatos DJ, listo para rollback.
- Video transcode: compatibilidad H.264 1080p; selector de códec con hw accel; ffmpeg opt-in/DRY-aware.
- API/OSC: token ligero en redes compartidas; endpoints mínimos sin exponer datos; OSC devuelve unauthorized si falta token.
- BPM/librosa: límites de tempo/duración equilibran precisión vs rendimiento; beats y primer beat ayudan a cues sin escribir tags.
- ML/TF/ONNX: modelos locales (yamnet/musicnn/musictag/CLAP/CLIP) para similitud/tagging sin subir audio; `DJPT_OFFLINE` asegura fallback; ONNX/TFLite útil en máquinas sin TF/GPU.
- DMX/OSC dry-run: siempre se puede simular; logs permiten validar sin hardware, evitando riesgos en vivo.
- Empaquetado/estado: todo en `BASE_PATH/_DJProducerTools`; `export-ignore` en `docs/internal` evita filtrar material interno; `git archive -o ../DJProducerTools_WAX.zip HEAD` + `djpt_icon.icns`.

---
## Resumen “Wiki Completa” (contenido heredado)
- **Qué es y para quién:** Limpieza/organización de bibliotecas Serato/Rekordbox/Traktor/Ableton (audio/video/DMX), backups seguros, dedupe exacto y planes avanzados, ML opcional local.
- **Archivos principales:** `DJProducerTools_MultiScript_ES.sh` / `_EN.sh`; `install_djpt.sh` para descarga rápida.
- **Instalación rápida:** snippet `install_djpt.sh` con `curl` (descarga EN/ES y pone +x).
- **Requisitos:** macOS + bash; `python3`; espacio en `_DJProducerTools/`; ML opcional (300–600 MB según paquete).
- **Uso básico:** ejecutar script EN/ES (doble clic mantiene ventana); crea `_DJProducerTools/` en BASE_PATH.
- **Estructura en disco:** config, reports, plans, quarantine, logs, venv dentro de `_DJProducerTools/` (detallado arriba).
- **Seguridad y modos:** Safe/Lock/DRY; confirmaciones; ninguna acción destructiva sin aviso.
- **Menús agrupados:** Core, Media/Org, Procesos/Limpieza, Deep/ML, Extras, Automatizaciones (21 cadenas A/68), submenús L/D/V/H.
- **Cadenas automatizadas:** 21 flujos predefinidos (backup+snapshot, dedup/quarantine, limpieza, show prep, integridad, eficiencia, ML, sync, visuales, etc.).
- **Salidas/planes:** `reports/` (hashes, corruptos, catálogos, playlists, ML), `plans/` (dupes, workflows, sync, integración), `quarantine/`, `logs/`.
- **Notas ML:** instalación opcional; TF sólo si se elige; se puede desactivar ML (63). Venv aislado en `_DJProducerTools/venv`.
- **Buenas prácticas:** hash+plan antes de mover; backup/snapshot previo; excluye cachés/pesados; mirror check (61) para multi-disco.
- **Recursos visuales:** menús SVG/PNG, banners; se pueden enlazar en README/wiki.
- **Licencia:** DJProducerTools License (Atribución + Revenue Share 20%); ver `LICENSE`.
- **Soporte:** Astro One Deep — onedeep1@gmail.com; abrir issues en GitHub.
