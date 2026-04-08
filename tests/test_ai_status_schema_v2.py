#!/usr/bin/env python3
import unittest
import subprocess
import sys
import json
from pathlib import Path

# Add repo root to path
REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from scripts.lib.report_json import validate_payload

SCRIPT = REPO_ROOT / "ai_status_enhanced.py"
SCHEMA = REPO_ROOT / "config" / "schemas" / "ai_status_v2.schema.json"

class TestAIStatusSchemaV2(unittest.TestCase):
    def test_ai_status_v2_schema_valid(self):
        # We need a models dir for the script to run without erroring out early or we can point to a dummy one
        # The script requires --models-dir
        models_dir = REPO_ROOT / "ai" / "models"
        
        proc = subprocess.run(
            [sys.executable, str(SCRIPT), "--models-dir", str(models_dir), "--format", "json"],
            capture_output=True,
            text=True,
        )
        
        # If models dir doesn't exist, it might fail or return error JSON. 
        # But if it returns JSON, we validate it.
        try:
            payload = json.loads(proc.stdout)
        except json.JSONDecodeError:
            self.fail(f"Script output invalid JSON: {proc.stdout} (stderr: {proc.stderr})")

        ok, errors = validate_payload(payload, SCHEMA)
        self.assertTrue(ok, f"Schema validation failed: {errors}")
        self.assertEqual(payload["schema_version"], "ai_status_v2")

if __name__ == "__main__":
    unittest.main()