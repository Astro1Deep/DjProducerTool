#!/usr/bin/env python3
"""
Instalador de Dependencias de IA para DJProducerTools
Instala TensorFlow, PyTorch, MLX, Scikit-Learn, Transformers, etc.
"""

import sys
import subprocess
import importlib.util


class AIDependencyInstaller:
    def __init__(self):
        self.python_bin = sys.executable
        self.packages = {
            "tensorflow": {
                "name": "TensorFlow",
                "description": "Deep Learning framework de Google",
                "packages": ["tensorflow"],
                "test_import": "tensorflow",
                "optional_features": ["tensorflow-hub"],
                "apple_silicon_optimized": True,
            },
            "pytorch": {
                "name": "PyTorch",
                "description": "Deep Learning framework de Facebook",
                "packages": ["torch", "torchvision", "torchaudio"],
                "test_import": "torch",
                "apple_silicon_optimized": True,
            },
            "mlx": {
                "name": "MLX",
                "description": "Apple ML framework para Silicon (M1/M2/M3)",
                "packages": ["mlx", "mlx-lm"],
                "test_import": "mlx",
                "apple_silicon_only": True,
            },
            "scikit_learn": {
                "name": "Scikit-Learn",
                "description": "Machine Learning clásico",
                "packages": ["scikit-learn"],
                "test_import": "sklearn",
            },
            "transformers": {
                "name": "Transformers",
                "description": "HuggingFace Transformers para NLP",
                "packages": ["transformers", "tokenizers"],
                "test_import": "transformers",
                "requires": ["torch", "tensorflow"],  # Requiere uno de los dos
            },
            "audio_processing": {
                "name": "Audio Processing",
                "description": "Librerías para análisis de audio",
                "packages": ["librosa", "soundfile", "pydub"],
                "test_import": "librosa",
            },
            "computer_vision": {
                "name": "Computer Vision",
                "description": "Procesamiento de imágenes y video",
                "packages": ["opencv-python", "pillow"],
                "test_import": "cv2",
            },
            "data_analysis": {
                "name": "Data Analysis",
                "description": "Análisis de datos y visualización",
                "packages": ["pandas", "numpy", "matplotlib", "seaborn"],
                "test_import": "pandas",
            },
        }

    def check_apple_silicon(self):
        """Verificar si es Apple Silicon"""
        try:
            import platform

            return platform.machine() in ["arm64", "arm64e"] and platform.system() == "Darwin"
        except:
            return False

    def check_package_installed(self, package_name):
        """Verificar si un paquete está instalado"""
        try:
            spec = importlib.util.find_spec(package_name)
            return spec is not None
        except:
            return False

    def get_install_command(self, package_info):
        """Obtener comando de instalación optimizado"""
        packages = package_info["packages"]

        # Optimización para Apple Silicon
        if self.check_apple_silicon() and package_info.get("apple_silicon_optimized"):
            if package_info["name"] == "TensorFlow":
                # TensorFlow para Apple Silicon
                return ["pip", "install", "tensorflow-metal"] + packages
            elif package_info["name"] == "PyTorch":
                # PyTorch para Apple Silicon
                return [
                    "pip",
                    "install",
                    "--index-url",
                    "https://download.pytorch.org/whl/cpu",
                    "torch",
                    "torchvision",
                    "torchaudio",
                ]

        # Comando estándar
        return ["pip", "install"] + packages

    def install_package(self, package_key):
        """Instalar un paquete específico"""
        if package_key not in self.packages:
            return False, f"Paquete '{package_key}' no reconocido"

        package_info = self.packages[package_key]

        # Verificar Apple Silicon para MLX
        if package_info.get("apple_silicon_only") and not self.check_apple_silicon():
            return (
                False,
                f"{package_info['name']} solo está disponible para Apple Silicon (M1/M2/M3)",
            )

        # Verificar dependencias
        if "requires" in package_info:
            missing_deps = []
            for dep in package_info["requires"]:
                if not self.check_package_installed(dep):
                    missing_deps.append(dep)

            if missing_deps:
                return (
                    False,
                    f"Requiere instalar primero: {', '.join(missing_deps)}",
                )

        print(f"🔧 Instalando {package_info['name']}...")
        print(f"📝 {package_info['description']}")

        try:
            cmd = self.get_install_command(package_info)
            print(f"🚀 Ejecutando: {' '.join(cmd)}")

            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            print(f"✅ {package_info['name']} instalado exitosamente")

            # Verificar instalación
            if self.check_package_installed(package_info["test_import"]):
                print(f"✅ Verificación: {package_info['test_import']} importable")

                # Instalar características opcionales
                if "optional_features" in package_info:
                    for feature in package_info["optional_features"]:
                        print(f"🔧 Instalando característica opcional: {feature}")
                        try:
                            subprocess.run(
                                [
                                    self.python_bin,
                                    "-m",
                                    "pip",
                                    "install",
                                    feature,
                                ],
                                capture_output=True,
                                text=True,
                                check=True,
                            )
                            print(f"✅ {feature} instalado")
                        except subprocess.CalledProcessError:
                            print(f"⚠️ No se pudo instalar {feature}")

                return True, f"{package_info['name']} instalado y verificado"
            else:
                return (
                    False,
                    f"{package_info['name']} instalado pero no se puede importar",
                )

        except subprocess.CalledProcessError as e:
            error_msg = f"Error instalando {package_info['name']}: {e.stderr}"
            print(f"❌ {error_msg}")
            return False, error_msg

    def install_all(self, categories=None):
        """Instalar todas las dependencias o categorías específicas"""
        if categories is None:
            categories = list(self.packages.keys())

        results = {}

        for category in categories:
            if category in self.packages:
                success, message = self.install_package(category)
                results[category] = {"success": success, "message": message}
            else:
                results[category] = {
                    "success": False,
                    "message": f"Categoría '{category}' no reconocida",
                }

        return results

    def show_status(self):
        """Mostrar estado de todas las dependencias"""
        print("🔍 Estado de Dependencias de IA:")
        print("=" * 50)

        apple_silicon = self.check_apple_silicon()
        print(f"🖥️  Sistema: {'Apple Silicon' if apple_silicon else 'Intel/Other'}")
        print(f"🐍 Python: {self.python_bin}")
        print()

        for key, info in self.packages.items():
            installed = self.check_package_installed(info["test_import"])
            status = "✅" if installed else "❌"
            print(f"{status} {info['name']}: {info['description']}")

            if info.get("apple_silicon_only") and not apple_silicon:
                print("   ⚠️  Solo disponible para Apple Silicon")
            elif info.get("apple_silicon_optimized") and apple_silicon:
                print("   🚀 Optimizado para Apple Silicon")

        print()

    def interactive_menu(self):
        """Menú interactivo de instalación"""
        while True:
            print("🤖 DJProducerTools - Instalador de Dependencias de IA")
            print("=" * 50)
            self.show_status()

            print("Opciones:")
            print("1. Instalar TensorFlow (Deep Learning)")
            print("2. Instalar PyTorch (Deep Learning)")
            print("3. Instalar MLX (Apple Silicon only)")
            print("4. Instalar Scikit-Learn (Machine Learning)")
            print("5. Instalar Transformers (NLP)")
            print("6. Instalar Audio Processing (librosa, etc.)")
            print("7. Instalar Computer Vision (OpenCV)")
            print("8. Instalar Data Analysis (pandas, numpy)")
            print("9. Instalar TODO (recomendado)")
            print("10. Instalar básico (scikit-learn + audio)")
            print("0. Salir")

            choice = input("\nElige opción [0-10]: ").strip()

            if choice == "0":
                print("👋 Saliendo...")
                break
            elif choice == "1":
                self.install_package("tensorflow")
            elif choice == "2":
                self.install_package("pytorch")
            elif choice == "3":
                self.install_package("mlx")
            elif choice == "4":
                self.install_package("scikit_learn")
            elif choice == "5":
                self.install_package("transformers")
            elif choice == "6":
                self.install_package("audio_processing")
            elif choice == "7":
                self.install_package("computer_vision")
            elif choice == "8":
                self.install_package("data_analysis")
            elif choice == "9":
                print("🚀 Instalando TODAS las dependencias...")
                results = self.install_all()
                for key, result in results.items():
                    status = "✅" if result["success"] else "❌"
                    print(f"{status} {key}: {result['message']}")
            elif choice == "10":
                print("🔧 Instalando dependencias básicas...")
                basic = ["scikit_learn", "audio_processing", "data_analysis"]
                results = self.install_all(basic)
                for key, result in results.items():
                    status = "✅" if result["success"] else "❌"
                    print(f"{status} {key}: {result['message']}")
            else:
                print("❌ Opción inválida")

            input("\nPresiona ENTER para continuar...")
            print("\n" * 2)


def main():
    """Función principal"""
    import argparse

    parser = argparse.ArgumentParser(description="Instalador de Dependencias de IA para DJProducerTools")
    parser.add_argument("--status", action="store_true", help="Mostrar estado de dependencias")
    parser.add_argument("--install", help="Instalar paquete específico")
    parser.add_argument("--all", action="store_true", help="Instalar todas las dependencias")
    parser.add_argument("--basic", action="store_true", help="Instalar dependencias básicas")
    parser.add_argument("--interactive", action="store_true", help="Menú interactivo")

    args = parser.parse_args()

    installer = AIDependencyInstaller()

    if args.status:
        installer.show_status()
        return 0

    if args.install:
        success, message = installer.install_package(args.install)
        if success:
            print(f"✅ {message}")
            return 0
        else:
            print(f"❌ {message}")
            return 1

    if args.all:
        print("🚀 Instalando TODAS las dependencias de IA...")
        results = installer.install_all()
        success_count = sum(1 for r in results.values() if r["success"])
        total_count = len(results)
        print(f"\n📊 Resultado: {success_count}/{total_count} paquetes instalados exitosamente")
        return 0 if success_count == total_count else 1

    if args.basic:
        print("🔧 Instalando dependencias básicas...")
        basic = ["scikit_learn", "audio_processing", "data_analysis"]
        results = installer.install_all(basic)
        success_count = sum(1 for r in results.values() if r["success"])
        total_count = len(results)
        print(f"\n📊 Resultado: {success_count}/{total_count} paquetes básicos instalados")
        return 0 if success_count == total_count else 1

    if args.interactive:
        installer.interactive_menu()
        return 0

    # Si no hay argumentos, mostrar estado
    installer.show_status()
    return 0


if __name__ == "__main__":
    sys.exit(main())
