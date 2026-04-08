from __future__ import annotations

import os
import sys
import time
import urllib.request
from importlib.util import find_spec
from pathlib import Path
from typing import Any
import tomllib

from ia_backend_manager import IABackendManager
from scripts.lib.report_json import dump_report, write_report


def _severity(ok: bool, missing_is_fail: bool = False) -> str:
    if ok:
        return "ok"
    return "fail" if missing_is_fail else "warn"


def _backend_entry(available: bool, detail: str, missing_is_fail: bool = False) -> dict[str, Any]:
    return {
        "available": available,
        "status": _severity(available, missing_is_fail=missing_is_fail),
        "details": detail,
    }


def _optional_remote_entry(available: bool, present_detail: str, missing_detail: str, required: bool = False) -> dict[str, Any]:
    if available:
        return {
            "available": True,
            "status": "ok",
            "details": present_detail,
        }

    if required:
        return {
            "available": False,
            "status": "warn",
            "details": missing_detail,
        }

    return {
        "available": False,
        "status": "ok",
        "details": f"Opcional (local-first): {missing_detail}",
    }


def _optional_stack_entry(available: bool, present_detail: str, missing_detail: str, required: bool = False) -> dict[str, Any]:
    if available:
        return {
            "available": True,
            "status": "ok",
            "details": present_detail,
        }
    if required:
        return {
            "available": False,
            "status": "warn",
            "details": missing_detail,
        }
    return {
        "available": False,
        "status": "ok",
        "details": f"Opcional (local-first): {missing_detail}",
    }


def _load_ai_config(repo_root: Path) -> dict[str, Any]:
    cfg_path = repo_root / "config" / "ai_model_params.toml"
    if not cfg_path.exists():
        return {}
    with cfg_path.open("rb") as fh:
        return tomllib.load(fh)


def _optional_local_backend_entry(enabled: bool, available: bool, ok_detail: str, warn_detail: str, disabled_detail: str) -> dict[str, Any]:
    if not enabled:
        return {
            "available": False,
            "status": "ok",
            "details": disabled_detail,
        }
    return {
        "available": available,
        "status": "ok" if available else "warn",
        "details": ok_detail if available else warn_detail,
    }


def _probe_http(url: str, timeout: float = 1.5) -> bool:
    try:
        with urllib.request.urlopen(url, timeout=timeout):
            return True
    except Exception:
        return False


def build_payload(repo_root: Path) -> tuple[dict[str, Any], int]:
    start = time.perf_counter()
    base_path = Path(os.environ.get("BASE_PATH") or os.environ.get("DJPT_BASE_DIR") or repo_root).resolve()
    manager = IABackendManager(base_path)
    status = manager.status()
    config = _load_ai_config(repo_root)
    sklearn_available = find_spec("sklearn") is not None
    transformers_available = find_spec("transformers") is not None
    require_openai = os.environ.get("DJPT_REQUIRE_OPENAI", "0") == "1"
    require_hf = os.environ.get("DJPT_REQUIRE_HF", "0") == "1"
    require_mlx = os.environ.get("DJPT_REQUIRE_MLX", "0") == "1"
    require_tf = os.environ.get("DJPT_REQUIRE_TENSORFLOW", "0") == "1"
    require_ollama = os.environ.get("DJPT_REQUIRE_OLLAMA", "0") == "1"
    transformers_cfg = config.get("transformers", {})
    openai_local_cfg = config.get("openai_local", {})
    transformers_enabled = bool(transformers_cfg.get("enabled", False))
    transformers_model_ref = str(transformers_cfg.get("model_path") or transformers_cfg.get("model") or "").strip()
    transformers_ready = False
    transformers_detail = "Ruta local Transformers desactivada"
    if transformers_enabled:
        if not transformers_available:
            transformers_detail = "Transformers habilitado pero el módulo no está instalado"
        elif not transformers_model_ref:
            transformers_detail = "Transformers habilitado pero falta model/model_path local"
        else:
            model_path = Path(transformers_model_ref)
            if not model_path.is_absolute():
                model_path = (repo_root / model_path).resolve()
            if model_path.exists():
                transformers_ready = True
                transformers_detail = f"Transformers local listo: {model_path}"
            else:
                transformers_detail = f"Transformers habilitado pero no existe el modelo local: {model_path}"

    openai_local_enabled = bool(openai_local_cfg.get("enabled", False))
    openai_local_base = str(openai_local_cfg.get("base_url", "")).strip().rstrip("/")
    openai_local_health = str(openai_local_cfg.get("healthcheck_path", "/health") or "/health").strip()
    if not openai_local_health.startswith("/"):
        openai_local_health = f"/{openai_local_health}"
    openai_local_ready = False
    openai_local_detail = "Backend OpenAI local desactivado"
    if openai_local_enabled:
        if not openai_local_base:
            openai_local_detail = "OpenAI local habilitado pero falta base_url"
        else:
            health_url = f"{openai_local_base}{openai_local_health}"
            openai_local_ready = _probe_http(health_url)
            if openai_local_ready:
                openai_local_detail = f"Endpoint OpenAI local accesible: {health_url}"
            else:
                openai_local_detail = f"OpenAI local habilitado pero no responde: {health_url}"

    raw_messages = list(status.messages)
    filtered_messages: list[str] = []
    for message in raw_messages:
        if "OPENAI_API_KEY" in message and not require_openai:
            continue
        if "HUGGINGFACE_TOKEN" in message and not require_hf:
            continue
        if "mlx" in message.lower() and not require_mlx:
            continue
        if "tensorflow" in message.lower() and not require_tf:
            continue
        if "ollama" in message.lower() and not require_ollama:
            continue
        filtered_messages.append(message)

    backends = {
        "mlx": _optional_stack_entry(
            status.mlx_available,
            "MLX detectado",
            "MLX no disponible",
            required=require_mlx,
        ),
        "tensorflow": _optional_stack_entry(
            status.tf_available,
            "TensorFlow detectado",
            "TensorFlow no disponible",
            required=require_tf,
        ),
        "scikit_learn": _backend_entry(
            sklearn_available,
            "scikit-learn detectado" if sklearn_available else "scikit-learn no disponible",
        ),
        "ollama": _optional_stack_entry(
            status.ollama_ready,
            "Comando ollama disponible" if status.ollama_ready else "Comando ollama no encontrado",
            "Comando ollama no encontrado",
            required=require_ollama,
        ),
        "openai": _optional_remote_entry(
            status.openai_ready,
            "OPENAI_API_KEY configurada",
            "OPENAI_API_KEY ausente",
            required=require_openai,
        ),
        "huggingface": _optional_remote_entry(
            status.hf_ready,
            "Token HF configurado",
            "Falta HUGGINGFACE_TOKEN/HF_TOKEN",
            required=require_hf,
        ),
        "transformers": _optional_local_backend_entry(
            transformers_enabled,
            transformers_ready,
            transformers_detail,
            transformers_detail,
            "Opcional: backend Transformers local desactivado",
        ),
        "openai_local": _optional_local_backend_entry(
            openai_local_enabled,
            openai_local_ready,
            openai_local_detail,
            openai_local_detail,
            "Opcional: backend OpenAI local desactivado",
        ),
    }

    status_values = {entry["status"] for entry in backends.values()}
    if "fail" in status_values:
        overall_status = "fail"
        exit_code = 2
    elif "warn" in status_values:
        overall_status = "warn"
        exit_code = 1
    else:
        overall_status = "ok"
        exit_code = 0

    execution_ms = round((time.perf_counter() - start) * 1000, 3)
    payload = {
        "schema_version": "ai_health_v2",
        "base_path": str(base_path),
        "reports_dir": str((repo_root / "state" / "reports").resolve()),
        "summary": {
            "overall_status": overall_status,
            "available_backend_count": sum(1 for entry in backends.values() if entry["available"]),
            "total_backend_count": len(backends),
        },
        "backends": backends,
        "messages": filtered_messages,
        "python": {
            "executable": sys.executable,
            "version": sys.version.split()[0],
        },
        "execution_ms": execution_ms,
    }
    return payload, exit_code


def main() -> int:
    repo_root = Path(__file__).resolve().parent
    payload, exit_code = build_payload(repo_root)
    output_path = repo_root / "state" / "reports" / "ai_health.json"
    write_report(payload, output_path, schema_version="ai_health_v2", execution_ms=payload["execution_ms"])
    sys.stdout.write(dump_report(payload, schema_version="ai_health_v2", execution_ms=payload["execution_ms"]))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
