# DJProducerTools (DJPT)

Punto de entrada canónico (shell): `./bin/djpt`

- Crea/usa entorno aislado local en `djpt_venv/`.
- Usa configuración canónica en `config/ai_model_params.toml`.
- Ejecuta smoke IA y muestra estado MLX/TF/Ollama sin exigir `OPENAI_API_KEY` ni `HF_TOKEN` en modo local-first.
- Declara `transformers` y `openai_local` como rutas opcionales, desactivadas por defecto hasta que haya modelo/endpoint local real.
- Menú completo (90+ opciones) o CLI Typer (`python3 cli.py --help`).

Entradas rápidas:
- `./bin/djpt` — menú / CLI interactiva
- `./launch.sh` — shim legacy hacia `bin/djpt`
- `./DJProducerTools_Con_Opciones_IA.sh` — menú legacy enlazado a CLI
- `djpt_venv/bin/djpt ai status` — estado IA
- `djpt_venv/bin/djpt ai hf-sync --action status` — estado del pin HF local
- `djpt_venv/bin/djpt ai hf-sync --action sync --allow-remote --dry-run` — validar conexión HF sin descargar
- `djpt_venv/bin/djpt ai hf-sync --action sync --allow-remote` — descargar/pinnear modelo HF a local
- `djpt_venv/bin/djpt ai online-setup --apply --install-optional-deps --hf-sync --hf-dry-run` — setup online asistido
- `djpt_venv/bin/djpt ai module --action init --name mi_modulo` — crear módulo aislado
- `djpt_venv/bin/djpt ai module --action doctor` — sanear módulos inválidos sin tocar core
- `python3 lib/djpt_chat_cli.py` — asistente conversacional local
- `python3 lib/djpt_chat_cli.py` + `rag status` — estado RAG desde chat
- `python3 lib/djpt_chat_cli.py` + `hf status` — estado HF/transformers local-first
- `python3 lib/djpt_chat_cli.py` + `modulo list` — inventario de módulos aislados
- `python3 lib/djpt_chat_cli.py` + `estudiar-web https://huggingface.co/models --index-rag` — ingestión web + indexado RAG
- `python3 lib/djpt_chat_cli.py` + `programar cada 30m scan mp3` — tarea programada persistente
- `python3 lib/djpt_chat_cli.py` + `tareas run` — ejecutar tareas vencidas
- `python3 lib/djpt_chat_cli.py` + `combo status` — chequeo combinado (chat+RAG+HF+módulos+tareas)
- `python3 lib/djpt_chat_cli.py` + `combo learn https://huggingface.co/models` — aprendizaje web + indexado RAG
- `python3 scripts/chat_tasks_runner.py --base-path . --json` — ejecución one-shot de tareas vencidas
- `python3 scripts/launchd_chat_tasks.py install --interval 300` — genera plist launchd (dry-run)
- `python3 scripts/launchd_chat_tasks.py install --interval 300 --apply` — instala/carga launchd automático
- `python3 scripts/launchd_chat_tasks.py status` — estado del agente launchd
- `python3 scripts/launchd_chat_tasks.py uninstall --apply` — desinstala launchd
- `bash scripts/bootstrap_djpt_venv.sh --core --with-dev` — bootstrap limpio del entorno aislado
- `bash scripts/certify_fresh_install.sh` — certificación de instalación nueva desde el zip más reciente
- `bash scripts/reanchor_git_in_place.sh --apply --branch main` — reanclaje Git local cuando el worktree quedó roto

Notas recientes:
- CLI interactiva ahora soporta `cd/ls/pwd` y mapea `ai`→`ai status`, `config`→`config show`.
- Doctor Mode disponible: tecla `R` en el menú abre herramientas de diagnóstico/reparación.
- La capa de módulos (`state/modules`) permite extender sin modificar runtime base; `ai module doctor` marca inválidos como deshabilitados.
- Opciones 55-57 activas (Ableton tools, import cues, exclusiones).
- Opción `62` ya entrena/predice localmente con `lib/ml_evolutionary.py` real.
- Opción `71` expone el gestor multi-backend 1-8 canónico.
- Opción `74` centraliza tuning, health, dependencias y gestión de modelos IA.
- Opciones `91-92` del modo `LAB` ya son ejecutables por `--run`.

Validación recomendada antes de distribuir:
- `python3 scripts/menu_contract_tools.py validate-json`
- `bash tests/test_menu_release_navigation.sh`
- `bash tests/test_ai_advanced_ops_smoke.sh`
- `bash tests/test_destructive_flows_sacrificial.sh`
- `bash tests/run_smoke.sh`

Directorios generados en runtime (excluir de paquetes): `state/`, `logs/`, `reports/`, `scans/`, `quarantine/`, `djpt_venv/`, `venv/`, `_archive/`.

Documentación esencial:
- `QUICK_START_GUIDE.md`
- `CHAT_ADVANCED_SYSTEM.md`
- `UNIVERSAL_DEPLOYMENT.md`
- `REPARACION_COMPLETA.md`
- `ESTRUCTURA_COMPLETA_SISTEMA.md`
