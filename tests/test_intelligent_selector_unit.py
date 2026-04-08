from pathlib import Path

from ai.intelligent_selector import SelectorConfig, select_optimal_model
from ai.types_selector import (
    BenchmarkReport,
    BenchmarkResult,
    RepoStats,
    SelectionDecision,
    SystemSnapshot,
    UserPrefs,
)


def _snap(avail=8.0):
    return SystemSnapshot(
        total_ram_gb=16.0,
        avail_ram_gb=avail,
        cpu_percent=0.0,
        disk_percent=0.0,
        ts=0.0,
    )


def test_select_remote_when_ram_low():
    bench = BenchmarkReport(
        results=[
            BenchmarkResult(
                model_id="mlx-7b",
                backend="mlx",
                tokens_per_sec=50.0,
                latency_ms=200.0,
                mem_gb=8.0,
                context_size=2048,
                ts=0.0,
            ),
            BenchmarkResult(
                model_id="remote/gpt",
                backend="remote",
                tokens_per_sec=80.0,
                latency_ms=150.0,
                mem_gb=0.0,
                context_size=2048,
                ts=0.0,
            ),
        ],
        ts=0.0,
    )
    decision = select_optimal_model(
        task="general",
        context_tokens=2048,
        urgency="normal",
        repo_stats=RepoStats(loc=1, files=1, size_gb=0.1),
        prefs=UserPrefs(),
        config=SelectorConfig(ram_floor_local=6.0, headroom_pct_min=15.0),
        benchmark=bench,
        snapshot=_snap(avail=2.0),
    )
    assert decision.backend == "remote"


def test_select_mlx_when_fast_enough():
    bench = BenchmarkReport(
        results=[
            BenchmarkResult(
                model_id="mlx-7b",
                backend="mlx",
                tokens_per_sec=90.0,
                latency_ms=180.0,
                mem_gb=6.0,
                context_size=2048,
                ts=0.0,
            ),
            BenchmarkResult(
                model_id="remote/gpt",
                backend="remote",
                tokens_per_sec=100.0,
                latency_ms=200.0,
                mem_gb=0.0,
                context_size=2048,
                ts=0.0,
            ),
        ],
        ts=0.0,
    )
    decision = select_optimal_model(
        task="general",
        context_tokens=1024,
        urgency="normal",
        repo_stats=RepoStats(loc=1, files=1, size_gb=0.1),
        prefs=UserPrefs(),
        config=SelectorConfig(),
        benchmark=bench,
        snapshot=_snap(avail=12.0),
    )
    assert decision.backend == "mlx"


def test_fallback_when_no_benchmarks():
    decision = select_optimal_model(
        task="general",
        context_tokens=1024,
        urgency="normal",
        repo_stats=RepoStats(loc=1, files=1, size_gb=0.1),
        prefs=UserPrefs(),
        config=SelectorConfig(),
        benchmark=BenchmarkReport(results=[], ts=0.0),
        snapshot=_snap(avail=12.0),
    )
    assert decision.model_id == "none"
