#!/usr/bin/env python3
import runpy
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    target = root / "integrated_dedup_analyzer.py"
    if not target.exists():
        raise SystemExit("Target script not found: integrated_dedup_analyzer.py")
    runpy.run_path(str(target), run_name="__main__")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
