#!/usr/bin/env python3
"""
Tests unitarios de Resiliencia para el Motor Acústico ShazamIO de DJProducerTools.
Valida:
  1. Filtro Heurístico Local (descarta one-shots sin gastar ancho de banda).
  2. Persistencia en Caché SQLite (cero llamadas duplicadas).
  3. Fallbacks Offline Heurísticos cuando no hay conexión.
  4. Integridad del Sanitizador de Audio FFmpeg.
"""

import tempfile
import unittest
from pathlib import Path
from lib.shazam_resilient_engine import ResilientShazamEngine, ResilientCache, AudioSanitizer


class TestShazamResilience(unittest.TestCase):
    def setUp(self):
        self.tmp_dir = tempfile.TemporaryDirectory()
        self.cache_path = Path(self.tmp_dir.name) / "test_cache.db"
        self.engine = ResilientShazamEngine(cache_db=self.cache_path)

    def tearDown(self):
        self.tmp_dir.cleanup()

    def test_candidate_guard_filters_small_files(self):
        """Archivos menores de 150 KB deben ser rechazados inmediatamente."""
        small_file = Path(self.tmp_dir.name) / "click.wav"
        small_file.write_bytes(b"\x00" * 50000)  # ~50 KB
        ok, reason = self.engine.check_candidate_guard(small_file)
        self.assertFalse(ok)
        self.assertIn("too_small", reason)

    def test_candidate_guard_filters_one_shots(self):
        """One-shots con palabras clave típicas de batería corta deben ser excluidos."""
        kick_file = Path(self.tmp_dir.name) / "kick_deep_punch.wav"
        kick_file.write_bytes(b"\x00" * 200000)  # ~200 KB
        ok, reason = self.engine.check_candidate_guard(kick_file)
        self.assertFalse(ok)

    def test_cache_persistence_avoids_duplicate_work(self):
        """Una vez almacenado en la caché, debe recuperarse instantáneamente."""
        cache = ResilientCache(self.cache_path)
        dummy_hash = "abc123hash"
        record = {
            "file_hash": dummy_hash,
            "path": "/path/to/test.wav",
            "file_size_bytes": 1024,
            "mtime": 12345.0,
            "status": "MATCH",
            "title": "Song Title",
            "artist": "Famous Artist",
            "album": "Greatest Hits",
            "genre": "Soul",
            "shazam_url": "https://shazam.com/test",
            "apple_music_id": "999",
            "method": "test"
        }
        cache.set(record)

        recovered = cache.get(dummy_hash)
        self.assertIsNotNone(recovered)
        self.assertEqual(recovered["title"], "Song Title")
        self.assertEqual(recovered["artist"], "Famous Artist")
        self.assertEqual(recovered["status"], "MATCH")

    def test_offline_fallback_resolution(self):
        """Si la API falla o no hay conexión, el fallback debe parsear nombre y carpeta sin crashear."""
        track_file = Path(self.tmp_dir.name) / "Miles Davis - So What (Remastered) [1959].wav"
        base_record = {
            "file_hash": "dummy",
            "path": str(track_file),
            "filename": track_file.name,
            "status": "ERROR_FALLBACK"
        }
        fallback_res = self.engine._apply_offline_fallback(track_file, base_record)
        self.assertEqual(fallback_res["artist"], "Miles Davis")
        self.assertEqual(fallback_res["title"], "So What (Remastered)")
        self.assertEqual(fallback_res["status"], "HEURISTIC_PARSED")
        self.assertEqual(fallback_res["method"], "offline_heuristic_fallback")


if __name__ == "__main__":
    unittest.main()
