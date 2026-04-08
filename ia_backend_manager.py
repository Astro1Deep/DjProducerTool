"""IA backend manager
======================

Lightweight, side‑effect–free status checks for local AI backends (Ollama,
OpenAI key, Hugging Face token, MLX, TensorFlow) plus minimal auto‑heal hooks.

Design goals
------------
- **No heavy imports**: avoid hanging on MLX/TF by using `find_spec` instead of
  importing. Respect `DJPT_SKIP_MLX` / `DJPT_SKIP_TF` to keep tests fast and to
  honor the hardening runbook.
- **Deterministic output**: status is a pure function of env + filesystem.
- **Safe heal**: only creates local cache/model directories under `base_path`.
"""

from __future__ import annotations

import os
import shutil
from argparse import ArgumentParser
from dataclasses import dataclass, field, asdict
from importlib.util import find_spec
from pathlib import Path
from typing import List, Optional, Tuple


@dataclass
class BackendStatus:
    ollama_ready: bool
    openai_ready: bool
    hf_ready: bool
    mlx_available: bool
    tf_available: bool
    messages: List[str] = field(default_factory=list)

    def summary(self) -> str:
        flags = []
        flags.append(f"ollama={'ok' if self.ollama_ready else 'missing'}")
        flags.append(f"openai={'ok' if self.openai_ready else 'missing'}")
        flags.append(f"hf={'ok' if self.hf_ready else 'missing'}")
        flags.append(f"mlx={'ok' if self.mlx_available else 'missing'}")
        flags.append(f"tf={'ok' if self.tf_available else 'missing'}")
        return ", ".join(flags)


@dataclass
class HealResult:
    actions: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)


class IABackendManager:
    def __init__(self, base_path: Path):
        self.base_path = Path(base_path)

    def status(self) -> BackendStatus:
        messages: List[str] = []
        ollama_ready = shutil.which("ollama") is not None
        if not ollama_ready:
            messages.append("Instala Ollama: brew install ollama; inicia con 'ollama serve'")

        openai_ready = bool(os.environ.get("OPENAI_API_KEY"))
        if not openai_ready:
            messages.append("Falta OPENAI_API_KEY en entorno")

        hf_ready = bool(os.environ.get("HUGGINGFACE_TOKEN") or os.environ.get("HF_TOKEN"))
        if not hf_ready:
            messages.append("Falta HUGGINGFACE_TOKEN/HF_TOKEN para modelos HF")

        mlx_available, mlx_msg = self._module_available("mlx", skip_env="DJPT_SKIP_MLX")
        tf_available, tf_msg = self._module_available("tensorflow", skip_env="DJPT_SKIP_TF")

        if mlx_msg:
            messages.append(mlx_msg)
        if tf_msg:
            messages.append(tf_msg)

        return BackendStatus(
            ollama_ready=ollama_ready,
            openai_ready=openai_ready,
            hf_ready=hf_ready,
            mlx_available=mlx_available,
            tf_available=tf_available,
            messages=messages,
        )

    def auto_heal(self) -> HealResult:
        actions: List[str] = []
        warnings: List[str] = []

        models_dir = self.base_path / "ai" / "models"
        try:
            models_dir.mkdir(parents=True, exist_ok=True)
            actions.append(f"mkdir -p {models_dir}")
        except Exception as e:
            warnings.append(f"No se pudo crear {models_dir}: {e}")

        cache_dir = self.base_path / "state" / "cache"
        try:
            cache_dir.mkdir(parents=True, exist_ok=True)
            actions.append(f"mkdir -p {cache_dir}")
        except Exception as e:
            warnings.append(f"No se pudo crear {cache_dir}: {e}")

        return HealResult(actions=actions, warnings=warnings)

    def _module_available(self, module: str, skip_env: Optional[str] = None) -> Tuple[bool, Optional[str]]:
        """Check availability without importing heavy modules.

        Returns (available, message). The message is suitable for user-facing
        diagnostics and is only set when availability is False or explicitly
        skipped.
        """

        if skip_env and os.environ.get(skip_env):
            return False, f"{module} saltado por {skip_env}=1"

        if find_spec(module) is not None:
            return True, None

        return False, f"{module} no instalado"


def _cli() -> int:
    parser = ArgumentParser(description="IA backend status and safe auto-heal")
    parser.add_argument("--base-path", default=".", help="Directorio base de DJPT/SeratOrganizer")
    parser.add_argument("--heal", action="store_true", help="Crear carpetas locales de cache/modelos si faltan")
    parser.add_argument("--json", action="store_true", help="Emitir JSON en stdout")
    args = parser.parse_args()

    manager = IABackendManager(Path(args.base_path))
    status = manager.status()
    heal_result = manager.auto_heal() if args.heal else None

    payload = {
        "status": asdict(status),
        "heal": asdict(heal_result) if heal_result else None,
    }

    if args.json:
        import json

        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        print(status.summary())
        for msg in status.messages:
            print(f"- {msg}")
        if heal_result:
            for action in heal_result.actions:
                print(f"[heal] {action}")
            for warn in heal_result.warnings:
                print(f"[warn] {warn}")

    return 0


if __name__ == "__main__":
    raise SystemExit(_cli())
