# Universal Deployment

## Objetivo
Preparar un paquete ZIP reproducible para entregar DJProducerTools a otro usuario o a otro Mac sin arrastrar artefactos de runtime.

Cada release generado por `scripts/build_release_package.sh` debe dejar además:
- `dist/<release>.zip`
- `dist/<release>.zip.sha256`
- `dist/<release>_TESTER_HANDOFF.md`

## Qué se distribuye
- Código fuente del proyecto
- Scripts canónicos y wrappers de compatibilidad
- `config/ai_model_params.toml`
- Tests y smokes de validación
- Documentación de uso, reparación y estructura

## Qué no se debe incluir
- `state/`
- `reports/`
- `tests/logs/`
- `venv/`
- `djpt_venv/`
- Bootstrap recomendado en destino: `bash scripts/bootstrap_djpt_venv.sh --core --with-dev`
- Certificación recomendada del release extraído: `bash scripts/certify_fresh_install.sh --zip dist/<release>.zip`
- `.pytest_cache/`
- `__pycache__/`

## Pasos en el equipo destino
1. Descomprimir el ZIP.
2. Verificar el checksum con el fichero `.sha256` o seguir el handoff `dist/<release>_TESTER_HANDOFF.md`.
3. Dar permisos si hace falta: `chmod +x bin/djpt launch.sh DJProducerTools_Con_Opciones_IA.sh`.
4. Ejecutar `./bin/djpt`.
5. Ejecutar `bash tests/test_destructive_flows_sacrificial.sh`.
6. Correr `bash tests/run_smoke.sh`.

## Requisitos recomendados
- macOS Apple Silicon para el perfil completo MLX/Metal
- `python3`
- `bash`
- `ollama` para LLM local
- `tensorflow-macos` y `tensorflow-metal` solo si se quiere TF real

## Configuración portable
- Mantener `config/ai_model_params.toml` como fuente canónica.
- Activar `transformers` u `openai_local` solo cuando la máquina destino tenga modelo o endpoint local funcional.
- No distribuir `_DJProducerTools/state/config/ai_backend_env.sh` salvo que se quiera clonar una sesión concreta.
