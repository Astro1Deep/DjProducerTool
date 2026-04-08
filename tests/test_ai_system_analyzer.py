#!/usr/bin/env python3
"""Contract tests for ai_system_analyzer hardening behaviors."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path


def _write_stub(path: Path) -> None:
    path.write_text(
        "#!/usr/bin/env python3\n"
        "import json\n"
        "print(json.dumps({'ok': True, 'stub': 'ok'}))\n",
        encoding="utf-8",
    )
    path.chmod(0o755)


class TestAISystemAnalyzer(unittest.TestCase):
    def _make_root(self) -> Path:
        td = tempfile.TemporaryDirectory()
        self.addCleanup(td.cleanup)
        root = Path(td.name)
        (root / "scripts").mkdir(parents=True, exist_ok=True)
        _write_stub(root / "scripts/system_analyzer.py")
        _write_stub(root / "scripts/deep_debugger.py")
        _write_stub(root / "scripts/production_tester.py")
        _write_stub(root / "scripts/structure_optimizer.py")
        _write_stub(root / "scripts/cross_directory_analyzer.py")
        return root

    def _run(self, root: Path, *extra: str) -> subprocess.CompletedProcess[str]:
        repo_root = Path(__file__).resolve().parent.parent
        cmd = [
            os.environ.get("DJPT_PYTHON_BIN", "python3"),
            str(repo_root / "ai_system_analyzer.py"),
            "--root",
            str(root),
            *extra,
        ]
        return subprocess.run(cmd, capture_output=True, text=True, timeout=30)

    def test_no_write_skips_report_files(self) -> None:
        root = self._make_root()

        result = self._run(root, "--skip-cross", "--no-write")
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        payload = json.loads(result.stdout)
        self.assertIsNone(payload.get("report_file"))

        reports = list((root / "reports").glob("ai_system_report_*.json"))
        self.assertEqual(reports, [])

    def test_no_write_ignores_md_out(self) -> None:
        root = self._make_root()
        md_path = root / "report.md"

        result = self._run(root, "--skip-cross", "--no-write", "--md-out", str(md_path))
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        payload = json.loads(result.stdout)
        self.assertTrue(payload.get("md_out_ignored"))
        self.assertFalse(md_path.exists())

    def test_max_reports_prunes_old_reports(self) -> None:
        root = self._make_root()
        reports_dir = root / "reports"
        reports_dir.mkdir(parents=True, exist_ok=True)

        for idx in range(5):
            f = reports_dir / f"ai_system_report_20000101_00000{idx}.json"
            f.write_text("{}", encoding="utf-8")
            time.sleep(0.01)

        result = self._run(root, "--skip-cross", "--max-reports", "2")
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        payload = json.loads(result.stdout)
        self.assertIsInstance(payload.get("reports_pruned"), list)

        reports = sorted(reports_dir.glob("ai_system_report_*.json"))
        self.assertLessEqual(len(reports), 2)

    def test_max_reports_uses_filename_timestamp_order(self) -> None:
        root = self._make_root()
        reports_dir = root / "reports"
        reports_dir.mkdir(parents=True, exist_ok=True)

        names = [
            "ai_system_report_20240101_000001.json",
            "ai_system_report_20240101_000002.json",
            "ai_system_report_20240101_000003.json",
        ]
        for idx, name in enumerate(names):
            path = reports_dir / name
            path.write_text("{}", encoding="utf-8")
            # Intentionally invert mtimes to ensure pruning is not mtime-based.
            os.utime(path, (10_000 + (100 - idx), 10_000 + (100 - idx)))

        result = self._run(root, "--skip-cross", "--max-reports", "2")
        self.assertEqual(result.returncode, 0, msg=result.stderr)

        self.assertTrue((reports_dir / "ai_system_report_20240101_000003.json").exists())
        self.assertFalse((reports_dir / "ai_system_report_20240101_000001.json").exists())

    def test_missing_stage_returns_structured_error(self) -> None:
        root = self._make_root()
        (root / "scripts/structure_optimizer.py").unlink()

        result = self._run(root, "--skip-cross")
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        payload = json.loads(result.stdout)

        stage = payload["structure_optimizer"]
        self.assertFalse(stage["success"])
        self.assertEqual(stage.get("error_type"), "command_missing")
        self.assertIn("error_summary", stage)


if __name__ == "__main__":
    unittest.main()
