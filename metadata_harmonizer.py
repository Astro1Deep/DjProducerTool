#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
from pathlib import Path
from types import ModuleType


def _load_impl() -> ModuleType:
    module_path = Path(__file__).resolve().parent / 'lib' / 'metadata_harmonizer.py'
    spec = importlib.util.spec_from_file_location('djpt_metadata_harmonizer_impl', module_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f'Target script not found: {module_path}')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


_IMPL = _load_impl()
harmonize = _IMPL.harmonize
main = _IMPL.main


if __name__ == '__main__':
    raise SystemExit(main())
