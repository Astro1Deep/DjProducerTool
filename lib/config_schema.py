#!/usr/bin/env python3
"""
DJProducerTools Configuration Schema - Unificado y Validado
Schema TOML completo con validación de tipos y rangos
"""

from __future__ import annotations

import os
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Optional
from datetime import datetime

try:  # py311+
    import tomllib
except ImportError:  # pragma: no cover
    import tomli as tomllib  # type: ignore

try:
    import tomli_w
except ImportError:
    tomli_w = None

# Paths base (permiten override por entorno)
BASE_DIR = Path(os.environ.get("DJPT_BASE_DIR", Path(__file__).resolve().parents[1]))
CONFIG_FILE = BASE_DIR / "config" / "ai_model_params.toml"
STATE_DIR = BASE_DIR / "state"
CAPABILITIES_FILE = STATE_DIR / "ai_capabilities.json"
PROFILE_FILE = STATE_DIR / "ai_profile.json"


# Validadores
def validate_backend(value: str) -> str:
    valid = {"auto", "mlx", "tensorflow", "ollama"}
    if value not in valid:
        raise ValueError(f"backend must be one of {valid}, got {value}")
    return value


def validate_threads(value: int) -> int:
    cpu_count = os.cpu_count() or 4
    if value < 0 or value > cpu_count * 2:
        raise ValueError(f"threads must be 0-{cpu_count * 2}, got {value}")
    return value or cpu_count


def validate_memory_fraction(value: float) -> float:
    if not 0.1 <= value <= 0.9:
        raise ValueError(f"memory_fraction must be 0.1-0.9, got {value}")
    return value


def validate_positive_int(value: int) -> int:
    if value <= 0:
        raise ValueError(f"must be positive integer, got {value}")
    return value


def validate_timeout(value: int) -> int:
    if not 5 <= value <= 300:
        raise ValueError(f"timeout must be 5-300 seconds, got {value}")
    return value


# Dataclasses completas con validación
@dataclass
class General:
    preferred_backend: str = field(default="auto", metadata={"validator": validate_backend})
    temperature: float = 0.7
    batch_size: int = field(default=32, metadata={"validator": validate_positive_int})
    allow_gpu: bool = True
    max_files: int = field(default=5000, metadata={"validator": validate_positive_int})
    parallel_threads: int = field(default=4, metadata={"validator": validate_threads})
    max_memory_gb: int = field(default=8, metadata={"validator": validate_positive_int})


@dataclass
class MLX:
    cache_limit_mb: int = field(default=1024, metadata={"validator": validate_positive_int})
    device: str = "metal"  # metal | cpu
    enable_gpu: bool = True
    memory_fraction: float = field(default=0.25, metadata={"validator": validate_memory_fraction})


@dataclass
class TensorFlow:
    intraop_threads: int = field(default=0, metadata={"validator": validate_threads})
    interop_threads: int = field(default=0, metadata={"validator": validate_threads})
    gpu_memory_growth: bool = True
    device: str = "auto"  # auto | cpu | gpu | mps
    mixed_precision: bool = True


@dataclass
class Ollama:
    base_url: str = "http://localhost:11434"
    default_model: str = "llama3.2:3b"
    timeout_seconds: int = field(default=30, metadata={"validator": validate_timeout})
    max_tokens: int = field(default=2048, metadata={"validator": validate_positive_int})
    temperature: float = 0.7


@dataclass
class Threads:
    cpu_threads: int = field(
        default_factory=lambda: os.cpu_count() or 4,
        metadata={"validator": validate_threads},
    )
    tf_intraop: int = field(default=0, metadata={"validator": validate_threads})
    tf_interop: int = field(default=0, metadata={"validator": validate_threads})


@dataclass
class Jobs:
    scan_workers: int = field(default=4, metadata={"validator": validate_threads})
    batch_processing: bool = True
    chunk_size: int = field(default=1000, metadata={"validator": validate_positive_int})
    progress_interval: int = field(default=10, metadata={"validator": validate_positive_int})
    retry_attempts: int = field(default=3, metadata={"validator": lambda x: max(1, min(10, x))})


@dataclass
class Optimization:
    auto_tune: bool = True
    profile_memory: bool = True
    cache_models: bool = True
    preload_models: bool = False
    cleanup_temp: bool = True


@dataclass
class Learning:
    learning_rate: float = 0.01
    max_sessions: int = field(default=5, metadata={"validator": lambda x: max(1, min(20, x))})
    session_timeout: int = field(default=1800, metadata={"validator": lambda x: max(60, min(1800, x))})
    save_patterns: bool = True
    adaptive_mode: bool = True


@dataclass
class Limits:
    max_file_size_mb: int = field(default=500, metadata={"validator": lambda x: max(10, min(5000, x))})
    max_concurrent_jobs: int = field(default=3, metadata={"validator": lambda x: max(1, min(10, x))})
    max_memory_usage: float = field(default=0.8, metadata={"validator": validate_memory_fraction})
    disk_space_threshold: float = field(default=0.9, metadata={"validator": lambda x: max(0.5, min(0.95, x))})


@dataclass
class Trends:
    max_files: int = field(default=5000, metadata={"validator": validate_positive_int})


@dataclass
class Settings:
    general: General = field(default_factory=General)
    mlx: MLX = field(default_factory=MLX)
    tensorflow: TensorFlow = field(default_factory=TensorFlow)
    ollama: Ollama = field(default_factory=Ollama)
    threads: Threads = field(default_factory=Threads)
    jobs: Jobs = field(default_factory=Jobs)
    optimization: Optimization = field(default_factory=Optimization)
    learning: Learning = field(default_factory=Learning)
    limits: Limits = field(default_factory=Limits)
    trends: Trends = field(default_factory=Trends)


class ConfigManager:
    """Gestor unificado de configuración con validación y exportación"""

    def __init__(self, config_path: Optional[Path] = None):
        self.config_path = config_path or CONFIG_FILE
        self._settings: Optional[Settings] = None
        self._capabilities: Optional[Dict[str, Any]] = None

    @property
    def settings(self) -> Settings:
        if self._settings is None:
            self._settings = self.load_settings()
        return self._settings

    def load_settings(self, config_path: Optional[Path] = None) -> Settings:
        """Carga y valida configuración desde TOML"""
        path = config_path or self.config_path

        if not path.exists():
            print(f"[WARN] Config file not found: {path}, using defaults")
            return Settings()

        try:
            data = tomllib.loads(path.read_text(encoding="utf-8"))
            settings = Settings()

            # Mapeo de secciones con validación
            section_mappings = {
                "general": (General, "general"),
                "mlx": (MLX, "mlx"),
                "tensorflow": (TensorFlow, "tensorflow"),
                "ollama": (Ollama, "ollama"),
                "threads": (Threads, "threads"),
                "jobs": (Jobs, "jobs"),
                "optimization": (Optimization, "optimization"),
                "learning": (Learning, "learning"),
                "limits": (Limits, "limits"),
                "trends": (Trends, "trends"),
            }

            for section_name, (
                section_cls,
                attr_name,
            ) in section_mappings.items():
                if section_name in data:
                    section_data = data[section_name]
                    section_obj = section_cls()

                    # Validar cada campo
                    for field_name, field_value in section_data.items():
                        if hasattr(section_obj, field_name):
                            field_def = section_cls.__dataclass_fields__[field_name]
                            validator = field_def.metadata.get("validator")

                            if validator:
                                try:
                                    validated_value = validator(field_value)
                                    setattr(
                                        section_obj,
                                        field_name,
                                        validated_value,
                                    )
                                except ValueError as e:
                                    print(f"[WARN] Invalid {section_name}.{field_name}: {e}, using default")
                                    try:
                                        default_value = getattr(section_obj, field_name)
                                        if validator:
                                            default_value = validator(default_value)
                                        setattr(
                                            section_obj,
                                            field_name,
                                            default_value,
                                        )
                                    except Exception as inner_e:
                                        print(f"[ERR] Default for {section_name}.{field_name} invalid: {inner_e}")
                            else:
                                setattr(section_obj, field_name, field_value)

                    setattr(settings, attr_name, section_obj)

            self._settings = settings
            return settings

        except Exception as e:
            print(f"[ERR] Failed to load config: {e}")
            return Settings()

    def save_settings(self, settings: Optional[Settings] = None) -> bool:
        """Guarda configuración validada a TOML"""
        settings_to_save = settings or self.settings

        try:
            self.config_path.parent.mkdir(parents=True, exist_ok=True)

            # Serializar todas las secciones
            content = {
                "general": settings_to_save.general.__dict__,
                "mlx": settings_to_save.mlx.__dict__,
                "tensorflow": settings_to_save.tensorflow.__dict__,
                "ollama": settings_to_save.ollama.__dict__,
                "threads": settings_to_save.threads.__dict__,
                "jobs": settings_to_save.jobs.__dict__,
                "optimization": settings_to_save.optimization.__dict__,
                "learning": settings_to_save.learning.__dict__,
                "limits": settings_to_save.limits.__dict__,
                "trends": settings_to_save.trends.__dict__,
            }

            tmp_path = self.config_path.with_suffix(".tmp")
            try:
                if tomli_w:
                    tmp_path.write_text(tomli_w.dumps(content), encoding="utf-8")
                else:
                    # Fallback simple
                    lines = []
                    for section_name, section_data in content.items():
                        lines.append(f"[{section_name}]")
                        for k, v in section_data.items():
                            lines.append(f"{k} = {repr(v)}")
                        lines.append("")
                    tmp_path.write_text("\n".join(lines), encoding="utf-8")

                # Escritura atómica: mover .tmp al destino final
                tmp_path.replace(self.config_path)

            except Exception as write_error:
                # Limpiar archivo temporal si falla
                if tmp_path.exists():
                    tmp_path.unlink()
                raise write_error

            return True

        except Exception as e:
            print(f"[ERR] Failed to save config: {e}")
            return False

    def get_nested_setting(self, path: str) -> Any:
        """Obtiene configuración con notación de puntos"""
        parts = path.split(".")
        if len(parts) != 2:
            raise ValueError(f"Invalid path format: {path}. Expected 'section.key'")

        section_name, key = parts
        if not hasattr(self.settings, section_name):
            raise ValueError(f"Unknown section: {section_name}")

        section_obj = getattr(self.settings, section_name)
        if not hasattr(section_obj, key):
            raise ValueError(f"Unknown key: {key} in section {section_name}")

        return getattr(section_obj, key)

    def set_nested_setting(self, path: str, value: Any) -> None:
        """Establece configuración con validación"""
        parts = path.split(".")
        if len(parts) != 2:
            raise ValueError(f"Invalid path format: {path}. Expected 'section.key'")

        section_name, key = parts
        if not hasattr(self.settings, section_name):
            raise ValueError(f"Unknown section: {section_name}")

        section_obj = getattr(self.settings, section_name)
        if not hasattr(section_obj, key):
            raise ValueError(f"Unknown key: {key} in section {section_name}")

        # Type casting y validación
        current = getattr(section_obj, key)
        field_def = section_obj.__class__.__dataclass_fields__[key]
        validator = field_def.metadata.get("validator")

        # Cast básico
        if isinstance(current, bool):
            value = str(value).lower() in ("1", "true", "yes", "on")
        elif isinstance(current, int):
            value = int(value)
        elif isinstance(current, float):
            value = float(value)

        # Validación personalizada
        if validator:
            value = validator(value)

        setattr(section_obj, key, value)

    def export_env_vars(self) -> Dict[str, str]:
        """Exporta todas las variables de entorno relevantes"""
        s = self.settings
        return {
            # General
            "DJPT_PREFERRED_BACKEND": s.general.preferred_backend,
            "DJPT_TEMPERATURE": str(s.general.temperature),
            "DJPT_BATCH_SIZE": str(s.general.batch_size),
            "DJPT_ALLOW_GPU": str(int(s.general.allow_gpu)),
            "DJPT_MAX_FILES": str(s.general.max_files),
            "DJPT_PARALLEL_THREADS": str(s.general.parallel_threads),
            "DJPT_MAX_MEMORY_GB": str(s.general.max_memory_gb),
            # MLX
            "DJPT_MLX_CACHE_LIMIT_MB": str(s.mlx.cache_limit_mb),
            "DJPT_MLX_DEVICE": s.mlx.device,
            "DJPT_MLX_ENABLE_GPU": str(int(s.mlx.enable_gpu)),
            "DJPT_MLX_MEMORY_FRACTION": str(s.mlx.memory_fraction),
            # TensorFlow
            "TF_INTRAOP_THREADS": str(s.tensorflow.intraop_threads),
            "TF_INTEROP_THREADS": str(s.tensorflow.interop_threads),
            "DJPT_TF_GPU_MEMORY_GROWTH": str(int(s.tensorflow.gpu_memory_growth)),
            "DJPT_TF_DEVICE": s.tensorflow.device,
            "DJPT_TF_MIXED_PRECISION": str(int(s.tensorflow.mixed_precision)),
            # Ollama
            "DJPT_OLLAMA_BASE_URL": s.ollama.base_url,
            "DJPT_OLLAMA_DEFAULT_MODEL": s.ollama.default_model,
            "DJPT_OLLAMA_TIMEOUT_SECONDS": str(s.ollama.timeout_seconds),
            "DJPT_OLLAMA_MAX_TOKENS": str(s.ollama.max_tokens),
            "DJPT_OLLAMA_TEMPERATURE": str(s.ollama.temperature),
            # Threads
            "DJPT_CPU_THREADS": str(s.threads.cpu_threads),
            "DJPT_TF_INTRAOP": str(s.threads.tf_intraop),
            "DJPT_TF_INTEROP": str(s.threads.tf_interop),
            # Jobs
            "DJPT_SCAN_WORKERS": str(s.jobs.scan_workers),
            "DJPT_BATCH_PROCESSING": str(int(s.jobs.batch_processing)),
            "DJPT_CHUNK_SIZE": str(s.jobs.chunk_size),
            "DJPT_PROGRESS_INTERVAL": str(s.jobs.progress_interval),
            "DJPT_RETRY_ATTEMPTS": str(s.jobs.retry_attempts),
            # Limits
            "DJPT_MAX_FILE_SIZE_MB": str(s.limits.max_file_size_mb),
            "DJPT_MAX_CONCURRENT_JOBS": str(s.limits.max_concurrent_jobs),
            "DJPT_MAX_MEMORY_USAGE": str(s.limits.max_memory_usage),
            "DJPT_DISK_SPACE_THRESHOLD": str(s.limits.disk_space_threshold),
        }

    def detect_capabilities(self, force_refresh: bool = False) -> Dict[str, Any]:
        """Detecta capacidades AI del sistema"""
        if self._capabilities is None or force_refresh:
            self._capabilities = self._detect_capabilities_impl()
            self._save_capabilities()
        return self._capabilities

    def _detect_capabilities_impl(self) -> Dict[str, Any]:
        """Implementación de detección de capacidades"""
        import subprocess
        import sys

        detection_timeout = int(os.environ.get("DJPT_DETECTION_TIMEOUT", "30"))

        capabilities = {
            "timestamp": datetime.now().isoformat(),
            "system": {
                "python_version": sys.version.split()[0],
                "platform": sys.platform,
                "arch": os.uname().machine if hasattr(os, "uname") else "unknown",
                "cpu_count": os.cpu_count(),
            },
            "backends": {
                "mlx": {
                    "available": False,
                    "gpu_available": False,
                    "version": None,
                },
                "tensorflow": {
                    "available": False,
                    "gpu_available": False,
                    "version": None,
                },
                "ollama": {"available": False, "version": None, "models": []},
            },
        }

        # Detectar MLX
        try:
            result = subprocess.run(
                [
                    sys.executable,
                    "-c",
                    "import mlx.core as mx; print(mx.__version__); print(mx.metal.is_available())",
                ],
                capture_output=True,
                text=True,
                timeout=detection_timeout,
            )

            if result.returncode == 0:
                lines = result.stdout.strip().split("\n")
                capabilities["backends"]["mlx"] = {
                    "available": True,
                    "version": lines[0],
                    "gpu_available": len(lines) > 1 and lines[1].strip() == "True",
                }
        except Exception:
            pass

        # Detectar TensorFlow
        try:
            result = subprocess.run(
                [
                    sys.executable,
                    "-c",
                    "import tensorflow as tf; print(tf.__version__); print(len(tf.config.list_physical_devices('GPU')))",  # noqa: E501
                ],
                capture_output=True,
                text=True,
                timeout=detection_timeout,
            )

            if result.returncode == 0:
                lines = result.stdout.strip().split("\n")
                capabilities["backends"]["tensorflow"] = {
                    "available": True,
                    "version": lines[0],
                    "gpu_available": len(lines) > 1 and int(lines[1]) > 0,
                }
        except Exception:
            pass

        # Detectar Ollama
        try:
            result = subprocess.run(
                ["ollama", "--version"],
                capture_output=True,
                text=True,
                timeout=min(10, detection_timeout),
            )
            if result.returncode == 0:
                capabilities["backends"]["ollama"]["available"] = True
                capabilities["backends"]["ollama"]["version"] = result.stdout.strip()

                # Listar modelos
                list_result = subprocess.run(
                    ["ollama", "list"],
                    capture_output=True,
                    text=True,
                    timeout=detection_timeout,
                )
                if list_result.returncode == 0:
                    lines = list_result.stdout.strip().split("\n")[1:]  # Skip header
                    capabilities["backends"]["ollama"]["models"] = [line.split()[0] for line in lines if line.strip()]
        except Exception:
            pass

        return capabilities

    def _save_capabilities(self) -> None:
        """Guarda capacidades a JSON"""
        try:
            STATE_DIR.mkdir(parents=True, exist_ok=True)
            tmp = CAPABILITIES_FILE.with_suffix(".tmp")
            with open(tmp, "w") as f:
                json.dump(self._capabilities, f, indent=2)
            tmp.replace(CAPABILITIES_FILE)
        except Exception as e:
            print(f"[WARN] Failed to save capabilities: {e}")

    def select_best_backend(self) -> str:
        """Selecciona el mejor backend disponible"""
        caps = self.detect_capabilities()
        preferred = self.settings.general.preferred_backend

        # Si se prefiere uno específico y está disponible
        if preferred != "auto":
            if preferred == "mlx" and caps["backends"]["mlx"]["available"]:
                return "mlx"
            elif preferred == "tensorflow" and caps["backends"]["tensorflow"]["available"]:
                return "tensorflow"
            elif preferred == "ollama" and caps["backends"]["ollama"]["available"]:
                return "ollama"

        # Selección automática por capacidad
        if caps["backends"]["mlx"]["available"] and caps["backends"]["mlx"]["gpu_available"]:
            return "mlx"
        elif caps["backends"]["tensorflow"]["available"] and caps["backends"]["tensorflow"]["gpu_available"]:
            return "tensorflow"
        elif caps["backends"]["ollama"]["available"]:
            return "ollama"
        elif caps["backends"]["mlx"]["available"]:
            return "mlx"
        elif caps["backends"]["tensorflow"]["available"]:
            return "tensorflow"
        else:
            return "none"


# Instancia global del gestor
config_manager = ConfigManager()


# Funciones de compatibilidad con código existente
def load_settings(config_path: Optional[Path] = None) -> Settings:
    return config_manager.load_settings(config_path)


def save_settings(settings: Settings, config_path: Optional[Path] = None) -> bool:
    return config_manager.save_settings(settings)


def get_nested_setting(settings: Settings, path: str) -> Any:
    return config_manager.get_nested_setting(path)


def set_nested_setting(settings: Settings, path: str, value: Any) -> None:
    config_manager.set_nested_setting(path, value)


def export_all_env_vars(settings: Settings) -> Dict[str, str]:
    return config_manager.export_env_vars()
