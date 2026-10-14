<div align="center">
  <img src="docs/assets/branding/waxspaceship_hero_banner.svg" alt="WaxSpaceship x Astro1Deep Hero Banner" width="100%">
</div>

# 🎧 DJProducerTools v1.3.0

Suite Profesional de Producción DJ para macOS | [English Version](README.md)

## Estado

- **Versión actual:** 1.3.0 (2026-10-14)
- **Implementado (CLI):** catálogo de archivos, índice SHA-256 y plan de duplicados, motor acústico ShazamIO en 5 capas con caché SQLite local, quarantine manager, backups de `_Serato_`/metadatos DJ, snapshot hash rápido, reportes TSV (ffprobe, relink helper, rescan), playlists por carpeta, toggles `SAFE_MODE`/`DJ_SAFE_LOCK`/`DRYRUN_FORCE`, inventario ffprobe + plan de transcode (H.264 1080p), planes playlists→OSC/DMX, envío DMX opcional (ENTTEC) en dry-run, servidor HTTP/OSC local, análisis BPM/librosa → TSV y `video_tags.tsv` (keyframes + `clip_tags` si `clip_vitb16_onnx` está instalado).
- **Roadmap/placeholder:** auto-tagging ML avanzado y laboratorio TensorFlow (solo plan/documentado); exportes HTML/PDF avanzados.

## Características principales (CLI)

| Característica | Estado | Detalles |
|---|---|---|
| 📂 Catálogo + hash | ✅ Listo | Índice SHA-256, plan duplicados exactos, quarantine opcional |
| 🛡️ Safety/Quarantine | ✅ Listo | `SAFE_MODE`/`DJ_SAFE_LOCK` activos, `DRYRUN_FORCE` disponible, gestor de quarantine |
| 💾 Backups DJ | ✅ Listo | rsync de `_Serato_` y metadatos DJ (Serato/Traktor/Rekordbox/Ableton) en `_DJProducerTools/` |
| 🔍 Reportes TSV | ✅ Listo | Snapshot hash, ffprobe corrupción, relink helper, rescan inteligente, playlists `.m3u8` por carpeta |
| 🎥 Video / OSC / DMX | ✅ Parcial | Inventario ffprobe, plan transcode H.264 1080p, planes playlists→OSC/DMX, envío DMX opcional (ENTTEC) con Safe/Lock/dry-run |
| 🔌 API/OSC local | ✅ Parcial | Servidor HTTP (/status,/reports) y OSC (/djpt/ping) con inicio/parada desde menú |
| 🔊 BPM/librosa | ✅ Ligero | Reporte TSV de BPM/onsets con `librosa` (no modifica tags) |
| 🎧 ShazamIO Acústico | ✅ Listo | Reconocimiento resiliente multi-capa (Akai MPC, Serato DJ, Ableton) con caché SQLite y fallback offline |
| 🤖 ML/TF | 🚧 Placeholder | Auto-tagging/TF Lab documentados como plan; sin mutar audio |

## Instalación Rápida

```bash
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool
chmod +x scripts/*.sh
./scripts/DJProducerTools_MultiScript_ES.sh
```

## Requisitos

- macOS 10.13+ (recomendado 10.15+)
- bash 4.0+ o zsh
- ffmpeg/ffprobe, jq, curl, python3
- Opcional: `pyserial` para enviar DMX (`pip install pyserial`), `python-osc` para servidor OSC, `librosa`+`soundfile` para BPM auto

### Flags y seguridad (menú WAX 1-72)

- `./scripts/DJProducerTools_MultiScript_ES.sh --help|--version|--test|--dry-run`
- `--test` ejecuta chequeo de dependencias (bash, find, awk, sed, xargs, python3, ffprobe, sox, jq); `--dry-run` activa `DRYRUN_FORCE=1` (respeta backups/quarantine).
- Estado en `BASE_PATH/_DJProducerTools` (por defecto el cwd al lanzar); `HOME_OVERRIDE=/ruta` si quieres aislar estado. Existe estado legacy en `~/.DJProducerTools` (ya no se usa).
- Variables por defecto: `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`.
- Corpus compartido: `DJPT_SHARED_CORPUS=/ruta/compartida` (o elección en el menú 69) copia embeddings/tags en `reports/` para poder reutilizarlos en otras bases sin volver a escanear.
- Informe maestro ML (menú 65.13) combina matching/anomalías/segmentos/loudness/video tags en `reports/ml_master_report.tsv`. Ajusta batch/threshold/top-N en la opción 65.12 y activa MusicBrainz (65.14) para sumar metadata oficial si hay conexión.

## Documentación

- Características: ver README.md/README_ES para resumen bilingüe.
- [guides/GUIDE_es.md](guides/GUIDE_es.md) / [guides/GUIDE.md](guides/GUIDE.md) - Guía rápida
- [guides/ADVANCED_GUIDE_es.md](guides/ADVANCED_GUIDE_es.md) / [guides/ADVANCED_GUIDE.md](guides/ADVANCED_GUIDE.md) - Guía avanzada por acción/opción
- **Colaboradores:** planes/roadmap/API/seguridad (incluye FEATURES/DEBUG/API/VERSION) en `docs/internal/` (no necesario para usuarios).
- **Wiki (manual extendido):** `docs/wiki/WIKI_EXTENDED_MANUAL_ES.md` (ES) y `docs/wiki/WIKI_EXTENDED_MANUAL_EN.md` (EN) con todas las opciones/acciones en detalle.

### Novedades
- Reconocimiento acústico resiliente ShazamIO (opción 9): identificación de canciones completas, vinilos ripeados y chops en Akai MPC Sample, Serato DJ Pro y Ableton/Producción, con caché SQLite, reintentos con sanitizador FFmpeg y fallback heurístico offline.
- Plan de transcode: permite elegir códec (auto/videotoolbox/nvenc/libx264) y ejecutar ffmpeg con confirmación; respeta `DRYRUN_FORCE`.
- API/OSC: soporta Bearer token; `/djpt/ping` y `/djpt/status` responden “unauthorized” si falta token.
- Corpus compartido (opción 69): exporta/importa reports/planes entre discos para reutilizar hashes/ML sin reescanear.

## Seguridad y empaquetado (recordatorios rápidos)
- No ejecutes el script como root ni apuntes `BASE_PATH` al disco del sistema. Usa `confirm_heavy_action` para operaciones grandes y revisa exclusiones por defecto antes de escanear discos con mucho media.
- Dependencias mínimas: `bash`, `python3`, `ffprobe`, `sox`, `jq`. Ejemplo macOS: `brew install ffmpeg sox jq`.
- Paquete limpio: `git archive -o ../DJProducerTools_WAX.zip HEAD` e incluye `djpt_icon.icns` para el icono del Dock.

### Deep Thinking & ML/TF Lab (modelos reales onnx/tflite)

 1. Activa el venv local o deja que el menú lo cree: `source _DJProducerTools/venv/bin/activate` (se aloja en la carpeta donde arrancas el script, nunca en el sistema).
 2. En TF Lab (menú 65), pon `DJPT_OFFLINE=0` para permitir modelos reales. Si eliges modelos ONNX (clap_onnx/clip_vitb16_onnx/sentence_t5_tflite), se pedirá instalar `onnxruntime`; si falta, se usa fallback mock con aviso.
 3. TFLite en macOS ARM: no hay wheel oficial `tflite-runtime`; usa TensorFlow (opción 64) o un entorno con wheel compatible. Mientras tanto, MusicGen_tflite opera en modo fallback seguro.
 4. `DJPT_OFFLINE=1` fuerza heurísticos/mocks en todas las opciones ML. Los avisos son no bloqueantes y el script permanece en modo seguro.
 5. Modelos disponibles: `yamnet`, `musicnn`, `musictag` (TF Hub), `clap_onnx`, `clip_vitb16_onnx`, `musicgen_tflite` y `sentence_t5_tflite`. `music_tags` usa CLAP + prompts (`MUSIC_TAG_PROMPTS`), `video_tags` extrae keyframes con ffmpeg y aplica CLIP, y `matching/anomalies/segments/loudness/mastering` reutilizan embeddings de `DJPT_SHARED_CORPUS`/`SHARED_CORPUS_DIR`.
 6. Descarga pesos opcionales con `./lib/ml_tf.py download_model --name <model>` o la opción 65.15; los archivos se guardan en `_DJProducerTools/venv/models` para llevar a otros discos.
 7. El reporte maestro (65.14) admite `--online`/`--query` para consultar MusicBrainz y anexa título/artista/fecha en `reports/ml_master_report.tsv`. Mantén `DJPT_OFFLINE=1` si prefieres un flujo local y privado.

## Licencia

MIT - Ver [LICENSE](LICENSE)

---
**Versión:** 1.3.0 | **Estado:** ✅ Suite completa lista / 🎧 Motor Acústico Resiliente ShazamIO activo
