from __future__ import annotations

from dataclasses import dataclass

from ai.types_selector import BenchmarkReport, RepoStats, SelectionDecision, SystemSnapshot, UserPrefs


@dataclass
class SelectorConfig:
    ram_floor_local: float = 4.0
    headroom_pct_min: float = 10.0


def _required_ram(mem_gb: float, headroom_pct_min: float) -> float:
    return mem_gb * (1.0 + (headroom_pct_min / 100.0))


def select_optimal_model(
    task: str,
    context_tokens: int,
    urgency: str,
    repo_stats: RepoStats,
    prefs: UserPrefs,
    config: SelectorConfig,
    benchmark: BenchmarkReport,
    snapshot: SystemSnapshot,
) -> SelectionDecision:
    if not benchmark.results:
        return SelectionDecision(model_id="none", backend="none", reason="no_benchmarks")

    remote_candidates = [row for row in benchmark.results if row.backend == "remote"]
    local_candidates = [row for row in benchmark.results if row.backend != "remote"]

    eligible_local = [
        row
        for row in local_candidates
        if snapshot.avail_ram_gb >= max(config.ram_floor_local, _required_ram(row.mem_gb, config.headroom_pct_min))
    ]

    if not eligible_local:
        if remote_candidates:
            chosen = max(remote_candidates, key=lambda row: (row.tokens_per_sec, -row.latency_ms))
            return SelectionDecision(model_id=chosen.model_id, backend=chosen.backend, reason="local_ram_too_low")
        chosen = max(local_candidates, key=lambda row: (row.tokens_per_sec, -row.latency_ms))
        return SelectionDecision(model_id=chosen.model_id, backend=chosen.backend, reason="fallback_local")

    best_local = max(eligible_local, key=lambda row: (row.tokens_per_sec, -row.latency_ms))
    if not remote_candidates or prefs.prefer_local:
        return SelectionDecision(model_id=best_local.model_id, backend=best_local.backend, reason="local_preferred")

    best_remote = max(remote_candidates, key=lambda row: (row.tokens_per_sec, -row.latency_ms))
    if best_local.tokens_per_sec >= best_remote.tokens_per_sec * 0.8 and best_local.latency_ms <= best_remote.latency_ms * 1.25:
        return SelectionDecision(model_id=best_local.model_id, backend=best_local.backend, reason="local_good_enough")
    return SelectionDecision(model_id=best_remote.model_id, backend=best_remote.backend, reason="remote_faster")
