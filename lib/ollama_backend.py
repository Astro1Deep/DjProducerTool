#!/usr/bin/env python3
"""
Backend Ollama para DJProducerTools Chat CLI
Proporciona integración con modelos de lenguaje locales vía Ollama
"""

import sys
import json
import urllib.request


class OllamaBackend:
    def __init__(
        self,
        model_name="deepseek-r1:latest",
        base_url="http://localhost:11434",
    ):
        self.model_name = model_name
        self.base_url = base_url
        self.timeout = 30

    def check_ollama_status(self):
        """Verifica si Ollama está corriendo y el modelo está disponible"""
        try:
            # Verificar si el servidor está corriendo
            with urllib.request.urlopen(f"{self.base_url}/api/tags", timeout=5) as response:
                data = json.loads(response.read().decode())

            # Verificar si el modelo está disponible
            models = [model["name"] for model in data.get("models", [])]
            if self.model_name not in models:
                return (
                    False,
                    f"Modelo '{self.model_name}' no encontrado. Modelos disponibles: {', '.join(models)}",
                )

            return True, f"Ollama OK con modelo '{self.model_name}'"

        except Exception as e:
            return False, f"Error conectando con Ollama: {e}"

    def generate_response(self, prompt, context=None):
        """Genera respuesta usando el modelo de Ollama"""
        try:
            # Construir el prompt con contexto si se proporciona
            full_prompt = prompt
            if context:
                full_prompt = f"Contexto anterior: {context}\n\nPregunta actual: {prompt}"

            # Preparar la petición para Ollama
            data = {
                "model": self.model_name,
                "prompt": full_prompt,
                "stream": False,
                "options": {
                    "temperature": 0.7,
                    "top_p": 0.9,
                    "max_tokens": 1000,
                },
            }

            # Enviar petición
            req_data = json.dumps(data).encode("utf-8")
            req = urllib.request.Request(
                f"{self.base_url}/api/generate",
                data=req_data,
                headers={"Content-Type": "application/json"},
            )

            with urllib.request.urlopen(req, timeout=self.timeout) as response:
                result = json.loads(response.read().decode())
                return result.get("response", ""), None

        except Exception as e:
            return "", f"Error generando respuesta: {e}"

    def chat_loop(self):
        """Bucle de chat interactivo"""
        print("🤖 DJProducerTools AI Assistant (Ollama)")
        print(f"Modelo: {self.model_name}")
        print("Escribe 'salir' para terminar\n")

        context = ""

        while True:
            try:
                user_input = input("🧠 DJPT> ").strip()

                if user_input.lower() in ["salir", "exit", "quit"]:
                    print("👋 Saliendo del asistente IA...")
                    break

                if not user_input:
                    continue

                print("🤔 Pensando...")
                response, error = self.generate_response(user_input, context)

                if error:
                    print(f"❌ Error: {error}")
                else:
                    print(f"🤖 IA: {response}")
                    context = user_input + "\n" + response  # Mantener contexto corto

            except KeyboardInterrupt:
                print("\n👋 Saliendo del asistente IA...")
                break
            except Exception as e:
                print(f"❌ Error inesperado: {e}")


def main():
    """Función principal para ejecutar el backend Ollama"""
    import argparse

    parser = argparse.ArgumentParser(description="Backend Ollama para DJProducerTools")
    parser.add_argument("--model", default="deepseek-r1:latest", help="Modelo a usar")
    parser.add_argument("--check", action="store_true", help="Verificar estado de Ollama")
    parser.add_argument("--chat", action="store_true", help="Iniciar chat interactivo")
    parser.add_argument("--prompt", help="Enviar un prompt y obtener respuesta")

    args = parser.parse_args()

    backend = OllamaBackend(args.model)

    if args.check:
        status, message = backend.check_ollama_status()
        if status:
            print(f"✅ {message}")
            return 0
        else:
            print(f"❌ {message}")
            return 1

    if args.chat:
        backend.chat_loop()
        return 0

    if args.prompt:
        response, error = backend.generate_response(args.prompt)
        if error:
            print(f"❌ Error: {error}")
            return 1
        else:
            print(response)
            return 0

    # Si no hay argumentos, mostrar ayuda
    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
