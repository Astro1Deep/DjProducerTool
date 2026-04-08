from __future__ import annotations

import csv
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ML_TF = ROOT / "lib" / "ml_tf.py"


def _make_fixture_tree(base: Path) -> None:
    (base / "audio").mkdir(parents=True, exist_ok=True)
    (base / "video").mkdir(parents=True, exist_ok=True)
    (base / "audio" / "techno_peak_track.mp3").write_bytes(b"A" * 32000)
    (base / "audio" / "techno_peak_track.wav").write_bytes(b"B" * 64000)
    (base / "audio" / "silence_broken.mp3").write_bytes(b"")
    (base / "video" / "live_tutorial_mix.mp4").write_bytes(b"V" * 48000)


def _run(*args: str, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(ML_TF), *args],
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
        check=False,
    )


def _read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def test_embeddings_similarity_and_matching_are_real(tmp_path: Path) -> None:
    _make_fixture_tree(tmp_path)
    embeddings = tmp_path / "reports" / "audio_embeddings.tsv"
    similarity = tmp_path / "reports" / "audio_similarity.tsv"
    tags = tmp_path / "reports" / "audio_tags.tsv"
    matching = tmp_path / "reports" / "audio_matching.tsv"

    proc_embeddings = _run("embeddings", "--base", str(tmp_path), "--out", str(embeddings), "--limit", "10", "--model", "yamnet")
    assert proc_embeddings.returncode == 0, proc_embeddings.stderr
    assert embeddings.exists()
    emb_rows = _read_tsv(embeddings)
    assert len(emb_rows) >= 2
    assert emb_rows[0]["embedding"]
    assert "compatibility_mode" not in embeddings.read_text(encoding="utf-8")

    proc_similarity = _run("similarity", "--embeddings", str(embeddings), "--out", str(similarity), "--threshold", "0.0", "--top", "10")
    assert proc_similarity.returncode == 0, proc_similarity.stderr
    sim_rows = _read_tsv(similarity)
    assert sim_rows
    assert {"path_a", "path_b", "score", "model"} <= set(sim_rows[0].keys())

    proc_tags = _run("tags", "--base", str(tmp_path), "--out", str(tags), "--limit", "10")
    assert proc_tags.returncode == 0, proc_tags.stderr
    tag_rows = _read_tsv(tags)
    assert any("techno" in row["tags"] for row in tag_rows)

    proc_matching = _run(
        "matching",
        "--base",
        str(tmp_path),
        "--out",
        str(matching),
        "--embeddings",
        str(embeddings),
        "--tags",
        str(tags),
        "--limit",
        "10",
    )
    assert proc_matching.returncode == 0, proc_matching.stderr
    match_rows = _read_tsv(matching)
    assert match_rows
    assert any("techno_peak_track.mp3" in row["path_a"] + row["path_b"] for row in match_rows)


def test_analysis_reports_and_video_music_tags_are_real(tmp_path: Path) -> None:
    _make_fixture_tree(tmp_path)
    anomalies = tmp_path / "reports" / "audio_anomalies.tsv"
    garbage = tmp_path / "reports" / "audio_garbage.tsv"
    loudness = tmp_path / "reports" / "audio_loudness.tsv"
    segments = tmp_path / "reports" / "audio_segments.tsv"
    video_tags = tmp_path / "reports" / "video_tags.tsv"
    music_tags = tmp_path / "reports" / "music_tags.tsv"
    mastering = tmp_path / "reports" / "audio_mastering.tsv"

    for command, output in (
        ("anomalies", anomalies),
        ("garbage", garbage),
        ("loudness", loudness),
        ("segments", segments),
        ("video_tags", video_tags),
        ("music_tags", music_tags),
        ("mastering", mastering),
    ):
        proc = _run(command, "--base", str(tmp_path), "--out", str(output), "--limit", "10")
        assert proc.returncode == 0, f"{command}: {proc.stderr}"
        assert output.exists(), command
        rows = _read_tsv(output)
        assert rows is not None

    anomaly_rows = _read_tsv(anomalies)
    assert any(row["anomaly"] == "empty_file" for row in anomaly_rows)
    video_rows = _read_tsv(video_tags)
    assert any("tutorial" in row["tags"] or "live" in row["tags"] for row in video_rows)
    mastering_rows = _read_tsv(mastering)
    assert any(row["recommendation"] for row in mastering_rows)


def test_download_model_without_base_creates_real_cache(tmp_path: Path) -> None:
    proc = _run("download_model", "--name", "yamnet", "--offline", cwd=tmp_path)
    assert proc.returncode == 0, proc.stderr
    model_dir = tmp_path / "_DJProducerTools" / "state" / "models" / "yamnet"
    manifest = model_dir / "manifest.json"
    assert manifest.exists()
    data = json.loads(manifest.read_text(encoding="utf-8"))
    assert data["name"] == "yamnet"
    assert data["offline_requested"] is True
