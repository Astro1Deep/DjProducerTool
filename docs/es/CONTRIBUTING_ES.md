# Contribuyendo a DJProducerTools

## Descripción General
DJProducerTools es un proyecto de código abierto dedicado a ayudar a DJs y productores a gestionar sus bibliotecas de música de manera eficiente y segura.

## Primeros Pasos

### Requisitos Previos
- macOS 10.15+
- bash 4.0+
- git

### Configuración de Desarrollo
```bash
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool
```

## Estándares de Código

### Directrices para Scripts Bash
1. **Shebang**: Siempre usa `#!/usr/bin/env bash`
2. **Manejo de Errores**: Usa `set -u` para detectar variables indefinidas
3. **Códigos de Color**: Usa las constantes de color definidas (C_RED, C_GRN, etc.)
4. **Comentarios**: Mantén los comentarios breves y solo para lógica compleja
5. **Nombres de Variables**: Usa MAYÚSCULAS para constantes, minúsculas para locales
6. **Nombres de Funciones**: Usa snake_case, prefijo con guión bajo si es interno

### Directrices para Python
1. **Estilo**: Sigue PEP 8
2. **Linting**: Usa `pylint` o `black`
3. **Pruebas**: Escribe pruebas unitarias para nuevas funciones
4. **Documentación**: Incluye docstrings para todas las funciones

## Pruebas

Ejecuta la suite de pruebas antes de enviar:
```bash
bash tests/test_runner_fixed.sh
```

## Localización

- Inglés: `DJProducerTools_MultiScript_EN.sh`
- Español: `DJProducerTools_MultiScript_ES.sh`

Mantén ambos archivos sincronizados cuando hagas cambios.

## Reportar Problemas

Incluye:
- Versión de macOS
- Versión de bash
- Mensaje de error exacto
- Pasos para reproducir
- Comportamiento esperado

## Proceso de Pull Request

1. Fork del repositorio
2. Crea una rama de características (`git checkout -b feature/amazing-feature`)
3. Prueba exhaustivamente
4. Commit con mensajes claros
5. Push y crea Pull Request
6. Responde a las revisiones rápidamente

## Licencia
Al contribuir, aceptas licenciar tus contribuciones bajo la Licencia de DJProducerTools.

¡Gracias por mejorar DJProducerTools! 🎵
