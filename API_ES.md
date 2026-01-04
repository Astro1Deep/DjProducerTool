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

---

**Versión**: 2.0.0  
**Licencia**: DJProducerTools License
