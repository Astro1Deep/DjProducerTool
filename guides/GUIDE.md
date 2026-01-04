# DJProducerTools – Complete Wiki

Extensive documentation for using the library cleaning and organization toolkit for DJs and Producers on macOS.

## 1) What It Is and Who It's For

- Cleaning and organization of Serato/Rekordbox/Traktor/Ableton libraries (audio, video, visuals, DMX).
- Secure backups and integrity snapshots.
- Duplicate detection and management (exact matches and advanced plans).
- Optional Deep/ML tools (recommendations, organization, similarity).
- Creation of `.pkg` installers and automation of development tasks.

## 2) Main Files

- `DJProducerTools_MultiScript_ES.sh` – Spanish interface.
- `DJProducerTools_MultiScript_EN.sh` – English interface.
- `install_djpt.sh` – simple installer (downloads the latest version).

## 3) Quick Installation

```bash
cat <<'EOF' > install_djpt.sh
#!/usr/bin/env bash
set -e
for f in DJProducerTools_MultiScript_ES.sh DJProducerTools_MultiScript_EN.sh; do
  url="https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/$f"
  curl -fsSL "$url" -o "$f"
  chmod +x "$f"
done
echo "Done. Run ./DJProducerTools_MultiScript_ES.sh or ./DJProducerTools_MultiScript_EN.sh"
EOF
chmod +x install_djpt.sh
./install_djpt.sh
```

## 4) Requisitos
- macOS + bash (el script se re-ejecuta con bash si abres con doble clic).
- `python3` recomendado para ffprobe/librosa y ML opcional.
- Espacio libre para `_DJProducerTools/` (config, logs, planes, quarantine).
- ML opcional: descarga básica ~300 MB (numpy/pandas); evolutiva ~450 MB (scikit-learn/joblib); TensorFlow opcional +600 MB.
 - Perfil IA local (opción 59): LIGHT recomendado (numpy+pandas+scikit-learn+joblib+librosa). TF_ADV opcional para Apple Silicon (tensorflow-macos + tensorflow-metal).

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
- **Deep/ML (42-59)**: análisis, predictor, optimizador, dedup integrado, organización ML, armonizador de metadata, backup predictivo, sync multiplataforma, análisis avanzado, TensorFlow opcional.  
  *Ventaja:* decisiones guiadas y planes automáticos; ML opcional y local.
- **Extras (60-72)**: reset estado, perfiles de rutas, Ableton tools, import cues, gestor de exclusiones, comparar hash_index, health-check, LUFS, auto-cues.  
  *Ventaja:* portabilidad de configuración y diagnósticos rápidos.
- **Automatizaciones (A/71)**: Más de 20 cadenas predefinidas para backup/snapshot, dedup, limpieza, show prep, integridad, eficiencia, ML, sync, visuales, seguridad Serato, dedup multi-disco.  
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
9) Backup predictivo (49 -> 8 -> 27)  
10) Sync multiplataforma (50 -> 39 -> 8 -> 8)  
11) Diagnóstico rápido (1 -> 3 -> 4 -> 5)  
12) Salud Serato (7 -> 59)
13) Hash + mirror check (9 -> 68)
14) Audio prep (31 -> 69 -> 70)
15) Auditoría integridad (6 -> 9 -> 27 -> 68)
16) Limpieza + backup seguro (39 -> 34 -> 10 -> 11 -> 8 -> 27)  
17) Prep sync librerías (18 -> 14 -> 50 -> 8 -> 27)  
18) Salud visuales (V2 -> V6 -> V8 -> V9 -> 8)  
19) Organización audio avanzada (31 -> 30 -> 35 -> 45 -> 46)  
20) Seguridad Serato reforzada (7 -> 8 -> 59 -> 12 -> 49)  
21) Dedup multi-disco + mirror (9 -> 10 -> 46 -> 11 -> 68)

## 10) Salidas y ubicación
- Planes: `_DJProducerTools/plans/` (dupes, limpieza, workflows, integraciones, sync, eficiencia).
- Reportes: `_DJProducerTools/reports/` (hashes, corruptos, catálogos, playlists, cues, ML).
- Quarantine: `_DJProducerTools/quarantine/` (aplicado por 11 o cadenas que la usen).
- Logs: `_DJProducerTools/logs/` (visor en opción 28).

## 11) Notas de ML/TensorFlow
- ML básico/evolutivo es opcional y local. Se pide confirmación antes de instalar paquetes (~300–450 MB).
- TensorFlow (64/65) es opcional (+600 MB) para auto-tagging/embeddings/similitud avanzada.
- Puedes desactivar ML con la opción 56 (Toggle ML ON/OFF) para evitar usar el venv.

## 12) Buenas prácticas
- Antes de mover/quarantine: generar `hash_index` (9) y `dupes_plan` (10); desactiva SafeMode/Lock si quieres aplicar (11).
- Haz snapshot (27) y backup DJ (8) antes de grandes cambios.
- Usa el gestor de exclusiones (64) para evitar cachés/proyectos pesados en scans.
- Para dedup multi-disco, usa 68 (mirror check) con hash_index de origen/destino.

## 13) Recursos visuales
- Capturas menú completo: `docs/menu_es_full.svg` y `docs/menu_en_full.svg`.
- Para regenerar las capturas SVG automáticamente, ejecuta: `bash docs/generate_menu_svgs.sh`.
- Añade en README (ya enlazado) o en issues/wikis de GitHub.

## 14) Estrategias Profesionales de Gestión

### La Regla de Backup 3-2-1 para DJs
Para evitar desastres antes de un gig, sigue esta regla usando las herramientas del script:
1.  **3 Copias**: Tu librería en el portátil, una copia en disco externo (Time Machine o clon) y una copia "fría" en otro lugar.
2.  **2 Medios**: Usa SSD para el directo y HDD para el archivo frío.
3.  **1 Off-site**: Una copia fuera de tu estudio (nube o casa de un amigo).
*Uso en script*: Ejecuta la cadena **A9 (Backup Predictivo)** semanalmente.

### Gestión de Calidad de Audio
- **Conversión (Opción 40)**: Si compras WAV/AIFF pero necesitas ahorrar espacio en el USB para CDJs, usa la opción 40. Convierte a MP3 320kbps (CBR) usando el codec LAME con la máxima calidad (`-q:a 0`). El script mueve automáticamente los WAVs pesados a una carpeta `_WAV_Backup` para que puedas archivarlos en tu disco de estudio y llevar solo los MP3s ligeros.
- **Normalización (Opción 69)**: Analiza el LUFS de tus tracks. No normalices destructivamente tus archivos originales. Usa la ganancia del mixer o tags de ReplayGain.

### Limpieza de Metadatos para CDJs
Los CDJs antiguos pueden fallar con caracteres extraños o art works muy grandes.
- Usa la **Opción 34** para normalizar nombres de archivo (elimina caracteres ilegales).
- Usa la **Opción 39** para limpiar comentarios basura (URLs de descarga) que ensucian la pantalla del CDJ.

## 15) Perfiles de artista y distribución (opción 72)
- Opción 72 crea/usa `artist_pages.tsv` (en `config/`) con plantillas de bio, press kit, rider/stage plot, showfile DMX/OBS/Ableton y links a plataformas/redes (Spotify, Apple, YouTube, SoundCloud, Beatport, Traxsource, Bandcamp, Mixcloud, Audius, Tidal, Deezer, Amazon, Shazam, Juno, Pandora, Instagram, TikTok, Facebook, Twitter/X, Threads, RA, Patreon, Twitch, Discord, Telegram, WhatsApp, Merch, Boiler Room…). Puedes editar en línea y exportar a CSV/HTML/JSON (`reports/`).
- Registro como artista (resumen rápido):
  - **Distribución digital**: sube música mediante agregadores (DistroKid, TuneCore, CD Baby, Record Union, Amuse). Beatport/Traxsource suelen requerir distribuidor/label. Bandcamp/SoundCloud/Mixcloud se suben directo.
  - **Reclamar perfiles**: Spotify for Artists, Apple Music for Artists, YouTube (Channel + Content ID), SoundCloud/Beatport/Traxsource (vía distribuidor), Instagram/Facebook Music (a través de distribuidor para Content ID).
  - **Identificadores**: usa UPC para lanzamientos e ISRC por pista (los agregadores suelen generarlos; si no, consigue tu prefijo ISRC local).
  - **Metadatos clave**: artista, ISRC, UPC, compositores, porcentaje splits, género, BPM, key, arte de portada (mín. 3000x3000), audio WAV 16/24-bit, sample rate 44.1/48 kHz.
  - **Derechos y cobros**: registra composiciones en tu PRO (SGAE/ASCAP/BMI/SOCAN, etc.), y si quieres publishing admin global usa servicios como Songtrust. Para performance digital en EE. UU., registra en SoundExchange. Configura métodos de pago del agregador (PayPal/transferencia) y de tiendas directas (Bandcamp/Patreon/Twitch/merch).
  - **EPK/Press**: prepara EPK PDF, press kit assets (fotos HQ, logo, banners, rider/stage plot), links a clips/sets (YouTube/Boiler Room), y añádelos en la plantilla.

## 16) Licencia
- DJProducerTools License (Attribution + Revenue Share). Crédito obligatorio.
- Uso comercial o de derivados: notificar y compartir 20% de ingresos brutos (ver `LICENSE`).

## 17) Soporte
- Autor: Astro One Deep — onedeep1@gmail.com
- Issues/sugerencias: abrir issue en GitHub o enviar correo.

## 18) Testing y Desarrollo

El proyecto incluye una suite de tests unitarios básicos para verificar la funcionalidad de las funciones de utilidad principales.

### Ejecutar los Tests

1.  **Abre una terminal** y navega hasta el directorio raíz de tu proyecto. Usa comillas si la ruta tiene espacios:
    ```bash
    **cd "/Users/ivan/Desktop/0 SERATO BIBLIOTECA/DJProducerTools_Project "**
    ```

2.  **Da permisos de ejecución** al script de test (solo necesitas hacerlo una vez):
    ```bash
    **chmod +x tests/test_runner.sh**
    ```

3.  **Ejecuta los tests**:
    ```bash
    **bash tests/test_runner.sh**
    ```

El runner descubrirá y ejecutará automáticamente todas las funciones de test, mostrando un resumen de los tests pasados y fallidos.

### Cómo Funciona

-   `tests/test_runner.sh` carga el script principal (`DJProducerTools_MultiScript_EN.sh`).
-   Usa una serie de funciones "mock" para sobreescribir comportamientos no aptos para testing (como la entrada de usuario, limpiar la pantalla o modificar ficheros de configuración).
-   Cada función de test (`test_*`) valida una pieza de lógica específica usando helpers simples como `assert_equals`.
-   Esto permite testear de forma aislada funciones como `strip_quotes` y `should_exclude_path`.

### Añadir Nuevos Tests

Para añadir un nuevo test, abre `tests/test_runner.sh` y crea una nueva función cuyo nombre empiece por `test_`. El runner la detectará automáticamente.

### Scripts de Desarrollo

- **`build_macos_pkg.sh`**: Crea un instalador `.pkg` nativo de macOS que instala la aplicación en `/Applications`. Ideal para una distribución sencilla.
- **`generate_menu_svgs.sh`**: Genera automáticamente las capturas de pantalla de los menús en formato SVG. Requiere `termtosvg` (`pip install termtosvg`).
- **`test_runner.sh`**: Ejecuta la suite de tests unitarios para asegurar la calidad del código.
- **`tests/check_consistency.sh`**: Verifica la consistencia interna del proyecto. Comprueba menús, funciones, cadenas, existencia de documentación, busca `TODOs`/`FIXMEs` pendientes, valida la sintaxis de todos los scripts `.sh` usando `shellcheck` (si está instalado) y busca posibles secretos o claves hardcodeadas. Esencial para ejecutar antes de un commit.
- **`build_release_pack.sh`**: Prepara un paquete completo para un lanzamiento en GitHub. Ejecuta los otros scripts de build, comprime el código fuente y agrupa todo en una carpeta `release/VERSION`.

Estos scripts automatizan el ciclo de vida del desarrollo, desde las pruebas hasta la creación del producto final y la actualización de la documentación.
