#!/usr/bin/env python3
"""
DJProducerTools AI Backend Manager
Sistema completo de gestión de múltiples backends de IA con capacidades de aprendizaje
"""

import sys
import json
import os
import subprocess
import urllib.request
import importlib.util
from pathlib import Path
from datetime import datetime
import hashlib
import tomllib


class AIBackendManager:
    def __init__(self, config_dir=None):
        self.repo_root = Path(__file__).resolve().parents[1]
        self.config_dir = Path(config_dir) if config_dir else self.repo_root / "state" / "config"
        self.config_file = self.config_dir / "ai_backends.json"
        self.knowledge_base = self.config_dir / "ai_knowledge_base.json"
        self.learning_data = self.config_dir / "ai_learning_data.json"

        # Asegurar directorios
        self.config_dir.mkdir(parents=True, exist_ok=True)

        # Cargar configuración
        self.backends = self.load_backends_config()
        self.knowledge = self.load_knowledge_base()
        self.learning = self.load_learning_data()

        # Backends soportados
        self.supported_backends = {
            "ollama": {
                "name": "Ollama",
                "type": "local_llm",
                "description": "Modelos de lenguaje locales (Llama, DeepSeek, etc.)",
                "check_command": "ollama --version",
                "api_endpoint": "http://localhost:11434",
                "models_command": "ollama list",
            },
            "mlx": {
                "name": "MLX",
                "type": "apple_silicon",
                "description": "Apple MLX para Silicon (optimizado para M1/M2/M3)",
                "check_import": "mlx",
                "models_path": "state/models/mlx",
            },
            "tensorflow": {
                "name": "TensorFlow",
                "type": "deep_learning",
                "description": "TensorFlow/Keras para deep learning",
                "check_import": "tensorflow",
                "models_path": "state/models/tensorflow",
            },
            "pytorch": {
                "name": "PyTorch",
                "type": "deep_learning",
                "description": "PyTorch para deep learning",
                "check_import": "torch",
                "models_path": "state/models/pytorch",
            },
            "scikit_learn": {
                "name": "Scikit-Learn",
                "type": "machine_learning",
                "description": "Machine Learning clásico",
                "check_import": "sklearn",
                "models_path": "state/models/sklearn",
            },
            "transformers": {
                "name": "Transformers",
                "type": "nlp",
                "description": "HuggingFace Transformers para NLP",
                "check_import": "transformers",
                "models_path": "state/models/transformers",
            },
            "openai_local": {
                "name": "OpenAI Compatible Local",
                "type": "api",
                "description": "API compatible con OpenAI (LocalAI, etc.)",
                "api_endpoint": "http://localhost:8080",
            },
        }

    def load_backends_config(self):
        """Cargar configuración de backends"""
        if self.config_file.exists():
            with open(self.config_file, "r") as f:
                return json.load(f)
        else:
            # Configuración por defecto
            return {
                "active_backend": "ollama",
                "backends": {
                    "ollama": {
                        "enabled": True,
                        "model": "deepseek-r1:latest",
                        "temperature": 0.7,
                        "max_tokens": 1000,
                    },
                    "mlx": {
                        "enabled": False,
                        "model": "mlx_lm",
                        "parameters": {},
                    },
                    "tensorflow": {
                        "enabled": False,
                        "model_path": "",
                        "parameters": {},
                    },
                    "pytorch": {
                        "enabled": False,
                        "model_path": "",
                        "parameters": {},
                    },
                    "scikit_learn": {
                        "enabled": True,
                        "analysis_mode": "semantic_router",
                        "parameters": {},
                    },
                    "transformers": {
                        "enabled": False,
                        "model": "",
                        "model_path": "",
                        "parameters": {},
                    },
                    "openai_local": {
                        "enabled": False,
                        "model": "local-model",
                        "temperature": 0.4,
                        "max_tokens": 512,
                        "parameters": {},
                    },
                },
            }

    def save_backends_config(self):
        """Guardar configuración de backends"""
        with open(self.config_file, "w") as f:
            json.dump(self.backends, f, indent=2)

    def load_knowledge_base(self):
        """Cargar base de conocimiento"""
        if self.knowledge_base.exists():
            with open(self.knowledge_base, "r") as f:
                return json.load(f)
        else:
            return {
                "dj_producing": {
                    "topics": [
                        "mixing",
                        "mastering",
                        "beat_matching",
                        "harmonic mixing",
                    ],
                    "techniques": ["EQ", "compression", "reverb", "delay"],
                    "software": [
                        "Serato",
                        "Traktor",
                        "Rekordbox",
                        "Ableton Live",
                    ],
                },
                "audio_analysis": {
                    "formats": ["MP3", "WAV", "FLAC", "AIFF"],
                    "analysis_types": ["BPM", "key", "loudness", "timbre"],
                    "features": [
                        "spectral_centroid",
                        "zero_crossing_rate",
                        "mfcc",
                    ],
                },
                "file_organization": {
                    "strategies": [
                        "by_genre",
                        "by_key",
                        "by_bpm",
                        "by_energy",
                    ],
                    "naming_conventions": [
                        "artist_-_title_-_mix",
                        "artist_-_title_(key)",
                    ],
                    "metadata_standards": ["ID3v2", "Vorbis Comments"],
                },
            }

    def save_knowledge_base(self):
        """Guardar base de conocimiento"""
        with open(self.knowledge_base, "w") as f:
            json.dump(self.knowledge, f, indent=2)

    def load_learning_data(self):
        """Cargar datos de aprendizaje"""
        if self.learning_data.exists():
            with open(self.learning_data, "r") as f:
                return json.load(f)
        else:
            return {
                "interactions": [],
                "user_preferences": {},
                "learned_patterns": {},
                "performance_metrics": {},
            }

    def save_learning_data(self):
        """Guardar datos de aprendizaje"""
        with open(self.learning_data, "w") as f:
            json.dump(self.learning, f, indent=2)

    def check_backend_availability(self, backend_name):
        """Verificar disponibilidad de un backend"""
        if backend_name not in self.supported_backends:
            return False, f"Backend '{backend_name}' no soportado"

        backend_info = self.supported_backends[backend_name]

        try:
            if "check_command" in backend_info:
                # Verificar comando del sistema
                result = subprocess.run(
                    backend_info["check_command"],
                    shell=True,
                    capture_output=True,
                    text=True,
                )
                if result.returncode == 0:
                    return (
                        True,
                        f"{backend_info['name']} disponible: {result.stdout.strip()}",
                    )
                else:
                    return False, f"{backend_info['name']} no encontrado"

            elif "check_import" in backend_info:
                # Verificar import Python
                spec = importlib.util.find_spec(backend_info["check_import"])
                if spec is not None:
                    return (
                        True,
                        f"{backend_info['name']} disponible como módulo Python",
                    )
                else:
                    return (
                        False,
                        f"Módulo {backend_info['check_import']} no encontrado",
                    )

            elif "api_endpoint" in backend_info:
                # Verificar endpoint API
                try:
                    with urllib.request.urlopen(f"{backend_info['api_endpoint']}/health", timeout=5) as response:
                        return True, f"{backend_info['name']} API disponible"
                except:
                    return False, f"{backend_info['name']} API no responde"

        except Exception as e:
            return False, f"Error verificando {backend_info['name']}: {e}"

        return False, "Método de verificación no definido"

    def get_available_backends(self):
        """Obtener lista de backends disponibles"""
        available = {}
        for name, info in self.supported_backends.items():
            is_available, message = self.check_backend_availability(name)
            available[name] = {
                "info": info,
                "available": is_available,
                "message": message,
                "enabled": self.backends["backends"].get(name, {}).get("enabled", False),
            }
        return available

    def configure_backend(self, backend_name, config):
        """Configurar un backend específico"""
        if backend_name not in self.supported_backends:
            return False, f"Backend '{backend_name}' no soportado"

        # Actualizar configuración
        if backend_name not in self.backends["backends"]:
            self.backends["backends"][backend_name] = {}

        self.backends["backends"][backend_name].update(config)
        self.save_backends_config()

        return True, f"Backend '{backend_name}' configurado exitosamente"

    def set_active_backend(self, backend_name):
        """Establecer backend activo"""
        if backend_name not in self.supported_backends:
            return False, f"Backend '{backend_name}' no soportado"

        available, message = self.check_backend_availability(backend_name)
        if not available:
            return False, f"Backend no disponible: {message}"

        self.backends["active_backend"] = backend_name
        self.save_backends_config()

        return True, f"Backend activo cambiado a '{backend_name}'"

    def generate_response(self, prompt, context=None, backend_name=None):
        """Generar respuesta usando el backend especificado o el activo"""
        backend_to_use = backend_name or self.backends["active_backend"]

        if backend_to_use not in self.supported_backends:
            return None, f"Backend '{backend_to_use}' no soportado"

        # Registrar interacción para aprendizaje
        self.register_interaction(prompt, backend_to_use)

        # Enriquecer prompt con conocimiento base
        enriched_prompt = self.enrich_prompt_with_knowledge(prompt)

        # Usar backend específico
        if backend_to_use == "ollama":
            return self._ollama_generate(enriched_prompt, context)
        elif backend_to_use == "mlx":
            return self._mlx_generate(enriched_prompt, context)
        elif backend_to_use == "tensorflow":
            return self._tensorflow_generate(enriched_prompt, context)
        elif backend_to_use == "pytorch":
            return self._pytorch_generate(enriched_prompt, context)
        elif backend_to_use == "scikit_learn":
            return self._scikit_learn_generate(enriched_prompt, context)
        elif backend_to_use == "transformers":
            return self._transformers_generate(enriched_prompt, context)
        elif backend_to_use == "openai_local":
            return self._openai_local_generate(enriched_prompt, context)
        else:
            return None, f"Backend '{backend_to_use}' no implementado aún"

    def enrich_prompt_with_knowledge(self, prompt):
        """Enriquecer prompt con conocimiento base"""
        # Detectar temas en el prompt
        prompt_lower = prompt.lower()
        enriched = prompt

        # Añadir contexto de DJ producing si es relevante
        if any(word in prompt_lower for word in ["mix", "bpm", "key", "harmonic", "beat"]):
            if "dj_producing" in self.knowledge:
                enriched += f"\n\nContexto DJ Producing: {json.dumps(self.knowledge['dj_producing'], indent=2)}"

        # Añadir contexto de análisis de audio si es relevante
        if any(word in prompt_lower for word in ["audio", "analysis", "spectral", "frequency"]):
            if "audio_analysis" in self.knowledge:
                enriched += f"\n\nContexto Audio Analysis: {json.dumps(self.knowledge['audio_analysis'], indent=2)}"

        return enriched

    def _ollama_generate(self, prompt, context=None):
        """Generar usando Ollama"""
        try:
            backend_config = self.backends["backends"]["ollama"]
            model = backend_config.get("model", "deepseek-r1:latest")

            # Construir prompt completo
            full_prompt = prompt
            if context:
                full_prompt = f"Contexto anterior: {context}\n\nPregunta actual: {prompt}"

            # Preparar petición
            data = {
                "model": model,
                "prompt": full_prompt,
                "stream": False,
                "options": {
                    "temperature": backend_config.get("temperature", 0.7),
                    "top_p": backend_config.get("top_p", 0.9),
                    "max_tokens": backend_config.get("max_tokens", 1000),
                },
            }

            req_data = json.dumps(data).encode("utf-8")
            req = urllib.request.Request(
                f"{self.supported_backends['ollama']['api_endpoint']}/api/generate",
                data=req_data,
                headers={"Content-Type": "application/json"},
            )

            with urllib.request.urlopen(req, timeout=30) as response:
                result = json.loads(response.read().decode())
                response_text = result.get("response", "")

                # Guardar para aprendizaje
                self.save_learning_interaction(prompt, response_text, "ollama")

                return response_text, None

        except Exception as e:
            return None, f"Error con Ollama: {e}"

    def _mlx_generate(self, prompt, context=None):
        """Generar usando MLX (Apple Silicon) - Implementación Real"""
        try:
            # Intentar importar mlx_lm (librería optimizada para LLMs en MLX)
            # pip install mlx-lm
            from mlx_lm import load, generate

            backend_config = self.backends["backends"]["mlx"]
            model_path = backend_config.get("model", "mlx-community/Llama-3.2-3B-Instruct-4bit")

            # Verificar si tenemos el modelo cargado en caché para no recargar cada vez
            # (En una implementación persistente real, mantendríamos el modelo en memoria)
            if not hasattr(self, "_mlx_model_cache") or self._mlx_model_cache["path"] != model_path:
                print(f"⏳ Cargando modelo MLX: {model_path} (esto puede tardar la primera vez)...")
                model, tokenizer = load(model_path)
                self._mlx_model_cache = {
                    "path": model_path,
                    "model": model,
                    "tokenizer": tokenizer,
                }
            else:
                model = self._mlx_model_cache["model"]
                tokenizer = self._mlx_model_cache["tokenizer"]

            # Construir prompt (simple template, idealmente usaría chat template del tokenizer)
            full_prompt = prompt
            if context:
                full_prompt = f"Context: {context}\n\nUser: {prompt}\nAssistant:"
            else:
                # Basic Instruct format fallback
                if "Instruct" in model_path:
                    full_prompt = f"<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\n{prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n"  # noqa: E501

            # Generar
            response = generate(
                model,
                tokenizer,
                prompt=full_prompt,
                max_tokens=backend_config.get("max_tokens", 500),
                verbose=False,
            )

            self.save_learning_interaction(prompt, response, "mlx")
            return response, None

        except ImportError:
            return (
                None,
                "Librería 'mlx_lm' no instalada. Ejecuta: pip install mlx-lm",
            )
        except Exception as e:
            return None, f"Error MLX: {e}"

    def _tensorflow_generate(self, prompt, context=None):
        """Generar usando TensorFlow"""
        try:
            import tensorflow as tf  # noqa: F401

            # Aquí iría la lógica específica de TensorFlow
            # Por ahora, simulamos una respuesta
            response = f"[TensorFlow] Análisis profundo con TensorFlow para: {prompt[:100]}..."

            self.save_learning_interaction(prompt, response, "tensorflow")
            return response, None

        except ImportError:
            return None, "TensorFlow no está instalado"
        except Exception as e:
            return None, f"Error con TensorFlow: {e}"

    def _pytorch_generate(self, prompt, context=None):
        """Generar usando PyTorch"""
        try:
            import torch  # noqa: F401

            # Aquí iría la lógica específica de PyTorch
            # Por ahora, simulamos una respuesta
            response = f"[PyTorch] Procesamiento con PyTorch para: {prompt[:100]}..."

            self.save_learning_interaction(prompt, response, "pytorch")
            return response, None

        except ImportError:
            return None, "PyTorch no está instalado"
        except Exception as e:
            return None, f"Error con PyTorch: {e}"

    def _scikit_learn_generate(self, prompt, context=None):
        """Clasificación semántica local usando scikit-learn."""
        try:
            from sklearn.feature_extraction.text import TfidfVectorizer
            from sklearn.metrics.pairwise import cosine_similarity

            documents = []
            labels = []
            for label, knowledge in sorted(self.knowledge.items()):
                labels.append(label)
                documents.append(json.dumps(knowledge, ensure_ascii=False))

            if not documents:
                return None, "Base de conocimiento vacía para backend scikit_learn"

            vectorizer = TfidfVectorizer(ngram_range=(1, 2))
            knowledge_matrix = vectorizer.fit_transform(documents)
            prompt_text = f"{context}\n\n{prompt}" if context else prompt
            prompt_vector = vectorizer.transform([prompt_text])
            similarities = cosine_similarity(prompt_vector, knowledge_matrix)[0]

            best_index = max(range(len(similarities)), key=similarities.__getitem__)
            best_label = labels[best_index]
            best_score = float(similarities[best_index])

            response = {
                "backend": "scikit_learn",
                "mode": "semantic_router",
                "top_category": best_label,
                "confidence": round(best_score, 4),
                "matched_categories": [
                    {
                        "category": labels[index],
                        "score": round(float(score), 4),
                    }
                    for index, score in sorted(
                        enumerate(similarities),
                        key=lambda item: (-float(item[1]), labels[item[0]]),
                    )[:3]
                ],
                "prompt_excerpt": prompt_text[:240],
            }
            payload = json.dumps(response, ensure_ascii=False, indent=2)
            self.save_learning_interaction(prompt, payload, "scikit_learn")
            return payload, None
        except ImportError:
            return None, "scikit-learn no está instalado"
        except Exception as e:
            return None, f"Error con scikit_learn: {e}"

    def _transformers_generate(self, prompt, context=None):
        """Usar un modelo local de Transformers si está configurado."""
        try:
            backend_config = self.backends["backends"].get("transformers", {})
            model_ref, local_files_only = self._resolve_transformers_model_ref(backend_config)
            if not model_ref:
                return (
                    None,
                    "Transformers disponible pero requiere model_path/model local en configuración",
                )

            from transformers import AutoModelForCausalLM, AutoTokenizer

            tokenizer = AutoTokenizer.from_pretrained(model_ref, local_files_only=local_files_only)
            model = AutoModelForCausalLM.from_pretrained(model_ref, local_files_only=local_files_only)

            full_prompt = f"{context}\n\n{prompt}" if context else prompt
            encoded = tokenizer(full_prompt, return_tensors="pt")
            max_new_tokens = int(backend_config.get("max_tokens", 128))
            output = model.generate(
                **encoded,
                max_new_tokens=max_new_tokens,
                do_sample=False,
            )
            decoded = tokenizer.decode(output[0], skip_special_tokens=True)
            response = decoded[len(full_prompt):].strip() or decoded.strip()
            if not response:
                response = "[Transformers] modelo local cargado pero no produjo texto nuevo"

            self.save_learning_interaction(prompt, response, "transformers")
            return response, None
        except ImportError:
            return None, "Transformers no está instalado"
        except OSError as e:
            return None, f"Modelo local de Transformers no accesible: {e}"
        except Exception as e:
            return None, f"Error con Transformers: {e}"

    def _load_canonical_ai_params(self):
        config_override = os.environ.get("DJPT_CONFIG_FILE")
        config_path = Path(config_override).expanduser().resolve() if config_override else self.repo_root / "config" / "ai_model_params.toml"
        if not config_path.exists():
            return {}
        try:
            with config_path.open("rb") as fh:
                return tomllib.load(fh)
        except Exception:
            return {}

    def _resolve_transformers_model_ref(self, backend_config):
        """Resuelve model_ref usando backend state/config y fallback canónico."""
        local_files_only = bool(backend_config.get("local_files_only", True))
        model_ref = (backend_config.get("model_path") or backend_config.get("model") or "").strip()
        if model_ref:
            return model_ref, local_files_only

        ai_params = self._load_canonical_ai_params()
        transformers_cfg = ai_params.get("transformers", {})
        if not bool(transformers_cfg.get("enabled", False)):
            return "", local_files_only

        local_files_only = bool(transformers_cfg.get("local_files_only", local_files_only))
        model_ref = str(transformers_cfg.get("model_path") or transformers_cfg.get("model") or "").strip()
        if not model_ref:
            return "", local_files_only

        model_path = Path(model_ref)
        if model_path.is_absolute():
            return str(model_path), local_files_only
        return str((self.repo_root / model_path).resolve()), local_files_only

    def _openai_local_generate(self, prompt, context=None):
        """Generar usando un endpoint local compatible con OpenAI."""
        try:
            backend_config = self.backends["backends"].get("openai_local", {})
            model = backend_config.get("model", "local-model")
            full_prompt = f"{context}\n\n{prompt}" if context else prompt
            endpoint = self.supported_backends["openai_local"]["api_endpoint"].rstrip("/")
            payload = {
                "model": model,
                "messages": [
                    {"role": "system", "content": "Asistente local DJProducerTools"},
                    {"role": "user", "content": full_prompt},
                ],
                "temperature": backend_config.get("temperature", 0.4),
                "max_tokens": backend_config.get("max_tokens", 512),
            }
            req = urllib.request.Request(
                f"{endpoint}/v1/chat/completions",
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req, timeout=30) as response:
                result = json.loads(response.read().decode("utf-8"))
            choices = result.get("choices") or []
            if not choices:
                return None, "OpenAI local respondió sin choices"
            message = choices[0].get("message", {})
            content = message.get("content", "").strip()
            if not content:
                return None, "OpenAI local respondió sin contenido"

            self.save_learning_interaction(prompt, content, "openai_local")
            return content, None
        except Exception as e:
            return None, f"Error con OpenAI local: {e}"

    def register_interaction(self, prompt, backend):
        """Registrar interacción para análisis"""
        interaction = {
            "timestamp": datetime.now().isoformat(),
            "prompt": prompt,
            "backend": backend,
            "prompt_hash": hashlib.md5(prompt.encode()).hexdigest(),
        }
        self.learning["interactions"].append(interaction)

        # Mantener solo últimas 1000 interacciones
        if len(self.learning["interactions"]) > 1000:
            self.learning["interactions"] = self.learning["interactions"][-1000:]

    def save_learning_interaction(self, prompt, response, backend):
        """Guardar interacción completa para aprendizaje"""
        learning_entry = {
            "timestamp": datetime.now().isoformat(),
            "prompt": prompt,
            "response": response,
            "backend": backend,
            "prompt_length": len(prompt),
            "response_length": len(response),
        }

        if "interactions_history" not in self.learning:
            self.learning["interactions_history"] = []

        self.learning["interactions_history"].append(learning_entry)

        # Actualizar preferencias de usuario
        self.update_user_preferences(prompt, backend)

        self.save_learning_data()

    def update_user_preferences(self, prompt, backend):
        """Actualizar preferencias de usuario basadas en interacciones"""
        if "backend_usage" not in self.learning["user_preferences"]:
            self.learning["user_preferences"]["backend_usage"] = {}

        backend_usage = self.learning["user_preferences"]["backend_usage"]
        backend_usage[backend] = backend_usage.get(backend, 0) + 1

    def add_knowledge(self, category, topic, information):
        """Añadir conocimiento a la base"""
        if category not in self.knowledge:
            self.knowledge[category] = {}

        self.knowledge[category][topic] = information
        self.save_knowledge_base()

    def get_learning_insights(self):
        """Obtener insights del aprendizaje"""
        insights = {
            "total_interactions": len(self.learning.get("interactions_history", [])),
            "backend_preferences": self.learning.get("user_preferences", {}).get("backend_usage", {}),
            "most_used_backends": [],
            "learning_progress": {},
        }

        # Calcular backends más usados
        if insights["backend_preferences"]:
            sorted_backends = sorted(
                insights["backend_preferences"].items(),
                key=lambda x: x[1],
                reverse=True,
            )
            insights["most_used_backends"] = sorted_backends[:3]

        return insights

    def chat_loop(self, backend_name=None):
        """Bucle de chat interactivo con backend específico"""
        backend_to_use = backend_name or self.backends["active_backend"]

        print(f"🤖 DJProducerTools AI Chat - Backend: {backend_to_use.upper()}")
        print(f"Modelo/Configuración: {self.backends['backends'].get(backend_to_use, {})}")
        print("Escribe 'salir' para terminar, '/backend' para cambiar, '/config' para configurar\n")

        context = ""

        while True:
            try:
                user_input = input(f"🧠 [{backend_to_use.upper()}]> ").strip()

                if user_input.lower() in ["salir", "exit", "quit"]:
                    print("👋 Saliendo del asistente IA...")
                    break

                if user_input.startswith("/backend"):
                    self.show_available_backends()
                    new_backend = input("Elige backend: ").strip()
                    if new_backend in self.supported_backends:
                        success, message = self.set_active_backend(new_backend)
                        if success:
                            backend_to_use = new_backend
                            print(f"✅ {message}")
                        else:
                            print(f"❌ {message}")
                    continue

                if user_input.startswith("/config"):
                    self.configure_backend_interactive(backend_to_use)
                    continue

                if user_input.startswith("/learn"):
                    self.add_knowledge_interactive()
                    continue

                if user_input.startswith("/insights"):
                    insights = self.get_learning_insights()
                    print("📊 Insights de Aprendizaje:")
                    print(json.dumps(insights, indent=2))
                    continue

                if not user_input:
                    continue

                print("🤔 Pensando...")
                response, error = self.generate_response(user_input, context, backend_to_use)

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

    def show_available_backends(self):
        """Mostrar backends disponibles"""
        available = self.get_available_backends()
        print("\n🔧 Backends Disponibles:")
        for name, info in available.items():
            status = "✅" if info["available"] else "❌"
            enabled = "🟢" if info["enabled"] else "🔴"
            print(f"  {status} {enabled} {name}: {info['info']['description']}")
            print(f"      {info['message']}")
        print()

    def configure_backend_interactive(self, backend_name):
        """Configurar backend interactivamente"""
        if backend_name not in self.supported_backends:
            print(f"❌ Backend '{backend_name}' no soportado")
            return

        print(f"\n⚙️ Configurando {backend_name}...")
        current_config = self.backends["backends"].get(backend_name, {})

        if backend_name == "ollama":
            print("Configuración actual:")
            print(f"  Modelo: {current_config.get('model', 'deepseek-r1:latest')}")
            print(f"  Temperatura: {current_config.get('temperature', 0.7)}")
            print(f"  Max Tokens: {current_config.get('max_tokens', 1000)}")

            new_model = input(f"Modelo [{current_config.get('model', 'deepseek-r1:latest')}]: ").strip()
            if new_model:
                current_config["model"] = new_model

            try:
                temp = input(f"Temperatura [{current_config.get('temperature', 0.7)}]: ").strip()
                if temp:
                    current_config["temperature"] = float(temp)
            except ValueError:
                print("⚠️ Temperatura inválida, manteniendo valor actual")

            try:
                max_tokens = input(f"Max Tokens [{current_config.get('max_tokens', 1000)}]: ").strip()
                if max_tokens:
                    current_config["max_tokens"] = int(max_tokens)
            except ValueError:
                print("⚠️ Max tokens inválido, manteniendo valor actual")

        self.configure_backend(backend_name, current_config)
        print("✅ Configuración guardada")

    def add_knowledge_interactive(self):
        """Añadir conocimiento interactivamente"""
        print("\n📚 Añadir conocimiento a la base:")
        category = input("Categoría (ej: dj_producing, audio_analysis): ").strip()
        topic = input("Tema: ").strip()
        information = input("Información (puedes usar JSON para datos estructurados): ").strip()

        try:
            # Intentar parsear como JSON
            info_data = json.loads(information)
        except:
            # Si no es JSON, usar como texto plano
            info_data = information

        self.add_knowledge(category, topic, info_data)
        print("✅ Conocimiento añadido exitosamente")


def main():
    """Función principal"""
    import argparse

    parser = argparse.ArgumentParser(description="DJProducerTools AI Backend Manager")
    parser.add_argument("--check", action="store_true", help="Verificar backends disponibles")
    parser.add_argument("--backends", action="store_true", help="Mostrar todos los backends")
    parser.add_argument("--active", help="Establecer backend activo")
    parser.add_argument("--chat", help="Iniciar chat con backend específico")
    parser.add_argument("--config", help="Configurar backend específico")
    parser.add_argument(
        "--insights",
        action="store_true",
        help="Mostrar insights de aprendizaje",
    )

    args = parser.parse_args()

    # Inicializar manager
    manager = AIBackendManager()

    if args.check:
        available = manager.get_available_backends()
        print("🔍 Verificación de Backends:")
        for name, info in available.items():
            status = "✅" if info["available"] else "❌"
            print(f"  {status} {name}: {info['message']}")
        return 0

    if args.backends:
        manager.show_available_backends()
        return 0

    if args.active:
        success, message = manager.set_active_backend(args.active)
        if success:
            print(f"✅ {message}")
            return 0
        else:
            print(f"❌ {message}")
            return 1

    if args.config:
        manager.configure_backend_interactive(args.config)
        return 0

    if args.insights:
        insights = manager.get_learning_insights()
        print("📊 Insights de Aprendizaje:")
        print(json.dumps(insights, indent=2))
        return 0

    if args.chat:
        manager.chat_loop(args.chat)
        return 0

    # Si no hay argumentos, iniciar chat con backend activo
    manager.chat_loop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
