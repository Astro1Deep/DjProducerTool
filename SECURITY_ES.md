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

---

**Versión**: 2.0.0  
**Creador**: Astro1Deep 🎵
