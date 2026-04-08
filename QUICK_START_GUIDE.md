# Quick Start Guide

## Objetivo
Arrancar DJProducerTools con la superficie canónica y validar que el sistema base responde en un equipo nuevo.

## Entradas canónicas
- `./bin/djpt`
- `./launch.sh`
- `./DJProducerTools_Con_Opciones_IA.sh`
- `python3 cli.py --help`
- `python3 lib/djpt_chat_cli.py`

## Configuración base
- Configuración persistente: `config/ai_model_params.toml`
- Estado runtime: `_DJProducerTools/` o `state/` según el punto de entrada
- Configuración IA de sesión: `_DJProducerTools/state/config/ai_backend_env.sh`

## Primer arranque
1. Ejecuta `./bin/djpt`.
2. Verifica la opción `70` para health IA.
3. Verifica la opción `71` para el gestor multi-backend.
4. Verifica la opción `74` para tuning/dependencias/health centralizado.

## Validación mínima
1. `python3 scripts/menu_contract_tools.py validate-json`
2. `bash tests/test_menu_release_navigation.sh`
3. `bash tests/test_ai_advanced_ops_smoke.sh`
4. `bash tests/test_destructive_flows_sacrificial.sh`
5. `bash tests/run_smoke.sh`

## Notas local-first
- `OPENAI_API_KEY` y `HF_TOKEN` son opcionales.
- El backend Ollama por defecto recomendado es `llama3.2:3b`.
- `transformers` y `openai_local` están desactivados por defecto hasta que configures un modelo o endpoint local real.
- Para pin controlado de HuggingFace: `djpt ai hf-sync --action sync --allow-remote --dry-run` y luego sin `--dry-run` para descargar a local.
- Para setup online guiado: `djpt ai online-setup --apply --install-optional-deps --hf-sync --hf-dry-run`.
- Para extensiones seguras sin romper core: `djpt ai module --action init --name mi_modulo` y `djpt ai module --action doctor`.
- Desde chat puedes orquestar lo mismo con comandos cortos: `rag status`, `hf status`, `online-setup --apply --hf-sync`, `modulo list`.
- Para aprendizaje web local y RAG: `estudiar-web <url> --index-rag`.
- Para automatización periódica: `programar cada 30m scan mp3`, `tareas`, `tareas run`.
- Para pipeline combinado de máxima eficiencia: `combo status`, `combo learn <url>`, `combo optimize`, `combo setup ...`.
- Referencia completa del chat avanzado: `CHAT_ADVANCED_SYSTEM.md`.
- Para ejecución automática de tareas (macOS launchd): `python3 scripts/launchd_chat_tasks.py install --interval 300 --apply`.
- Para runner manual de tareas vencidas: `python3 scripts/chat_tasks_runner.py --base-path . --json`.
- Para recuperar Git local si el worktree quedó roto: `bash scripts/reanchor_git_in_place.sh --apply --branch main`.
- `TensorFlow Lab` no hace bootstrap automático al abrirse; se instala explícitamente desde `64`, `72` o exportando `DJPT_TF_LAB_BOOTSTRAP=1`.
- Para una instalación limpia reproducible usa `bash scripts/bootstrap_djpt_venv.sh --core --with-dev`.
- Para certificar un zip fuera del repo usa `bash scripts/certify_fresh_install.sh`.
