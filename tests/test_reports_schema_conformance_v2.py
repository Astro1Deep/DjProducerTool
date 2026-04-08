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

from scripts.lib.report_json import validate_payload

class TestReportsSchemaConformanceV2(unittest.TestCase):
    def setUp(self):
        self.schema = {
            "type": "object",
            "required": ["foo", "timestamp"],
            "properties": {
                "foo": {"type": "string"},
                "timestamp": {"type": "string"}
            }
        }

    def test_valid_payload(self):
        data = {"foo": "bar", "timestamp": "2023-01-01"}
        ok, error = validate_payload(data, self.schema)
        self.assertTrue(ok)
        self.assertIsNone(error)

    def test_invalid_payload(self):
        data = {"foo": 123} # int, should be string, missing timestamp
        ok, error = validate_payload(data, self.schema)
        self.assertFalse(ok)
        self.assertIsNotNone(error)

    def test_schema_file_loading(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json") as f:
            json.dump(self.schema, f)
            f.flush()
            
            data = {"foo": "bar", "timestamp": "2023-01-01"}
            ok, error = validate_payload(data, f.name)
            self.assertTrue(ok)

if __name__ == "__main__":
    unittest.main()