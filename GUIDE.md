# Guía rápida DJProducerTools

Scripts Bash para limpiar y organizar bibliotecas de DJ/producer en macOS. Incluyen interfaz en español e inglés con banners diferenciados por gradiente.

## Archivos principales
- `DJProducerTools_MultiScript_ES.sh` – interfaz en español.
- `DJProducerTools_MultiScript_EN.sh` – interfaz en inglés.
- Instalador simple: `install_djpt.sh` o un solo comando con `curl` (abajo).

## Instalación rápida
```bash
cat <<'EOF' > install_djpt.sh
#!/usr/bin/env bash
set -e
for f in DJProducerTools_MultiScript_ES.sh DJProducerTools_MultiScript_EN.sh; do
  url="https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/$f"
  curl -fsSL "$url" -o "$f"
  chmod +x "$f"
done
echo "Listo. Ejecuta ./DJProducerTools_MultiScript_ES.sh o ./DJProducerTools_MultiScript_EN.sh"
EOF
chmod +x install_djpt.sh
./install_djpt.sh
```

## Uso básico
```bash
./DJProducerTools_MultiScript_ES.sh   # versión en español
./DJProducerTools_MultiScript_EN.sh   # versión en inglés
```
- Si lo abres con doble clic, el script mantiene la ventana abierta al terminar y muestra el mensaje final.
- El script crea `_DJProducerTools/` dentro del directorio donde se ejecuta para configs, logs y planes.

## Qué hace
- Escanear estado de tu volumen y carpetas base.
- Backups seguros de metadatos Serato/Traktor/Rekordbox/Ableton.
- Índices y reportes (sha256, duplicados, integridad de media).
- Herramientas de mirror/organización y presets de exclusiones (audio, proyectos).
- Menús agrupados (Core, Media, Doctor, etc.) con líneas de estado y spinner 👻.
- Menú 68: “Cadenas automatizadas” con 10 flujos predefinidos (backup + snapshot, dedup + quarantine, limpieza de metadatos/nombres, prep de show, integridad, eficiencia, ML básico, backup predictivo, sync multiplataforma).

## Banners y color
- Ambos scripts usan el mismo banner ASCII; el gradiente es distinto por idioma:
  - EN: degradado frío→cálido (`GRN, CYN, BLU, PURP, RED, YLW`).
  - ES: degradado cálido→frío (`PURP, RED, YLW, GRN, CYN, BLU`).

## Rutas y datos
- Configuración, reportes y planes viven en `_DJProducerTools/` (ignorada en git).
- Si `BASE_PATH` no es válido, el script te pedirá elegir o escribir uno.
- Soporta histórico de rutas para sugerencias rápidas.

## Licencia y atribución
- Licencia: DJProducerTools License (Attribution + Revenue Share). Crédito obligatorio.
- Uso comercial o de derivados requiere notificar y compartir el 20% de ingresos brutos con el autor (ver `LICENSE`).

## Recursos visuales
- Ejemplos de banner:
  - Español: `docs/banner_es.png`
  - Inglés: `docs/banner_en.png`

## Actualización
```
git pull
./install_djpt.sh   # vuelve a descargar la última versión
```

## Soporte
- Autor: Astro One Deep (onedeep1@gmail.com)
- Issues/sugerencias: abre un issue en GitHub o envía correo.
