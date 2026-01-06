#!/bin/bash
cd "$(dirname "$0")" || exit 1
# Forzar estado en este directorio
export HOME_OVERRIDE="$(pwd)"
/bin/bash ./scripts/DJProducerTools_MultiScript_EN.sh
