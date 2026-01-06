# DJProducerTools - Guía de Depuración y Progreso

## Descripción General

Todas las opciones del script incluyen ahora:
- ✅ **Barras de progreso** mostrando porcentaje y estimaciones de tiempo
- ✅ **Spinners fantasma** animando durante el procesamiento
- ✅ **Actualizaciones de estado en tiempo real** para saber que no está congelado
- ✅ **Modo de depuración** para inspección profunda
- ✅ **Datos de ejecución** para optimización de rendimiento
- ✅ **Rastreo paso a paso** para operaciones complejas

## Ejecutar con Salida de Depuración

### Habilitar Modo de Depuración

```bash
DEBUG_MODE=1 ./DJProducerTools_MultiScript_ES.sh
```

Esto mostrará:
- Puntos de entrada/salida de funciones con nombres de código
- Tiempo exacto para cada operación
- Estados de variables y valores intermedios
- Trazas completas de comandos
- Advertencias de uso de recursos

### Niveles de Depuración

| Nivel | Símbolo | Cuándo Usar | Ejemplo |
|-------|---------|-------------|---------|
| INFO | ℹ | Información general | Iniciando operación |
| SUCCESS | ✓ | Finalización exitosa | Índice hash generado |
| WARN | ⚠ | Advertencias | Espacio en disco bajo |
| ERROR | ✗ | Condiciones de error | Archivo no encontrado |
| DEBUG | ⚙ | Información de desarrollo | Valores de variables |

## Indicadores de Progreso

### Barras de Progreso

Durante operaciones largas, verás:
```
Progreso: ████████░░░░░░░░░░░░░░░░░░░░░░ 33% [1000/3000] (45s transcurridos, ~90s restantes)
```

Desglosado:
- **Barra visual**: Bloques llenos (█) vs vacíos (░)
- **Porcentaje**: 0-100%
- **Contador**: Items actuales/totales
- **Tiempo**: Transcurrido y tiempo restante estimado

### Spinners Fantasma

Mientras procesa sin items individuales:
```
◐ Escaneando biblioteca...   
◓ Escaneando biblioteca...
◑ Escaneando biblioteca...
◒ Escaneando biblioteca...
```

Estos rotan continuamente, demostrando que la herramienta está funcionando incluso sin progreso para mostrar.

### Operaciones Multi-Paso

Para flujos de trabajo complejos:
```
▶ Paso 1/5: Inicializando workspace
✓ Paso 1/5 completado
▶ Paso 2/5: Escaneando archivos
✓ Paso 2/5 completado
```

## Usar con Opciones Específicas

### Opción 1: Verificación de Estado (con debug)
```bash
DEBUG_MODE=1 ./DJProducerTools_MultiScript_ES.sh --option 1
```
Salida:
```
[08:30:15] ℹ Iniciando Verificación de Estado
[08:30:15] ⚙ → Entrando: check_paths()
[08:30:15] ⚙ Cargando configuración desde /ruta/a/djpt.conf
[08:30:16] ✓ Configuración cargada exitosamente (1.2ms)
[08:30:16] ⚙ ← Saliendo: check_paths() [code: 0]
```

### Opción 9: Índice Hash (con progreso)
```bash
./DJProducerTools_MultiScript_ES.sh --option 9
```
Salida:
```
▶ Paso 1/3: Escaneando archivos
ℹ Se encontraron 2,345 archivos de audio
Hashing: ████████████░░░░░░░░░░░░░░░░░░░░░ 45% [1050/2345] (120s transcurridos, ~145s restantes)
```

### Opción 10: Encontrar Duplicados (con debug + progreso)
```bash
DEBUG_MODE=1 ./DJProducerTools_MultiScript_ES.sh --option 10
```
Muestra:
- Cada comparación de hash con estado
- Grupos de duplicados siendo identificados
- Estadísticas finales
- Todo en tiempo real

### Opción 27: Snapshot (simple spinner)
```bash
./DJProducerTools_MultiScript_ES.sh --option 27
```
Salida:
```
◐ Creando snapshot de integridad...
◓ Creando snapshot de integridad...
[08:35:20] ✓ Snapshot creado: integrity_2024-01-04.json
```

## Perfilado de Rendimiento

Todas las operaciones con temporizador habilitado muestran:

```
[08:40:00] ℹ Iniciando scan_workspace...
[08:40:15] ✓ scan_workspace completado en 15234.567ms
```

Úsalo para identificar cuellos de botella:
- Operaciones hash: Usualmente 5-20ms por archivo
- I/O de archivos: Usualmente 1-10ms por operación
- Lecturas de metadatos: Usualmente 2-5ms por archivo

## Advertencias de Memoria

Cuando la memoria disponible cae por debajo de 500MB:
```
[08:45:30] ⚠ Memoria baja: 350MB disponibles (umbral: 500MB)
```

Esto indica:
- El escaneo de biblioteca podría ralentizarse
- El procesamiento de archivos grandes podría fallar
- Considera cerrar otras aplicaciones

## Solución de Problemas con Debug

### El Script Parece Congelado

Cuando NO ves progreso por >5 segundos:
1. Verifica con `DEBUG_MODE=1` para ver operación actual
2. Busca mensajes de error en rojo
3. Presiona CTRL+C para detener y revisar registros

### Rendimiento Lento

Con datos de temporizador, puedes ver qué paso es lento:
```
[08:50:00] ℹ Iniciando hash_calculation...
[08:50:45] ✓ hash_calculation completado en 45000ms  ← ¡DEMASIADO LENTO!
```

Soluciones:
- Reduce el número de archivos con filtros
- Aumenta la RAM disponible
- Cierra aplicaciones en competencia

### Errores de Memoria

Si ves:
```
[08:55:00] ⚠ Memoria baja: 100MB disponibles
[08:55:05] ✗ Operación falló: Memoria insuficiente
```

Entonces:
- Reinicia el script
- Cierra navegador y otras aplicaciones
- Reduce el alcance (menos archivos)

## Archivos de Registro

Toda la salida detallada de depuración también se guarda:

```
_DJProducerTools/logs/debug_YYYY-MM-DD.log
```

Ver con:
```bash
tail -f _DJProducerTools/logs/debug_*.log
```

## Depuración Avanzada

### Rastrear Función Específica

Edita el script para agregar:
```bash
trace_function "nombre_mi_funcion" arg1 arg2
nombre_mi_funcion arg1 arg2
trace_exit "nombre_mi_funcion" $?
```

### Sección de Perfil

Envuelve cualquier sección de código:
```bash
time_function "descripcion" ./seccion_script.sh
```

### Verificación de Recursos

Antes de operaciones:
```bash
check_resources 1000  # Verificar 1GB disponible
```

## Ejemplos

### Operación Rápida (Bueno)
```
◐ Comparando hashes...   
[08:50:00] ✓ Completado en 2.3ms
```

### Operación Lenta (Advertencia)
```
Comparando: ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 15% [150/1000] (30s transcurridos, ~170s restantes)
```

### Operación Fallida (Error)
```
[08:55:00] ✗ Operación falló: Permiso denegado
[08:55:00] → Última función: process_files
[08:55:00] → Archivo actual: /ruta/restringida/musica.mp3
```

---

## Resumen

- **Salida siempre visible**: Nunca te preguntes si está congelado
- **Barras de progreso**: Sabe cuánto falta
- **Modo de depuración**: Inspección profunda cuando sea necesario
- **Datos de temporizador**: Identifica cuellos de botella
- **Sistema de advertencia**: Notificaciones tempranas de problemas

¡Combina estas características para visibilidad completa en todas las operaciones!
