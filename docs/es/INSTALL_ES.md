# Guía de Instalación

## Instalación Rápida

### Para Usuarios Finales
```bash
curl -sL https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/install_djpt.sh | bash
```

Esto descarga e instala la versión estable más reciente.

### Para Desarrolladores
```bash
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool
source .venv/bin/activate  # Entorno Python opcional
```

## Requisitos del Sistema

- **SO**: macOS 10.15 (Catalina) o posterior
- **Shell**: bash 4.0+ (macOS incluye 3.2, pero se auto-actualiza)
- **Espacio**: 2GB libres (para entorno virtual)
- **Permisos**: Acceso lectura/escritura a bibliotecas de música

## Dependencias Opcionales

La herramienta auto-detecta e instala estas según sea necesario:

| Herramienta | Propósito | Instalación |
|------------|-----------|-------------|
| `ffmpeg` | Detección de audio | `brew install ffmpeg` |
| `ffprobe` | Análisis de medios | `brew install ffmpeg` |
| `sox` | Conversión de audio | `brew install sox` |
| `jq` | Procesamiento JSON | `brew install jq` |
| `python3` | Características ML | `brew install python3` |

## Métodos de Instalación

### Método 1: Script Automatizado
```bash
bash install_djpt.sh
```

### Método 2: Clone Manual de Git
```bash
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool
chmod +x DJProducerTools_MultiScript_*.sh
```

### Método 3: Paquete Instalador macOS
```bash
./build_macos_pkg.sh
# Sigue el instalador gráfico
```

## Configuración

### Primera Ejecución
1. Ejecuta el script: `./DJProducerTools_MultiScript_EN.sh` o `_ES.sh`
2. Selecciona Opción 2: Cambiar Ruta Base
3. Apunta a la raíz de tu biblioteca de música
4. La herramienta auto-crea el directorio de configuración `_DJProducerTools`

### Archivos de Configuración
Ubicados en `BASE_PATH/_DJProducerTools/config/`:
- `djpt.conf` - Configuración principal
- `profiles/` - Perfiles de análisis personalizados
- `audio_history.txt` - Historial de biblioteca de audio

## Verificación

Después de la instalación, verifica:
```bash
# Comprueba que los scripts sean ejecutables
ls -l DJProducerTools_MultiScript_*.sh

# Ejecuta pruebas
bash tests/test_runner_fixed.sh

# Prueba el menú de ayuda
./DJProducerTools_MultiScript_EN.sh --help
```

## Desinstalación

### Eliminar Instalación de Usuario
```bash
rm -f /usr/local/bin/djproducertool
rm -rf ~/.djproducertool
```

### Eliminar Clone de Git
```bash
cd /path/to/DjProducerTool
rm -rf .git _DJProducerTools .venv
```

## Solución de Problemas

### El Script No Se Ejecutará
```bash
# Asegúrate de tener los permisos correctos
chmod +x DJProducerTools_MultiScript_*.sh

# Verifica la versión de bash
bash --version  # Debería ser 4.0+
```

### Dependencias de Python Faltantes
```bash
# Instala los paquetes Python requeridos
python3 -m pip install numpy pandas scikit-learn joblib librosa

# O usa la configuración automática desde la opción de menú 70
```

### Errores de Permiso
```bash
# Corrige la propiedad de los archivos
sudo chown -R $(whoami) /path/to/music/library
```

## Obteniendo Ayuda

- **Documentación**: Ver `GUIDE.md` o `GUIDE_es.md`
- **Problemas**: [GitHub Issues](https://github.com/Astro1Deep/DjProducerTool/issues)
- **Contribuyendo**: Ver `CONTRIBUTING.md`

## Próximos Pasos

1. Lee la [Guía de Inicio Rápido](GUIDE_es.md)
2. Ejecuta Verificación de Estado (Opción 1) para ver tu biblioteca
3. Crea tu primer backup (Opción 7)
4. Prueba Análisis Inteligente (Opción 59)
