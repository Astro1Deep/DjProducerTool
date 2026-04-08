# Reparación Completa

## Fallos típicos

### El menú abre pero una opción IA no responde
1. Ejecuta `70` para health IA.
2. Ejecuta `74 -> 4` para validar dependencias.
3. Ejecuta `72` si faltan dependencias IA.

### TensorFlow Lab falla
1. Usa `64` o `72` para instalar TensorFlow.
2. Si quieres bootstrap directo, exporta `DJPT_TF_LAB_BOOTSTRAP=1`.
3. Reabre `65`.

### Configuración IA inconsistente
1. Revisa `config/ai_model_params.toml`.
2. Revisa `_DJProducerTools/state/config/ai_backend_env.sh`.
3. Usa `74` para regenerar runtime config.

### Modelos locales Ollama
1. Usa `71 -> 4` para verificar Ollama.
2. Usa `87` u `88` para instalar modelos locales.
3. Prioriza `llama3.2:3b`.

### Verificación de release
1. `python3 scripts/menu_contract_tools.py validate-json`
2. `bash tests/test_menu_release_navigation.sh`
3. `bash tests/test_ai_advanced_ops_smoke.sh`
4. `bash tests/test_destructive_flows_sacrificial.sh`
5. `bash tests/run_smoke.sh`
