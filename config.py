from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict

try:  # py311+
    import tomllib
except ImportError:  # pragma: no cover
    import tomli as tomllib  # type: ignore


BASE_DIR = Path(__file__).resolve().parents[1]
CONFIG_FILE = BASE_DIR / "config" / "ai_model_params.toml"


@dataclass
class General:
    preferred_backend: str = "auto"
    temperature: float = 0.7
    batch_size: int = 32
    allow_gpu: bool = True
    max_files: int = 5000
    parallel_threads: int = 4
    max_memory_gb: int = 8


@dataclass
class MLX:
    cache_limit_mb: int = 1024
    device: str = "metal"
    enable_gpu: bool = True
    memory_fraction: float = 0.25


@dataclass
class TensorFlow:
    intraop_threads: int = 0
    interop_threads: int = 0
    gpu_memory_growth: bool = True
    device: str = "auto"
    mixed_precision: bool = True


@dataclass
class Ollama:
    base_url: str = "http://localhost:11434"
    default_model: str = "llama2"
    timeout_seconds: int = 30
    max_tokens: int = 2048
    temperature: float = 0.7


@dataclass
class Threads:
    cpu_threads: int = os.cpu_count() or 4
    tf_intraop: int = 0
    tf_interop: int = 0


@dataclass
class Jobs:
    scan_workers: int = 4
    batch_processing: bool = True
    chunk_size: int = 1000
    progress_interval: int = 10
    retry_attempts: int = 3


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
    max_sessions: int = 5
    session_timeout: int = 1800
    save_patterns: bool = True
    adaptive_mode: bool = True


@dataclass
class Limits:
    max_file_size_mb: int = 500
    max_concurrent_jobs: int = 3
    max_memory_usage: float = 0.8
    disk_space_threshold: float = 0.9


@dataclass
class Trends:
    max_files: int = 5000


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


def _merge_section(section_cls, data: Dict[str, Any]):
    obj = section_cls()
    for k, v in data.items():
        if hasattr(obj, k):
            setattr(obj, k, v)
    return obj


def load_settings(config_path: Path = CONFIG_FILE) -> Settings:
    if not config_path.exists():
        return Settings()

    data = tomllib.loads(config_path.read_text())
    settings = Settings()

    # Mapear todas las secciones del TOML
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

    for section_name, (section_cls, attr_name) in section_mappings.items():
        if section_name in data:
            merged = _merge_section(section_cls, data[section_name])
            setattr(settings, attr_name, merged)

    return settings


def save_settings(settings: Settings, config_path: Path = CONFIG_FILE) -> None:
    config_path.parent.mkdir(parents=True, exist_ok=True)

    # Serializar todas las secciones
    content = {
        "general": settings.general.__dict__,
        "mlx": settings.mlx.__dict__,
        "tensorflow": settings.tensorflow.__dict__,
        "ollama": settings.ollama.__dict__,
        "threads": settings.threads.__dict__,
        "jobs": settings.jobs.__dict__,
        "optimization": settings.optimization.__dict__,
        "learning": settings.learning.__dict__,
        "limits": settings.limits.__dict__,
        "trends": settings.trends.__dict__,
    }

    try:
        import tomli_w  # lightweight writer

        config_path.write_text(tomli_w.dumps(content), encoding="utf-8")
    except ImportError:
        # Fallback: simple TOML writing
        lines = []
        for section_name, section_data in content.items():
            lines.append(f"[{section_name}]")
            for k, v in section_data.items():
                lines.append(f"{k} = {repr(v)}")
            lines.append("")  # Empty line between sections

        config_path.write_text("\n".join(lines), encoding="utf-8")


def get_nested_setting(settings: Settings, path: str) -> Any:
    """Get setting by dot notation path (e.g., 'mlx.device', 'limits.max_memory_usage')"""
    parts = path.split(".")
    if len(parts) != 2:
        raise ValueError(f"Invalid path format: {path}. Expected 'section.key'")

    section_name, key = parts
    if not hasattr(settings, section_name):
        raise ValueError(f"Unknown section: {section_name}")

    section_obj = getattr(settings, section_name)
    if not hasattr(section_obj, key):
        raise ValueError(f"Unknown key: {key} in section {section_name}")

    return getattr(section_obj, key)


def set_nested_setting(settings: Settings, path: str, value: Any) -> None:
    """Set setting by dot notation path (e.g., 'mlx.device', 'limits.max_memory_usage')"""
    parts = path.split(".")
    if len(parts) != 2:
        raise ValueError(f"Invalid path format: {path}. Expected 'section.key'")

    section_name, key = parts
    if not hasattr(settings, section_name):
        raise ValueError(f"Unknown section: {section_name}")

    section_obj = getattr(settings, section_name)
    if not hasattr(section_obj, key):
        raise ValueError(f"Unknown key: {key} in section {section_name}")

    # Type casting
    current = getattr(section_obj, key)
    if isinstance(current, bool):
        value = str(value).lower() in ("1", "true", "yes", "on")
    elif isinstance(current, int):
        value = int(value)
    elif isinstance(current, float):
        value = float(value)

    setattr(section_obj, key, value)


def export_all_env_vars(settings: Settings) -> Dict[str, str]:
    """Export all relevant settings as environment variables"""
    env_vars = {}

    # General
    env_vars["DJPT_PREFERRED_BACKEND"] = settings.general.preferred_backend
    env_vars["DJPT_PARALLEL_THREADS"] = str(settings.general.parallel_threads)
    env_vars["DJPT_MAX_MEMORY_GB"] = str(settings.general.max_memory_gb)
    env_vars["DJPT_MAX_FILES"] = str(settings.general.max_files)

    # MLX
    env_vars["DJPT_MLX_DEVICE"] = settings.mlx.device
    env_vars["DJPT_MLX_ENABLE_GPU"] = str(settings.mlx.enable_gpu)
    env_vars["DJPT_MLX_MEMORY_FRACTION"] = str(settings.mlx.memory_fraction)

    # TensorFlow
    env_vars["TF_INTRAOP_THREADS"] = str(settings.tensorflow.intraop_threads)
    env_vars["TF_INTEROP_THREADS"] = str(settings.tensorflow.interop_threads)
    env_vars["DJPT_TF_DEVICE"] = settings.tensorflow.device
    env_vars["DJPT_TF_MIXED_PRECISION"] = str(settings.tensorflow.mixed_precision)

    # Ollama
    env_vars["DJPT_OLLAMA_BASE_URL"] = settings.ollama.base_url
    env_vars["DJPT_OLLAMA_DEFAULT_MODEL"] = settings.ollama.default_model

    # Threads
    env_vars["DJPT_CPU_THREADS"] = str(settings.threads.cpu_threads)

    # Jobs
    env_vars["DJPT_SCAN_WORKERS"] = str(settings.jobs.scan_workers)
    env_vars["DJPT_CHUNK_SIZE"] = str(settings.jobs.chunk_size)

    # Limits
    env_vars["DJPT_MAX_FILE_SIZE_MB"] = str(settings.limits.max_file_size_mb)
    env_vars["DJPT_MAX_CONCURRENT_JOBS"] = str(settings.limits.max_concurrent_jobs)
    env_vars["DJPT_MAX_MEMORY_USAGE"] = str(settings.limits.max_memory_usage)

    return env_vars
