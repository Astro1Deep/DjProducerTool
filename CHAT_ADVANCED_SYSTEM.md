# Chat Advanced System (DJProducerTools)

## Objetivo
Definir un chat operativo, persistente y combinable con toda la capa técnica de DJProducerTools sin romper el core:

- Conversación natural + comandos explícitos.
- IA local-first con orquestación real de RAG/HF/módulos/scheduler.
- Aprendizaje web controlado.
- Ejecución reproducible y trazable.

## Superficie canónica

- Chat runtime: `python3 lib/djpt_chat_cli.py`
- CLI canónica: `python3 cli.py`
- Menú shell canónico: `scripts/DJProducerTools_MultiScript_ES.sh`
- Config IA: `config/ai_model_params.toml`
- Estado runtime: `state/`

## Mapa de capacidades

1. Diagnóstico y contexto:
- `diag`, `ia-status`, `recomienda`

2. Escaneo operativo:
- `scan [all|media|audio|video|other|mp3|wav] [--quick] [ruta]`

3. IA local orquestada:
- `rag status|index-text|index-audio|query`
- `hf status|sync [--allow-remote] [--force-enable]`
- `online-setup [--apply] [--install-optional-deps] [--hf-sync]`
- `modulo list|init|check|run|doctor`

4. Aprendizaje web:
- `estudiar-web <url> [--index-rag]`
- Guarda conocimiento en `kb/raw/web_*.md`.

5. Automatización periódica:
- `programar cada 30m rag status`
- `tareas`
- `tareas run`
- `tareas enable|disable|remove <task_id>`
- Runner one-shot: `python3 scripts/chat_tasks_runner.py --base-path . --json`
- Automatización launchd (macOS): `python3 scripts/launchd_chat_tasks.py install --interval 300 --apply`

6. Pipeline combinado:
- `combo status`
- `combo learn <url>`
- `combo optimize`
- `combo setup [args de online-setup]`

## Pipeline combinado (detalle)

### `combo status`
Ejecuta chequeo integral:
- diagnóstico de chat
- estado backends
- `rag status`
- `hf status`
- `modulo list`
- inventario de tareas programadas

### `combo learn <url>`
Ejecuta secuencia de aprendizaje:
- descarga URL
- limpieza HTML->texto
- persistencia en `kb/raw/`
- indexado RAG
- estado final de RAG y HF

### `combo optimize`
Optimización segura no destructiva:
- autoheal base
- `modulo doctor`
- `tareas run` (solo tareas vencidas)
- estado RAG/HF
- opcional: `--engine-optimize` para disparar `run_engine("optimize")`

### `combo setup ...`
Proxy directo a `online-setup` para bootstrap de conectividad/deps.

## Persistencia y archivos de estado

- Tareas chat: `state/chat_tasks.json`
- Knowledge web: `kb/raw/web_*.md`
- Reportes de módulos: `state/reports/module_manager.json`
- Estado HF/AI: `state/config/`, `state/models/`, `reports/`
- Launchd logs: `logs/launchd_chat_tasks.out.log`, `logs/launchd_chat_tasks.err.log`

## Reglas de seguridad operativa

1. No acciones destructivas automáticas sobre librería real sin confirmación explícita.
2. Scheduler ejecuta solo comandos soportados por whitelist interna (`scan`, `rag`, `hf`, `online-setup`, `modulo`, acciones engine permitidas).
3. Integraciones opcionales (HF/Ollama/MLX/TF/OpenAI local) dependen del entorno destino.

## Validación recomendada (triple capa)

1. Unit tests del chat:
- `python3 -m pytest -q tests/test_djpt_chat_cli_env_detection.py tests/test_djpt_chat_cli_conversation_v2.py tests/test_djpt_chat_cli_tasking_v3.py tests/test_djpt_chat_cli_combo_v4.py`

2. Smokes de integración:
- `bash tests/test_chat_cli_delegate_consistency.sh`
- `bash tests/test_enhanced_chat_menu_smoke.sh`

3. Contrato de menú:
- `python3 scripts/menu_contract_tools.py validate-json`

## Limitaciones reales (explícitas)

1. No se puede garantizar “cero fallos” en cualquier máquina.
2. `hf sync`, `transformers`, `ollama`, `mlx`, `tensorflow` dependen de prerequisitos del equipo destino.
3. `estudiar-web` requiere conectividad para descarga real.

## Flujo mínimo recomendado para usuario final

1. `./bin/djpt`
2. Abrir chat (`73` o `89` según menú)
3. `combo status`
4. `combo setup --apply --install-optional-deps --hf-sync --hf-dry-run`
5. `combo learn https://huggingface.co/models`
6. `programar cada 30m rag status`
7. `tareas`
