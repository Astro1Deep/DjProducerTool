#!/usr/bin/env bash
# Wrapper to call the real script in scripts/
exec "$(cd -- "$(dirname "$0")" && pwd)/scripts/DJProducerTools_MultiScript_ES.sh" "$@"
