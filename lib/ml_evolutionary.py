#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import math
import os
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

from joblib import dump, load
from sklearn.ensemble import IsolationForest, RandomForestClassifier
from sklearn.feature_extraction import DictVectorizer

SKIP_DIRS = {".git", "__pycache__", "node_modules", ".venv", "venv", "djpt_venv", "_DJProducerTools"}


@dataclass
class FeatureRow:
    path: str
    size_bytes: int
    depth: int
    extension: str
    basename_length: int
    dirname_depth: int
    token_count: int
    from_hash_plan: int
    from_name_plan: int
    label: int

    def to_model_dict(self) -> dict[str, float | int | str]:
        return {
            "size_log": round(math.log1p(self.size_bytes), 6),
            "depth": self.depth,
            "basename_length": self.basename_length,
            "dirname_depth": self.dirname_depth,
            "token_count": self.token_count,
            "from_hash_plan": self.from_hash_plan,
            "from_name_plan": self.from_name_plan,
            "extension": self.extension or "<none>",
        }


def _walk_files(base: Path) -> Iterable[Path]:
    for root, dirs, files in os.walk(base):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for name in sorted(files):
            path = Path(root) / name
            if path.is_file():
                yield path


def _safe_rel(base: Path, path: Path) -> str:
    try:
        return str(path.resolve().relative_to(base.resolve()))
    except Exception:
        return str(path.resolve())


def _read_plan_paths(plan_path: Path | None) -> set[str]:
    if plan_path is None or not plan_path.exists():
        return set()

    resolved: set[str] = set()
    with plan_path.open("r", encoding="utf-8", errors="ignore") as fh:
        for raw_line in fh:
            line = raw_line.strip()
            if not line:
                continue
            parts = line.split("\t")
            for candidate in reversed(parts):
                candidate = candidate.strip()
                if not candidate:
                    continue
                path_obj = Path(candidate).expanduser()
                if path_obj.is_absolute():
                    resolved.add(str(path_obj.resolve()))
                    break
    return resolved


def _extract_rows(base: Path, hash_plan: set[str], name_plan: set[str], max_files: int) -> list[FeatureRow]:
    rows: list[FeatureRow] = []
    for index, path in enumerate(_walk_files(base)):
        if index >= max_files:
            break
        stat = path.stat()
        rel = _safe_rel(base, path)
        absolute = str(path.resolve())
        basename_tokens = [token for token in path.stem.replace("-", " ").replace("_", " ").split() if token]
        dirname_depth = max(0, len(path.relative_to(base).parents) - 1)
        from_hash = int(absolute in hash_plan)
        from_name = int(absolute in name_plan)
        rows.append(
            FeatureRow(
                path=rel,
                size_bytes=stat.st_size,
                depth=len(Path(rel).parts),
                extension=path.suffix.lower(),
                basename_length=len(path.stem),
                dirname_depth=dirname_depth,
                token_count=len(basename_tokens),
                from_hash_plan=from_hash,
                from_name_plan=from_name,
                label=1 if (from_hash or from_name) else 0,
            )
        )
    return rows


def _write_features(rows: list[FeatureRow], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(asdict(rows[0]).keys()) if rows else list(asdict(FeatureRow("", 0, 0, "", 0, 0, 0, 0, 0, 0)).keys()), delimiter="\t")
        writer.writeheader()
        for row in rows:
            writer.writerow(asdict(row))


def _fit_bundle(rows: list[FeatureRow]) -> dict:
    vectorizer = DictVectorizer(sparse=False)
    x = vectorizer.fit_transform([row.to_model_dict() for row in rows])
    y = [row.label for row in rows]
    positives = sum(y)
    negatives = len(y) - positives

    if positives > 0 and negatives > 0:
        model = RandomForestClassifier(
            n_estimators=64,
            max_depth=8,
            min_samples_leaf=1,
            random_state=42,
            n_jobs=1,
        )
        model.fit(x, y)
        mode = "supervised"
    else:
        contamination = 0.1
        if len(rows) > 0:
            contamination = min(0.25, max(0.05, positives / max(1, len(rows)) or 0.1))
        model = IsolationForest(
            n_estimators=64,
            contamination=contamination,
            random_state=42,
        )
        model.fit(x)
        mode = "unsupervised"

    return {
        "mode": mode,
        "vectorizer": vectorizer,
        "model": model,
        "feature_count": len(rows),
        "positive_samples": positives,
        "negative_samples": negatives,
    }


def train(args: argparse.Namespace) -> int:
    base = Path(args.base).expanduser().resolve()
    if not base.exists():
        print(f"[ERR] BASE no existe: {base}", file=sys.stderr)
        return 2

    hash_plan = _read_plan_paths(Path(args.plan_hash).expanduser().resolve()) if args.plan_hash else set()
    name_plan = _read_plan_paths(Path(args.plan_name).expanduser().resolve()) if args.plan_name else set()
    rows = _extract_rows(base, hash_plan, name_plan, args.max_files)
    if not rows:
        print(f"[ERR] No se encontraron archivos para entrenar en {base}", file=sys.stderr)
        return 2

    features_out = Path(args.features_out).expanduser().resolve()
    model_out = Path(args.model_out).expanduser().resolve()
    features_out.parent.mkdir(parents=True, exist_ok=True)
    model_out.parent.mkdir(parents=True, exist_ok=True)

    _write_features(rows, features_out)
    bundle = _fit_bundle(rows)
    bundle.update(
        {
            "base_path": str(base),
            "hash_plan": args.plan_hash or "",
            "name_plan": args.plan_name or "",
        }
    )
    dump(bundle, model_out)

    print(f"[OK] Modelo ML evolutivo guardado en {model_out}")
    print(f"[OK] Features guardadas en {features_out}")
    print(f"[INFO] modo={bundle['mode']} filas={bundle['feature_count']} positivos={bundle['positive_samples']} negativos={bundle['negative_samples']}")
    return 0


def predict(args: argparse.Namespace) -> int:
    base = Path(args.base).expanduser().resolve()
    model_in = Path(args.model_in).expanduser().resolve()
    report_out = Path(args.report_out).expanduser().resolve()

    if not model_in.exists():
        print(f"[ERR] Modelo no encontrado: {model_in}", file=sys.stderr)
        return 2

    bundle = load(model_in)
    rows = _extract_rows(base, set(), set(), args.max_files)
    if not rows:
        print(f"[ERR] No se encontraron archivos para predecir en {base}", file=sys.stderr)
        return 2

    vectorizer: DictVectorizer = bundle["vectorizer"]
    model = bundle["model"]
    x = vectorizer.transform([row.to_model_dict() for row in rows])

    report_out.parent.mkdir(parents=True, exist_ok=True)
    with report_out.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh, delimiter="\t")
        writer.writerow(["path", "score", "label", "mode"])
        if bundle["mode"] == "supervised":
            probabilities = model.predict_proba(x)
            for row, probs in sorted(zip(rows, probabilities), key=lambda item: float(item[1][1]), reverse=True):
                score = float(probs[1])
                writer.writerow([row.path, f"{score:.6f}", "SUSPICIOUS" if score >= args.threshold else "OK", "supervised"])
        else:
            raw_scores = (-model.decision_function(x)).tolist()
            low, high = min(raw_scores), max(raw_scores)
            spread = (high - low) or 1.0
            normalized = [(score - low) / spread for score in raw_scores]
            for row, score, flag in sorted(zip(rows, normalized, model.predict(x)), key=lambda item: float(item[1]), reverse=True):
                writer.writerow([row.path, f"{float(score):.6f}", "SUSPICIOUS" if int(flag) == -1 or float(score) >= args.threshold else "OK", "unsupervised"])

    print(f"[OK] Predicción guardada en {report_out}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="ML evolutivo local para DJProducerTools")
    sub = parser.add_subparsers(dest="cmd", required=True)

    train_parser = sub.add_parser("train", help="Entrena o reentrena un modelo local")
    train_parser.add_argument("--base", required=True, help="Directorio base a analizar")
    train_parser.add_argument("--plan-hash", default=None, help="Plan hash de duplicados")
    train_parser.add_argument("--plan-name", default=None, help="Plan por nombre/tamaño")
    train_parser.add_argument("--features-out", default="ml_features.tsv")
    train_parser.add_argument("--model-out", default="ml_model.pkl")
    train_parser.add_argument("--max-files", type=int, default=10000)
    train_parser.set_defaults(func=train)

    predict_parser = sub.add_parser("predict", help="Genera un reporte de sospechosos")
    predict_parser.add_argument("--base", required=True, help="Directorio base a analizar")
    predict_parser.add_argument("--model-in", default="ml_model.pkl")
    predict_parser.add_argument("--report-out", default="ml_predictions.tsv")
    predict_parser.add_argument("--max-files", type=int, default=10000)
    predict_parser.add_argument("--threshold", type=float, default=0.5)
    predict_parser.set_defaults(func=predict)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
