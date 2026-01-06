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
import shutil
import subprocess
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
    # Placeholders: si no hay modelo, se usa hash_mock
    "clap": None,
    "musicgen": None,
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


def text_embedding(text: str, dim: int = 16) -> List[float]:
    h = hashlib.sha256(text.encode("utf-8")).digest()
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
    if url is None:
        return None
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

def write_embeddings(base: Path, out: Path, limit: int, model_choice: str, offline: bool) -> None:
    files = list_audio(base, limit)
    out.parent.mkdir(parents=True, exist_ok=True)
    rows: List[Tuple[str, str, str]] = []
    use_tf = tf_available() and model_choice in MODEL_URLS and not offline
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
            method = f"{model_choice}_mock"
        rows.append((str(p), method, json.dumps(emb)))
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "method", "embedding_json"])
        w.writerows(rows)


def write_tags(base: Path, out: Path, limit: int, model_choice: str, offline: bool) -> None:
    files = list_audio(base, limit)
    out.parent.mkdir(parents=True, exist_ok=True)
    rows: List[Tuple[str, str, str]] = []
    use_tf = tf_available() and model_choice in MODEL_URLS and not offline
    model = load_tf_model(model_choice) if use_tf else None
    for p in files:
        tags: List[str] = []
        method = f"{model_choice}_mock"
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
    rows: List[Tuple[str, str, str]] = []
    have_librosa = False
    try:
        import librosa  # type: ignore
        have_librosa = True
    except Exception:
        have_librosa = False

    for p in files:
        onsets: List[float] = []
        beats: List[float] = []
        if have_librosa:
            try:
                import numpy as _np
                y, sr = librosa.load(p, sr=22050, mono=True, duration=180)
                on = librosa.onset.onset_detect(y=y, sr=sr, units="time")
                onsets = [float(x) for x in on[:12]]
                tempo, beat_frames = librosa.beat.beat_track(y=y, sr=sr)
                beats = [float(x) for x in librosa.frames_to_time(beat_frames, sr=sr)[:16]]
            except Exception:
                onsets = []
                beats = []
        else:
            # Fallback: simple energy change detector + beats aproximados
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
                        if len(onsets) >= 12:
                            break
                step = 1.5
                t = 0.0
                total = len(data) / float(sr if sr else 1)
                while t < total and len(beats) < 16:
                    beats.append(round(t, 2))
                    t += step
            except Exception:
                onsets = []
                beats = []
        rows.append(
            (
                str(p),
                ",".join(f"{t:.2f}" for t in onsets),
                ",".join(f"{t:.2f}" for t in beats),
            )
        )
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "onsets_sec", "beats_sec"])
        for path, ons, beats in rows:
            w.writerow([path, ons, beats])


def write_garbage(base: Path, out_tsv: Path, limit: int) -> None:
    files = list_audio(base, limit)
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    rows: List[Tuple[str, float, str]] = []
    for p in files:
        score = 0.0
        flags = []
        try:
            import soundfile as _sf
            import numpy as _np
            data, sr = _sf.read(str(p))
            if data.ndim > 1:
                data = data.mean(axis=1)
            dur = len(data) / sr if sr else 0.0
            rms = float(_np.sqrt(_np.mean(_np.square(data)))) if len(data) else 0.0
            if dur < 5:
                flags.append("short")
                score += 0.5
            if rms < 0.01:
                flags.append("silence")
                score += 0.4
            peak = float(_np.max(_np.abs(data))) if len(data) else 0.0
            if peak > 0.98:
                flags.append("clipping")
                score += 0.3
            if len(data) > 0:
                diffs = _np.abs(_np.diff(data))
                if diffs.size and float(_np.percentile(diffs, 99)) > 0.25:
                    flags.append("clicks")
                    score += 0.2
        except Exception:
            flags.append("error")
            score = 1.0
        rows.append((str(p), min(score, 1.0), ",".join(flags)))
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "score", "flags"])
        for path, score, flags in rows:
            w.writerow([path, f"{score:.2f}", flags])


def write_loudness(base: Path, out_tsv: Path, limit: int, target_lufs: float = -14.0) -> None:
    files = list_audio(base, limit)
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    rows: List[Tuple[str, float, float, float, float, float, str]] = []
    for p in files:
        lufs = 0.0
        crest = 0.0
        dyn_range = 0.0
        method = "rms_dbfs"
        gain = 0.0
        lra = 0.0
        try:
            import soundfile as _sf
            import numpy as _np
            data, sr = _sf.read(str(p))
            if data.ndim > 1:
                data = data.mean(axis=1)
            rms = float(_np.sqrt(_np.mean(_np.square(data)))) if len(data) else 0.0
            if rms > 0:
                lufs = 20 * float(_np.log10(rms))
            else:
                lufs = -120.0
            peak = float(_np.max(_np.abs(data))) if len(data) else 0.0
            crest = 20 * float(_np.log10(peak / (rms + 1e-9))) if rms > 0 else 0.0
            if len(data):
                p95 = float(_np.percentile(_np.abs(data), 95))
                p10 = float(_np.percentile(_np.abs(data), 10))
                dyn_range = 20 * float(_np.log10((p95 + 1e-9) / (p10 + 1e-9)))
            try:
                import pyloudnorm as pyln  # type: ignore
                meter = pyln.Meter(sr)
                lufs = float(meter.integrated_loudness(data))
                try:
                    lra = float(meter.loudness_range(data))
                except Exception:
                    lra = 0.0
                method = "pyloudnorm"
            except Exception:
                method = "rms_dbfs"
            gain = target_lufs - lufs
        except Exception:
            method = "error"
            lufs = 0.0
            crest = 0.0
            dyn_range = 0.0
            gain = 0.0
            lra = 0.0
        rows.append((str(p), lufs, gain, crest, dyn_range, lra, method))
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "loudness_lufs", "gain_db_to_target", "crest_factor_db", "dyn_range_db", "lra_db", "method"])
        for path, lufs, gain, crest, dyn_range, lra, method in rows:
            w.writerow([path, f"{lufs:.2f}", f"{gain:.2f}", f"{crest:.2f}", f"{dyn_range:.2f}", f"{lra:.2f}", method])


def write_matching(base: Path, out_tsv: Path, limit: int, emb_tsv: Optional[Path] = None, tags_tsv: Optional[Path] = None) -> None:
    """
    Matching simple multi-modal: nombre normalizado + tags heurísticos + opcional similitud de embeddings.
    """
    files = list_audio(base, limit)
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    rows: List[Tuple[str, str, str, float]] = []
    import re

    tag_map: Dict[str, List[str]] = {}
    if tags_tsv and tags_tsv.exists():
        try:
            with tags_tsv.open("r", encoding="utf-8") as f:
                next(f, None)
                for line in f:
                    parts = line.rstrip("\n").split("\t")
                    if len(parts) >= 3:
                        tag_map[parts[0]] = json.loads(parts[2])
        except Exception:
            tag_map = {}

    emb_map: Dict[str, List[float]] = {}
    if emb_tsv and emb_tsv.exists():
        try:
            for path, vec in load_embeddings(emb_tsv):
                emb_map[path] = vec
        except Exception:
            emb_map = {}

    text_map: Dict[str, List[float]] = {}

    def emb_score(a: str, b: str) -> float:
        va, vb = emb_map.get(a), emb_map.get(b)
        if not va or not vb:
            return 0.0
        return cosine(va, vb)

    def text_score(a: str, b: str) -> float:
        va, vb = text_map.get(a), text_map.get(b)
        if not va or not vb:
            return 0.0
        return cosine(va, vb)

    import itertools
    # Precompute normalized names and base rows
    for p in files:
        name = p.stem.lower()
        name = re.sub(r"[^a-z0-9]+", "_", name).strip("_")
        text_map[str(p)] = text_embedding(name)
        tags = tag_map.get(str(p), heuristic_tags(p))
        base_score = 0.0
        if "unknown" not in tags:
            base_score += 0.1 * len(tags)
        rows.append((str(p), name, ",".join(tags), base_score))

    # Boost scores using name matches and embedding similarity
    for i, j in itertools.combinations(range(len(rows)), 2):
        path_i, norm_i, tags_i, score_i = rows[i]
        path_j, norm_j, tags_j, score_j = rows[j]
        if norm_i and norm_i == norm_j:
            score_i += 0.3
            score_j += 0.3
        sim = emb_score(path_i, path_j)
        if sim >= 0.75:
            score_i += 0.2
            score_j += 0.2
        t_sim = text_score(path_i, path_j)
        if t_sim >= 0.75:
            score_i += 0.15
            score_j += 0.15
        rows[i] = (path_i, norm_i, tags_i, score_i)
        rows[j] = (path_j, norm_j, tags_j, score_j)

    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "normalized_name", "tags", "match_score_hint"])
        w.writerows(rows)


def _ffprobe_meta(path: Path) -> Dict[str, Any]:
    if not shutil.which("ffprobe"):
        return {}
    try:
        out = subprocess.check_output(
            ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height,duration", "-of", "json", str(path)],
            text=True,
        )
        data = json.loads(out)
        streams = data.get("streams") or []
        if streams:
            st = streams[0]
            return {
                "width": st.get("width"),
                "height": st.get("height"),
                "duration": float(st.get("duration")) if st.get("duration") else None,
            }
    except Exception:
        return {}
    return {}


def write_video_tags(base: Path, out_tsv: Path, limit: int) -> None:
    VIDEO_EXTS = {".mp4", ".mov", ".mkv", ".avi", ".m4v"}
    files = [p for p in base.rglob("*") if p.suffix.lower() in VIDEO_EXTS and p.is_file()]
    if limit > 0:
        files = files[:limit]
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    keyframe_dir = out_tsv.parent / "video_keyframes"
    keyframe_dir.mkdir(parents=True, exist_ok=True)
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "tags_json", "meta_json", "keyframe_path"])
        for p in files:
            tags = heuristic_tags(p)
            meta = _ffprobe_meta(p)
            if meta.get("width") and meta.get("height"):
                if meta["width"] > meta["height"]:
                    tags.append("landscape")
                else:
                    tags.append("portrait")
            if meta.get("duration"):
                dur = meta["duration"]
                if dur and dur > 600:
                    tags.append("longform")
                elif dur and dur < 60:
                    tags.append("shortform")
            keyframe_path = ""
            if shutil.which("ffmpeg"):
                try:
                    keyframe_path = str(keyframe_dir / f"{p.stem}_kf.jpg")
                    t_seek = "0"
                    if meta.get("duration"):
                        t_seek = str(max(meta["duration"] * 0.1, 0.0))
                    subprocess.run(
                        ["ffmpeg", "-y", "-v", "error", "-ss", t_seek, "-i", str(p), "-frames:v", "1", "-q:v", "4", keyframe_path],
                        check=True,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                except Exception:
                    keyframe_path = ""
            w.writerow([str(p), json.dumps(tags), json.dumps(meta), keyframe_path])


def write_music_tags(base: Path, out_tsv: Path, limit: int) -> None:
    files = list_audio(base, limit)
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "tags_json", "method"])
        for p in files:
            tags = heuristic_tags(p)
            w.writerow([str(p), json.dumps(tags), "heuristic_multi"])


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
    p_emb.add_argument("--offline", action="store_true", help="Forzar modo sin TF/Hub (mock) incluso si está disponible.")

    p_tags = sub.add_parser("tags")
    p_tags.add_argument("--base", default=".")
    p_tags.add_argument("--out", required=True)
    p_tags.add_argument("--limit", type=int, default=150)
    p_tags.add_argument("--model", default="yamnet", choices=list(MODEL_URLS.keys()))
    p_tags.add_argument("--offline", action="store_true", help="Forzar modo sin TF/Hub (mock) incluso si está disponible.")

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

    p_garb = sub.add_parser("garbage")
    p_garb.add_argument("--base", default=".")
    p_garb.add_argument("--out", required=True)
    p_garb.add_argument("--limit", type=int, default=200)

    p_lufs = sub.add_parser("loudness")
    p_lufs.add_argument("--base", default=".")
    p_lufs.add_argument("--out", required=True)
    p_lufs.add_argument("--limit", type=int, default=200)
    p_lufs.add_argument("--target", type=float, default=-14.0, help="Objetivo LUFS para sugerir ganancia (default -14).")

    p_match = sub.add_parser("matching")
    p_match.add_argument("--base", default=".")
    p_match.add_argument("--out", required=True)
    p_match.add_argument("--limit", type=int, default=200)
    p_match.add_argument("--embeddings", help="Embeddings TSV opcional para similitud cruzada.")
    p_match.add_argument("--tags", help="Tags TSV opcional para pista->tags.")

    p_vtags = sub.add_parser("video_tags")
    p_vtags.add_argument("--base", default=".")
    p_vtags.add_argument("--out", required=True)
    p_vtags.add_argument("--limit", type=int, default=200)

    p_mtags = sub.add_parser("music_tags")
    p_mtags.add_argument("--base", default=".")
    p_mtags.add_argument("--out", required=True)
    p_mtags.add_argument("--limit", type=int, default=200)

    args = ap.parse_args()

    if args.mode == "embeddings":
        write_embeddings(
            Path(args.base).expanduser().resolve(),
            Path(args.out).expanduser().resolve(),
            args.limit,
            args.model,
            args.offline,
        )
    elif args.mode == "tags":
        write_tags(
            Path(args.base).expanduser().resolve(),
            Path(args.out).expanduser().resolve(),
            args.limit,
            args.model,
            args.offline,
        )
    elif args.mode == "similarity":
        write_similarity(Path(args.embeddings).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.threshold, args.top)
    elif args.mode == "anomalies":
        write_anomalies(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit)
    elif args.mode == "segments":
        write_segments(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit)
    elif args.mode == "garbage":
        write_garbage(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit)
    elif args.mode == "loudness":
        write_loudness(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit, args.target)
    elif args.mode == "matching":
        emb = Path(args.embeddings).expanduser().resolve() if getattr(args, "embeddings", None) else None
        tags = Path(args.tags).expanduser().resolve() if getattr(args, "tags", None) else None
        write_matching(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit, emb, tags)
    elif args.mode == "video_tags":
        write_video_tags(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit)
    elif args.mode == "music_tags":
        write_music_tags(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit)


if __name__ == "__main__":
    main()
