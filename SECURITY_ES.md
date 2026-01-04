# Política de Seguridad

## Reportar Vulnerabilidades de Seguridad

**NO** abras problemas públicos para vulnerabilidades de seguridad. En su lugar, envía un correo a: `security@astro1deep.com`

Por favor incluye:
1. Descripción de la vulnerabilidad
2. Pasos para reproducir
3. Impacto potencial
4. Corrección sugerida (si está disponible)

Nosotros:
- Confirmaremos recepción dentro de 48 horas
- Proporcionaremos actualizaciones de estado semanalmente
- Te acreditaremos en el aviso de seguridad (a menos que prefieras anonimato)
- Trabajaremos contigo en un cronograma de corrección

## Mejores Prácticas de Seguridad

### Modo Seguro
Siempre ejecuta con `SAFE_MODE=1` (por defecto):
- Previene eliminación accidental de archivos
- Requiere confirmación antes de operaciones destructivas
- Mantiene registros detallados de todos los cambios

### Copias de Seguridad
La herramienta automáticamente:
- Crea copias de seguridad con marca de tiempo antes de modificaciones
- Preserva archivos originales en cuarentena por 30 días
- Mantiene sumas de verificación de integridad

### Permisos
- Nunca se ejecuta con `sudo` a menos que sea explícitamente necesario
- Respeta propiedad de archivos y permisos
- No modificará archivos que no poseas

### Aislamiento
- Las características ML se ejecutan en entorno virtual aislado
- Sin llamadas de red sin permiso del usuario
- Ningún dato enviado a servidores externos

## Versiones Soportadas

| Versión | Estado | Hasta |
|---------|--------|-------|
| 2.0.0 | Soportada | 2025-01-04 |
| 1.9.5 | Solo correcciones de seguridad | 2024-07-04 |
| < 1.9.5 | No soportada | - |

## Cronograma de Divulgación

Nuestra política de divulgación de vulnerabilidades:
- **Día 0**: Vulnerabilidad reportada
- **Día 1**: Reconocimiento inicial
- **Día 7**: Desarrollo de parche comienza
- **Día 21**: Parche lanzado (o cronograma negociado)
- **Día 30**: Divulgación pública (si no se corrige, cronograma extendido)

## Limitaciones Conocidas

### Sistema de Archivos
- Limitado a sistemas de archivos de macOS (HFS+, APFS)
- Los enlaces simbólicos pueden no funcionar como se esperaba
- Unidades de red no recomendadas para rendimiento

### Memoria
- Bibliotecas grandes (>100K archivos) pueden requerir optimización
- Mínimo recomendado 8GB RAM
- Aumenta espacio en disco disponible para procesamiento

## Dependencias

### Críticas
- bash 4.0+ (incluido en macOS)
- Utilidades Unix estándar (grep, find, sed, awk)

### Consideraciones de Seguridad
- ffmpeg: Puede procesar archivos de audio no confiables (aislado via entorno)
- Python: Ejecución local solamente, sin acceso a red
- jq: Análisis JSON de archivos potencialmente no confiables

## Conformidad

Esta herramienta:
- ✅ No recopila telemetría
- ✅ No requiere creación de cuenta
- ✅ No accede a Internet por defecto
- ✅ Respeta privacidad de archivos
- ✅ Permite operación completamente offline

## Actualizaciones de Seguridad

Las actualizaciones de seguridad se lanzan como versiones de parche (p. ej., 2.0.1) y se aplican a las versiones actual y anterior.

Para verificar actualizaciones:
```bash
# Verificar versión
cat VERSION

# O usar actualizador incorporado (Opción 3 en menú)
```

## Auditoría

Todas las operaciones crean registros de auditoría en:
```
_DJProducerTools/logs/audit_YYYY-MM-DD.txt
```

Habilitar registro completo:
```bash
DEBUG_MODE=1 ./DJProducerTools_MultiScript_ES.sh
```

## Contribuyendo Correcciones de Seguridad

1. Envía correo a `security@astro1deep.com` primero
2. No hagas commit en repositorio público
3. Incluye casos de prueba
4. Proporciona explicación detallada

¡Gracias por ayudar a mantener DJProducerTools seguro! 🛡️
