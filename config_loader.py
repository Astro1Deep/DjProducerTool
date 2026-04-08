from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, List

import yaml


class AgentMode(str, Enum):
    OPERATIONAL = "agentic_operational"
    SAFE = "safe_mode"


@dataclass
class SafetyConfig:
    safe_mode: bool = True
    require_confirmation_for_destructive_actions: bool = True


@dataclass
class PlatformConfig:
    os: str = "macOS"
    architecture: str = "apple_silicon"
    chip: str = "M4_Pro"


@dataclass
class AIConfig:
    local_first: bool = True
    frameworks: List[str] = field(default_factory=lambda: ["mlx"])
    models: dict[str, Any] = field(default_factory=dict)


@dataclass
class MetricsConfig:
    tracked_metrics: List[str] = field(default_factory=list)


@dataclass
class LoggingConfig:
    level: str = "INFO"


@dataclass
class AgentConfig:
    name: str = "audio_ai_architect"
    mode: AgentMode = AgentMode.OPERATIONAL
    cycle: List[str] = field(default_factory=lambda: ["PLAN", "EXECUTE", "VALIDATE", "REPORT"])
    safety: SafetyConfig = field(default_factory=SafetyConfig)
    platform: PlatformConfig = field(default_factory=PlatformConfig)
    ai: AIConfig = field(default_factory=AIConfig)
    metrics: MetricsConfig = field(default_factory=MetricsConfig)
    logging: LoggingConfig = field(default_factory=LoggingConfig)


class ConfigLoader:
    def load_config(self, config_path: str | None) -> AgentConfig:
        if not config_path:
            return AgentConfig()

        path = Path(config_path)
        if not path.exists():
            return AgentConfig()

        try:
            if path.suffix.lower() in {".yaml", ".yml"}:
                data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
            elif path.suffix.lower() == ".json":
                data = json.loads(path.read_text(encoding="utf-8"))
            else:
                return AgentConfig()
            return self._create_config_from_dict(data)
        except Exception:
            return AgentConfig()

    def _create_config_from_dict(self, payload: dict[str, Any]) -> AgentConfig:
        agent_data = payload.get("agent", payload)
        metrics_data = agent_data.get("metrics", [])
        if isinstance(metrics_data, list):
            metrics = MetricsConfig(tracked_metrics=metrics_data)
        else:
            metrics = MetricsConfig(tracked_metrics=list(metrics_data.get("tracked_metrics", [])))

        try:
            mode = AgentMode(agent_data.get("mode", AgentMode.OPERATIONAL.value))
        except Exception:
            raise ValueError("invalid_mode")

        return AgentConfig(
            name=agent_data.get("name", "audio_ai_architect"),
            mode=mode,
            cycle=list(agent_data.get("cycle", ["PLAN", "EXECUTE", "VALIDATE", "REPORT"])),
            safety=SafetyConfig(**agent_data.get("safety", {})),
            platform=PlatformConfig(**agent_data.get("platform", {})),
            ai=AIConfig(**agent_data.get("ai", {})),
            metrics=metrics,
            logging=LoggingConfig(**agent_data.get("logging", {})),
        )

    def validate_config(self, config: AgentConfig) -> List[str]:
        errors: List[str] = []
        if not isinstance(config.name, str) or not config.name.strip():
            errors.append("Agent name must be a non-empty string")
        if not isinstance(config.cycle, list) or not config.cycle:
            errors.append("Agent cycle must be a non-empty list")
        valid_os = ["macOS", "Linux", "Windows"]
        if config.platform.os not in valid_os:
            errors.append(f"Invalid OS: {config.platform.os}. Valid: {valid_os}")
        return errors

    def save_config(self, config: AgentConfig, output_path: str, fmt: str = "yaml") -> None:
        path = Path(output_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "agent": {
                "name": config.name,
                "mode": config.mode.value,
                "cycle": config.cycle,
                "safety": asdict(config.safety),
                "platform": asdict(config.platform),
                "ai": asdict(config.ai),
                "metrics": config.metrics.tracked_metrics,
                "logging": asdict(config.logging),
            }
        }
        if fmt.lower() == "json":
            path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        else:
            path.write_text(yaml.safe_dump(payload, sort_keys=False), encoding="utf-8")

    def get_config_summary(self, config: AgentConfig) -> str:
        return (
            "Agent Configuration Summary\n"
            f"Name: {config.name}\n"
            f"Mode: {config.mode.value}\n"
            f"Safe mode: {config.safety.safe_mode}\n"
            f"Platform: {config.platform.os}/{config.platform.architecture}"
        )
