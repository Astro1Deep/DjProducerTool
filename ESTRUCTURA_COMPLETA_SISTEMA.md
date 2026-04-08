# Estructura Completa Del Sistema

## Superficie canónica
- Shell: `bin/djpt`
- CLI Python: `cli.py`
- Configuración IA: `config/ai_model_params.toml`
- Imports Python estables: `core/*`

## Compatibilidad
- `launch.sh`
- `DJProducerTools_Con_Opciones_IA.sh`
- `scripts/cli.py`
- `scripts/config_schema.py`
- `scripts/core/*`

## Capas principales
- `scripts/DJProducerTools_MultiScript_ES.sh`: menú canónico
- `lib/*`: módulos operativos
- `core/*`: namespace Python raíz para contratos públicos
- `tests/*`: validación, smoke y contrato

## Estado runtime
- `state/` o `_DJProducerTools/state/`
- `reports/` o `_DJProducerTools/reports/`
- `plans/` o `_DJProducerTools/plans/`

## Menús relevantes
- `62`: ML evolutivo local
- `65`: TensorFlow Lab
- `70`: Health IA
- `71`: Gestor multi-backend IA
- `74`: Hub de configuración de backends IA
- `80-88`: menús IA avanzados
- `91-92`: LAB/doctor/grafo
