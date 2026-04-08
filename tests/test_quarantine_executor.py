import os
import tempfile
from pathlib import Path

import sys
ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from quarantine_executor import execute  # noqa: E402


def write_plan(path, rows):
    lines = ["hash\taction\tpath\treason"]
    lines += rows
    path.write_text("\n".join(lines))

def test_executor_respects_base_path():
    with tempfile.TemporaryDirectory(prefix="djpt_qe_") as td:
        base = Path(td)
        plan = base / "plan.tsv"
        quar = base / "quar"
        inside = base / "keepme.mp3"
        outside = base.parent / "outside.mp3"
        inside.write_text("x")
        outside.write_text("y")

        write_plan(plan, [
            f"H1\tQUARANTINE\t{inside}\tdup",
            f"H2\tQUARANTINE\t{outside}\tdup",
        ])

        os.environ["BASE_PATH"] = str(base)
        os.environ.pop("DJPT_ALLOW_OUTSIDE", None)

        execute(str(plan), str(quar), dry_run=False)

        # Inside should move
        moved = list((quar / "H1").glob("*"))
        assert len(moved) == 1
        assert moved[0].name == "keepme.mp3"
        # Outside should remain
        assert outside.exists()


def test_executor_allows_outside_with_flag():
    with tempfile.TemporaryDirectory(prefix="djpt_qe_") as td:
        base = Path(td)
        plan = base / "plan.tsv"
        quar = base / "quar"
        outside = base.parent / "outside2.mp3"
        outside.write_text("y")

        write_plan(plan, [f"H2\tQUARANTINE\t{outside}\tdup"])

        os.environ["BASE_PATH"] = str(base)
        os.environ["DJPT_ALLOW_OUTSIDE"] = "1"

        execute(str(plan), str(quar), dry_run=False)

        moved = list((quar / "H2").glob("*"))
        assert len(moved) == 1
        assert moved[0].name == "outside2.mp3"
