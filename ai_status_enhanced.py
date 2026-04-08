from __future__ import annotations

import argparse
import sys
import time
from importlib.util import find_spec
from pathlib import Path
from shutil import which
from typing import Any
import tomllib
import urllib.request

from scripts.lib.report_json import dump_report, write_report


def _status(value: bool) -> str:
    return "ok" if value else "warn"


def _check(status: str, details: str, suggestion: str | None = None) -> dict[str, Any]:
    payload: dict[str, Any] = {"status": status, "details": details}
    if suggestion and status in {"warn", "fail"}:
        payload["suggestion"] = suggestion
    return payload


def _load_ai_config(repo_root: Path) -> dict[str, Any]:
    cfg_path = repo_root / "config" / "ai_model_params.toml"
    if not cfg_path.exists():
        return {}
    with cfg_path.open("rb") as fh:
        return tomllib.load(fh)


def _probe_http(url: str, timeout: float = 1.5) -> bool:
    try:
        with urllib.request.urlopen(url, timeout=timeout):
            return True
    except Exception:
        return False


def build_payload(models_dir: Path) -> dict[str, Any]:
    start = time.perf_counter()
    repo_root = Path(__file__).resolve().parent
    config = _load_ai_config(repo_root)
    mlx_available = find_spec("mlx") is not None
    tf_available = find_spec("tensorflow") is not None
    sklearn_available = find_spec("sklearn") is not None
    transformers_available = find_spec("transformers") is not None
    sentence_transformers_available = find_spec("sentence_transformers") is not None
    ollama_available = which("ollama") is not None
    asr_assets_present = models_dir.exists() and any(models_dir.iterdir()) if models_dir.exists() else False
    transformers_cfg = config.get("transformers", {})
    transformers_enabled = bool(transformers_cfg.get("enabled", False))
    transformers_model_ref = str(transformers_cfg.get("model_path") or transformers_cfg.get("model") or "").strip()
    transformers_model_ok = False
    if transformers_enabled and transformers_model_ref:
        model_path = Path(transformers_model_ref)
        if not model_path.is_absolute():
            model_path = (repo_root / model_path).resolve()
        transformers_model_ok = model_path.exists()

    openai_local_cfg = config.get("openai_local", {})
    openai_local_enabled = bool(openai_local_cfg.get("enabled", False))
    openai_local_base = str(openai_local_cfg.get("base_url", "")).strip().rstrip("/")
    openai_local_health = str(openai_local_cfg.get("healthcheck_path", "/health") or "/health").strip()
    if not openai_local_health.startswith("/"):
        openai_local_health = f"/{openai_local_health}"
    openai_local_ok = bool(openai_local_enabled and openai_local_base and _probe_http(f"{openai_local_base}{openai_local_health}"))

    checks = {
        "models_dir": _check(
            "ok" if models_dir.exists() else "warn",
            f"models_dir={models_dir}",
            suggestion="Crea el directorio de modelos IA o monta la ruta correcta.",
        ),
        "mlx": _check(_status(mlx_available), "MLX import spec detectado" if mlx_available else "MLX no instalado", "Instala MLX para Apple Silicon."),
        "tensorflow": _check(
            _status(tf_available),
            "TensorFlow import spec detectado" if tf_available else "TensorFlow no instalado",
            "Instala tensorflow-macos/tensorflow-metal si necesitas esa ruta.",
        ),
        "sklearn": _check(
            _status(sklearn_available),
            "scikit-learn import spec detectado" if sklearn_available else "scikit-learn no instalado",
            "Instala scikit-learn para operaciones locales.",
        ),
        "ollama": _check(
            "ok" if ollama_available else "warn",
            "Comando ollama disponible" if ollama_available else "Comando ollama ausente",
            "Instala Ollama y arranca el servicio local si vas a usar LLM local.",
        ),
        "transformers": _check(
            "ok" if not transformers_enabled or (transformers_available and transformers_model_ok) else "warn",
            (
                "Backend Transformers desactivado"
                if not transformers_enabled
                else "Transformers local listo"
                if transformers_available and transformers_model_ok
                else "Transformers habilitado pero falta módulo o modelo local"
            ),
            "Configura [transformers] en config/ai_model_params.toml y deja un modelo local accesible.",
        ),
        "openai_local": _check(
            "ok" if not openai_local_enabled or openai_local_ok else "warn",
            (
                "Backend OpenAI local desactivado"
                if not openai_local_enabled
                else "Endpoint OpenAI local accesible"
                if openai_local_ok
                else "OpenAI local habilitado pero el endpoint no responde"
            ),
            "Activa el servicio compatible y revisa [openai_local] en config/ai_model_params.toml.",
        ),
    }

    return {
        "schema_version": "ai_status_v2",
        "summary": {
            "overall_status": "ok" if all(check["status"] == "ok" for check in checks.values()) else "warn",
            "models_dir": str(models_dir),
        },
        "mlx_llm": {
            "severity": _status(mlx_available),
            "details": "MLX listo para LLM local" if mlx_available else "MLX no está disponible",
        },
        "embeddings": {
            "severity": _status(sentence_transformers_available or sklearn_available),
            "details": (
                "Embeddings locales disponibles"
                if sentence_transformers_available or sklearn_available
                else "No hay backend local de embeddings detectado"
            ),
        },
        "asr": {
            "severity": "ok" if asr_assets_present else "warn",
            "details": "Directorio de modelos con contenido" if asr_assets_present else "No se detectaron assets ASR en models_dir",
        },
        "ollama": {
            "severity": "ok" if ollama_available else "warn",
            "details": "Ollama binario disponible" if ollama_available else "Ollama no está instalado en PATH",
        },
        "checks": checks,
        "execution_ms": round((time.perf_counter() - start) * 1000, 3),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Estado IA mejorado y determinista")
    parser.add_argument("--models-dir", type=Path, default=Path("ai/models"))
    parser.add_argument("--format", choices=("json", "text"), default="text")
    parser.add_argument("--lang", default="ES")
    args = parser.parse_args(argv)

    repo_root = Path(__file__).resolve().parent
    models_dir = args.models_dir.resolve() if not args.models_dir.is_absolute() else args.models_dir
    payload = build_payload(models_dir)
    output_path = repo_root / "state" / "reports" / "ai_status.json"
    write_report(payload, output_path, schema_version="ai_status_v2", execution_ms=payload["execution_ms"])

    if args.format == "json":
        sys.stdout.write(dump_report(payload, schema_version="ai_status_v2", execution_ms=payload["execution_ms"]))
    else:
        print("AI status")
        print(f"- Overall: {payload['summary']['overall_status']}")
        for key in ("mlx_llm", "embeddings", "asr", "ollama"):
            entry = payload[key]
            print(f"- {key}: {entry['severity']} ({entry['details']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
