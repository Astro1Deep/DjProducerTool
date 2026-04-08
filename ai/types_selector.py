from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class SystemSnapshot:
    total_ram_gb: float
    avail_ram_gb: float
    cpu_percent: float
    disk_percent: float
    ts: float


@dataclass
class RepoStats:
    loc: int
    files: int
    size_gb: float


@dataclass
class UserPrefs:
    prefer_local: bool = True


@dataclass
class BenchmarkResult:
    model_id: str
    backend: str
    tokens_per_sec: float
    latency_ms: float
    mem_gb: float
    context_size: int
    ts: float


@dataclass
class BenchmarkReport:
    results: list[BenchmarkResult] = field(default_factory=list)
    ts: float = 0.0


@dataclass
class SelectionDecision:
    model_id: str
    backend: str
    reason: str
