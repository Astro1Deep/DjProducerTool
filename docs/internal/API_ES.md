# Documentación de API de DJProducerTools

## Descripción General
Este documento describe las funciones internas e interfaces de DJProducerTools.

## Funciones Principales

### Gestión de Rutas

#### `init_paths()`
Inicializa directorios de trabajo y rutas de configuración.
```bash
init_paths
# Establece: CONFIG_DIR, REPORTS_DIR, PLANS_DIR, QUAR_DIR, VENV_DIR
```

#### `ensure_base_path_valid()`
Valida que BASE_PATH existe y contiene la estructura esperada.
```bash
ensure_base_path_valid
# Estado de salida: 0 si válido, 1 si inválido
```

### Funciones de Análisis

#### `scan_workspace()`
Escanea la biblioteca de música y genera catálogo.
```bash
scan_workspace [--dry-run] [--verbose]
# Produce: catalog.tsv en REPORTS_DIR
```

#### `generate_hash_index()`
Genera hashes SHA-256 para todos los archivos de audio.
```bash
generate_hash_index [--force] [--pattern "*.mp3"]
# Produce: hash_index.json
```

#### `find_exact_duplicates()`
Encuentra archivos de audio idénticos bit a bit.
```bash
find_exact_duplicates [--output FORMAT]
# Formatos: json, tsv, txt
# Produce: dupes_plan.json
```

### Funciones de Backup

#### `backup_serato()`
Realiza backup de metadatos específicos de Serato.
```bash
backup_serato [--destination PATH]
# Crea backup con marca de tiempo en _DJProducerTools/backups/
```

#### `backup_metadata()`
Realiza backup de metadatos de software DJ (Serato, Traktor, Rekordbox, Ableton).
```bash
backup_metadata [--format FORMAT]
```

### Funciones de Seguridad

#### `quarantine_files()`
Mueve archivos a cuarentena de forma segura para revisión.
```bash
quarantine_files FILE1 FILE2 [--reason "duplicate"]
# Archivos preservados en _DJProducerTools/quarantine/ con capacidad de recuperación
```

#### `restore_quarantine()`
Restaura archivos de cuarentena.
```bash
restore_quarantine FILE_ID [--destination PATH]
```

## Configuración

### Formato del Archivo de Configuración
Ubicado en `_DJProducerTools/config/djpt.conf`

```bash
BASE_PATH="/ruta/a/musica"
AUDIO_ROOT="/ruta/a/musica/audio"
SERATO_ROOT="/Users/usuario/Music/_Serato_"
SAFE_MODE=1
DEBUG_MODE=0
```

### Configuración de Perfil
Perfiles de análisis personalizados en `_DJProducerTools/config/profiles/`

## Variables de Entorno

| Variable | Propósito | Ejemplo |
|----------|-----------|---------|
| `DJ_SAFE_LOCK` | Habilitar protecciones de seguridad | `1` o `0` |
| `DEBUG_MODE` | Habilitar salida detallada | `0` (default), `1` |
| `DRYRUN_FORCE` | Forzar modo dry-run | `0` (default), `1` |
| `ML_ENV_DISABLED` | Desabilitar características ML | `0` (default), `1` |

## Códigos de Retorno

| Código | Significado |
|--------|-------------|
| 0 | Éxito |
| 1 | Error general |
| 2 | Argumentos inválidos |
| 3 | Permiso denegado |
| 4 | Archivo no encontrado |
| 5 | Directorio no encontrado |

## Códigos de Salida

```bash
exit 0   # Ejecución exitosa
exit 1   # Error general
exit 2   # Ruta inválida
exit 3   # Dependencias faltantes
```

## Formatos de Archivo

### Índice de Hash (JSON)
```json
{
  "generated": "2024-01-04T08:30:00Z",
  "hashes": {
    "hash_sha256": {
      "path": "/ruta/a/archivo.mp3",
      "size": 5242880,
      "modified": "2024-01-04"
    }
  }
}
```

### Plan de Duplicados (JSON)
```json
{
  "timestamp": "2024-01-04T08:30:00Z",
  "duplicates": [
    {
      "hash": "abc123...",
      "count": 2,
      "files": [
        {"path": "/ruta/a/archivo1.mp3", "size": 5242880},
        {"path": "/ruta/a/archivo2.mp3", "size": 5242880}
      ]
    }
  ]
}
```

## Manejo de Errores

Todas las funciones siguen el manejo estándar de errores:
```bash
nombre_funcion() {
    if [ ! -d "$1" ]; then
        printf "%s[ERROR] Directorio no encontrado: %s%s\n" "$C_RED" "$1" "$C_RESET" >&2
        return 1
    fi
    # ... lógica de la función ...
    return 0
}
```

## Pruebas

Suite de pruebas: `tests/test_runner_fixed.sh`

Ejecutar todas las pruebas:
```bash
bash tests/test_runner_fixed.sh
```

## Depuración

Habilitar salida de depuración:
```bash
DEBUG_MODE=1 ./DJProducerTools_MultiScript_ES.sh
```

## Versión

Versión actual: 1.0.0
Ver archivo `VERSION` para más detalles.

## Contribuyendo

Ver `CONTRIBUTING_ES.md` para guías de desarrollo.
