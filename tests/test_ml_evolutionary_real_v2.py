from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "lib" / "ml_evolutionary.py"


def _run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True, check=False)


def test_ml_evolutionary_train_and_predict_are_real(tmp_path: Path) -> None:
    library = tmp_path / "library"
    library.mkdir()
    dup_a = library / "dup_a.wav"
    dup_b = library / "dup_b.wav"
    unique = library / "unique_track.wav"
    dup_a.write_bytes(b"same-audio-a")
    dup_b.write_bytes(b"same-audio-b")
    unique.write_bytes(b"unique-audio")

    plan_hash = tmp_path / "general_hash_dupes_plan.tsv"
    plan_hash.write_text(
        "\n".join(
            [
                f"hash123\tKEEP\t{dup_a}",
                f"hash123\tQUARANTINE\t{dup_b}",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    plan_name = tmp_path / "general_dupes_plan.tsv"
    plan_name.write_text(f"group01\tQUARANTINE\t{dup_b}\n", encoding="utf-8")

    features_out = tmp_path / "ml_features.tsv"
    model_out = tmp_path / "ml_model.pkl"
    report_out = tmp_path / "ml_predictions.tsv"

    train = _run(
        [
            "train",
            "--base",
            str(library),
            "--plan-hash",
            str(plan_hash),
            "--plan-name",
            str(plan_name),
            "--features-out",
            str(features_out),
            "--model-out",
            str(model_out),
        ]
    )
    assert train.returncode == 0, train.stderr or train.stdout
    assert model_out.exists()
    assert features_out.exists()
    assert "stub" not in train.stdout.lower()

    predict = _run(
        [
            "predict",
            "--base",
            str(library),
            "--model-in",
            str(model_out),
            "--report-out",
            str(report_out),
        ]
    )
    assert predict.returncode == 0, predict.stderr or predict.stdout
    assert report_out.exists()
    report_text = report_out.read_text(encoding="utf-8")
    assert "path\tscore\tlabel\tmode" in report_text
    assert "dup_b.wav" in report_text
