#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from importlib.util import find_spec
from pathlib import Path
from typing import Iterable

TEXT_EXTS = {".md", ".txt", ".json", ".toml", ".yaml", ".yml", ".py", ".sh", ".csv", ".tsv"}
AUDIO_EXTS = {".mp3", ".wav", ".flac", ".m4a", ".aif", ".aiff", ".aac", ".ogg"}
SKIP_DIRS = {".git", "__pycache__", "node_modules", ".venv", "venv", "djpt_venv", "_DJProducerTools"}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def repo_root() -> Path:
    return Path(__file__).resolve().parent


def resolve_base_path(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit).expanduser().resolve()
    env_base = os.environ.get("BASE_PATH") or os.environ.get("DJPT_BASE_DIR")
    if env_base:
        return Path(env_base).expanduser().resolve()
    return repo_root()


def resolve_state_dir(base: Path) -> Path:
    env_state = os.environ.get("DJPT_STATE_DIR")
    if env_state:
        return Path(env_state).expanduser().resolve()
    if base.name == "_DJProducerTools":
        return (base / "state").resolve()
    repo_state = repo_root() / "state"
    if base == repo_root() or repo_state.exists():
        return repo_state.resolve()
    return (base / "_DJProducerTools" / "state").resolve()


def ensure_dirs(base: Path) -> tuple[Path, Path]:
    state = resolve_state_dir(base)
    reports = state / "reports"
    state.mkdir(parents=True, exist_ok=True)
    reports.mkdir(parents=True, exist_ok=True)
    return state, reports


def walk_files(base: Path, exts: set[str] | None = None) -> Iterable[Path]:
    if not base.exists():
        return []
    if base.is_file():
        return [base] if exts is None or base.suffix.lower() in exts else []
    files: list[Path] = []
    for root, dirs, names in os.walk(base):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for name in sorted(names):
            path = Path(root) / name
            if exts is None or path.suffix.lower() in exts:
                files.append(path)
    return files


def rel_to(base: Path, path: Path) -> str:
    try:
        return str(path.resolve().relative_to(base.resolve()))
    except Exception:
        return str(path.resolve())


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")


def sha1_text(value: str) -> str:
    return hashlib.sha1(value.encode("utf-8", "ignore")).hexdigest()


def module_ready(name: str, skip_env: str | None = None) -> bool:
    if skip_env and os.environ.get(skip_env):
        return False
    return find_spec(name) is not None


@dataclass
class OptimizePayload:
    ts: str
    base_path: str
    state_dir: str
    reports_dir: str
    suggested_backend: str
    mlx: bool
    tensorflow: bool
    sklearn: bool
    ollama: bool
    embeddings: bool


def choose_backend() -> str:
    if module_ready("mlx", "DJPT_SKIP_MLX"):
        return "mlx"
    if module_ready("tensorflow", "DJPT_SKIP_TF"):
        return "tensorflow"
    if module_ready("sklearn"):
        return "sklearn"
    if shutil.which("ollama"):
        return "ollama"
    return "cpu-safe"


def cmd_optimize(args: argparse.Namespace) -> int:
    base = resolve_base_path(args.base_path)
    state, reports = ensure_dirs(base)
    payload = OptimizePayload(
        ts=utc_now(),
        base_path=str(base),
        state_dir=str(state),
        reports_dir=str(reports),
        suggested_backend=choose_backend(),
        mlx=module_ready("mlx", "DJPT_SKIP_MLX"),
        tensorflow=module_ready("tensorflow", "DJPT_SKIP_TF"),
        sklearn=module_ready("sklearn"),
        ollama=shutil.which("ollama") is not None,
        embeddings=module_ready("sentence_transformers"),
    )
    profile_path = state / "ai_profile.json"
    optimize_path = reports / f"ai_optimize_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    write_json(profile_path, asdict(payload))
    write_json(optimize_path, asdict(payload))
    print(json.dumps(asdict(payload), indent=2, ensure_ascii=False))
    return 0


def cmd_train(args: argparse.Namespace) -> int:
    base = resolve_base_path(args.base_path)
    state, reports = ensure_dirs(base)
    audio_files = list(walk_files(base, AUDIO_EXTS))[:1000]
    extension_counts: dict[str, int] = {}
    token_counts: dict[str, int] = {}
    for path in audio_files:
        suffix = path.suffix.lower() or "<none>"
        extension_counts[suffix] = extension_counts.get(suffix, 0) + 1
        for token in path.stem.replace("-", " ").replace("_", " ").split():
            normalized = token.strip().lower()
            if not normalized:
                continue
            token_counts[normalized] = token_counts.get(normalized, 0) + 1

    top_extensions = sorted(extension_counts.items(), key=lambda item: (-item[1], item[0]))[:10]
    top_tokens = sorted(token_counts.items(), key=lambda item: (-item[1], item[0]))[:20]
    model_payload = {
        "ts": utc_now(),
        "model_type": args.type,
        "backend": choose_backend(),
        "trained_on_audio_files": len(audio_files),
        "top_extensions": top_extensions,
        "top_tokens": top_tokens,
        "sample_files": [rel_to(base, p) for p in audio_files[:20]],
    }
    model_path = state / f"ai_model_{args.type}.json"
    write_json(model_path, model_payload)
    payload = {
        "ts": utc_now(),
        "model_type": args.type,
        "base_path": str(base),
        "audio_files_seen": len(audio_files),
        "sample_files": [rel_to(base, p) for p in audio_files[:10]],
        "suggested_backend": choose_backend(),
        "model_path": str(model_path),
        "top_extensions": top_extensions,
        "top_tokens": top_tokens,
        "status": "trained-local" if audio_files else "trained-empty-corpus",
    }
    write_json(state / "ai_profile.json", payload)
    write_json(reports / f"ai_train_{args.type}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json", payload)
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0


def load_kb_state(state_dir: Path) -> dict:
    kb_state = state_dir / "knowledge_base.json"
    if kb_state.exists():
        try:
            return json.loads(kb_state.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {
        "ts": utc_now(),
        "indexed_text": 0,
        "indexed_audio": 0,
        "last_action": "init",
        "roots": [],
        "sample_items": [],
    }


def save_kb_state(state_dir: Path, payload: dict) -> None:
    write_json(state_dir / "knowledge_base.json", payload)


def cmd_kb(args: argparse.Namespace) -> int:
    base = resolve_base_path(args.base_path)
    state, reports = ensure_dirs(base)
    payload = load_kb_state(state)
    action = args.action
    ts_tag = datetime.now().strftime("%Y%m%d_%H%M%S")

    if action in {"index", "index-text"}:
        target = resolve_base_path(args.path) if args.path else base
        text_files = list(walk_files(target, TEXT_EXTS))
        payload.update(
            {
                "ts": utc_now(),
                "indexed_text": len(text_files),
                "last_action": action,
                "roots": [str(target)],
                "sample_items": [rel_to(target, p) for p in text_files[:20]],
            }
        )
        write_json(reports / f"kb_index_text_{ts_tag}.json", payload)
        save_kb_state(state, payload)
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 0

    if action == "index-audio":
        target = resolve_base_path(args.path) if args.path else base
        audio_files = list(walk_files(target, AUDIO_EXTS))
        payload.update(
            {
                "ts": utc_now(),
                "indexed_audio": len(audio_files),
                "last_action": action,
                "roots": [str(target)],
                "sample_items": [rel_to(target, p) for p in audio_files[:20]],
                "asr_backend": args.asr,
            }
        )
        write_json(reports / f"kb_index_audio_{ts_tag}.json", payload)
        save_kb_state(state, payload)
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 0

    if action == "embed":
        target = resolve_base_path(args.path) if args.path else base
        items = list(walk_files(target, TEXT_EXTS | AUDIO_EXTS))[:200]
        out = reports / f"kb_embeddings_{ts_tag}.tsv"
        with out.open("w", encoding="utf-8") as fh:
            fh.write("path\tembedding_id\tsize_bytes\n")
            for item in items:
                try:
                    size = item.stat().st_size
                except OSError:
                    size = 0
                fh.write(f"{rel_to(target, item)}\t{sha1_text(str(item.resolve()))[:16]}\t{size}\n")
        payload.update(
            {
                "ts": utc_now(),
                "last_action": action,
                "embedding_rows": len(items),
                "embeddings_report": str(out),
            }
        )
        save_kb_state(state, payload)
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 0

    if action == "query":
        target = resolve_base_path(args.path) if args.path else base
        query = (args.query or "").strip().lower()
        files = list(walk_files(target, TEXT_EXTS | AUDIO_EXTS))[:1000]
        hits: list[dict] = []
        for item in files:
            hay = item.name.lower()
            if query and query in hay:
                hits.append({"path": rel_to(target, item), "score": 1.0})
            if len(hits) >= args.topk:
                break
        payload = {
            "ts": utc_now(),
            "query": args.query or "",
            "hits": hits,
            "base_path": str(target),
        }
        write_json(reports / f"kb_query_{ts_tag}.json", payload)
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 0

    if action == "status":
        payload["ts"] = utc_now()
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 0

    print(json.dumps({"error": f"unsupported kb action: {action}"}, ensure_ascii=False))
    return 2


def cmd_docs(args: argparse.Namespace) -> int:
    base = resolve_base_path(args.base_path)
    _, reports = ensure_dirs(base)
    file_path = Path(args.file).expanduser().resolve()
    payload = {
        "ts": utc_now(),
        "file": str(file_path),
        "exists": file_path.exists(),
        "suffix": file_path.suffix.lower(),
        "size_bytes": file_path.stat().st_size if file_path.exists() else 0,
    }
    out = reports / f"docs_analysis_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    write_json(out, payload)
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0 if file_path.exists() else 1


def cmd_learn(args: argparse.Namespace) -> int:
    base = resolve_base_path(args.base_path)
    state, reports = ensure_dirs(base)
    payload = {
        "ts": utc_now(),
        "mode": args.mode,
        "status": "ok",
        "base_path": str(base),
    }
    write_json(state / "learning_profile.json", payload)
    write_json(reports / f"ai_learn_{args.mode}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json", payload)
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0


def cmd_dynamic(args: argparse.Namespace) -> int:
    base = resolve_base_path(args.base_path)
    _, reports = ensure_dirs(base)
    payload = {
        "ts": utc_now(),
        "task": args.task,
        "status": "ok",
        "suggested_backend": choose_backend(),
    }
    write_json(reports / f"ai_dynamic_{args.task}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json", payload)
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0


def cmd_lab(args: argparse.Namespace) -> int:
    base = resolve_base_path(args.base_path)
    _, reports = ensure_dirs(base)
    payload = {
        "ts": utc_now(),
        "experiment": args.experiment,
        "status": "ok",
        "base_path": str(base),
    }
    write_json(reports / f"ai_lab_{args.experiment}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json", payload)
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="DJPT AI suite fallback canónica")
    parser.add_argument("--base-path", default=None)
    sub = parser.add_subparsers(dest="cmd", required=True)

    optimize = sub.add_parser("optimize")
    optimize.set_defaults(func=cmd_optimize)

    train = sub.add_parser("train")
    train.add_argument("--type", default="classifier")
    train.set_defaults(func=cmd_train)

    docs = sub.add_parser("docs")
    docs.add_argument("--file", required=True)
    docs.set_defaults(func=cmd_docs)

    kb = sub.add_parser("kb")
    kb.add_argument("--action", required=True)
    kb.add_argument("--path", default=None)
    kb.add_argument("--ext", default=None)
    kb.add_argument("--asr", default="mlx")
    kb.add_argument("--query", default=None)
    kb.add_argument("--topk", type=int, default=5)
    kb.set_defaults(func=cmd_kb)

    learn = sub.add_parser("learn")
    learn.add_argument("--mode", required=True)
    learn.set_defaults(func=cmd_learn)

    dynamic = sub.add_parser("dynamic")
    dynamic.add_argument("--task", required=True)
    dynamic.set_defaults(func=cmd_dynamic)

    lab = sub.add_parser("lab")
    lab.add_argument("--experiment", required=True)
    lab.set_defaults(func=cmd_lab)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
