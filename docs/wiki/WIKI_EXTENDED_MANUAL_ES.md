# DJProducerTools – Manual Extendido (v1.0.0, ES)

## Fundamentos
- Estado: `BASE_PATH/_DJProducerTools/{reports,plans,logs,config,quarantine,venv}`; `HOME_OVERRIDE=/ruta` para aislar; no uses disco del sistema ni root.
- Seguridad: `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE=0`; `--dry-run` fuerza simulación; `confirm_heavy` en acciones pesadas.
- Mínimos: bash, python3, ffprobe, sox, jq. Opcionales: ffmpeg (transcode/keyframes), librosa (BPM/onsets), python-osc, pyserial, onnxruntime, tensorflow.
- Offline: `DJPT_OFFLINE=1` fuerza heurísticos; `DJPT_TF_MOCK=1` evita descargas TF.

## Uso rápido por CLI y flags globales
- Ejecutar: `./scripts/DJProducerTools_MultiScript_ES.sh` (o `_EN.sh`). Flags: `--help`, `--version`, `--test`.
- Cambiar base aislada: `HOME_OVERRIDE=/ruta ./scripts/DJProducerTools_MultiScript_ES.sh` (estado en esa carpeta).
- Forzar offline ML: `DJPT_OFFLINE=1 ./scripts/DJProducerTools_MultiScript_ES.sh` (afecta TF Lab).
- Forzar mock TF: `DJPT_TF_MOCK=1` para evitar descargas de TF.
- Seguridad por defecto: `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`; DRY global: `DRYRUN_FORCE=1` (cuando el flujo soporta dry-run).
- Raíces generales: `GENERAL_ROOT=/ruta`; fuentes extra para consolidación: `EXTRA_SOURCE_ROOTS=/Vol/A,/Vol/B`.

## Flujo de seguridad (paso a paso)
1) Verifica `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE=0` (el menú ofrece restaurar 1/1 si estaban en 0).
2) Escanea y cataloga (6, 9, 10) antes de mover nada. Revisa los TSV.
3) Haz backup 7/8 y snapshot 27 antes de cuarentenas o envíos.
4) Sólo aplica movimientos con Safe/Lock desactivados y tras confirmar (11, envíos DMX, etc.).
5) Usa `DJPT_OFFLINE=1` cuando no quieras descargas; `--dry-run` cuando esté disponible.

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

## Duplicados / Consolidación (submenú D)
- D1 Catálogo general (usa `GENERAL_ROOT`), D2 duplicados por nombre+tamaño, D3 reporte inteligente (pistas ML).
- D4 Plan de consolidación multi-disco (destino vs orígenes) → `plans/consolidation_plan.tsv` + helper `consolidation_rsync.sh`.
- D5 duplicados exactos por hash (multirraíz), D6 consolidación inversa (sobrantes en origen), D7 matrioshkas, D8 carpetas espejo por contenido, D9 similitud audio (YAMNet, TF).
- D10 Helpers rsync por lotes: divide `consolidation_plan.tsv` en `consolidation_rsync_batchXX.sh` (50 GB por defecto), usa tamaño real del archivo, omite faltantes con avisos, resume archivos/GB por batch y total; solo genera scripts (Safe/Lock informativos).

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

---
## Detalle opción por opción (extendido)

### Core (1–12)
- 1 Estado: muestra BASE_PATH, SAFE/LOCK/DRY, reportes/logs recientes. Solo lectura.
- 2 Cambiar base: reinit `_DJProducerTools` en nueva BASE_PATH (crea si falta). No mueve media.
- 3 Resumen volumen: `du -sh` en BASE_PATH/estado; lista planes/reportes recientes.
- 4/5 Top dirs/files: ranking por tamaño; solo lectura.
- 6 Escaneo workspace: listado completo -> `reports/workspace_scan.tsv`; usa exclusiones en `config/djpt.conf` para saltar cachés.
- 7/8 Backups: rsync `_Serato_` y metadatos DJ. Respeta Safe/Lock; `confirm_heavy` en ejecuciones grandes; DRY imprime comandos.
- 9 Índice hash: SHA-256 bajo BASE_PATH -> `reports/hash_index.tsv`; puede tardar.
- 10 Plan de duplicados exactos: consume hash_index -> `plans/dupes_plan.tsv/json` con KEEP/QUARANTINE.
- 11 Aplicar quarantine: mueve a `_DJProducerTools/quarantine/<hash>/file`; bloqueado si Safe/Lock=1; confirma antes.
- 12 Gestor de quarantine: listar/restaurar/borrar; Safe/Lock bloquea acciones destructivas.

### Media / Organización (13–24)
- 13 ffprobe corruptos -> `media_corrupt.tsv` (path|error); necesita ffprobe.
- 14 Playlists por carpeta -> `playlist.m3u8` por directorio de audio.
- 15 Relink helper: TSV de rutas relativas/absolutas para DAWs.
- 16 Plan por género: placeholder TSV (sin acciones).
- 17 Detectar librerías DJ: Serato/Traktor/Rekordbox/Ableton.
- 18 Rescan inteligente: TSV con tamaño/mtime/tipo; barra de progreso.
- 19 Diagnóstico de herramientas: presencia de ffprobe/shasum/rsync/find/ls/du.
- 20 Plan ownership/flags: TSV chown/chmod (no aplica cambios).
- 21/22 Symlink cmd: instala/quita `dj`/`dj-en`/`dj-es`; bloqueado por Safe/Lock.
- 23/24 Toggles SAFE_MODE / DJ_SAFE_LOCK (pide confirmación).

### Procesos / Limpieza (25–39)
- 26 Export/Import estado: bundle `DJPT_state_bundle.tar.gz` (config/reportes/planes/logs/quarantine).
- 27 Snapshot hash rápido -> `reports/hash_snapshot.tsv`.
- 28 Visor de logs: tail de `_DJProducerTools/logs/*`.
- 29 Toggle DRYRUN_FORCE (fuerza dry-run cuando aplica).
- 30/31 Plan/reporte de tags: placeholders (solo TSV).
- 32 Reporte video: inventario ffprobe -> TSV/JSON (codec, resolución, duración, bitrate).
- 33 Preparar video: códec `auto/videotoolbox/nvenc/libx264`; plan TSV/JSON, pregunta si correr ffmpeg; respeta DRYRUN_FORCE.
- 34 Plan de renombrado; 35 Samples por tipo; 36–39 Limpieza web/whitelist (TSV).

### Duplicados / Consolidación (D)
- D1 Catálogo general (usa `GENERAL_ROOT`).
- D2 Duplicados por nombre+tamaño -> `general_dupes_plan.tsv/json`.
- D3 Reporte inteligente con pistas ML (texto + TSV).
- D4 Consolidación multi-disco: destino vs orígenes, genera `consolidation_plan.tsv` + `consolidation_rsync.sh` (solo plan).
- D5 Duplicados exactos por hash (multirraíz, profundidad/tamaño máximo opcional + exclusiones).
- D6 Consolidación inversa: marca sobrantes en orígenes ya presentes en destino (umbral de tamaño opcional).
- D7 Matrioshkas (estructuras duplicadas) -> TSV KEEP/REMOVE sugerido.
- D8 Carpetas espejo por contenido (hash de listados) -> TSV.
- D9 Similitud audio (YAMNet TF) con presets (rápido/balanceado/estricto).
- D10 Helpers rsync por lotes: entrada `consolidation_plan.tsv`, lote en GB (por defecto 50), chequeo de espacio libre mínimo (20 GB por defecto) y opción `--remove-source-files`. Genera `consolidation_rsync_batchXX.sh` con control de espacio, autodetección de rsync (quita `--protect-args` si no existe), logs en `_DJProducerTools/logs`, omite faltantes con aviso y resume archivos/GB por batch/total. Safe/Lock informativos; no mueve nada al generarlos.

### ML / Deep (40–52, 62–67)
- 40 Análisis inteligente JSON; 41 predictor heurístico; 42 checklist de eficiencia TSV; 43 flujo inteligente TSV; 44 dedupe integrado placeholder.
- 45 Plan de organización; 46 Armonizador de metadata; 47 Backup predictivo; 48 Sync multiplataforma (TSV/JSON).
- 49 BPM/onsets: `--tempo-min/--tempo-max --max-duration`; salida bpm/conf/key/energy/beat_count/first_beat_sec (librosa).
- 50 API/OSC: iniciar/parar server; puerto/token. HTTP `/status,/reports,/dupes/summary,/logs/tail`; OSC `/djpt/ping,/djpt/status`; unauthorized si falta token; guarda PID.
- 62 ML evolutivo (scikit-learn opcional); 63 toggle ML; 64 instalar TF.
- 65 TF Lab: modelos yamnet/musicnn/musictag/clap_onnx/clip_vitb16_onnx/musicgen_tflite/sentence_t5_tflite; respeta `DJPT_OFFLINE`/`DJPT_TF_MOCK`; genera embeddings/tags/similarity/anomalies/segments/loudness/matching/video_tags/music_tags/mastering TSV. Advierte y cae a mock si falta runtime.
- 66 Plan LUFS (pyloudnorm+soundfile opcional); 67 Auto-cues (onsets/segmentos con librosa).

### Visuales / OSC / DMX (V)
- V1 Ableton .als quick report; V2 Inventario visuales; V3 Envío plan DMX (ENTTEC dry-run por defecto, log de frames); V4/V5 reporte/plan de video; V6 resolución/duración; V7 visuales por resolución; V8 duplicados visuales; V9 plan optimizar; V10 playlist→OSC; V11 playlist→DMX; V12 presets DMX (ajusta canales/valores).

### Automatización (A/68)
- 21 cadenas predefinidas (backup+snapshot, dedupe/quarantine, limpieza, show prep, integridad, eficiencia, ML, sync, visuales, etc.). Safe/Lock/DRY aplican. Opción 68 instala deps Python en venv.

### Seguridad y modos
- Por defecto: `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE=0`. No desactives sin revisar planes.
- Offline: `DJPT_OFFLINE=1` fuerza heurísticos; `DJPT_TF_MOCK=1` evita descargas TF; aplica en TF Lab.
- Evita root/disco del sistema; acciones pesadas piden `confirm_heavy_action`.

### Instalación / venv / deps
- Mínimos: bash, python3, ffprobe, sox, jq. Opcionales: ffmpeg, librosa, python-osc, pyserial, onnxruntime/tflite-runtime, tensorflow.
- Venv: `_DJProducerTools/venv` (según BASE_PATH). Para recrear: `python3 -m venv _DJProducerTools/venv && source _DJProducerTools/venv/bin/activate && pip install --upgrade pip`.
- Instalación rápida: usa snippet `install_djpt.sh` (descarga EN/ES, chmod +x).

### Salidas y logs
- Planes: `_DJProducerTools/plans/*.tsv/json`; reportes: `_DJProducerTools/reports/*`; logs: `_DJProducerTools/logs/*`; quarantine: `_DJProducerTools/quarantine/`; batch helpers: `_DJProducerTools/plans/consolidation_rsync_batchXX.sh`.

### Recetas prácticas
- Dedupe seguro: 6 → 9 → 10 (revisar) → desactivar Safe/Lock si aplicarás → 11 quarantine.
- Merge multi-disco: D4 plan → D10 batches (50 GB) → ejecutar helpers manualmente.
- Prep video: 32 reporte → 33 códec auto → confirmar ffmpeg (o DRY solo imprime).
- BPM sin escribir tags: 49 con `--tempo-min 70 --tempo-max 180 --max-duration 600`; usa beat_count/first_beat_sec.
- API con token: menú 50 define token; curl `-H "Authorization: Bearer TOKEN" http://127.0.0.1:9000/status`.
- CLI rápido:
  - Dry-run mínimo (ML offline): `DJPT_OFFLINE=1 DRYRUN_FORCE=1 ./scripts/DJProducerTools_MultiScript_ES.sh --test`
  - Base aislada: `HOME_OVERRIDE=/tmp/djpt_sandbox ./scripts/DJProducerTools_MultiScript_ES.sh`
  - TF Lab mock: `DJPT_TF_MOCK=1 ./scripts/DJProducerTools_MultiScript_ES.sh` y usar opción 65.
  - Plan de video rápido: `BASE_PATH=/tu/base ./scripts/DJProducerTools_MultiScript_ES.sh --dry-run` y en menú 33 responde N a ejecutar ffmpeg.

### Ajustes avanzados y afinado (por sección)
- **Seguridad y estado:** mantén Safe/Lock=1 salvo para aplicar un plan revisado; DRYRUN_FORCE=1 en pruebas de ffmpeg/rsync. Usa `HOME_OVERRIDE` para aislar el estado y no mezclar con `~/.DJProducerTools` legacy.
- **Exclusiones:** edita `config/djpt.conf` o menú 57 para saltar cachés (`*/Cache/*`, `*.asd`, temporales). Acelera scans y reduce falsos duplicados.
- **Hashes/dupes:** en árboles grandes usa profundidad/tamaño máximo en D5; define exclusiones si no quieres videos/stems pesados. Siempre revisa `plans/dupes_plan.tsv` antes de la opción 11.
- **Consolidación (D4/D10):** fija tamaño de lote según tu espacio libre (20–50 GB recomendable). Activa el guard de GB libres (20 por defecto). Se preservan espacios finales en rutas, ejecuta helpers desde terminal para respetar el quoting. Logs en `_DJProducerTools/logs/*.log`. Usa `--remove-source-files` sólo si confirmaste la copia y quieres limpiar origen.
- **Video prep (33/V5):** códec `auto` prioriza hardware (`videotoolbox`); fallback `libx264`. DRYRUN_FORCE imprime los ffmpeg. El plan incluye el códec; audio AAC 160 kbps por defecto salvo que lo cambies en el script.
- **BPM (49):** acota `--tempo-min/--tempo-max` para más precisión; `--max-duration` evita archivos larguísimos. Salida con beats/first beat para cues; no escribe tags.
- **API/OSC (50):** pon token en redes compartidas; HTTP es local por defecto. OSC responde unauthorized sin token. PID guardado; usa el menú para parar.
- **TF Lab (65):** elige modelo según recursos (ONNX/TFLite para CPU ligero, TF si lo tienes). Usa `DJPT_OFFLINE=1` para evitar descargas; `DJPT_TF_MOCK=1` para forzar mock. Salidas TSV en `reports/`: embeddings/tags/similarity/anomalies/segments/loudness/matching/video_tags/music_tags/mastering.
- **DMX/OSC envío (V3/V10/V11):** Safe/Lock/DRY bloquean envío live; logs de frames. Revisa presets (V12) y ajusta canales antes de usar.
- **Automatizaciones (A/68):** cada cadena respeta Safe/Lock/DRY. Para operaciones grandes, lánzalas con DRYRUN_FORCE=1 y revisa.
- **Espacio en disco:** usa la opción 59 (salud) y el guard de D10. Para staging en disco externo, regenera plan o edita los batch scripts al nuevo destino.

### Licencia
- DJProducerTools License (Atribución + 20% revenue share en derivados/comercial). Mantén el crédito; ver `LICENSE`.
