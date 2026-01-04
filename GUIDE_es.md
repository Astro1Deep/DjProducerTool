# DJProducerTools – Wiki Completa

Documentación extensa para usar el toolkit de limpieza y organización de librerías para DJs y Productores en macOS.

## 1) Qué es y para quién

- Limpieza y organización de bibliotecas Serato/Rekordbox/Traktor/Ableton (audio, video, visuales, DMX).
- Backups seguros y snapshots de integridad.
- Detección y gestión de duplicados (exactos y planes avanzados).
- Herramientas Deep/ML opcionales (recomendaciones, organización, similitud).
- Creación de instaladores `.pkg` y automatización de tareas de desarrollo.

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
- `DEBUG_MODE`: Si una tarea se queda "colgada" con el logo girando, puedes editar el script y poner `DEBUG_MODE=1` al principio. Esto desactivará las animaciones y mostrará la salida de los comandos en tiempo real para ayudarte a diagnosticar el problema.

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
- Autor: Astro One Deep — <onedeep1@gmail.com>
- Issues/sugerencias: abrir issue en GitHub o enviar correo.

## 18) Testing y Desarrollo

El proyecto incluye una suite de tests unitarios básicos para verificar la funcionalidad de las funciones de utilidad principales.

### Ejecutar los Tests

1.  **Abre una terminal** y navega hasta el directorio raíz de tu proyecto. Usa comillas si la ruta tiene espacios:
    ```bash
    cd "/Users/ivan/Desktop/0 SERATO BIBLIOTECA/DJProducerTools_Project "
    ```

2.  **Da permisos de ejecución** al script de test (solo necesitas hacerlo una vez):
    ```bash
    chmod +x tests/test_runner.sh
    ```

3.  **Ejecuta los tests**:
    ```bash
    bash tests/test_runner.sh
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
- **`build_release_pack.sh`**: Prepara un paquete completo para un lanzamiento en GitHub. Genera un borrador del `CHANGELOG.md` agrupando los commits por tipo (ej. `feat`, `fix`) a partir del historial de git. Opcionalmente, puede publicar el release automáticamente en GitHub si configuras un token de acceso.
- **`generate_html_report.sh`**: Ejecuta el script `check_consistency.sh` y genera un informe de estado visual en formato HTML (`project_status_report.html`), con secciones separadas para fallos, tareas pendientes (TODOs) y comprobaciones correctas.

Estos scripts automatizan el ciclo de vida del desarrollo, desde las pruebas hasta la creación del producto final y la actualización de la documentación.

## 19) Firma de Código y Notarización (macOS)

Para distribuir tu aplicación fuera de la Mac App Store sin que los usuarios vean advertencias de seguridad de Gatekeeper, necesitas firmar tu instalador `.pkg` con un certificado de desarrollador de Apple y, opcionalmente, notarizarlo.

### Requisitos Previos

1.  **Apple Developer Program**: Debes estar inscrito en el Apple Developer Program (es un servicio de pago anual).
2.  **Certificado "Developer ID Installer"**:
    *   Desde tu cuenta de desarrollador, crea un certificado de tipo "Developer ID Installer".
    *   Descárgalo e instálalo en tu Llavero (Keychain Access) de macOS haciendo doble clic en el archivo `.cer`.

### Cómo Firmar el Paquete `.pkg`

1.  **Encuentra tu Identidad de Firma**:
    Abre la aplicación **Terminal** y ejecuta el siguiente comando para listar tus identidades de firma disponibles:
    ```bash
    security find-identity -v -p codesigning
    ```
    Busca en la lista una línea que se parezca a esto:
    `1) XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX "Developer ID Installer: Tu Nombre (XXXXXXXXXX)"`
    Copia el texto completo que está entre comillas, incluyendo el ID entre paréntesis.

2.  **Modifica el Script `build_macos_pkg.sh`**:
    Abre el archivo `build_macos_pkg.sh` en un editor de texto. Verás una sección comentada para la firma. Descomenta la línea `SIGNING_IDENTITY=...` y pega la identidad que copiaste.

    El resultado debería ser algo así:
    ```shell
    SIGNING_IDENTITY="Developer ID Installer: John Appleseed (123ABC456D)"
    ```

3.  **Ejecuta el Script de Build**:
    Ahora, cuando ejecutes `./build_macos_pkg.sh`, el script usará automáticamente tu certificado para firmar el paquete `.pkg` resultante.

### Notarización (Paso Avanzado)

La firma evita la mayoría de las advertencias, pero para una compatibilidad total con las últimas versiones de macOS, Apple recomienda "notarizar" la aplicación. El script `build_macos_pkg.sh` puede automatizar este proceso.

1.  **Crea una Contraseña Específica de App**:
    *   Ve a appleid.apple.com e inicia sesión.
    *   En la sección "Inicio de sesión y seguridad", busca "Contraseñas específicas de apps" y haz clic en "Generar contraseña".
    *   Dale un nombre (ej. "DJProducerTools Notary") y copia la contraseña generada (ej. `xxxx-xxxx-xxxx-xxxx`).

2.  **Modifica el Script `build_macos_pkg.sh`**:
    Abre el script y busca la sección de notarización. Descomenta y rellena las siguientes variables:
    ```shell
    # Tu correo electrónico de Apple ID
    APPLE_ID_EMAIL="tu-correo@example.com"
    # La contraseña específica de app que generaste
    APPLE_ID_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
    ```

3.  **Ejecuta el Script de Build**:
    Asegúrate de que también tienes configurada la `SIGNING_IDENTITY`. Al ejecutar `./build_macos_pkg.sh`, el script firmará el paquete, lo subirá a Apple para su notarización, esperará el resultado y, si tiene éxito, adjuntará el "ticket" de notarización al instalador.

### Publicación Automática en GitHub

El script `build_release_pack.sh` puede publicar automáticamente el release en GitHub.
1.  **Crea un Token de Acceso Personal** en GitHub con el permiso `repo`.
2.  **Exporta el token** como una variable de entorno en tu terminal: `export GITHUB_TOKEN="ghp_..."`.
3.  Al ejecutar `build_release_pack.sh`, el script detectará el token y te ofrecerá publicar el release de forma automática.