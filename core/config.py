import os
from pathlib import Path


def _default_base_dir() -> Path:
    """Resolve the repository root relative to the canonical core package."""
    return Path(__file__).resolve().parents[1]


class Config:
    BASE_DIR = Path(os.environ.get("DJPT_BASE_DIR") or _default_base_dir()).resolve()
    SCANS_DIR = Path(os.environ.get("DJPT_SCANS_DIR") or (BASE_DIR / "scans")).resolve()
    STATE_DIR = Path(os.environ.get("DJPT_STATE_DIR") or (BASE_DIR / "state")).resolve()
    DB_PATH = Path(os.environ.get("DJPT_DB_PATH") or (STATE_DIR / "db" / "djpt.sqlite")).resolve()
    MODELS_DIR = Path(os.environ.get("DJPT_MODELS_DIR") or (BASE_DIR / "ai" / "models")).resolve()

    EXTENSIONS = {
        ".mp3",
        ".wav",
        ".aiff",
        ".flac",
        ".m4a",
        ".aac",
        ".ogg",
        ".mp4",
        ".mov",
        ".avi",
        ".mkv",
        ".wmv",
    }

    @classmethod
    def ensure_dirs(cls) -> None:
        base_str = str(cls.BASE_DIR)

        if f"{os.sep}_DJProducerTools{os.sep}_DJProducerTools" in base_str:
            if base_str.endswith(f"{os.sep}_DJProducerTools{os.sep}_DJProducerTools"):
                new_base = cls.BASE_DIR.parent
                print(f"[DJPT] [WARN] matrioshka detected in BASE_DIR: {cls.BASE_DIR}")
                print(f"[DJPT] [FIX] Auto-correcting BASE_DIR to: {new_base}")
                cls.BASE_DIR = new_base
                cls.SCANS_DIR = (cls.BASE_DIR / "scans").resolve()
                cls.STATE_DIR = (cls.BASE_DIR / "state").resolve()
                cls.DB_PATH = (cls.STATE_DIR / "db" / "djpt.sqlite").resolve()
                cls.MODELS_DIR = (cls.BASE_DIR / "ai" / "models").resolve()
            else:
                raise ValueError(f"CRITICAL: Nested _DJProducerTools detected in path: {cls.BASE_DIR}")

        state_dir_str = str(cls.STATE_DIR)
        if f"{os.sep}_DJProducerTools{os.sep}_DJProducerTools" in state_dir_str:
            raise ValueError(f"CRITICAL: matrioshka detected in STATE_DIR: {cls.STATE_DIR}")

        if f"{os.sep}state{os.sep}state" in state_dir_str:
            raise ValueError(f"CRITICAL: Nested 'state' directories detected: {cls.STATE_DIR}")

        cls.SCANS_DIR.mkdir(parents=True, exist_ok=True)
        cls.STATE_DIR.mkdir(parents=True, exist_ok=True)
        cls.DB_PATH.parent.mkdir(parents=True, exist_ok=True)
