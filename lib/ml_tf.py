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
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple, Optional
import importlib
import math
import statistics

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

try:  # optional onnx/tflite
    import onnxruntime as ort  # type: ignore
except Exception:  # pragma: no cover
    ort = None
try:
    import tflite_runtime.interpreter as tflite  # type: ignore
except Exception:  # pragma: no cover
    tflite = None

_onnx_warned = False
_tflite_warned = False


def is_offline_env() -> bool:
    return os.environ.get("DJPT_OFFLINE") == "1"


MODEL_URLS = {
    "yamnet": "https://tfhub.dev/google/yamnet/1",
    "musicnn": "https://tfhub.dev/google/musicnn/1",
    "musictag": "https://tfhub.dev/google/music_tagging/nnfp/1",
    # Placeholders: si no hay modelo, se usa hash_mock
    "clap": None,
    "musicgen": None,
}

ONNX_MODELS = {
    "clap_onnx": "CLAP.onnx",
    "clip_vitb16_onnx": "model.onnx",
    "musicgen_tflite": "musicgen-small.tflite",
    "sentence_t5_tflite": "sentence-t5.onnx",
}

# Modelos onnx/tflite opcionales (descarga manual vía subcomando download_model)
MODEL_WEIGHTS = {
    "clap_onnx": "https://huggingface.co/lukewys/laion_clap/resolve/main/CLAP.onnx",  # grande; descarga opcional
    "clip_vitb16_onnx": "https://huggingface.co/onnx-community/clip-vit-base-patch16/resolve/main/model.onnx",
    "musicgen_tflite": "https://huggingface.co/adarob/musicgen_tflite/resolve/main/musicgen-small.tflite",
    "sentence_t5_tflite": "https://huggingface.co/onnx-community/t5-small/resolve/main/model.onnx",  # placeholder texto
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


def load_audio_mono(path: Path, target_sr: int = 32000) -> Tuple[Optional["np.ndarray"], Optional[int]]:
    if sf is None or np is None:
        return None, None
    try:
        data, sr = sf.read(str(path))
    except Exception:
        return None, None
    if data.ndim > 1:
        data = data.mean(axis=1)
    data = np.asarray(data, dtype=np.float32)
    # normaliza a -1..1
    peak = np.max(np.abs(data)) if data.size else 1.0
    if peak > 0:
        data = data / peak
    if target_sr and sr != target_sr:
        try:
            import librosa  # type: ignore

            data = librosa.resample(data, orig_sr=sr, target_sr=target_sr)
            sr = target_sr
        except Exception:
            pass
    return data, sr


def text_embedding(text: str, dim: int = 16) -> List[float]:
    sess, inp = load_onnx_session("sentence_t5_tflite")
    if sess and inp:
        emb = run_onnx_text(sess, inp, text)
        if emb:
            return emb
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


def load_onnx_session(model_name: str) -> Tuple[Optional[Any], Optional[str]]:
    global _onnx_warned
    if ort is None:
        if not _onnx_warned:
            print(f"[WARN] onnxruntime no disponible; se usará fallback/mock para {model_name}", file=sys.stderr)
            _onnx_warned = True
        return None, None
    model_path = local_model_path(model_name)
    if not model_path or not model_path.exists():
        return None, None
    try:
        sess = ort.InferenceSession(str(model_path))
        input_name = sess.get_inputs()[0].name
        return sess, input_name
    except Exception:
        return None, None


def run_onnx_audio(sess: Any, input_name: str, path: Path) -> List[float]:
    try:
        data, _ = load_audio_mono(path, target_sr=16000)
        if data is None:
            return []
        out = sess.run(None, {input_name: data})
        if isinstance(out, list) and len(out) > 0:
            arr = np.asarray(out[0]).flatten()
            return arr.tolist()
    except Exception:
        return []
    return []


def run_onnx_text(sess: Any, input_name: str, text: str) -> List[float]:
    try:
        tokens = [ord(c) % 255 for c in text][:512]
        arr = np.array(tokens, dtype=np.float32)
        out = sess.run(None, {input_name: arr})
        if isinstance(out, list) and len(out) > 0:
            return np.asarray(out[0]).flatten().tolist()
    except Exception:
        return []
    return []


def load_tflite_interpreter(model_name: str) -> Optional[Any]:
    global _tflite_warned
    if tflite is None:
        if not _tflite_warned:
            print(f"[WARN] tflite-runtime no disponible; se usará fallback/mock para {model_name}", file=sys.stderr)
            _tflite_warned = True
        return None
    model_path = local_model_path(model_name)
    if not model_path or not model_path.exists():
        return None
    try:
        interpreter = tflite.Interpreter(model_path=str(model_path))
        interpreter.allocate_tensors()
        return interpreter
    except Exception:
        return None


def run_tflite_audio(interpreter: Any, path: Path) -> List[float]:
    try:
        import soundfile as _sf
        import numpy as _np

        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        if not input_details:
            return []
        data, sr = _sf.read(str(path))
        if data.ndim > 1:
            data = data.mean(axis=1)
        arr = _np.asarray(data, dtype=_np.float32)
        arr = _np.expand_dims(arr, axis=0)
        interpreter.set_tensor(input_details[0]["index"], arr)
        interpreter.invoke()
        out = interpreter.get_tensor(output_details[0]["index"])
        return _np.asarray(out).flatten().tolist()
    except Exception:
        return []


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


def ensure_model_cached(name: str) -> Optional[Path]:
    """
    Descarga un modelo opcional (onnx/tflite) a _DJProducerTools/venv/models.
    No se usa en los flujos por defecto, sólo cuando se llame al subcomando download_model.
    """
    if name not in MODEL_WEIGHTS:
        return None
    base = Path(os.environ.get("DJPT_MODELS_DIR") or "_DJProducerTools/venv/models").expanduser().resolve()
    base.mkdir(parents=True, exist_ok=True)
    target = base / f"{name}"
    if target.exists() and target.stat().st_size > 0:
        return target
    url = MODEL_WEIGHTS[name]
    try:
        import urllib.request

        urllib.request.urlretrieve(url, target)
        return target
    except Exception:
        return None


def local_model_path(name: str) -> Optional[Path]:
    base = Path(os.environ.get("DJPT_MODELS_DIR") or "_DJProducerTools/venv/models").expanduser().resolve()
    path = base / name
    return path if path.exists() else None


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
    offline = offline or os.environ.get("DJPT_OFFLINE") == "1"
    use_tf = tf_available() and model_choice in MODEL_URLS and not offline
    model = load_tf_model(model_choice) if use_tf else None
    onnx_sess, onnx_input = (None, None)
    if not use_tf and not offline and model_choice in ONNX_MODELS:
        onnx_sess, onnx_input = load_onnx_session(model_choice)
    tflite_interp = None
    if not use_tf and not offline and model_choice == "musicgen_tflite":
        tflite_interp = load_tflite_interpreter(model_choice)
    for p in files:
        if use_tf and model is not None:
            audio = load_audio_16k(p)
            emb, _ = model_embed_and_tag(model, audio)
            method = f"tf_{model_choice}" if emb else f"tf_{model_choice}_fallback"
            if not emb:
                emb = hash_embedding(p)
        elif model_choice in ONNX_MODELS:
            if onnx_sess and onnx_input:
                emb = run_onnx_audio(onnx_sess, onnx_input, p)
                method = f"onnx_{model_choice}" if emb else f"onnx_{model_choice}_fallback"
                if not emb:
                    emb = hash_embedding(p)
            else:
                emb = hash_embedding(p)
                model_path = local_model_path(model_choice)
                method = f"onnx_{model_choice}_missing" if not model_path else f"onnx_{model_choice}_fallback"
        elif tflite_interp is not None:
            emb = run_tflite_audio(tflite_interp, p)
            method = "tflite_musicgen" if emb else "tflite_musicgen_fallback"
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
    offline = offline or os.environ.get("DJPT_OFFLINE") == "1"
    use_tf = tf_available() and model_choice in MODEL_URLS and not offline
    model = load_tf_model(model_choice) if use_tf else None
    onnx_sess, onnx_input = (None, None)
    if not use_tf and not offline and model_choice in ONNX_MODELS:
        onnx_sess, onnx_input = load_onnx_session(model_choice)
    tflite_interp = None
    if not use_tf and not offline and model_choice == "musicgen_tflite":
        tflite_interp = load_tflite_interpreter(model_choice)
    for p in files:
        tags: List[str] = []
        method = f"{model_choice}_mock"
        if use_tf and model is not None:
            audio = load_audio_16k(p)
            _, tags = model_embed_and_tag(model, audio)
            method = f"tf_{model_choice}" if tags else f"tf_{model_choice}_fallback"
        elif model_choice in ONNX_MODELS:
            if onnx_sess and onnx_input:
                emb = run_onnx_audio(onnx_sess, onnx_input, p)
                if emb:
                    import numpy as _np
                    idx = int(_np.argmax(_np.asarray(emb)))
                    tags = [f"class_{idx}"]
                    method = f"onnx_{model_choice}"
                else:
                    method = f"onnx_{model_choice}_fallback"
            else:
                model_path = local_model_path(model_choice)
                method = f"onnx_{model_choice}_missing" if not model_path else f"onnx_{model_choice}_fallback"
        elif tflite_interp is not None:
            emb = run_tflite_audio(tflite_interp, p)
            if emb:
                import numpy as _np
                idx = int(_np.argmax(_np.asarray(emb)))
                tags = [f"class_{idx}"]
                method = "tflite_musicgen"
            else:
                method = "tflite_musicgen_fallback"
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
    rows: List[Dict[str, Any]] = []
    for p in files:
        silence_ratio = 0.0
        clipping = 0.0
        clicks = 0.0
        pops = 0.0
        noise_dbfs = -90.0
        flags: List[str] = []
        try:
            data, sr = load_audio_mono(p, target_sr=32000)
            if data is not None and sr:
                silence_ratio = float(np.mean(np.abs(data) < 1e-3))
                clipping = float(np.mean(np.abs(data) > 0.98))
                diff = np.abs(np.diff(data)) if data.size > 1 else np.array([0.0], dtype=np.float32)
                clicks = float(np.mean(diff > 0.6))
                pops = float(np.mean(diff > 0.8))
                rms = float(np.sqrt(np.mean(np.square(data)))) if data.size else 0.0
                if rms > 0:
                    noise_dbfs = 20 * math.log10(rms + 1e-9)
                if clipping > 0.01:
                    flags.append("clipping")
                if silence_ratio > 0.5:
                    flags.append("silence")
                if clicks > 0.01:
                    flags.append("clicks")
                if pops > 0.005:
                    flags.append("pops")
        except Exception:
            flags.append("error")
        severity = min(1.0, clipping * 2 + clicks + pops + silence_ratio * 0.5)
        rows.append(
            {
                "path": str(p),
                "silence_ratio": round(silence_ratio, 6),
                "clipping_ratio": round(clipping, 6),
                "clicks_ratio": round(clicks, 6),
                "pops_ratio": round(pops, 6),
                "noise_dbfs": round(noise_dbfs, 2),
                "severity": round(severity, 6),
                "flags": ",".join(flags),
            }
        )
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(
            ["path", "silence_ratio", "clipping_ratio", "clicks_ratio", "pops_ratio", "noise_dbfs", "severity", "flags"]
        )
        for r in rows:
            w.writerow(
                [
                    r["path"],
                    f"{r['silence_ratio']:.6f}",
                    f"{r['clipping_ratio']:.6f}",
                    f"{r['clicks_ratio']:.6f}",
                    f"{r['pops_ratio']:.6f}",
                    f"{r['noise_dbfs']:.2f}",
                    f"{r['severity']:.6f}",
                    r["flags"],
                ]
            )


def write_segments(base: Path, out_tsv: Path, limit: int) -> None:
    files = list_audio(base, limit)
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    rows: List[Tuple[str, str, str, float, float]] = []
    have_librosa = False
    try:
        import librosa  # type: ignore
        have_librosa = True
    except Exception:
        have_librosa = False

    for p in files:
        onsets: List[float] = []
        beats: List[float] = []
        tempo_val: float = 0.0
        bars_est: float = 4.0
        if have_librosa:
            try:
                import numpy as _np
                y, sr = librosa.load(p, sr=22050, mono=True, duration=180)
                on = librosa.onset.onset_detect(y=y, sr=sr, units="time")
                onsets = [float(x) for x in on[:12]]
                tempo, beat_frames = librosa.beat.beat_track(y=y, sr=sr)
                tempo_val = float(tempo)
                beats = [float(x) for x in librosa.frames_to_time(beat_frames, sr=sr)[:16]]
            except Exception:
                onsets = []
                beats = []
                tempo_val = 0.0
                bars_est = 4.0
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
                tempo_val = 0.0
        rows.append(
            (
                str(p),
                ",".join(f"{t:.2f}" for t in onsets),
                ",".join(f"{t:.2f}" for t in beats),
                tempo_val,
                bars_est,
            )
        )
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "onsets_sec", "beats_sec", "tempo_est_bpm", "bars_est"])
        for path, ons, beats, tempo, bars in rows:
            w.writerow([path, ons, beats, f"{tempo:.2f}", f"{bars:.2f}"])


def write_garbage(base: Path, out_tsv: Path, limit: int) -> None:
    files = list_audio(base, limit)
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    rows: List[Tuple[str, float, str, float, float]] = []
    for p in files:
        score = 0.0
        flags = []
        try:
            import soundfile as _sf
            import numpy as _np
            data, sr = _sf.read(str(p))
            if data.ndim > 1:
                data = data.mean(axis=1)
            # High-pass simple (resta media móvil)
            try:
                window = min(len(data), 2048)
                if window > 0:
                    kernel = _np.ones(window) / window
                    smoothed = _np.convolve(data, kernel, mode="same")
                    data_hp = data - smoothed
                else:
                    data_hp = data
            except Exception:
                data_hp = data
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
                diffs = _np.abs(_np.diff(data_hp))
                if diffs.size and float(_np.percentile(diffs, 99)) > 0.25:
                    flags.append("clicks")
                    score += 0.2
                zc = float(((data_hp[:-1] * data_hp[1:]) < 0).sum()) / max(len(data_hp), 1)
                if zc > 0.15:
                    flags.append("high_zcr")
                    score += 0.1
            else:
                zc = 0.0
        except Exception:
            flags.append("error")
            score = 1.0
            peak = 0.0
            zc = 0.0
        rows.append((str(p), min(score, 1.0), ",".join(flags), peak, zc))
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "score", "flags", "peak", "zcr"])
        for path, score, flags, peak, zc in rows:
            w.writerow([path, f"{score:.2f}", flags, f"{peak:.4f}", f"{zc:.4f}"])


def write_loudness(base: Path, out_tsv: Path, limit: int, target_lufs: float = -14.0) -> None:
    files = list_audio(base, limit)
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    rows: List[Tuple[str, float, float, float, float, float, str, str]] = []
    tol = float(os.environ.get("DJPT_GAIN_TOL", "1.5"))
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
        rows.append((str(p), lufs, gain, crest, dyn_range, lra, method, "OK"))
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "loudness_lufs", "gain_db_to_target", "crest_factor_db", "dyn_range_db", "lra_db", "method", "action"])
        for path, lufs, gain, crest, dyn_range, lra, method, _action in rows:
            action = "OK"
            if gain > tol:
                action = "BOOST"
            elif gain < -tol:
                action = "CUT"
            w.writerow([path, f"{lufs:.2f}", f"{gain:.2f}", f"{crest:.2f}", f"{dyn_range:.2f}", f"{lra:.2f}", method, action])


def write_mastering(base: Path, out_tsv: Path, limit: int, target_lufs: float = -14.0, crest_min: float = 6.0, dr_min: float = 5.0) -> None:
    """
    Análisis estilo mastering: LUFS, true-peak aprox, crest, rango dinámico, sugerencias.
    """
    files = list_audio(base, limit)
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    rows: List[Tuple[str, float, float, float, float, str]] = []
    for p in files:
        lufs = -120.0
        peak_db = -120.0
        crest = 0.0
        dyn_range = 0.0
        note = "OK"
        try:
            import soundfile as _sf
            import numpy as _np
            data, sr = _sf.read(str(p))
            if data.ndim > 1:
                data = data.mean(axis=1)
            peak = float(_np.max(_np.abs(data))) if len(data) else 0.0
            peak_db = 20 * float(_np.log10(peak + 1e-9)) if peak > 0 else -120.0
            rms = float(_np.sqrt(_np.mean(_np.square(data)))) if len(data) else 0.0
            lufs = 20 * float(_np.log10(rms)) if rms > 0 else -120.0
            crest = peak_db - lufs if peak_db > -120 and lufs > -120 else 0.0
            if len(data):
                p95 = float(_np.percentile(_np.abs(data), 95))
                p10 = float(_np.percentile(_np.abs(data), 10))
                dyn_range = 20 * float(_np.log10((p95 + 1e-9) / (p10 + 1e-9)))
            try:
                import pyloudnorm as pyln  # type: ignore
                meter = pyln.Meter(sr)
                lufs = float(meter.integrated_loudness(data))
                peak_db = 20 * float(_np.log10(peak + 1e-9)) if peak > 0 else -120.0
            except Exception:
                pass
            if lufs < target_lufs - 2:
                note = "LOW"
            elif lufs > target_lufs + 2:
                note = "LOUD"
            if crest < crest_min:
                note = note + "|CREST_LOW"
            if dyn_range < dr_min:
                note = note + "|DR_LOW"
        except Exception:
            note = "ERROR"
        rows.append((str(p), lufs, peak_db, crest, dyn_range, note))
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "lufs", "peak_db", "crest_db", "dyn_range_db", "note"])
        for path, lufs, peak_db, crest, dyn_range, note in rows:
            w.writerow([path, f"{lufs:.2f}", f"{peak_db:.2f}", f"{crest:.2f}", f"{dyn_range:.2f}", note])


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
    common_offline = argparse.ArgumentParser(add_help=False)
    common_offline.add_argument("--offline", action="store_true", help="Forzar modo offline/heurístico (equivale a DJPT_OFFLINE=1).")
    sub = ap.add_subparsers(dest="mode", required=True)

    p_emb = sub.add_parser("embeddings", parents=[common_offline])
    p_emb.add_argument("--base", default=".")
    p_emb.add_argument("--out", required=True)
    p_emb.add_argument("--limit", type=int, default=150)
    p_emb.add_argument("--model", default="yamnet", choices=list(MODEL_URLS.keys()) + list(ONNX_MODELS.keys()))

    p_tags = sub.add_parser("tags", parents=[common_offline])
    p_tags.add_argument("--base", default=".")
    p_tags.add_argument("--out", required=True)
    p_tags.add_argument("--limit", type=int, default=150)
    p_tags.add_argument("--model", default="yamnet", choices=list(MODEL_URLS.keys()) + list(ONNX_MODELS.keys()))

    p_sim = sub.add_parser("similarity", parents=[common_offline])
    p_sim.add_argument("--embeddings", required=True, help="Input embeddings TSV")
    p_sim.add_argument("--out", required=True)
    p_sim.add_argument("--threshold", type=float, default=0.60)
    p_sim.add_argument("--top", type=int, default=200)

    p_an = sub.add_parser("anomalies", parents=[common_offline])
    p_an.add_argument("--base", default=".")
    p_an.add_argument("--out", required=True)
    p_an.add_argument("--limit", type=int, default=200)

    p_seg = sub.add_parser("segments", parents=[common_offline])
    p_seg.add_argument("--base", default=".")
    p_seg.add_argument("--out", required=True)
    p_seg.add_argument("--limit", type=int, default=50)

    p_garb = sub.add_parser("garbage", parents=[common_offline])
    p_garb.add_argument("--base", default=".")
    p_garb.add_argument("--out", required=True)
    p_garb.add_argument("--limit", type=int, default=200)

    p_lufs = sub.add_parser("loudness", parents=[common_offline])
    p_lufs.add_argument("--base", default=".")
    p_lufs.add_argument("--out", required=True)
    p_lufs.add_argument("--limit", type=int, default=200)
    p_lufs.add_argument("--target", type=float, default=-14.0, help="Objetivo LUFS para sugerir ganancia (default -14).")
    p_lufs.add_argument("--tolerance", type=float, default=None, help="Umbral BOOST/CUT (default 1.5 dB o DJPT_GAIN_TOL).")

    p_master = sub.add_parser("mastering", parents=[common_offline])
    p_master.add_argument("--base", default=".")
    p_master.add_argument("--out", required=True)
    p_master.add_argument("--limit", type=int, default=200)
    p_master.add_argument("--target", type=float, default=-14.0, help="Objetivo LUFS (default -14).")
    p_master.add_argument("--crest-min", type=float, default=6.0, help="Crest factor mínimo recomendado.")
    p_master.add_argument("--dr-min", type=float, default=5.0, help="Rango dinámico mínimo recomendado.")

    p_match = sub.add_parser("matching", parents=[common_offline])
    p_match.add_argument("--base", default=".")
    p_match.add_argument("--out", required=True)
    p_match.add_argument("--limit", type=int, default=200)
    p_match.add_argument("--embeddings", help="Embeddings TSV opcional para similitud cruzada.")
    p_match.add_argument("--tags", help="Tags TSV opcional para pista->tags.")

    p_vtags = sub.add_parser("video_tags", parents=[common_offline])
    p_vtags.add_argument("--base", default=".")
    p_vtags.add_argument("--out", required=True)
    p_vtags.add_argument("--limit", type=int, default=200)

    p_mtags = sub.add_parser("music_tags", parents=[common_offline])
    p_mtags.add_argument("--base", default=".")
    p_mtags.add_argument("--out", required=True)
    p_mtags.add_argument("--limit", type=int, default=200)

    p_dl = sub.add_parser("download_model", parents=[common_offline])
    p_dl.add_argument("--name", required=True, choices=list(MODEL_WEIGHTS.keys()))

    args = ap.parse_args()
    offline = getattr(args, "offline", False) or is_offline_env()
    if getattr(args, "offline", False):
        os.environ["DJPT_OFFLINE"] = "1"

    if args.mode == "embeddings":
        write_embeddings(
            Path(args.base).expanduser().resolve(),
            Path(args.out).expanduser().resolve(),
            args.limit,
            args.model,
            offline,
        )
    elif args.mode == "tags":
        write_tags(
            Path(args.base).expanduser().resolve(),
            Path(args.out).expanduser().resolve(),
            args.limit,
            args.model,
            offline,
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
        tol = args.tolerance if args.tolerance is not None else float(os.environ.get("DJPT_GAIN_TOL", "1.5"))
        os.environ["DJPT_GAIN_TOL"] = str(tol)
        write_loudness(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit, args.target)
    elif args.mode == "mastering":
        write_mastering(
            Path(args.base).expanduser().resolve(),
            Path(args.out).expanduser().resolve(),
            args.limit,
            args.target,
            args.crest_min,
            args.dr_min,
        )
    elif args.mode == "matching":
        emb = Path(args.embeddings).expanduser().resolve() if getattr(args, "embeddings", None) else None
        tags = Path(args.tags).expanduser().resolve() if getattr(args, "tags", None) else None
        write_matching(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit, emb, tags)
    elif args.mode == "video_tags":
        write_video_tags(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit)
    elif args.mode == "music_tags":
        write_music_tags(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit)
    elif args.mode == "download_model":
        if offline:
            print("[WARN] Modo offline activo; omitiendo descarga de modelos (usa DJPT_OFFLINE=0 para forzar).")
            return
        dest = ensure_model_cached(args.name)
        if dest:
            print(f"[OK] Modelo {args.name} descargado en {dest}")
        else:
            print(f"[ERR] No se pudo descargar {args.name} (revisa red/URL).")


if __name__ == "__main__":
    main()
