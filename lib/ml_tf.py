#!/usr/bin/env python3
"""
TensorFlow-based (or mock) audio embeddings/tags/similarity helper.
- If tensorflow + tensorflow_hub + soundfile are available and DJPT_TF_MOCK is not set, it will try to use YAMNet embeddings.
- Otherwise, it falls back to deterministic hash-based embeddings and heuristic tags.
Outputs TSV files for embeddings/tags and similarity (cosine).
"""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
from typing import Any, Dict, List, Tuple, Optional

AUDIO_EXTS = {".mp3", ".wav", ".flac", ".m4a", ".aiff", ".aif", ".ogg"}

# Optional imports
try:  # pragma: no cover - optional path
    import tensorflow as tf  # type: ignore
    import tensorflow_hub as hub  # type: ignore
    import soundfile as sf  # type: ignore
    import numpy as np  # type: ignore
except Exception:  # pragma: no cover - optional path
    tf = None
    hub = None
    sf = None
    np = None


MODEL_URLS = {
    "yamnet": "https://tfhub.dev/google/yamnet/1",
    "musicnn": "https://tfhub.dev/google/musicnn/1",
    "musictag": "https://tfhub.dev/google/music_tagging/nnfp/1",
}


def tf_available() -> bool:
    return (
        tf is not None
        and hub is not None
        and sf is not None
        and np is not None
        and os.environ.get("DJPT_TF_MOCK") != "1"
    )


def list_audio(base: Path, limit: int) -> List[Path]:
    files: List[Path] = [p for p in base.rglob("*") if p.suffix.lower() in AUDIO_EXTS and p.is_file()]
    if limit > 0:
        files = files[:limit]
    return files


def hash_embedding(path: Path, dim: int = 16) -> List[float]:
    h = hashlib.sha256(str(path).encode("utf-8")).digest()
    vals = []
    for i in range(dim):
        b = h[i]
        vals.append((b / 255.0) * 2 - 1)
    return vals


def heuristic_tags(path: Path) -> List[str]:
    name = path.stem.lower()
    tags = []
    mapping = {
        "techno": "techno",
        "house": "house",
        "trance": "trance",
        "drum": "dnb",
        "bass": "bass",
        "ambient": "ambient",
        "click": "percussion",
    }
    for k, v in mapping.items():
        if k in name:
            tags.append(v)
    if not tags:
        tags.append("unknown")
    return tags


# --- TF helpers ---

def load_audio_16k(path: Path) -> Optional[Any]:
    if sf is None or tf is None:
        return None
    data, sr = sf.read(str(path))
    if data.ndim > 1:
        data = data.mean(axis=1)
    data = tf.convert_to_tensor(data, dtype=tf.float32)
    if sr != 16000:
        target_len = int(tf.shape(data)[0]) * 16000 // sr
        data = tf.signal.resample(data, target_len)
    return data


def load_tf_model(model_name: str) -> Optional[Any]:
    if hub is None:
        return None
    url = MODEL_URLS.get(model_name, MODEL_URLS["yamnet"])
    try:
        return hub.load(url)
    except Exception:
        return None


def model_embed_and_tag(model: Any, audio: Any) -> Tuple[List[float], List[str]]:
    if model is None or audio is None or tf is None or np is None:
        return [], []
    try:
        outputs = model(audio)
        # Different hubs return different shapes; try to extract embeddings and scores
        embeddings = None
        scores = None
        if isinstance(outputs, (list, tuple)) and len(outputs) >= 2:
            scores, embeddings = outputs[0], outputs[1]
        elif isinstance(outputs, dict):
            # choose first two items
            vals = list(outputs.values())
            if len(vals) >= 2:
                scores, embeddings = vals[0], vals[1]
            elif len(vals) == 1:
                scores = embeddings = vals[0]
        else:
            embeddings = outputs

        emb_vec: List[float] = []
        tags: List[str] = []
        if embeddings is not None:
            emb_mean = tf.reduce_mean(tf.convert_to_tensor(embeddings), axis=0)
            emb_vec = emb_mean.numpy().tolist()
        if scores is not None:
            scores_mean = tf.reduce_mean(tf.convert_to_tensor(scores), axis=0)
            top_idx = int(tf.argmax(scores_mean))
            tags = [f"class_{top_idx}"]
        return emb_vec, tags
    except Exception:
        return [], []


# --- Writers ---

def write_embeddings(base: Path, out: Path, limit: int, model_choice: str) -> None:
    files = list_audio(base, limit)
    out.parent.mkdir(parents=True, exist_ok=True)
    rows: List[Tuple[str, str, str]] = []
    use_tf = tf_available() and model_choice in MODEL_URLS
    model = load_tf_model(model_choice) if use_tf else None
    for p in files:
        if use_tf and model is not None:
            audio = load_audio_16k(p)
            emb, _ = model_embed_and_tag(model, audio)
            method = f"tf_{model_choice}" if emb else f"tf_{model_choice}_fallback"
            if not emb:
                emb = hash_embedding(p)
        else:
            emb = hash_embedding(p)
            method = "hash_mock"
        rows.append((str(p), method, json.dumps(emb)))
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "method", "embedding_json"])
        w.writerows(rows)


def write_tags(base: Path, out: Path, limit: int, model_choice: str) -> None:
    files = list_audio(base, limit)
    out.parent.mkdir(parents=True, exist_ok=True)
    rows: List[Tuple[str, str, str]] = []
    use_tf = tf_available() and model_choice in MODEL_URLS
    model = load_tf_model(model_choice) if use_tf else None
    for p in files:
        tags: List[str] = []
        method = "hash_mock"
        if use_tf and model is not None:
            audio = load_audio_16k(p)
            _, tags = model_embed_and_tag(model, audio)
            method = f"tf_{model_choice}" if tags else f"tf_{model_choice}_fallback"
        if not tags:
            tags = heuristic_tags(p)
        rows.append((str(p), method, json.dumps(tags)))
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "method", "tags_json"])
        w.writerows(rows)


def cosine(a: List[float], b: List[float]) -> float:
    import math
    if not a or not b or len(a) != len(b):
        return 0.0
    num = sum(x * y for x, y in zip(a, b))
    da = math.sqrt(sum(x * x for x in a))
    db = math.sqrt(sum(y * y for y in b))
    if da == 0 or db == 0:
        return 0.0
    return num / (da * db)


def write_anomalies(base: Path, out_tsv: Path, limit: int) -> None:
    files = list_audio(base, limit)
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    rows: List[Tuple[str, float, float, str]] = []
    for p in files:
        try:
            import soundfile as _sf  # local import to allow mock mode
            data, sr = _sf.read(str(p))
            if data.ndim > 1:
                data = data.mean(axis=1)
            import numpy as _np
            rms = float(_np.sqrt(_np.mean(_np.square(data)))) if len(data) else 0.0
            peak = float(_np.max(_np.abs(data))) if len(data) else 0.0
            flags = []
            if peak >= 0.99:
                flags.append("clipping")
            if rms < 0.01:
                flags.append("silence")
            rows.append((str(p), rms, peak, ",".join(flags)))
        except Exception:
            rows.append((str(p), 0.0, 0.0, "error"))
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "rms", "peak", "flags"])
        for r in rows:
            w.writerow([r[0], f"{r[1]:.6f}", f"{r[2]:.6f}", r[3]])


def write_segments(base: Path, out_tsv: Path, limit: int) -> None:
    files = list_audio(base, limit)
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    rows: List[Tuple[str, str]] = []
    have_librosa = False
    try:
        import librosa  # type: ignore
        have_librosa = True
    except Exception:
        have_librosa = False

    for p in files:
        onsets: List[float] = []
        if have_librosa:
            try:
                import numpy as _np
                y, sr = librosa.load(p, sr=22050, mono=True, duration=180)
                on = librosa.onset.onset_detect(y=y, sr=sr, units="time")
                onsets = [float(x) for x in on[:10]]
            except Exception:
                onsets = []
        else:
            # Fallback: simple energy change detector
            try:
                import soundfile as _sf
                import numpy as _np
                data, sr = _sf.read(str(p))
                if data.ndim > 1:
                    data = data.mean(axis=1)
                hop = max(int(sr * 0.05), 1)
                rms = []
                for i in range(0, len(data), hop):
                    window = data[i : i + hop]
                    if len(window) == 0:
                        continue
                    rms.append(float(_np.sqrt(_np.mean(_np.square(window)))))
                for idx in range(1, len(rms)):
                    if rms[idx] > 2 * rms[idx - 1] and rms[idx] > 0.02:
                        onsets.append(idx * 0.05)
                        if len(onsets) >= 10:
                            break
            except Exception:
                onsets = []
        rows.append((str(p), ",".join(f"{t:.2f}" for t in onsets)))
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "onsets_sec"])
        for path, ons in rows:
            w.writerow([path, ons])


def load_embeddings(tsv: Path) -> List[Tuple[str, List[float]]]:
    out: List[Tuple[str, List[float]]] = []
    with tsv.open("r", encoding="utf-8") as f:
        next(f, None)
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            path, _, emb_json = parts[0], parts[1], parts[2]
            try:
                vec = json.loads(emb_json)
            except Exception:
                continue
            if isinstance(vec, list):
                out.append((path, [float(x) for x in vec]))
    return out


def write_similarity(emb_tsv: Path, out_tsv: Path, threshold: float, top_n: int) -> None:
    pairs: List[Tuple[str, str, float]] = []
    items = load_embeddings(emb_tsv)
    for i in range(len(items)):
        for j in range(i + 1, len(items)):
            s = cosine(items[i][1], items[j][1])
            if s >= threshold:
                pairs.append((items[i][0], items[j][0], s))
    pairs.sort(key=lambda x: x[2], reverse=True)
    if top_n > 0:
        pairs = pairs[:top_n]
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path_a", "path_b", "score"])
        for a, b, s in pairs:
            w.writerow([a, b, f"{s:.4f}"])


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="mode", required=True)

    p_emb = sub.add_parser("embeddings")
    p_emb.add_argument("--base", default=".")
    p_emb.add_argument("--out", required=True)
    p_emb.add_argument("--limit", type=int, default=150)
    p_emb.add_argument("--model", default="yamnet", choices=list(MODEL_URLS.keys()))

    p_tags = sub.add_parser("tags")
    p_tags.add_argument("--base", default=".")
    p_tags.add_argument("--out", required=True)
    p_tags.add_argument("--limit", type=int, default=150)
    p_tags.add_argument("--model", default="yamnet", choices=list(MODEL_URLS.keys()))

    p_sim = sub.add_parser("similarity")
    p_sim.add_argument("--embeddings", required=True, help="Input embeddings TSV")
    p_sim.add_argument("--out", required=True)
    p_sim.add_argument("--threshold", type=float, default=0.60)
    p_sim.add_argument("--top", type=int, default=200)

    p_an = sub.add_parser("anomalies")
    p_an.add_argument("--base", default=".")
    p_an.add_argument("--out", required=True)
    p_an.add_argument("--limit", type=int, default=200)

    p_seg = sub.add_parser("segments")
    p_seg.add_argument("--base", default=".")
    p_seg.add_argument("--out", required=True)
    p_seg.add_argument("--limit", type=int, default=50)

    args = ap.parse_args()

    if args.mode == "embeddings":
        write_embeddings(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit, args.model)
    elif args.mode == "tags":
        write_tags(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit, args.model)
    elif args.mode == "similarity":
        write_similarity(Path(args.embeddings).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.threshold, args.top)
    elif args.mode == "anomalies":
        write_anomalies(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit)
    elif args.mode == "segments":
        write_segments(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit)


if __name__ == "__main__":
    main()
