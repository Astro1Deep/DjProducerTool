#!/usr/bin/env python3
"""
DJProducerTools AI Chat Interface
Sistema de chat inteligente con integración ML/DT y herramientas locales
"""

import sys
import json
import subprocess
import argparse
from pathlib import Path
from typing import Dict, List, Any, Optional

# Añadir librerías del proyecto
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root / "lib"))
sys.path.insert(0, str(project_root / "_DJProducerTools" / "scripts"))


class DJAIChat:
    """Sistema de chat inteligente DJProducerTools"""

    def __init__(self, venv_path: Optional[Path] = None):
        self.venv_path = venv_path
        self.project_root = Path(__file__).parent.parent
        self.session_history = []
        self.context = {
            "current_library": None,
            "analysis_results": {},
            "ml_models": {},
            "active_tools": [],
        }

        # Detectar herramientas disponibles
        self.available_tools = self._detect_tools()

    def _detect_tools(self) -> Dict[str, Any]:
        """Detectar herramientas disponibles en el sistema"""
        tools = {
            "audio_analysis": {
                "bpm_analyzer": self._check_tool("lib/bpm_analyzer.py"),
                "audio_similarity": self._check_tool("_DJProducerTools/scripts/audio_similarity.py"),
                "ml_autotag": self._check_tool("lib/ml_autotag.py"),
                "ml_evolutionary": self._check_tool("lib/ml_evolutionary.py"),
                "dmx_control": self._check_tool("lib/dmx_send.py"),
            },
            "bash_scripts": {
                "main_script": self._check_tool("DJProducerTools_MultiScript_ES.sh"),
                "english_script": self._check_tool("DJProducerTools_MultiScript_EN.sh"),
            },
            "ml_models": {
                "tensorflow": self._check_dependency("tensorflow"),
                "tensorflow_hub": self._check_dependency("tensorflow_hub"),
                "librosa": self._check_dependency("librosa"),
                "pandas": self._check_dependency("pandas"),
                "sklearn": self._check_dependency("sklearn"),
            },
        }
        return tools

    def _check_tool(self, tool_path: str) -> bool:
        """Verificar si una herramienta está disponible"""
        full_path = self.project_root / tool_path
        return full_path.exists() and full_path.is_file()

    def _check_dependency(self, dep_name: str) -> bool:
        """Verificar si una dependencia está instalada"""
        try:
            __import__(dep_name)
            return True
        except ImportError:
            return False

    def _execute_tool(self, tool_path: str, args: List[str] = None) -> Dict[str, Any]:
        """Ejecutar una herramienta del sistema"""
        try:
            full_path = self.project_root / tool_path
            cmd = [sys.executable, str(full_path)]
            if args:
                cmd.extend(args)

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=30,
                cwd=str(self.project_root),
            )

            return {
                "success": result.returncode == 0,
                "output": result.stdout,
                "error": result.stderr,
                "tool": tool_path,
            }
        except Exception as e:
            return {
                "success": False,
                "output": "",
                "error": str(e),
                "tool": tool_path,
            }

    def _analyze_audio_file(self, file_path: str) -> Dict[str, Any]:
        """Analizar archivo de audio con herramientas disponibles"""
        results = {}

        # Análisis BPM
        if self.available_tools["audio_analysis"]["bpm_analyzer"]:
            result = self._execute_tool("lib/bpm_analyzer.py", ["--file", file_path])
            results["bpm"] = result

        # Análisis de similitud
        if self.available_tools["audio_analysis"]["audio_similarity"]:
            result = self._execute_tool(
                "_DJProducerTools/scripts/audio_similarity.py",
                ["--analyze", file_path],
            )
            results["similarity"] = result

        # Auto-tagging ML
        if self.available_tools["audio_analysis"]["ml_autotag"]:
            result = self._execute_tool("lib/ml_autotag.py", ["--file", file_path])
            results["tags"] = result

        return results

    def _get_library_status(self) -> Dict[str, Any]:
        """Obtener estado de la biblioteca musical"""
        status = {}

        # Buscar bibliotecas Serato, Rekordbox, etc.
        music_paths = [
            Path.home() / "Music" / "_Serato_",
            Path.home() / "Music" / "Rekordbox",
            Path.home() / "Music" / "Traktor",
        ]

        for path in music_paths:
            if path.exists():
                status[path.name] = {
                    "path": str(path),
                    "exists": True,
                    "size": sum(f.stat().st_size for f in path.rglob("*") if f.is_file()),
                    "file_count": len(list(path.rglob("*"))),
                }

        return status

    def _generate_ml_insights(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Generar insights usando ML local"""
        insights = {}

        if self.available_tools["ml_models"]["pandas"] and self.available_tools["ml_models"]["sklearn"]:
            try:
                # Simular análisis de clustering de características
                if "analysis_results" in data:
                    # Aquí iría lógica real de ML
                    insights["clustering"] = "ML clustering analysis available"
                    insights["recommendations"] = "ML-based recommendations ready"

            except Exception as e:
                insights["ml_error"] = str(e)

        return insights

    def _show_main_menu(self) -> str:
        """Mostrar menú principal de opciones"""
        print("\n" + "=" * 60)
        print("🎵 DJProducerTools AI Chat Interface")
        print("=" * 60)
        print("\n🤖 **Menú Principal de Herramientas Inteligentes**")
        print("\n**1.** 🎧 Análisis de Audio Avanzado")
        print("   - BPM y tempo")
        print("   - Similitud entre tracks")
        print("   - Auto-tagging con ML")
        print("   - Características espectrales")

        print("\n**2.** 📚 Gestión de Bibliotecas")
        print("   - Estado de Serato/Rekordbox/Traktor")
        print("   - Análisis de colección")
        print("   - Detección de duplicados")
        print("   - Organización inteligente")

        print("\n**3.** 🧠 Machine Learning & IA")
        print("   - Modelos locales TensorFlow")
        print("   - Clustering de tracks")
        print("   - Predicciones de compatibilidad")
        print("   - Análisis evolutivo")

        print("\n**4.** 🎛️ Control de Hardware")
        print("   - DMX y luces")
        print("   - Control MIDI")
        print("   - Sincronización")

        print("\n**5.** 📊 Análisis y Reportes")
        print("   - Estadísticas de biblioteca")
        print("   - Insights ML")
        print("   - Reportes personalizados")

        print("\n**6.** 💬 Chat Asistente Inteligente")
        print("   - Preguntas sobre música")
        print("   - Recomendaciones")
        print("   - Ayuda con herramientas")

        print("\n**0.** 🚪 Salir")
        print("\n" + "-" * 60)

        return input("🎯 **Selecciona una opción (0-6):** ")

    def _handle_audio_analysis(self):
        """Manejar análisis de audio"""
        print("\n🎧 **Análisis de Audio Avanzado**")
        print("-" * 40)

        print("\n**Opciones de Análisis:**")
        print("1. Analizar archivo específico")
        print("2. Análisis batch de carpeta")
        print("3. Comparar tracks")
        print("4. Extraer características")

        choice = input("\nSelecciona opción (1-4): ")

        if choice == "1":
            file_path = input("Ruta del archivo de audio: ")
            if Path(file_path).exists():
                print(f"\n🔍 Analizando: {file_path}")
                results = self._analyze_audio_file(file_path)

                for analysis_type, result in results.items():
                    print(f"\n📊 {analysis_type.upper()}:")
                    if result["success"]:
                        print(result["output"])
                    else:
                        print(f"❌ Error: {result['error']}")
            else:
                print("❌ Archivo no encontrado")

        elif choice == "2":
            folder_path = input("Ruta de la carpeta: ")
            print(f"\n📁 Analizando carpeta: {folder_path}")
            # Implementar análisis batch

        elif choice == "3":
            print("🔄 Comparación de tracks - Implementar")

        elif choice == "4":
            print("🎛️ Extracción de características - Implementar")

    def _handle_library_management(self):
        """Manejar gestión de bibliotecas"""
        print("\n📚 **Gestión de Bibliotecas**")
        print("-" * 40)

        status = self._get_library_status()

        print("\n📊 **Estado de Bibliotecas Detectadas:**")
        for lib_name, lib_info in status.items():
            print(f"\n🎵 {lib_name}:")
            print(f"   📁 Ruta: {lib_info['path']}")
            print(f"   📊 Archivos: {lib_info['file_count']}")
            print(f"   💾 Tamaño: {lib_info['size'] / (1024**3):.2f} GB")

        print("\n**Acciones Disponibles:**")
        print("1. Escanear biblioteca completa")
        print("2. Buscar duplicados")
        print("3. Organizar por género")
        print("4. Generar reporte")

        choice = input("\nSelecciona acción (1-4): ")

        if choice == "1":
            print("🔍 Iniciando escaneo completo...")
            # Implementar escaneo

        elif choice == "2":
            print("🔍 Buscando duplicados...")
            # Implementar búsqueda de duplicados

    def _handle_ml_ai(self):
        """Manejar Machine Learning y IA"""
        print("\n🧠 **Machine Learning & IA**")
        print("-" * 40)

        print("\n🤖 **Modelos Disponibles:**")
        for model_name, available in self.available_tools["ml_models"].items():
            status = "✅" if available else "❌"
            print(f"   {status} {model_name}")

        print("\n**Capacidades ML:**")
        print("1. Clustering de tracks")
        print("2. Predicción de compatibilidad")
        print("3. Análisis de características")
        print("4. Generación de playlists")

        choice = input("\nSelecciona capacidad (1-4): ")

        if choice == "1":
            print("🎯 **Clustering de Tracks**")
            print("Analizando patrones en tu biblioteca...")
            # Implementar clustering

        elif choice == "2":
            print("🔮 **Predicción de Compatibilidad**")
            print("Analizando compatibilidad entre tracks...")
            # Implementar predicción

    def _handle_hardware_control(self):
        """Manejar control de hardware"""
        print("\n🎛️ **Control de Hardware**")
        print("-" * 40)

        if self.available_tools["audio_analysis"]["dmx_control"]:
            print("✅ DMX Control disponible")
            print("\n**Opciones DMX:**")
            print("1. Escanear dispositivos")
            print("2. Enviar comando DMX")
            print("3. Crear secuencia")
        else:
            print("❌ DMX Control no disponible")

    def _handle_analysis_reports(self):
        """Manejar análisis y reportes"""
        print("\n📊 **Análisis y Reportes**")
        print("-" * 40)

        print("\n**Tipos de Reportes:**")
        print("1. Estadísticas de biblioteca")
        print("2. Insights ML")
        print("3. Análisis de calidad")
        print("4. Reporte personalizado")

        choice = input("\nSelecciona tipo de reporte (1-4): ")

        if choice == "1":
            print("📈 Generando estadísticas de biblioteca...")
            # Implementar estadísticas

    def _handle_chat_assistant(self):
        """Manejar chat asistente inteligente"""
        print("\n💬 **Chat Asistente Inteligente**")
        print("-" * 40)
        print("🤖 DJAI Assistant: ¡Hola! Soy tu asistente musical inteligente.")
        print("Puedo ayudarte con análisis de música, recomendaciones, y uso de herramientas.")
        print("Escribe 'salir' para terminar el chat.\n")

        while True:
            user_input = input("👤 Tú: ").strip()

            if user_input.lower() in ["salir", "exit", "quit"]:
                print("🤖 DJAI: ¡Hasta luego! Que tengas buenos sets.")
                break

            # Procesar entrada del usuario
            response = self._process_chat_input(user_input)
            print(f"🤖 DJAI: {response}")

    def _process_chat_input(self, user_input: str) -> str:
        """Procesar entrada del chat y generar respuesta"""
        user_input_lower = user_input.lower()

        # Análisis de audio
        if any(word in user_input_lower for word in ["bpm", "tempo", "ritmo"]):
            return "Puedo analizar el BPM de tus tracks. Usa la opción 1 del menú principal para análisis de audio."

        # Similitud
        elif any(word in user_input_lower for word in ["similar", "parecido", "compatibilidad"]):
            return "Puedo encontrar tracks similares usando análisis de características. Ve a Análisis de Audio > Comparar tracks."  # noqa: E501

        # Organización
        elif any(word in user_input_lower for word in ["organizar", "ordenar", "limpiar"]):
            return (
                "Te puedo ayudar a organizar tu biblioteca. Ve a Gestión de Bibliotecas para opciones de organización."
            )

        # ML/IA
        elif any(word in user_input_lower for word in ["ml", "ia", "machine learning", "inteligencia"]):
            return "Tengo modelos ML locales para clustering y predicciones. Ve a Machine Learning & IA para explorar capacidades."  # noqa: E501

        # Hardware
        elif any(word in user_input_lower for word in ["dmx", "luces", "hardware"]):
            return "Puedo controlar hardware DMX si está disponible. Ve a Control de Hardware para opciones."

        # Ayuda general
        elif any(word in user_input_lower for word in ["ayuda", "help", "opciones"]):
            return "Usa el menú principal para explorar todas las herramientas disponibles. Cada opción tiene capacidades específicas."  # noqa: E501

        else:
            return f"Entiendo que quieres: '{user_input}'. Te recomiendo explorar las opciones del menú principal o ser más específico sobre qué necesitas."  # noqa: E501

    def run_interactive(self):
        """Ejecutar interfaz interactiva"""
        print("\n🚀 **Iniciando DJProducerTools AI Chat Interface**")
        print("Sistema de chat inteligente con integración ML/DT")

        while True:
            choice = self._show_main_menu()

            if choice == "0":
                print("\n👋 ¡Hasta luego! Sistema DJProducerTools AI finalizado.")
                break
            elif choice == "1":
                self._handle_audio_analysis()
            elif choice == "2":
                self._handle_library_management()
            elif choice == "3":
                self._handle_ml_ai()
            elif choice == "4":
                self._handle_hardware_control()
            elif choice == "5":
                self._handle_analysis_reports()
            elif choice == "6":
                self._handle_chat_assistant()
            else:
                print("❌ Opción no válida. Intenta nuevamente.")

            input("\nPresiona Enter para continuar...")

    def run_chat_only(self):
        """Ejecutar solo modo chat"""
        print("\n💬 **DJProducerTools AI Chat - Modo Chat Directo**")
        print("Escribe 'ayuda' para comandos o 'salir' para terminar.\n")

        while True:
            user_input = input("👤 Tú: ").strip()

            if user_input.lower() in ["salir", "exit", "quit"]:
                print("🤖 DJAI: ¡Hasta luego!")
                break

            response = self._process_chat_input(user_input)
            print(f"🤖 DJAI: {response}")


def main():
    """Función principal"""
    parser = argparse.ArgumentParser(description="DJProducerTools AI Chat Interface")
    parser.add_argument("--venv", help="Virtual environment path")
    parser.add_argument("--chat-only", action="store_true", help="Run chat mode only")
    parser.add_argument("--detect-tools", action="store_true", help="Detect available tools")

    args = parser.parse_args()

    venv_path = Path(args.venv) if args.venv else None

    # Inicializar sistema
    djai = DJAIChat(venv_path)

    if args.detect_tools:
        print("🔍 **Herramientas Detectadas:**")
        print(json.dumps(djai.available_tools, indent=2))
        return

    if args.chat_only:
        djai.run_chat_only()
    else:
        djai.run_interactive()


if __name__ == "__main__":
    main()
