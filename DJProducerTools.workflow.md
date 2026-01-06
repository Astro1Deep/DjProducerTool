# Automator app (instrucciones)

1. Abrir Automator → Nuevo → Aplicación.
2. Añadir acción "Ejecutar secuencia de órdenes de shell".
3. Comando a pegar:

```bash
cd "/Users/ivan/Desktop/0 SERATO BIBLIOTECA/DJProducerTools_Project" || exit 1
export HOME_OVERRIDE="/Users/ivan/Desktop/0 SERATO BIBLIOTECA/DJProducerTools_Project"
/bin/bash ./scripts/DJProducerTools_MultiScript_EN.sh
```

4. Guardar como `DJProducerTools.app` (por ejemplo, en Aplicaciones).
5. Asignar icono: clic derecho sobre la app → Obtener información → arrastrar un .icns al icono superior (opcional).
6. Arrastrar `DJProducerTools.app` al Dock.

Notas:
- Puedes cambiar a la versión ES sustituyendo el script en la última línea.
- `HOME_OVERRIDE` mantiene el estado dentro del proyecto; quítalo si prefieres el HOME real.
