# DJProducerTools

Toolkit para limpiar y organizar bibliotecas de DJ/producer en macOS. Incluye dos scripts:

- `DJProducerTools_MultiScript_ES.sh` – interfaz en español.
- `DJProducerTools_MultiScript_EN.sh` – interfaz en inglés.

## Requisitos
- macOS con bash (se re-ejecuta solo con bash si abres con doble clic).
- Acceso de lectura/escritura a tus carpetas de música/proyectos.

## Instalación rápida
Guarda ambos scripts con un solo comando (puedes pegarlo en tu terminal):

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

## Uso
```bash
./DJProducerTools_MultiScript_ES.sh   # versión en español
# o
./DJProducerTools_MultiScript_EN.sh   # versión en inglés
```

Si lo abres con doble clic, el script mantiene la ventana abierta al terminar para que puedas ver los mensajes.

## Nota
Este repositorio solo contiene scripts; no se suben datos ni configuraciones personales.

## Guía completa
Consulta `GUIDE.md` para ver instalación, uso y recursos visuales.

## Cadenas automatizadas
- Menú 68 (o tecla A/a) abre 21 flujos predefinidos: backup+snapshot, dedup+quarantine, limpieza de metadatos/nombres, health scan, prep de show, integridad/corruptos, eficiencia, ML básica, backup predictivo, sync multiplataforma, diagnóstico rápido, salud Serato, hash+mirror check, audio prep (tags+LUFS+cues), auditoría de integridad, limpieza+backup seguro, preparación de sync, salud de visuales, organización audio avanzada, seguridad Serato reforzada y dedup multi-disco con mirror check.

## Licencia
DJProducerTools License (Attribution + Revenue Share). Consulta el archivo `LICENSE`.
