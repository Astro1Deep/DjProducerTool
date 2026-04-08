"""Canonical root-level core package.

Keep the package importable even when optional runtime dependencies such as
`peewee` are not installed. Direct submodule imports (`core.config`,
`core.scanner`) should not pull the DB layer transitively.
"""

from .config import Config

__all__ = [
    "Config",
    "db",
    "init_db",
    "Scan",
    "FileIndex",
    "GlobalHash",
    "Deduper",
    "Scanner",
    "parse_args",
    "main",
]


def __getattr__(name):
    if name in {"db", "init_db", "Scan", "FileIndex", "GlobalHash"}:
        from .db import FileIndex, GlobalHash, Scan, db, init_db

        exports = {
            "db": db,
            "init_db": init_db,
            "Scan": Scan,
            "FileIndex": FileIndex,
            "GlobalHash": GlobalHash,
        }
        value = exports[name]
        globals()[name] = value
        return value

    if name == "Deduper":
        from .dedupe import Deduper

        globals()["Deduper"] = Deduper
        return Deduper

    if name in {"Scanner", "parse_args", "main"}:
        from .scanner import Scanner, main, parse_args

        exports = {"Scanner": Scanner, "parse_args": parse_args, "main": main}
        value = exports[name]
        globals()[name] = value
        return value

    raise AttributeError(f"module 'core' has no attribute {name!r}")
