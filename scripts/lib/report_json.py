from __future__ import annotations

import json
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _utc_timestamp() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def dump_report(payload: dict[str, Any], schema_version: str | None = None, execution_ms: float | None = None) -> str:
    data = deepcopy(payload)
    data.setdefault("timestamp", _utc_timestamp())
    if schema_version is not None:
        data["schema_version"] = schema_version
    if execution_ms is not None:
        data["execution_ms"] = execution_ms
    return json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def load_report(path: str | Path) -> dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_report(
    payload: dict[str, Any],
    path: str | Path,
    schema_version: str | None = None,
    execution_ms: float | None = None,
) -> Path:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(dump_report(payload, schema_version=schema_version, execution_ms=execution_ms), encoding="utf-8")
    return target


def _load_schema(schema: Any) -> dict[str, Any]:
    if isinstance(schema, dict):
        return schema
    return json.loads(Path(schema).read_text(encoding="utf-8"))


def _matches_type(value: Any, expected: str) -> bool:
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "null":
        return value is None
    return True


def _validate_node(payload: Any, schema: dict[str, Any], path: str, errors: list[str]) -> None:
    expected_type = schema.get("type")
    if expected_type is not None:
        expected_types = expected_type if isinstance(expected_type, list) else [expected_type]
        if not any(_matches_type(payload, item) for item in expected_types):
            errors.append(f"{path}: expected type {expected_type}, got {type(payload).__name__}")
            return

    if "enum" in schema and payload not in schema["enum"]:
        errors.append(f"{path}: value {payload!r} not in enum {schema['enum']!r}")
        return

    if isinstance(payload, dict):
        required = schema.get("required", [])
        for key in required:
            if key not in payload:
                errors.append(f"{path}: missing required property {key!r}")

        properties = schema.get("properties", {})
        additional = schema.get("additionalProperties", True)
        for key, value in payload.items():
            if key in properties:
                _validate_node(value, properties[key], f"{path}.{key}", errors)
            elif additional is False:
                errors.append(f"{path}: unexpected property {key!r}")
            elif isinstance(additional, dict):
                _validate_node(value, additional, f"{path}.{key}", errors)
        return

    if isinstance(payload, list):
        item_schema = schema.get("items")
        if item_schema:
            for index, value in enumerate(payload):
                _validate_node(value, item_schema, f"{path}[{index}]", errors)


def validate_payload(payload: Any, schema: Any) -> tuple[bool, list[str] | None]:
    try:
        resolved_schema = _load_schema(schema)
    except Exception as exc:
        return False, [f"schema load failed: {exc}"]

    errors: list[str] = []
    _validate_node(payload, resolved_schema, "$", errors)
    return (len(errors) == 0, None if not errors else errors)
