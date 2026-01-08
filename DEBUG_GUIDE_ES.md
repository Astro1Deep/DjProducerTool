# Guía de depuración (ES)

1. Ejecuta `bash scripts/VERIFY_AND_TEST.sh --fast` para validar dependencias y estructura.
2. Usa `bash tests/test_runner.sh` para comprobar los módulos de video, BPM, ML, DMX y OSC.
3. `bash tests/comprehensive_test.sh` valida integridad de documentación y wrappers.
4. Revisa `_DJProducerTools/logs/` para eventos de DMX, API/OSC y ML.
5. Para problemas de ML/TF, activa el venv con `source _DJProducerTools/venv/bin/activate` y vuelve a correr `scripts/DJProducerTools_MultiScript_ES.sh` con la opción 65.
