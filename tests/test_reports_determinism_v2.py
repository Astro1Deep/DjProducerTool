#!/usr/bin/env python3
import unittest
import sys
import json
import shutil
import tempfile
from pathlib import Path

# Add repo root to path
REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from scripts.lib.report_json import dump_report, load_report

class TestReportsDeterminismV2(unittest.TestCase):
    def test_key_sorting(self):
        data = {"z": 1, "a": 2, "m": 3}
        # Note: dump_report injects "timestamp" if missing.
        # "a": 2
        # "m": 3
        # "timestamp": ...
        # "z": 1
        
        json_str = dump_report(data)
        
        # We verify order by finding indices
        idx_a = json_str.find('"a": 2')
        idx_m = json_str.find('"m": 3')
        idx_z = json_str.find('"z": 1')
        
        self.assertLess(idx_a, idx_m)
        self.assertLess(idx_m, idx_z)

    def test_common_fields_injection(self):
        data = {"foo": "bar"}
        json_str = dump_report(data, schema_version="test_v1", execution_ms=123.45)
        loaded = json.loads(json_str)
        
        self.assertEqual(loaded["schema_version"], "test_v1")
        self.assertEqual(loaded["execution_ms"], 123.45)
        self.assertIn("timestamp", loaded)

    def test_unicode_handling(self):
        data = {"text": "café ☕"}
        json_str = dump_report(data)
        # Should not be escaped like \u2615
        self.assertIn("café ☕", json_str)

if __name__ == "__main__":
    unittest.main()
