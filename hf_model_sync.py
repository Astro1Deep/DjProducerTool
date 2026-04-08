from __future__ import annotations

import argparse
import json
import os
import re
import time
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

import tomllib

from scripts.lib.report_json import dump_report, write_report


SCHEMA_VERSION = "hf_model_sync_v1"


@dataclass
class HFConfig:
    enabled: bool
    model: str
    revision: str
    local_dir: Path
    allow_remote: bool
    require_token: bool
    verify_remote: bool
    apply_to_transformers: bool
    enable_transformers_after_sync: bool
    local_files_only: bool
    config_path: Path
    repo_root: Path


def _slug_model(model_id: str) -> str:
    sanitized = re.sub(r"[^A-Za-z0-9._-]+", "-", model_id.strip())
    sanitized = sanitized.strip("-._")
    return sanitized or "model"


def _load_toml(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    with path.open("rb") as fh:
        return tomllib.load(fh)


def _resolve_config_path(repo_root: Path) -> Path:
    override = os.environ.get("DJPT_CONFIG_FILE")
    if override:
        return Path(override).expanduser().resolve()
    return (repo_root / "config" / "ai_model_params.toml").resolve()


def load_hf_config(repo_root: Path) -> HFConfig:
    config_path = _resolve_config_path(repo_root)
    config_data = _load_toml(config_path)
    hf_cfg = config_data.get("huggingface", {})
    tr_cfg = config_data.get("transformers", {})

    model = str(hf_cfg.get("model") or tr_cfg.get("model") or "").strip()
    revision = str(hf_cfg.get("revision", "main")).strip() or "main"

    default_dir = f"state/models/huggingface/{_slug_model(model) if model else 'model'}"
    local_dir_value = str(hf_cfg.get("local_dir") or tr_cfg.get("model_path") or default_dir).strip()
    local_dir = Path(local_dir_value)
    if not local_dir.is_absolute():
        local_dir = (repo_root / local_dir).resolve()

    return HFConfig(
        enabled=bool(hf_cfg.get("enabled", False)),
        model=model,
        revision=revision,
        local_dir=local_dir,
        allow_remote=bool(hf_cfg.get("allow_remote", False)),
        require_token=bool(hf_cfg.get("require_token", False)),
        verify_remote=bool(hf_cfg.get("verify_remote", True)),
        apply_to_transformers=bool(hf_cfg.get("apply_to_transformers", True)),
        enable_transformers_after_sync=bool(hf_cfg.get("enable_transformers_after_sync", False)),
        local_files_only=bool(tr_cfg.get("local_files_only", True)),
        config_path=config_path,
        repo_root=repo_root,
    )


def _token_from_env() -> str | None:
    token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGINGFACE_TOKEN")
    return token.strip() if token else None


def _state_config_path(repo_root: Path) -> Path:
    return repo_root / "state" / "config" / "ai_backends.json"


def _sync_transformers_binding(repo_root: Path, model_dir: Path, enable_backend: bool) -> dict[str, Any]:
    target = _state_config_path(repo_root)
    target.parent.mkdir(parents=True, exist_ok=True)

    if target.exists():
        data = json.loads(target.read_text(encoding="utf-8"))
    else:
        data = {"active_backend": "ollama", "backends": {}}

    backends = data.setdefault("backends", {})
    transformers_cfg = backends.setdefault("transformers", {})
    transformers_cfg["model_path"] = str(model_dir)
    if enable_backend:
        transformers_cfg["enabled"] = True
    target.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return {"path": str(target), "enabled": bool(transformers_cfg.get("enabled", False))}


def _get_hf_clients() -> tuple[type[Any], Callable[..., str]]:
    from huggingface_hub import HfApi, snapshot_download  # type: ignore

    return HfApi, snapshot_download


def _probe_internet(url: str = "https://huggingface.co", timeout: float = 2.0) -> bool:
    try:
        with urllib.request.urlopen(url, timeout=timeout):
            return True
    except Exception:
        return False


def _base_payload(action: str, cfg: HFConfig) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "action": action,
        "config": {
            "enabled": cfg.enabled,
            "model": cfg.model,
            "revision": cfg.revision,
            "local_dir": str(cfg.local_dir),
            "allow_remote": cfg.allow_remote,
            "require_token": cfg.require_token,
            "verify_remote": cfg.verify_remote,
            "apply_to_transformers": cfg.apply_to_transformers,
            "enable_transformers_after_sync": cfg.enable_transformers_after_sync,
            "local_files_only": cfg.local_files_only,
            "config_path": str(cfg.config_path),
        },
        "env": {
            "hf_token_present": bool(_token_from_env()),
        },
    }


def run(
    action: str,
    repo_root: Path,
    *,
    allow_remote_override: bool = False,
    force_enable_override: bool = False,
    require_internet_probe: bool = True,
    verify_remote_override: bool | None = None,
    apply_transformers_override: bool | None = None,
    enable_transformers_override: bool | None = None,
    dry_run: bool = False,
) -> tuple[dict[str, Any], int]:
    start = time.perf_counter()
    cfg = load_hf_config(repo_root)
    payload = _base_payload(action, cfg)

    if action == "status":
        payload["status"] = "ok"
        payload["local"] = {
            "exists": cfg.local_dir.exists(),
            "path": str(cfg.local_dir),
        }
        if not cfg.enabled:
            payload["details"] = "HuggingFace sync desactivado por configuración"
        elif not cfg.model:
            payload["status"] = "warn"
            payload["details"] = "HuggingFace habilitado pero falta model en configuración"
        else:
            payload["details"] = "Configuración HuggingFace lista para sync explícito"
        payload["execution_ms"] = round((time.perf_counter() - start) * 1000, 3)
        return payload, 0 if payload["status"] == "ok" else 1

    if action != "sync":
        payload["status"] = "fail"
        payload["details"] = f"Acción no soportada: {action}"
        payload["execution_ms"] = round((time.perf_counter() - start) * 1000, 3)
        return payload, 2

    enabled = cfg.enabled or force_enable_override
    if not enabled:
        payload["status"] = "warn"
        payload["details"] = "Sync HF desactivado en [huggingface].enabled=false"
        payload["execution_ms"] = round((time.perf_counter() - start) * 1000, 3)
        return payload, 2

    if not cfg.model:
        payload["status"] = "fail"
        payload["details"] = "Falta model en [huggingface]"
        payload["execution_ms"] = round((time.perf_counter() - start) * 1000, 3)
        return payload, 2

    allow_remote = cfg.allow_remote or allow_remote_override
    if not allow_remote:
        payload["status"] = "warn"
        payload["details"] = "Red deshabilitada: activa [huggingface].allow_remote o usa --allow-remote"
        payload["execution_ms"] = round((time.perf_counter() - start) * 1000, 3)
        return payload, 2

    if require_internet_probe:
        online = _probe_internet()
        payload["env"]["internet_online"] = online
        if not online:
            payload["status"] = "fail"
            payload["details"] = "No hay conectividad a HuggingFace Hub (internet offline o bloqueada)"
            payload["execution_ms"] = round((time.perf_counter() - start) * 1000, 3)
            return payload, 2

    token = _token_from_env()
    if cfg.require_token and not token:
        payload["status"] = "fail"
        payload["details"] = "Token HF requerido pero ausente (HF_TOKEN/HUGGINGFACE_TOKEN)"
        payload["execution_ms"] = round((time.perf_counter() - start) * 1000, 3)
        return payload, 2

    verify_remote = cfg.verify_remote if verify_remote_override is None else verify_remote_override
    apply_to_transformers = cfg.apply_to_transformers if apply_transformers_override is None else apply_transformers_override
    enable_transformers = (
        cfg.enable_transformers_after_sync
        if enable_transformers_override is None
        else enable_transformers_override
    )

    try:
        hf_api_cls, snapshot_download = _get_hf_clients()
    except Exception as exc:
        payload["status"] = "fail"
        payload["details"] = f"huggingface_hub no disponible: {exc}"
        payload["execution_ms"] = round((time.perf_counter() - start) * 1000, 3)
        return payload, 2

    remote: dict[str, Any] = {}
    if verify_remote:
        try:
            api = hf_api_cls(token=token)
            info = api.model_info(cfg.model, revision=cfg.revision, token=token)
            remote = {
                "model_id": getattr(info, "id", cfg.model),
                "sha": getattr(info, "sha", None),
                "last_modified": str(getattr(info, "last_modified", "")) or None,
            }
        except Exception as exc:
            payload["status"] = "fail"
            payload["details"] = f"No se pudo verificar remoto en HF Hub: {exc}"
            payload["execution_ms"] = round((time.perf_counter() - start) * 1000, 3)
            return payload, 2

    if dry_run:
        payload["status"] = "ok"
        payload["details"] = "Dry-run completado: modelo remoto verificable y configuración válida"
        payload["remote"] = remote
        payload["local"] = {"path": str(cfg.local_dir), "downloaded": False}
        payload["execution_ms"] = round((time.perf_counter() - start) * 1000, 3)
        return payload, 0

    try:
        cfg.local_dir.mkdir(parents=True, exist_ok=True)
        downloaded_path = snapshot_download(
            repo_id=cfg.model,
            revision=cfg.revision,
            local_dir=str(cfg.local_dir),
            local_dir_use_symlinks=False,
            token=token,
            resume_download=True,
        )
    except Exception as exc:
        payload["status"] = "fail"
        payload["details"] = f"Falló snapshot_download: {exc}"
        payload["execution_ms"] = round((time.perf_counter() - start) * 1000, 3)
        return payload, 2

    payload["remote"] = remote
    payload["local"] = {
        "path": str(Path(downloaded_path).resolve()),
        "downloaded": True,
    }

    if apply_to_transformers:
        binding = _sync_transformers_binding(repo_root, Path(downloaded_path).resolve(), enable_transformers)
        payload["transformers_binding"] = {
            "applied": True,
            **binding,
        }
    else:
        payload["transformers_binding"] = {"applied": False}

    payload["status"] = "ok"
    payload["details"] = "Sync HF completado y modelo local pinneado"
    payload["execution_ms"] = round((time.perf_counter() - start) * 1000, 3)
    return payload, 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Sync controlado de modelos HuggingFace para DJProducerTools")
    parser.add_argument("action", choices=["status", "sync"], help="Acción a ejecutar")
    parser.add_argument("--allow-remote", action="store_true", help="Permite acceso de red para sync remoto")
    parser.add_argument("--force-enable", action="store_true", help="Permite sync aunque [huggingface].enabled=false")
    parser.add_argument("--no-internet-probe", action="store_true", help="Omite prueba explícita de internet antes del sync")
    parser.add_argument("--no-verify-remote", action="store_true", help="Omite model_info remoto antes de descargar")
    parser.add_argument("--no-apply-transformers", action="store_true", help="No actualiza state/config/ai_backends.json")
    parser.add_argument("--enable-transformers", action="store_true", help="Marca transformers.enabled=true al aplicar binding")
    parser.add_argument("--dry-run", action="store_true", help="Valida sin descargar archivos")
    parser.add_argument("--format", choices=["json", "text"], default="text")
    args = parser.parse_args(argv)

    repo_root = Path(__file__).resolve().parent
    payload, rc = run(
        action=args.action,
        repo_root=repo_root,
        allow_remote_override=args.allow_remote,
        force_enable_override=args.force_enable,
        require_internet_probe=not args.no_internet_probe,
        verify_remote_override=not args.no_verify_remote,
        apply_transformers_override=not args.no_apply_transformers,
        enable_transformers_override=args.enable_transformers,
        dry_run=args.dry_run,
    )

    output_path = repo_root / "state" / "reports" / "hf_model_sync.json"
    write_report(payload, output_path, schema_version=SCHEMA_VERSION, execution_ms=payload.get("execution_ms"))

    if args.format == "json":
        print(dump_report(payload, schema_version=SCHEMA_VERSION, execution_ms=payload.get("execution_ms")), end="")
    else:
        print(f"[HF] action={args.action} status={payload.get('status')}")
        print(f"[HF] details={payload.get('details')}")
        if "local" in payload:
            local = payload["local"]
            print(f"[HF] local={local.get('path')} downloaded={local.get('downloaded')}")
        if "remote" in payload:
            remote = payload["remote"]
            print(f"[HF] remote_model={remote.get('model_id', payload['config']['model'])} sha={remote.get('sha')}")

    return rc


if __name__ == "__main__":
    raise SystemExit(main())
