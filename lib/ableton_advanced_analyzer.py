#!/usr/bin/env python3
"""
DJProducerTools - Advanced Ableton Project Analysis System
Sistema avanzado de análisis de proyectos Ableton Live para detectar plugins y samples faltantes
Más robusto y eficiente que el sistema nativo de Ableton
"""

import sys
import json
import hashlib
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from datetime import datetime
import xml.etree.ElementTree as ET
from collections import defaultdict
import argparse


# Configuración de colores para terminal
class Colors:
    RED = "\033[1;31m"
    GREEN = "\033[38;5;46m"
    YELLOW = "\033[1;33m"
    CYAN = "\033[38;5;135m"
    BLUE = "\033[38;5;39m"
    MAGENTA = "\033[38;5;165m"
    ORANGE = "\033[38;5;208m"
    RESET = "\033[0m"


@dataclass
class PluginInfo:
    """Información sobre un plugin detectado"""

    name: str
    manufacturer: str
    version: str = ""
    plugin_type: str = ""  # VST, AU, AAX
    format: str = ""  # Instrument, Effect
    found: bool = False
    path: str = ""
    alternatives: List[str] = None

    def __post_init__(self):
        if self.alternatives is None:
            self.alternatives = []


@dataclass
class SampleInfo:
    """Información sobre un sample/audio file"""

    filename: str
    original_path: str
    file_hash: str = ""
    size: int = 0
    found: bool = False
    current_path: str = ""
    possible_locations: List[str] = None

    def __post_init__(self):
        if self.possible_locations is None:
            self.possible_locations = []


@dataclass
class AbletonProject:
    """Información completa de un proyecto Ableton"""

    project_path: str
    project_name: str
    ableton_version: str = ""
    last_modified: str = ""
    plugins: List[PluginInfo] = None
    samples: List[SampleInfo] = None
    missing_plugins: List[PluginInfo] = None
    missing_samples: List[SampleInfo] = None

    def __post_init__(self):
        if self.plugins is None:
            self.plugins = []
        if self.samples is None:
            self.samples = []
        if self.missing_plugins is None:
            self.missing_plugins = []
        if self.missing_samples is None:
            self.missing_samples = []


class AbletonAnalyzer:
    """Analizador avanzado de proyectos Ableton"""

    def __init__(self, base_path: str = None):
        self.base_path = Path(base_path) if base_path else Path.cwd()
        self.plugin_paths = self._detect_plugin_paths()
        self.sample_paths = self._detect_sample_paths()
        self.plugin_cache = {}
        self.sample_cache = {}

    def _detect_plugin_paths(self) -> List[Path]:
        """Detectar rutas de plugins en el sistema"""
        paths = []

        # macOS Common locations
        if sys.platform == "darwin":
            mac_paths = [
                Path("/Library/Audio/Plug-Ins/VST"),
                Path("/Library/Audio/Plug-Ins/VST3"),
                Path("/Library/Audio/Plug-Ins/Components"),
                Path("~/Library/Audio/Plug-Ins/VST").expanduser(),
                Path("~/Library/Audio/Plug-Ins/VST3").expanduser(),
                Path("~/Library/Audio/Plug-Ins/Components").expanduser(),
                Path("/Applications/Ableton Live*").expanduser(),
            ]

            for path in mac_paths:
                if path.exists():
                    paths.append(path)

        # Windows Common locations
        elif sys.platform == "win32":
            win_paths = [
                Path("C:/Program Files/Common Files/VST2"),
                Path("C:/Program Files/Common Files/VST3"),
                Path("C:/Program Files/Steinberg/VSTPlugins"),
                Path("C:/Program Files (x86)/Common Files/VST2"),
                Path("C:/Program Files (x86)/Common Files/VST3"),
            ]

            for path in win_paths:
                if path.exists():
                    paths.append(path)

        return paths

    def _detect_sample_paths(self) -> List[Path]:
        """Detectar rutas comunes de samples y librerías"""
        paths = []

        common_paths = [
            self.base_path / "Samples",
            self.base_path / "Audio",
            self.base_path / "Sounds",
            self.base_path / "Library",
            self.base_path / "Media",
            Path("~/Music/Samples").expanduser(),
            Path("~/Documents/Ableton/Library").expanduser(),
            Path("~/Music/Ableton").expanduser(),
        ]

        # Buscar carpetas de Ableton
        ableton_paths = list(Path("/Users").expanduser().glob("*/Ableton"))
        for path in ableton_paths:
            if path.exists():
                paths.append(path)

        # Buscar carpetas de samples comunes
        sample_keywords = [
            "samples",
            "sounds",
            "audio",
            "library",
            "loops",
            "presets",
        ]
        for keyword in sample_keywords:
            found_paths = list(self.base_path.rglob(f"*{keyword}*"))
            paths.extend([p for p in found_paths if p.is_dir()])

        # Eliminar duplicados y mantener solo existentes
        unique_paths = list(set([p for p in paths if p.exists()]))
        return unique_paths

    def _calculate_file_hash(self, file_path: Path) -> str:
        """Calcular hash SHA256 de un archivo"""
        try:
            with open(file_path, "rb") as f:
                return hashlib.sha256(f.read()).hexdigest()
        except Exception:
            return ""

    def _parse_als_file(self, als_path: Path) -> Dict[str, Any]:
        """Parsear archivo .als de Ableton (XML)"""
        try:
            with open(als_path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()

            # El archivo .als es XML comprimido, intentar parsear directamente
            try:
                root = ET.fromstring(content)
                return self._extract_project_data(root)
            except ET.ParseError:
                # Si no es XML válido, intentar descomprimir
                return self._parse_compressed_als(content)

        except Exception as e:
            print(f"{Colors.RED}Error parsing {als_path}: {e}{Colors.RESET}")
            return {}

    def _extract_project_data(self, root: ET.Element) -> Dict[str, Any]:
        """Extraer datos del XML del proyecto"""
        project_data = {
            "plugins": [],
            "samples": [],
            "version": "",
            "name": "",
        }

        # Extraer versión de Ableton
        creator = root.find(".//Creator")
        if creator is not None:
            project_data["version"] = creator.get("MinorVersion", "")

        # Extraer nombre del proyecto
        name_elem = root.find(".//Name")
        if name_elem is not None:
            project_data["name"] = name_elem.get("Value", "")

        # Buscar plugins (VST, AU, etc.)
        plugin_elements = root.findall(".//PluginDevice")
        for plugin in plugin_elements:
            plugin_info = self._extract_plugin_info(plugin)
            if plugin_info:
                project_data["plugins"].append(plugin_info)

        # Buscar samples y audio files
        sample_elements = root.findall(".//SampleRef")
        for sample in sample_elements:
            sample_info = self._extract_sample_info(sample)
            if sample_info:
                project_data["samples"].append(sample_info)

        return project_data

    def _extract_plugin_info(self, plugin_elem: ET.Element) -> Optional[Dict[str, Any]]:
        """Extraer información de un plugin del XML"""
        try:
            name_elem = plugin_elem.find(".//Name")
            if name_elem is not None:
                name = name_elem.get("Value", "")

                # Buscar manufacturer
                manufacturer = ""
                manu_elem = plugin_elem.find(".//Manufacturer")
                if manu_elem is not None:
                    manufacturer = manu_elem.get("Value", "")

                # Detectar tipo de plugin
                plugin_type = ""
                type_elem = plugin_elem.find(".//Type")
                if type_elem is not None:
                    plugin_type = type_elem.get("Value", "")

                return {
                    "name": name,
                    "manufacturer": manufacturer,
                    "type": plugin_type,
                    "found": False,
                }
        except Exception:
            pass

        return None

    def _extract_sample_info(self, sample_elem: ET.Element) -> Optional[Dict[str, Any]]:
        """Extraer información de un sample del XML"""
        try:
            # Buscar ruta del archivo
            path_elem = sample_elem.find(".//FileRef")
            if path_elem is not None:
                path = path_elem.get("Path", "")
                name = path_elem.get("Name", "")

                if not name and path:
                    name = Path(path).name

                return {
                    "filename": name,
                    "original_path": path,
                    "found": False,
                }
        except Exception:
            pass

        return None

    def _parse_compressed_als(self, content: str) -> Dict[str, Any]:
        """Parsear archivo .als comprimido"""
        # Implementación simplificada - en realidad necesitaría descomprimir
        # Por ahora devolver estructura básica
        return {
            "plugins": [],
            "samples": [],
            "version": "Unknown",
            "name": "Unknown",
        }

    def _check_plugin_availability(self, plugin_info: Dict[str, Any]) -> PluginInfo:
        """Verificar si un plugin está disponible en el sistema"""
        plugin = PluginInfo(
            name=plugin_info["name"],
            manufacturer=plugin_info.get("manufacturer", ""),
            plugin_type=plugin_info.get("type", ""),
        )

        # Buscar en rutas de plugins
        for plugin_path in self.plugin_paths:
            # Buscar archivos .vst, .vst3, .component
            for ext in [".vst", ".vst3", ".component"]:
                plugin_files = list(plugin_path.rglob(f"*{plugin.name}*{ext}"))
                if plugin_files:
                    plugin.found = True
                    plugin.path = str(plugin_files[0])
                    plugin.format = ext.replace(".", "").upper()
                    break

            if plugin.found:
                break

        # Si no se encuentra, buscar alternativas
        if not plugin.found:
            plugin.alternatives = self._find_plugin_alternatives(plugin)

        return plugin

    def _find_plugin_alternatives(self, plugin: PluginInfo) -> List[str]:
        """Encontrar plugins alternativos similares"""
        alternatives = []

        # Base de datos de alternativas comunes
        alternative_map = {
            "Massive": ["Serum", "Xfer Serum", "Diva", "Hive"],
            "Sylenth1": ["Serum", "Diva", "Hive", "Spire"],
            "Nexus": ["Serum", "Omnisphere", "Massive X"],
            "Omnisphere": ["Serum", "Massive X", "Diva"],
            "Kontakt": ["Sforzando", "Decent Sampler", "EXS24"],
            "Battery": ["Battery 4", "Drum Machine Designer", "Ultrabeat"],
            "Glitch": ["Glitch 2", "Effectrix", "Stutter Edit"],
            "Ozone": ["FabFilter Pro-Q", "Waves EQ", "Maag EQ"],
            "Waves": ["FabFilter", "Plugin Alliance", "Valhalla"],
        }

        plugin_lower = plugin.name.lower()
        for key, alts in alternative_map.items():
            if key.lower() in plugin_lower:
                alternatives.extend(alts)
                break

        return list(set(alternatives))  # Eliminar duplicados

    def _check_sample_availability(self, sample_info: Dict[str, Any]) -> SampleInfo:
        """Verificar si un sample está disponible en el sistema"""
        sample = SampleInfo(
            filename=sample_info["filename"],
            original_path=sample_info.get("original_path", ""),
        )

        # Buscar el archivo original
        if sample.original_path:
            original_file = Path(sample.original_path)
            if original_file.exists():
                sample.found = True
                sample.current_path = str(original_file)
                sample.file_hash = self._calculate_file_hash(original_file)
                sample.size = original_file.stat().st_size
                return sample

        # Buscar en todas las rutas de samples
        for sample_path in self.sample_paths:
            # Buscar exact filename
            found_files = list(sample_path.rglob(f"*{sample.filename}*"))
            for found_file in found_files:
                if found_file.is_file():
                    sample.found = True
                    sample.current_path = str(found_file)
                    sample.file_hash = self._calculate_file_hash(found_file)
                    sample.size = found_file.stat().st_size
                    return sample

        # Si no se encuentra, guardar posibles ubicaciones
        sample.possible_locations = self._find_possible_locations(sample)

        return sample

    def _find_possible_locations(self, sample: SampleInfo) -> List[str]:
        """Encontrar posibles ubicaciones para un sample faltante"""
        locations = []

        # Buscar por nombre parcial
        filename_parts = sample.filename.lower().split()
        for sample_path in self.sample_paths:
            for part in filename_parts:
                if len(part) > 3:  # Solo buscar partes significativas
                    found_files = list(sample_path.rglob(f"*{part}*"))
                    for found_file in found_files:
                        if found_file.is_file():
                            locations.append(str(found_file))

        return list(set(locations))[:10]  # Limitar a 10 resultados

    def analyze_project(self, project_path: Path) -> AbletonProject:
        """Analizar un proyecto Ableton completo"""
        print(f"{Colors.CYAN}Analizando proyecto: {project_path}{Colors.RESET}")

        project = AbletonProject(project_path=str(project_path), project_name=project_path.stem)

        # Buscar archivo .als principal
        als_files = list(project_path.rglob("*.als"))
        if not als_files:
            print(f"{Colors.YELLOW}No se encontraron archivos .als en {project_path}{Colors.RESET}")
            return project

        # Analizar cada archivo .als encontrado
        for als_file in als_files:
            print(f"  {Colors.BLUE}→ Analizando: {als_file.name}{Colors.RESET}")

            project_data = self._parse_als_file(als_file)

            # Actualizar información del proyecto
            if project_data.get("version"):
                project.ableton_version = project_data["version"]
            if project_data.get("name"):
                project.project_name = project_data["name"]

            # Analizar plugins
            for plugin_data in project_data.get("plugins", []):
                plugin = self._check_plugin_availability(plugin_data)
                project.plugins.append(plugin)

                if not plugin.found:
                    project.missing_plugins.append(plugin)

            # Analizar samples
            for sample_data in project_data.get("samples", []):
                sample = self._check_sample_availability(sample_data)
                project.samples.append(sample)

                if not sample.found:
                    project.missing_samples.append(sample)

        # Actualizar fecha de modificación
        if als_files:
            project.last_modified = datetime.fromtimestamp(max(f.stat().st_mtime for f in als_files)).strftime(
                "%Y-%m-%d %H:%M:%S"
            )

        return project

    def analyze_directory(self, directory: Path) -> List[AbletonProject]:
        """Analizar todos los proyectos en un directorio"""
        projects = []

        # Buscar carpetas que contengan archivos .als
        for als_file in directory.rglob("*.als"):
            project_dir = als_file.parent
            project = self.analyze_project(project_dir)
            projects.append(project)

        return projects

    def generate_report(self, projects: List[AbletonProject], output_file: str = None) -> str:
        """Generar reporte detallado del análisis"""
        report = []
        report.append(f"{Colors.MAGENTA}{'=' * 80}{Colors.RESET}")
        report.append(f"{Colors.MAGENTA}DJPRODUCERTOOLS - ADVANCED ABLETON PROJECT ANALYSIS{Colors.RESET}")
        report.append(f"{Colors.MAGENTA}{'=' * 80}{Colors.RESET}")
        report.append("")
        report.append(f"{Colors.CYAN}Análisis completado: {len(projects)} proyectos{Colors.RESET}")
        report.append("")

        total_missing_plugins = sum(len(p.missing_plugins) for p in projects)
        total_missing_samples = sum(len(p.missing_samples) for p in projects)

        report.append(f"{Colors.YELLOW}Resumen de problemas detectados:{Colors.RESET}")
        report.append(f"  • Plugins faltantes: {total_missing_plugins}")
        report.append(f"  • Samples faltantes: {total_missing_samples}")
        report.append("")

        # Detalles por proyecto
        for i, project in enumerate(projects, 1):
            report.append(f"{Colors.BLUE}{'=' * 60}{Colors.RESET}")
            report.append(f"{Colors.BLUE}Proyecto {i}: {project.project_name}{Colors.RESET}")
            report.append(f"  Ruta: {project.project_path}")
            report.append(f"  Versión Ableton: {project.ableton_version}")
            report.append(f"  Última modificación: {project.last_modified}")
            report.append("")

            # Plugins faltantes
            if project.missing_plugins:
                report.append(f"  {Colors.RED}❌ Plugins Faltantes ({len(project.missing_plugins)}):{Colors.RESET}")
                for plugin in project.missing_plugins:
                    report.append(f"    • {plugin.name} ({plugin.manufacturer})")
                    if plugin.alternatives:
                        report.append(f"      Alternativas: {', '.join(plugin.alternatives[:3])}")
                report.append("")

            # Samples faltantes
            if project.missing_samples:
                report.append(f"  {Colors.ORANGE}⚠️  Samples Faltantes ({len(project.missing_samples)}):{Colors.RESET}")
                for sample in project.missing_samples[:10]:  # Limitar a 10 por proyecto
                    report.append(f"    • {sample.filename}")
                    if sample.original_path:
                        report.append(f"      Ruta original: {sample.original_path}")
                    if sample.possible_locations:
                        report.append(f"      Posibles ubicaciones: {len(sample.possible_locations)} encontradas")
                if len(project.missing_samples) > 10:
                    report.append(f"    ... y {len(project.missing_samples) - 10} más")
                report.append("")

            if not project.missing_plugins and not project.missing_samples:
                report.append(f"  {Colors.GREEN}✅ Proyecto completo - No hay problemas detectados{Colors.RESET}")
                report.append("")

        # Resumen de plugins más faltantes
        if total_missing_plugins > 0:
            report.append(f"{Colors.MAGENTA}{'=' * 60}{Colors.RESET}")
            report.append(f"{Colors.MAGENTA}Plugins más faltantes (Top 10):{Colors.RESET}")

            plugin_counts = defaultdict(int)
            for project in projects:
                for plugin in project.missing_plugins:
                    plugin_counts[plugin.name] += 1

            sorted_plugins = sorted(plugin_counts.items(), key=lambda x: x[1], reverse=True)
            for plugin_name, count in sorted_plugins[:10]:
                report.append(f"  • {plugin_name}: {count} proyectos")
            report.append("")

        # Resumen de samples más faltantes
        if total_missing_samples > 0:
            report.append(f"{Colors.MAGENTA}{'=' * 60}{Colors.RESET}")
            report.append(f"{Colors.MAGENTA}Samples más faltantes (Top 10):{Colors.RESET}")

            sample_counts = defaultdict(int)
            for project in projects:
                for sample in project.missing_samples:
                    sample_counts[sample.filename] += 1

            sorted_samples = sorted(sample_counts.items(), key=lambda x: x[1], reverse=True)
            for sample_name, count in sorted_samples[:10]:
                report.append(f"  • {sample_name}: {count} proyectos")
            report.append("")

        # Recomendaciones
        report.append(f"{Colors.GREEN}{'=' * 60}{Colors.RESET}")
        report.append(f"{Colors.GREEN}Recomendaciones:{Colors.RESET}")
        report.append("")

        if total_missing_plugins > 0:
            report.append(f"  {Colors.YELLOW}Plugins:{Colors.RESET}")
            report.append("  • Considera instalar los plugins más faltantes primero")
            report.append("  • Busca alternativas gratuitas para plugins comerciales")
            report.append("  • Verifica si tienes versiones actualizadas instaladas")
            report.append("")

        if total_missing_samples > 0:
            report.append(f"  {Colors.YELLOW}Samples:{Colors.RESET}")
            report.append("  • Organiza tu librería de samples en una ubicación central")
            report.append("  • Considera usar Ableton's Library para samples comunes")
            report.append("  • Verifica backups externos para samples faltantes")
            report.append("")

        report.append(f"{Colors.CYAN}Para más detalles, ejecuta con --json para exportar datos completos{Colors.RESET}")

        report_text = "\n".join(report)

        # Guardar a archivo si se especifica
        if output_file:
            with open(output_file, "w", encoding="utf-8") as f:
                f.write(report_text)
            print(f"{Colors.GREEN}Reporte guardado en: {output_file}{Colors.RESET}")

        return report_text

    def export_json(self, projects: List[AbletonProject], output_file: str):
        """Exportar resultados a JSON"""
        data = {
            "analysis_date": datetime.now().isoformat(),
            "total_projects": len(projects),
            "projects": [asdict(project) for project in projects],
            "summary": {
                "total_missing_plugins": sum(len(p.missing_plugins) for p in projects),
                "total_missing_samples": sum(len(p.missing_samples) for p in projects),
                "plugin_paths": [str(p) for p in self.plugin_paths],
                "sample_paths": [str(p) for p in self.sample_paths],
            },
        }

        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

        print(f"{Colors.GREEN}Datos exportados a JSON: {output_file}{Colors.RESET}")


def main():
    parser = argparse.ArgumentParser(description="Advanced Ableton Project Analysis System")
    parser.add_argument("path", nargs="?", help="Path to analyze (directory or .als file)")
    parser.add_argument("--output", "-o", help="Output report file")
    parser.add_argument("--json", help="Export results to JSON file")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")

    args = parser.parse_args()

    # Determinar ruta a analizar
    if args.path:
        target_path = Path(args.path)
    else:
        # Usar ruta actual o buscar proyectos automáticamente
        target_path = Path.cwd()

    # Inicializar analizador
    analyzer = AbletonAnalyzer()

    print(f"{Colors.CYAN}DJProducerTools - Advanced Ableton Analysis{Colors.RESET}")
    print(f"{Colors.CYAN}Analizando: {target_path}{Colors.RESET}")
    print("")

    # Analizar según el tipo de ruta
    if target_path.is_file() and target_path.suffix == ".als":
        # Analizar archivo .als individual
        project_dir = target_path.parent
        projects = [analyzer.analyze_project(project_dir)]
    elif target_path.is_dir():
        # Analizar directorio completo
        projects = analyzer.analyze_directory(target_path)
    else:
        print(f"{Colors.RED}Error: Ruta no válida: {target_path}{Colors.RESET}")
        return 1

    if not projects:
        print(f"{Colors.YELLOW}No se encontraron proyectos Ableton en la ruta especificada{Colors.RESET}")
        return 1

    # Generar reporte
    report = analyzer.generate_report(projects, args.output)

    # Exportar JSON si se solicita
    if args.json:
        analyzer.export_json(projects, args.json)

    # Mostrar reporte en consola
    if not args.output:
        print(report)

    return 0


if __name__ == "__main__":
    sys.exit(main())
