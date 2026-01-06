#!/usr/bin/env python3
"""
Lightweight, offline-friendly auto-tagging/embeddings helper.
- embeddings: deterministic hash-based vectors (no model download).
- tags: heuristics from filename (genre-ish guesses) with method label.
Intended as a placeholder when TensorFlow models are not available.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
from typing import List, Dict

AUDIO_EXTS = {".mp3", ".wav", ".flac", ".m4a", ".aiff", ".aif", ".ogg"}

def list_audio(base: Path, limit: int) -> List[Path]:
    files: List[Path] = [p for p in base.rglob("*") if p.suffix.lower() in AUDIO_EXTS and p.is_file()]
    if limit > 0:
        files = files[:limit]
    return files

def hash_embedding(path: Path, dim: int = 8) -> List[float]:
    h = hashlib.sha256(str(path).encode("utf-8")).digest()
    vals = []
    for i in range(dim):
        b = h[i]
        vals.append((b / 255.0) * 2 - 1)  # -1..1
    return vals

def guess_tags(path: Path) -> List[str]:
    name = path.stem.lower()
    tags = []
    keywords = {
        "techno": "techno",
        "house": "house",
        "trance": "trance",
        "drum": "dnb",
        "bass": "bass",
        "ambient": "ambient",
        "click": "percussion",
    }
    for key, tag in keywords.items():
        if key in name:
            tags.append(tag)
    if not tags:
        tags.append("unknown")
    return tags

def write_embeddings(base: Path, out: Path, limit: int) -> None:
    files = list_audio(base, limit)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "method", "embedding_json"])
        for p in files:
            emb = hash_embedding(p)
            w.writerow([str(p), "hash_mock", json.dumps(emb)])

def write_tags(base: Path, out: Path, limit: int) -> None:
    files = list_audio(base, limit)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "method", "tags_json"])
        for p in files:
            tags = guess_tags(p)
            w.writerow([str(p), "heuristic_mock", json.dumps(tags)])

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["embeddings", "tags"], help="Output embeddings or tags")
    ap.add_argument("--base", default=".", help="Base path to scan")
    ap.add_argument("--out", required=True, help="Output TSV path")
    ap.add_argument("--limit", type=int, default=150, help="Max files (0 = all)")
    args = ap.parse_args()

    base = Path(args.base).expanduser().resolve()
    out = Path(args.out).expanduser().resolve()
    limit = args.limit
    if args.mode == "embeddings":
        write_embeddings(base, out, limit)
    else:
        write_tags(base, out, limit)

if __name__ == "__main__":
    main()
