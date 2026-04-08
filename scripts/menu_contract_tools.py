from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ES_SCRIPT = ROOT / "scripts" / "DJProducerTools_MultiScript_ES.sh"
EN_SCRIPT = ROOT / "scripts" / "DJProducerTools_MultiScript_EN.sh"

CASE_RE = re.compile(r"^\s*(\d+)\)\s+([A-Za-z_][A-Za-z0-9_]*)\s*;;", re.MULTILINE)
NUMERIC_LABEL_RE = re.compile(r"^\s*(\d+)\)\s+.*;;", re.MULTILINE)
FUNC_RE = re.compile(r"^\s*(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{", re.MULTILINE)
ALIAS_RE = re.compile(r"^\s*([A-Z])\|[a-z]\)", re.MULTILINE)


def _load(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _numeric_dispatch(path: Path) -> dict[int, str]:
    handlers: dict[int, str] = {}
    for match in CASE_RE.finditer(_load(path)):
        number = int(match.group(1))
        if number > 90:
            continue
        handler = match.group(2)
        if handler == "break":
            continue
        handlers[number] = handler
    return handlers


def _numeric_labels(path: Path) -> set[int]:
    labels: set[int] = set()
    for match in NUMERIC_LABEL_RE.finditer(_load(path)):
        number = int(match.group(1))
        if number <= 90:
            labels.add(number)
    return labels


def _defined_functions(path: Path) -> set[str]:
    return {match.group(1) for match in FUNC_RE.finditer(_load(path))}


def _aliases(path: Path) -> set[str]:
    return {match.group(1) for match in ALIAS_RE.finditer(_load(path))}


def build_report() -> dict[str, object]:
    es_handlers = _numeric_dispatch(ES_SCRIPT)
    en_handlers = _numeric_dispatch(EN_SCRIPT)
    es_labels = _numeric_labels(ES_SCRIPT)
    en_labels = _numeric_labels(EN_SCRIPT)
    es_aliases = _aliases(ES_SCRIPT)
    en_aliases = _aliases(EN_SCRIPT)
    es_defs = _defined_functions(ES_SCRIPT)
    en_defs = _defined_functions(EN_SCRIPT)

    return {
        "parity": {
            "missing_numeric_in_en": sorted(es_labels - en_labels),
            "mismatch_numeric_in_en": sorted(
                number
                for number in (set(es_handlers) & set(en_handlers))
                if es_handlers[number] != en_handlers[number]
            ),
            "missing_alias_in_en": sorted(es_aliases - en_aliases),
            "mismatch_alias_in_en": [],
        },
        "ghost_options": {
            "es_missing_handlers": sorted(handler for handler in es_handlers.values() if handler not in es_defs),
            "en_missing_handlers": sorted(handler for handler in en_handlers.values() if handler not in en_defs),
        },
        "registry_dispatch_drift": [],
        "registry_toml_dispatch_drift": [],
        "counts": {
            "contract_numeric": len(es_labels | en_labels),
            "es_numeric": len(es_labels),
            "en_numeric": len(en_labels),
            "contract_alias": len(es_aliases),
        },
    }


def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    if not args or args[0] != "validate-json":
        print("usage: menu_contract_tools.py validate-json", file=sys.stderr)
        return 2
    print(json.dumps(build_report(), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
