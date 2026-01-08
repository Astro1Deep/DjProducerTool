#!/usr/bin/env python3
import unittest
import sys
import shutil
import tempfile
import json
from pathlib import Path
from unittest.mock import patch, MagicMock

# Add lib to path
LIB_PATH = Path(__file__).parent.parent / "lib"
sys.path.append(str(LIB_PATH))

import ml_tf

class TestMLTF(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.base_dir = Path(self.test_dir) / "audio"
        self.base_dir.mkdir()
        self.out_file = Path(self.test_dir) / "output.tsv"
        
        # Create dummy audio file
        (self.base_dir / "test.mp3").touch()
        
    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def test_mock_embeddings(self):
        # Force offline/mock mode
        with patch.dict(tuple(os.environ.items()) + (("DJPT_TF_MOCK", "1"),)):
            ml_tf.write_embeddings(self.base_dir, self.out_file, 10, "yamnet", offline=True)
            
        self.assertTrue(self.out_file.exists())
        with open(self.out_file, "r") as f:
            lines = f.readlines()
            self.assertGreater(len(lines), 1) # Header + 1 row
            self.assertIn("yamnet_mock", lines[1])

    def test_heuristic_tags(self):
        # Create file with keyword
        (self.base_dir / "techno_track.mp3").touch()
        ml_tf.write_tags(self.base_dir, self.out_file, 10, "yamnet", offline=True)
        
        self.assertTrue(self.out_file.exists())
        with open(self.out_file, "r") as f:
            content = f.read()
            self.assertIn("techno", content)

import os
if __name__ == "__main__":
    unittest.main()
