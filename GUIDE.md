# Guía rápida DJProducerTools

Scripts Bash para limpiar y organizar bibliotecas de DJ/producer en macOS. Incluyen interfaz en español e inglés con banners diferenciados por gradiente.

## Archivos principales
- `DJProducerTools_MultiScript_ES.sh` – interfaz en español.
- `DJProducerTools_MultiScript_EN.sh` – interfaz en inglés.
- Instalador simple: `install_djpt.sh` o un solo comando con `curl` (abajo).

## Instalación rápida
```bash
cat <<'EOF' > install_djpt.sh
#!/usr/bin/env bash
set -e
for f in DJProducerTools_MultiScript_ES.sh DJProducerTools_MultiScript_EN.sh; do
  url="https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/$f"
  curl -fsSL "$url" -o "$f"
  chmod +x "$f"
done
echo "Listo. Ejecuta ./DJProducerTools_MultiScript_ES.sh o ./DJProducerTools_MultiScript_EN.sh"
EOF
chmod +x install_djpt.sh
./install_djpt.sh
```

## Uso básico
```bash
./DJProducerTools_MultiScript_ES.sh   # versión en español
./DJProducerTools_MultiScript_EN.sh   # versión en inglés
```
- Si lo abres con doble clic, el script mantiene la ventana abierta al terminar y muestra el mensaje final.
- El script crea `_DJProducerTools/` dentro del directorio donde se ejecuta para configs, logs y planes.

## Requisitos rápidos
- macOS + bash (reabre con bash si lanzas con doble clic).
- `python3` recomendado para funciones ML/ffprobe/librosa.
- Espacio en disco libre para `_DJProducerTools/` (config, logs, planes, quarantine).
- Opcional ML: descarga básica ~300 MB (numpy/pandas); evolutiva ~450 MB (scikit-learn/joblib); TensorFlow opcional (+600 MB) para auto-tagging/embeddings.

## Estructura y rutas
- `_DJProducerTools/` (creado en `BASE_PATH`):
  - `config/` (`djpt.conf`, perfiles de exclusiones, historial de rutas).
  - `reports/` (hash_index, media_corrupt, playlists, cues, etc.).
  - `plans/` (dupes_plan, cleanup_pipeline, workflow, etc.).
  - `logs/`, `quarantine/`, `venv/` (ML opcional), `banner.txt` (opcional).
- `BASE_PATH`: raíz de trabajo; configurable en opción 2. Se autodetecta al inicio y guarda histórico.
- Safe guards: `SAFE_MODE` y `DJ_SAFE_LOCK` bloquean acciones peligrosas/quarantine; `DRYRUN_FORCE` simula ciertos planes.

## Qué hace (vista de menús)
- **Core (1-12)**: estado, cambio de base, resumen, top dirs/files, backup Serato/DJ, hash_index, duplicados exactos, quarantine.
- **Media/organización (13-24)**: ffprobe corruptos, playlists, relink helper, mirrors por género, rescan inteligente, diag herramientas, fix permisos/flags, instalar comando.
- **Procesos/limpieza (25-39)**: snapshot integridad, visor de logs, toggle DryRun, planes de tags, Serato Video (reporte/plan), normalizar nombres, samples por tipo, limpieza web/whitelist.
- **Deep/ML (40-52, 62-65)**: análisis/predictor/optimizador, flujos inteligentes, dedup integrado, organización ML, armonizador metadata, backup predictivo, sync multiplataforma, análisis avanzado, motor integración, recomendaciones, pipeline automático. Opciones 62-65 gestionan ML evolutivo/TensorFlow/Lab.
- **Extras (53-67)**: reset estado, perfiles de rutas, Ableton Tools, import cues, gestor de exclusiones, comparar hash_index, health-check de estado, export/import config, mirror check, LUFS, auto-cues.
- **Automatizaciones A/68**: submenú con cadenas predefinidas (ver abajo). Acceso con `A` o `a`, o con opción `68`.
- **Submenús L/D/V**: librerías DJ & cues, duplicados avanzados, visuales/OSC/DMX.
- **Help H**: resumen detallado de opciones y notas técnicas.

## Cadenas automatizadas (A/68)
Flujos que combinan acciones existentes (respetan SafeMode/DJ_SAFE_LOCK):
1) Backup seguro + snapshot (8 -> 27)
2) Dedup exacto + quarantine (10 -> 11)
3) Limpieza metadatos + nombres (39 -> 34)
4) Salud media: rescan + playlists + relink (18 -> 14 -> 15)
5) Prep de show: backup/snapshot/dup/playlist (8 -> 27 -> 10 -> 11 -> 14 -> 8)
6) Integridad + corruptos (13 -> 18)
7) Plan de eficiencia (42 -> 44 -> 43)
8) ML organización básica (45 -> 46)
9) Backup predictivo (47 -> 8 -> 27)
10) Sync multiplataforma (48 -> 39 -> 8 -> 8)
11) Diagnóstico rápido (1 -> 3 -> 4 -> 5)
12) Salud Serato (7 -> 59)

## Salidas importantes
- Reportes: `_DJProducerTools/reports/` (ej: `hash_index.tsv`, `media_corrupt.tsv`, `dupes_plan.tsv`, `playlists_per_folder.m3u8`, `workspace_scan.tsv`, `ml_predictions_*.tsv`, etc.).
- Planes: `_DJProducerTools/plans/` (ej: `cleanup_pipeline_*.txt`, `workflow_*.txt`, `integration_engine_*.txt`, `efficiency_*.tsv`, `ml_organization_*.tsv`).
- Quarantine: `_DJProducerTools/quarantine/` (aplicado por opción 11 o flujos que la usen).
- Logs: `_DJProducerTools/logs/` (errores, ejecuciones, installs ML).

## Banners y color
- Ambos scripts usan el mismo banner ASCII; el gradiente es distinto por idioma:
  - EN: degradado frío→cálido (`GRN, CYN, BLU, PURP, RED, YLW`).
  - ES: degradado cálido→frío (`PURP, RED, YLW, GRN, CYN, BLU`).

## Licencia y atribución
- Licencia: DJProducerTools License (Attribution + Revenue Share). Crédito obligatorio.
- Uso comercial o de derivados requiere notificar y compartir el 20% de ingresos brutos con el autor (ver `LICENSE`).

## Recursos visuales
- Ejemplos de banner:
  - Español: `docs/banner_es.png`
  - Inglés: `docs/banner_en.png`

## Actualización
```
git pull
./install_djpt.sh   # vuelve a descargar la última versión
```

## Soporte
- Autor: Astro One Deep (onedeep1@gmail.com)
- Issues/sugerencias: abre un issue en GitHub o envía correo.
