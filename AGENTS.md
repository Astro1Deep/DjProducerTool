# Repository Guidelines

## Proyecto y estructura
- Código principal en `scripts/` (`DJProducerTools_MultiScript_EN.sh` y `..._ES.sh`) y utilidades como `VERIFY_AND_TEST.sh`. El estado persistente vive en `BASE_PATH/_DJProducerTools` (logs, reportes, cuarentenas); no lo edites manualmente.
- Activos de icono y lanzadores: `djpt_icon.icns/png`, `DJProducerTools.command` (doble clic) y `DJProducerTools.workflow.md` (Automator).
- Documentación de usuario y features en `README.md`, `README_ES.md`, `FEATURES.md/FEATURES_ES.md`; mantén ambas versiones sincronizadas.

## Comandos de build, test y desarrollo
- Ejecuta menús: `./scripts/DJProducerTools_MultiScript_EN.sh --help|--version|--test|--dry-run` (usa `--dry-run` para catálogos/rsync seguros). Equivalente en español con `..._ES.sh`.
- Salud rápida: `bash scripts/VERIFY_AND_TEST.sh --fast`; para chequeo completo (incluye red) omite `--fast`.
- `BASE_PATH` es el cwd al lanzar; para aislar pruebas, `HOME_OVERRIDE=/ruta_pruebas ./scripts/DJProducerTools_MultiScript_EN.sh`.

## Estilo y convenciones
- Bash 4+, sangría de 2 espacios, siempre comillas en rutas/vars. Funciones en `snake_case`, constantes en mayúsculas. Usa helpers existentes (`safe_rsync`, `confirm_heavy_action`, `ensure_state_dir_safe`) en lugar de comandos directos destructivos.
- Mensajería `[INFO]/[WARN]/[ERR]`; respeta valores por defecto `SAFE_MODE=1`, `DJ_SAFE_LOCK=1`, `DRYRUN_FORCE=0` salvo que un flag lo modifique.
- Nombra nuevas opciones de menú de forma concisa y actualiza los dos idiomas.

## Pruebas
- Antes de un PR: `./scripts/DJProducerTools_MultiScript_EN.sh --test` y `bash scripts/VERIFY_AND_TEST.sh --fast`. Si tocaste ML/ffprobe/sox o lógica de IO, ejecuta el test completo sin `--fast`.
- Para cambios que mueven archivos, prueba con `--dry-run` y revisa reportes en `_DJProducerTools/reports` y logs en `_DJProducerTools/logs`.
- Añade ejemplos de entrada/salida para flags nuevos y documenta supuestos en los comentarios del código cuando no sean obvios.

## Commits y Pull Requests
- Mensajes `scope: cambio` (ej.: `scripts: banner degradado`). Prefiere commits pequeños y temáticos.
- En PRs incluye: resumen breve, issue enlazada, lista de comandos de prueba ejecutados y notas de regresión. Adjunta capturas/logs si afectan UX CLI; evita subir media pesada.
- Mantén paridad EN/ES y actualiza `README.md`/`README_ES.md` y cualquier flujo automatizado afectado (`DJProducerTools.command`, iconos) al añadir opciones o flags.

## Seguridad y configuración
- No ejecutes el script como root ni apuntes `BASE_PATH` al disco del sistema. Usa `confirm_heavy_action` para operaciones grandes y revisa exclusiones por defecto antes de escanear discos con mucho media.
- Dependencias mínimas: `bash`, `python3`, `ffprobe`, `sox`, `jq`. Instálalas (p. ej. `brew install ffmpeg sox jq`) antes de probar.
- Para empaquetados limpios: `git archive -o ../DJProducerTools_WAX.zip HEAD` e incluye `djpt_icon.icns` para el icono de macOS Dock.
