# DJProducerTools – Wiki Completa

Documentación extensa para usar los scripts Bash que limpian y organizan bibliotecas de DJ/producers en macOS. Incluye interfaces en español e inglés, menús agrupados y cadenas automatizadas.

## 1) Qué es y para quién
- Limpieza y organización de bibliotecas Serato/Rekordbox/Traktor/Ableton (audio, video, visuales, DMX).
- Backups seguros y snapshots de integridad.
- Detección y gestión de duplicados (exactos y planes avanzados).
- Herramientas Deep/ML opcionales (recomendaciones, organización, similitud).

## 2) Archivos principales
- `DJProducerTools_MultiScript_ES.sh` – interfaz en español.
- `DJProducerTools_MultiScript_EN.sh` – interfaz en inglés.
- `install_djpt.sh` – instalador simple (descarga última versión).

## 3) Instalación rápida
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

## 4) Requisitos
- macOS + bash (el script se re-ejecuta con bash si abres con doble clic).
- `python3` recomendado para ffprobe/librosa y ML opcional.
- Espacio libre para `_DJProducerTools/` (config, logs, planes, quarantine).
- ML opcional: descarga básica ~300 MB (numpy/pandas); evolutiva ~450 MB (scikit-learn/joblib); TensorFlow opcional +600 MB.

## 5) Uso básico
```bash
./DJProducerTools_MultiScript_ES.sh   # versión en español
./DJProducerTools_MultiScript_EN.sh   # versión en inglés
```
- Doble clic: la ventana queda abierta al terminar para mostrar mensajes finales.
- El script crea `_DJProducerTools/` en el `BASE_PATH` (config/logs/planes/quarantine).
- Auto-detección: si hay `_DJProducerTools` cerca del directorio actual, se usa esa raíz como `BASE_PATH`.

## 6) Estructura en disco
- `_DJProducerTools/config/`: `djpt.conf` (BASE_PATH, roots, flags SafeMode/Lock/DryRun), perfiles de exclusiones, historial de rutas.
- `_DJProducerTools/reports/`: `hash_index.tsv`, `media_corrupt.tsv`, `workspace_scan.tsv`, `serato_video_report.tsv`, `playlists_per_folder.m3u8`, `ml_predictions_*.tsv`, etc.
- `_DJProducerTools/plans/`: `dupes_plan.tsv/json`, `cleanup_pipeline_*.txt`, `workflow_*.txt`, `integration_engine_*.txt`, `efficiency_*.tsv`, `ml_organization_*.tsv`, `predictive_backup_*.txt`, `cross_platform_*.txt`, `mirror_integrity_*.tsv`, etc.
- `_DJProducerTools/quarantine/`: archivos movidos por la opción 11 o cadenas que la usen.
- `_DJProducerTools/logs/`: ejecuciones, instalaciones ML; visor en opción 28.
- `_DJProducerTools/venv/`: entorno virtual para ML opcional.

## 7) Seguridad y modos
- `SAFE_MODE` y `DJ_SAFE_LOCK` bloquean acciones peligrosas (quarantine/movidas). Desactiva ambos si quieres aplicar planes.
- `DRYRUN_FORCE` fuerza simulación en algunas acciones.
- El script siempre pide confirmación antes de mover/quarantine.

## 8) Menús y ventajas (vista agrupada)
- **Core (1-12)**: estado, cambio de base, resumen, top dirs/files, backups, hash_index, plan exacto de duplicados, quarantine.  
  *Ventaja:* base segura para cualquier workflow (hashes + backups antes de tocar nada).
- **Media/organización (13-24)**: ffprobe corruptos, playlists por carpeta, relink helper, mirrors por género, rescan inteligente, diagnóstico de herramientas, permisos/flags, instalar CLI.  
  *Ventaja:* deja listas las rutas y playlists para DJs y VJ.
- **Procesos/limpieza (25-39)**: snapshot rápido, visor de logs, normalizar nombres, samples por tipo, limpieza web en playlists/tags, Serato Video (reporte/plan).  
  *Ventaja:* limpiar tags/nombres y preparar librerías sin tocar audio.
- **Deep/ML (40-52, 62-65)**: análisis, predictor, optimizador, dedup integrado, organización ML, armonizador de metadata, backup predictivo, sync multiplataforma, análisis avanzado, TensorFlow opcional.  
  *Ventaja:* decisiones guiadas y planes automáticos; ML opcional y local.
- **Extras (53-67)**: reset estado, perfiles de rutas, Ableton tools, import cues, gestor de exclusiones, comparar hash_index, health-check, LUFS, auto-cues.  
  *Ventaja:* portabilidad de configuración y diagnósticos rápidos.
- **Automatizaciones (A/68)**: 21 cadenas predefinidas para backup/snapshot, dedup, limpieza, show prep, integridad, eficiencia, ML, sync, visuales, seguridad Serato, dedup multi-disco.  
- **Auto-pilot IA local (A23–A28)**: flujos completos sin intervención (todo en uno, clean+backup, deep/ML, seguro con reuso y lista de únicos).  
  *Ventaja:* ejecutar flujos completos con un número/letra.
- **Submenús L/D/V/H**: librerías y cues, duplicados avanzados, visuales/OSC/DMX, ayuda detallada.

## 9) Cadenas automatizadas (resumen)
1) Backup seguro + snapshot (8 -> 27)  
2) Dedup exacto + quarantine (10 -> 11)  
3) Limpieza metadatos + nombres (39 -> 34)  
4) Salud media: rescan + playlists + relink (18 -> 14 -> 15)  
5) Prep show: backup/snapshot/dup/playlist (8 -> 27 -> 10 -> 11 -> 14 -> 8)  
6) Integridad + corruptos (13 -> 18)  
7) Plan eficiencia (42 -> 44 -> 43)  
8) ML organización básica (45 -> 46)  
9) Backup predictivo (47 -> 8 -> 27)  
10) Sync multiplataforma (48 -> 39 -> 8 -> 8)  
11) Diagnóstico rápido (1 -> 3 -> 4 -> 5)  
12) Salud Serato (7 -> 59)  
13) Hash + mirror check (9 -> 61)  
14) Audio prep (31 -> 66 -> 67)  
15) Auditoría integridad (6 -> 9 -> 27 -> 61)  
16) Limpieza + backup seguro (39 -> 34 -> 10 -> 11 -> 8 -> 27)  
17) Prep sync librerías (18 -> 14 -> 48 -> 8 -> 27)  
18) Salud visuales (V2 -> V6 -> V8 -> V9 -> 8)  
19) Organización audio avanzada (31 -> 30 -> 35 -> 45 -> 46)  
20) Seguridad Serato reforzada (7 -> 8 -> 59 -> 12 -> 47)  
21) Dedup multi-disco + mirror (9 -> 10 -> 44 -> 11 -> 61)

## 10) Salidas y ubicación
- Planes: `_DJProducerTools/plans/` (dupes, limpieza, workflows, integraciones, sync, eficiencia).
- Reportes: `_DJProducerTools/reports/` (hashes, corruptos, catálogos, playlists, cues, ML).
- Quarantine: `_DJProducerTools/quarantine/` (aplicado por 11 o cadenas que la usen).
- Logs: `_DJProducerTools/logs/` (visor en opción 28).

## 11) Notas de ML/TensorFlow
- ML básico/evolutivo es opcional y local. Se pide confirmación antes de instalar paquetes (~300–450 MB).
- TensorFlow (64/65) es opcional (+600 MB) para auto-tagging/embeddings/similitud avanzada.
- Puedes desactivar ML con la opción 63 (Toggle ML ON/OFF) para evitar usar el venv.

## 12) Buenas prácticas
- Antes de mover/quarantine: generar `hash_index` (9) y `dupes_plan` (10); desactiva SafeMode/Lock si quieres aplicar (11).
- Haz snapshot (27) y backup DJ (8) antes de grandes cambios.
- Usa el gestor de exclusiones (57) para evitar cachés/proyectos pesados en scans.
- Para dedup multi-disco, usa 61 (mirror check) con hash_index de origen/destino.

## 13) Recursos visuales
- Capturas menú completo: `docs/menu_es_full.svg` y `docs/menu_en_full.svg`.
- Banners de ejemplo: `docs/banner_es.png`, `docs/banner_en.png`, `docs/banner_es_terminal.svg`.
- Añade en README (ya enlazado) o en issues/wikis de GitHub.

## 14) Perfiles de artista y distribución (opción 69)
- Opción 69 crea/usa `artist_pages.tsv` (en `config/`) con plantillas de bio, press kit, rider/stage plot, showfile DMX/OBS/Ableton y links a plataformas/redes (Spotify, Apple, YouTube, SoundCloud, Beatport, Traxsource, Bandcamp, Mixcloud, Audius, Tidal, Deezer, Amazon, Shazam, Juno, Pandora, Instagram, TikTok, Facebook, Twitter/X, Threads, RA, Patreon, Twitch, Discord, Telegram, WhatsApp, Merch, Boiler Room…). Puedes editar en línea y exportar a CSV/HTML/JSON (`reports/`).
- Registro como artista (resumen rápido):
  - **Distribución digital**: sube música mediante agregadores (DistroKid, TuneCore, CD Baby, Record Union, Amuse). Beatport/Traxsource suelen requerir distribuidor/label. Bandcamp/SoundCloud/Mixcloud se suben directo.
  - **Reclamar perfiles**: Spotify for Artists, Apple Music for Artists, YouTube (Channel + Content ID), SoundCloud/Beatport/Traxsource (vía distribuidor), Instagram/Facebook Music (a través de distribuidor para Content ID).
  - **Identificadores**: usa UPC para lanzamientos e ISRC por pista (los agregadores suelen generarlos; si no, consigue tu prefijo ISRC local).
  - **Metadatos clave**: artista, ISRC, UPC, compositores, porcentaje splits, género, BPM, key, arte de portada (mín. 3000x3000), audio WAV 16/24-bit, sample rate 44.1/48 kHz.
  - **Derechos y cobros**: registra composiciones en tu PRO (SGAE/ASCAP/BMI/SOCAN, etc.), y si quieres publishing admin global usa servicios como Songtrust. Para performance digital en EE. UU., registra en SoundExchange. Configura métodos de pago del agregador (PayPal/transferencia) y de tiendas directas (Bandcamp/Patreon/Twitch/merch).
  - **EPK/Press**: prepara EPK PDF, press kit assets (fotos HQ, logo, banners, rider/stage plot), links a clips/sets (YouTube/Boiler Room), y añádelos en la plantilla.

## 14) Licencia
- DJProducerTools License (Attribution + Revenue Share). Crédito obligatorio.
- Uso comercial o de derivados: notificar y compartir 20% de ingresos brutos (ver `LICENSE`).

## 15) Soporte
- Autor: Astro One Deep — onedeep1@gmail.com
- Issues/sugerencias: abrir issue en GitHub o enviar correo.
