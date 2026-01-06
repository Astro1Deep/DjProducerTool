# 🎧 DJProducerTools v1.0.0

Suite Profesional de Producción DJ para macOS | [English Version](README.md)

## Estado

- **Versión actual:** 1.0.0 (2024-01-04)
- **Implementado (CLI):** catálogo de archivos, índice SHA-256 y plan de duplicados, quarantine manager, backups de `_Serato_`/metadatos DJ, snapshot hash rápido, reportes TSV (ffprobe, relink helper, rescan), playlists por carpeta, toggles `SAFE_MODE`/`DJ_SAFE_LOCK`/`DRYRUN_FORCE`, inventario ffprobe + plan de transcode (H.264 1080p), planes playlists→OSC/DMX, envío DMX opcional (ENTTEC) en dry-run, servidor HTTP/OSC local, análisis BPM/librosa → TSV.
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

## Documentación

- [FEATURES_ES.md](FEATURES_ES.md) / [FEATURES.md](FEATURES.md) - Estado y alcance
- [guides/GUIDE_es.md](guides/GUIDE_es.md) / [guides/GUIDE.md](guides/GUIDE.md) - Guía rápida
- [guides/ADVANCED_GUIDE_es.md](guides/ADVANCED_GUIDE_es.md) / [guides/ADVANCED_GUIDE.md](guides/ADVANCED_GUIDE.md) - Guía avanzada por acción/opción
- [DEBUG_GUIDE_ES.md](DEBUG_GUIDE_ES.md) - Guía de depuración
- **Colaboradores:** planes/roadmap/API/seguridad en `docs/internal/` (no necesario para usuarios).

## Seguridad y empaquetado (recordatorios rápidos)
- No ejecutes el script como root ni apuntes `BASE_PATH` al disco del sistema. Usa `confirm_heavy_action` para operaciones grandes y revisa exclusiones por defecto antes de escanear discos con mucho media.
- Dependencias mínimas: `bash`, `python3`, `ffprobe`, `sox`, `jq`. Ejemplo macOS: `brew install ffmpeg sox jq`.
- Paquete limpio: `git archive -o ../DJProducerTools_WAX.zip HEAD` e incluye `djpt_icon.icns` para el icono del Dock.

### ML/TF Lab desde cero (modelos reales onnx/tflite)

1. Activa el venv local o deja que el menú lo cree: `source _DJProducerTools/venv/bin/activate` (se aloja en la carpeta donde arrancas el script, nunca en el sistema).
2. En TF Lab (menú 65), pon `DJPT_OFFLINE=0` para permitir modelos reales. Si eliges modelos ONNX (clap_onnx/clip_vitb16_onnx/sentence_t5_tflite), se pedirá instalar `onnxruntime`; si falta, se usa fallback mock con aviso.
3. TFLite en macOS ARM: no hay wheel oficial `tflite-runtime`; usa TensorFlow (opción 64) o un entorno con wheel compatible. Mientras tanto, MusicGen_tflite opera en modo fallback seguro.
4. `DJPT_OFFLINE=1` fuerza heurísticos/mocks en todas las opciones ML. Los avisos son no bloqueantes y el script permanece en modo seguro.

## Licencia

MIT - Ver [LICENSE](LICENSE)

---
**Versión:** 1.0.0 | **Estado:** ✅ CLI básica lista / 🚧 módulos avanzados pendientes
