#!/usr/bin/env python3
"""
Local-first ML operations for DJProducerTools.

This module provides deterministic and reproducible local analysis:
- cluster: grouping tracks by feature similarity
- similarity: nearest-neighbor pairs
- recommend: recommendations from local embeddings
- popularity: popularity score from local metadata
- summary: compact library summary for AI context
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import time
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple

try:
    import numpy as np

    HAS_NUMPY = True
except Exception:
    HAS_NUMPY = False

try:
    from sklearn.cluster import KMeans
    from sklearn.preprocessing import StandardScaler

    HAS_SKLEARN = True
except Exception:
    HAS_SKLEARN = False

AUDIO_EXTS = {".mp3", ".wav", ".flac", ".m4a", ".aiff", ".aif", ".ogg", ".aac"}
DEFAULT_EXCLUDES = {
    ".git",
    ".Trash",
    "node_modules",
    "__pycache__",
    "_DJProducerTools",
    "_SeratOrganizer",
}

KEYWORDS = {
    "techno": 1.0,
    "house": 0.9,
    "deep": 0.7,
    "dnb": 1.1,
    "drum": 0.8,
    "bass": 0.8,
    "trap": 0.7,
    "ambient": 0.6,
    "remix": 0.5,
    "vip": 0.5,
    "edit": 0.4,
    "extended": 0.4,
    "radio": 0.3,
    "official": 0.3,
}


@dataclass
class TrackMeta:
    path: Path
    size_mb: float
    age_days: float
    keyword_bonus: float
    recency_score: float
    popularity_score: float


def _hash_vec(seed: str, dim: int = 16) -> List[float]:
    digest = hashlib.sha256(seed.encode("utf-8")).digest()
    return [((digest[i % len(digest)] / 255.0) * 2.0) - 1.0 for i in range(dim)]


def _keyword_bonus(name: str) -> float:
    lowered = name.lower()
    score = 0.0
    for token, weight in KEYWORDS.items():
        if token in lowered:
            score += weight
    return min(score, 3.0)


def _track_meta(path: Path, now_ts: float) -> TrackMeta:
    stat = path.stat()
    size_mb = stat.st_size / (1024.0 * 1024.0)
    age_days = max(0.0, (now_ts - stat.st_mtime) / 86400.0)
    recency_score = math.exp(-age_days / 365.0)
    keyword = _keyword_bonus(path.stem)
    size_score = min(math.log1p(size_mb) / math.log1p(200.0), 1.0)
    popularity = (0.55 * recency_score) + (0.35 * size_score) + (0.10 * (keyword / 3.0))
    return TrackMeta(
        path=path,
        size_mb=size_mb,
        age_days=age_days,
        keyword_bonus=keyword,
        recency_score=recency_score,
        popularity_score=max(0.0, min(popularity, 1.0)),
    )


def scan_audio(base: Path, limit: int, excludes: Sequence[str]) -> List[Path]:
    if not base.exists():
        return []

    exclude_set = set(excludes) | DEFAULT_EXCLUDES
    found: List[Path] = []

    for root, dirs, files in os.walk(base, topdown=True):
        dirs[:] = [d for d in dirs if d not in exclude_set]
        for filename in files:
            p = Path(root) / filename
            if p.suffix.lower() not in AUDIO_EXTS:
                continue
            found.append(p)
            if limit > 0 and len(found) >= limit:
                return found
    return found


def build_features(paths: Sequence[Path]) -> Tuple[List[List[float]], List[TrackMeta]]:
    now_ts = time.time()
    metas = [_track_meta(p, now_ts) for p in paths]
    feats: List[List[float]] = []
    for meta in metas:
        ext_bits = _hash_vec(meta.path.suffix.lower(), dim=4)
        path_bits = _hash_vec(str(meta.path), dim=16)
        keyword = meta.keyword_bonus / 3.0
        vec = path_bits + ext_bits + [
            math.log1p(meta.size_mb),
            1.0 / (1.0 + meta.age_days),
            keyword,
            meta.popularity_score,
        ]
        feats.append(vec)
    return feats, metas


def to_numpy(features: Sequence[Sequence[float]]):
    if not HAS_NUMPY:
        return None
    return np.asarray(features, dtype=float)


def _cosine(a: Sequence[float], b: Sequence[float]) -> float:
    if HAS_NUMPY:
        va = np.asarray(a, dtype=float)
        vb = np.asarray(b, dtype=float)
        denom = float(np.linalg.norm(va) * np.linalg.norm(vb))
        if denom == 0.0:
            return 0.0
        return float(np.dot(va, vb) / denom)

    dot = 0.0
    na = 0.0
    nb = 0.0
    for x, y in zip(a, b):
        dot += x * y
        na += x * x
        nb += y * y
    denom = math.sqrt(na * nb)
    if denom == 0.0:
        return 0.0
    return dot / denom


def write_tsv(path: Path, header: Sequence[str], rows: Iterable[Sequence[object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh, delimiter="\t")
        writer.writerow(list(header))
        for row in rows:
            writer.writerow(list(row))


def cmd_summary(args: argparse.Namespace) -> int:
    files = scan_audio(args.base, args.limit, args.exclude)
    counter = Counter(p.suffix.lower() for p in files)
    by_dir = Counter(str(p.parent) for p in files)
    payload = {
        "base": str(args.base),
        "audio_files": len(files),
        "extensions": dict(counter.most_common()),
        "top_directories": by_dir.most_common(15),
    }
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps(payload, indent=2))
    return 0


def cmd_cluster(args: argparse.Namespace) -> int:
    files = scan_audio(args.base, args.limit, args.exclude)
    if len(files) < 2:
        print("[WARN] Not enough audio files for clustering.")
        return 1

    features, metas = build_features(files)
    labels: List[int] = []
    if HAS_SKLEARN and len(files) >= 4:
        np_features = to_numpy(features)
        scaler = StandardScaler()
        scaled = scaler.fit_transform(np_features)
        requested = args.clusters if args.clusters > 0 else max(2, int(math.sqrt(len(files) / 2)))
        n_clusters = max(2, min(requested, min(12, len(files))))
        model = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
        labels = [int(x) for x in model.fit_predict(scaled)]
    else:
        buckets = max(2, min(8, args.clusters if args.clusters > 0 else 4))
        labels = [int(abs(hash(str(p))) % buckets) for p in files]

    rows = []
    for meta, label in zip(metas, labels):
        rows.append(
            (
                label,
                str(meta.path),
                meta.path.suffix.lower(),
                f"{meta.size_mb:.2f}",
                f"{meta.age_days:.1f}",
                f"{meta.popularity_score:.4f}",
            )
        )

    write_tsv(
        args.out,
        ["cluster", "path", "ext", "size_mb", "age_days", "popularity_score"],
        rows,
    )
    summary = defaultdict(int)
    for label in labels:
        summary[str(label)] += 1
    args.out.with_suffix(".json").write_text(json.dumps({"clusters": dict(summary), "count": len(files)}, indent=2), encoding="utf-8")
    print(f"[OK] Cluster report: {args.out}")
    return 0


def cmd_similarity(args: argparse.Namespace) -> int:
    files = scan_audio(args.base, args.limit, args.exclude)
    if len(files) < 2:
        print("[WARN] Not enough audio files for similarity.")
        return 1

    features, _ = build_features(files)
    top_k = max(1, args.top)
    seen_pairs = set()
    out_rows = []
    for i, src in enumerate(files):
        scored: List[Tuple[int, float]] = []
        for j, dst in enumerate(files):
            if i == j:
                continue
            sim = _cosine(features[i], features[j])
            scored.append((j, sim))
        scored.sort(key=lambda x: x[1], reverse=True)
        for j, sim in scored[:top_k]:
            pair = tuple(sorted((i, j)))
            if pair in seen_pairs:
                continue
            seen_pairs.add(pair)
            out_rows.append((str(src), str(files[j]), f"{sim:.6f}"))

    out_rows.sort(key=lambda r: float(r[2]), reverse=True)
    write_tsv(args.out, ["source", "target", "similarity"], out_rows)
    print(f"[OK] Similarity report: {args.out}")
    return 0


def cmd_popularity(args: argparse.Namespace) -> int:
    files = scan_audio(args.base, args.limit, args.exclude)
    if not files:
        print("[WARN] No audio files found.")
        return 1

    now_ts = time.time()
    metas = [_track_meta(p, now_ts) for p in files]
    metas.sort(key=lambda m: m.popularity_score, reverse=True)

    rows = []
    for meta in metas:
        reason = f"recency={meta.recency_score:.3f}; keyword={meta.keyword_bonus:.2f}; size_mb={meta.size_mb:.2f}"
        rows.append(
            (
                str(meta.path),
                f"{meta.popularity_score:.6f}",
                f"{meta.recency_score:.6f}",
                f"{meta.size_mb:.2f}",
                f"{meta.keyword_bonus:.2f}",
                reason,
            )
        )

    write_tsv(
        args.out,
        ["path", "popularity_score", "recency_score", "size_mb", "keyword_bonus", "reason"],
        rows,
    )
    print(f"[OK] Popularity report: {args.out}")
    return 0


def cmd_recommend(args: argparse.Namespace) -> int:
    files = scan_audio(args.base, args.limit, args.exclude)
    if len(files) < 3:
        print("[WARN] Not enough audio files for recommendations.")
        return 1

    features, metas = build_features(files)
    top_k = max(1, args.top)

    query = (args.query or "").strip().lower()
    seed_indexes: List[int] = []
    if query:
        seed_indexes = [i for i, p in enumerate(files) if query in p.name.lower()]

    if not seed_indexes:
        ranked = sorted(enumerate(metas), key=lambda x: x[1].popularity_score, reverse=True)
        seed_indexes = [idx for idx, _ in ranked[: min(5, len(files))]]

    rows = []
    for seed_idx in seed_indexes:
        scored = []
        for j, _dst in enumerate(files):
            if seed_idx == j:
                continue
            sim = _cosine(features[seed_idx], features[j])
            scored.append((j, sim))
        scored.sort(key=lambda x: x[1], reverse=True)
        for j, sim in scored[:top_k]:
            rows.append(
                (
                    str(files[seed_idx]),
                    str(files[j]),
                    f"{sim:.6f}",
                    "cosine+local_features",
                )
            )

    rows.sort(key=lambda r: float(r[2]), reverse=True)
    write_tsv(args.out, ["seed", "recommendation", "similarity", "method"], rows)
    print(f"[OK] Recommendation report: {args.out}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Local ML operations for DJProducerTools")
    sub = parser.add_subparsers(dest="cmd", required=True)

    def add_common(p: argparse.ArgumentParser) -> None:
        p.add_argument("--base", type=Path, required=True, help="Base path")
        p.add_argument("--out", type=Path, required=True, help="Output file")
        p.add_argument("--limit", type=int, default=500, help="Max audio files to scan (0 = all)")
        p.add_argument("--exclude", nargs="*", default=[], help="Directory names to exclude")

    p_summary = sub.add_parser("summary", help="Build compact local summary")
    add_common(p_summary)
    p_summary.set_defaults(func=cmd_summary)

    p_cluster = sub.add_parser("cluster", help="Cluster tracks")
    add_common(p_cluster)
    p_cluster.add_argument("--clusters", type=int, default=0, help="Requested clusters (auto if 0)")
    p_cluster.set_defaults(func=cmd_cluster)

    p_similarity = sub.add_parser("similarity", help="Pairwise similarity")
    add_common(p_similarity)
    p_similarity.add_argument("--top", type=int, default=5, help="Top neighbors per source")
    p_similarity.set_defaults(func=cmd_similarity)

    p_recommend = sub.add_parser("recommend", help="Generate local recommendations")
    add_common(p_recommend)
    p_recommend.add_argument("--top", type=int, default=5, help="Recommendations per seed")
    p_recommend.add_argument("--query", default="", help="Optional seed filter by filename")
    p_recommend.set_defaults(func=cmd_recommend)

    p_pop = sub.add_parser("popularity", help="Popularity scoring")
    add_common(p_pop)
    p_pop.set_defaults(func=cmd_popularity)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
