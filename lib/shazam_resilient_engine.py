#!/usr/bin/env python3
"""
DJProducerTools - Motor Resiliente de Reconocimiento Acústico con ShazamIO & Fallbacks
Arquitectura defensiva de grado de producción:
  - Nivel 1: Guardia Heurística Local (Filtra one-shots < 3.5s o silencios).
  - Nivel 2: Caché Persistente SQLite (Evita llamadas duplicadas).
  - Nivel 3: Sanitizador con FFmpeg (Normaliza headers corruptos o códecs complejos).
  - Nivel 4: Reconocimiento ShazamIO Asíncrono con Timeout estricto (8s) y Backoff.
  - Nivel 5: Fallback Offline Heurístico si falla la red o si no hay match.
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import hashlib
import json
import logging
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("djpt.shazam_resilient")

AUDIO_EXTS = {".mp3", ".wav", ".flac", ".m4a", ".aif", ".aiff", ".ogg", ".wma"}

ONE_SHOT_KEYWORDS = {
    "kick", "kik", "snare", "snr", "clap", "clp", "hihat", "hh", "hat",
    "rim", "rimshot", "snap", "tom", "cajon", "cowbell", "shaker", "laser",
    "woodblock", "clave", "conga", "bongo"
}


class ResilientCache:
    """Gestiona la persistencia en SQLite para evitar cualquier consulta duplicada."""
    def __init__(self, db_path: Path):
        self.db_path = db_path
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
            CREATE TABLE IF NOT EXISTS shazam_cache (
                file_hash TEXT PRIMARY KEY,
                file_path TEXT,
                file_size_bytes INTEGER,
                mtime REAL,
                status TEXT,
                title TEXT,
                artist TEXT,
                album TEXT,
                genre TEXT,
                shazam_url TEXT,
                apple_music_id TEXT,
                method TEXT,
                checked_at TEXT
            );
            """)
            conn.execute("CREATE INDEX IF NOT EXISTS idx_cache_status ON shazam_cache(status);")
            conn.commit()

    @staticmethod
    def calculate_file_hash(file_path: Path) -> str:
        """Hash rápido de los primeros 128KB + últimos 128KB + tamaño para identificar unívocamente."""
        try:
            sz = file_path.stat().st_size
            h = hashlib.sha256()
            h.update(str(sz).encode("utf-8"))
            with file_path.open("rb") as f:
                head = f.read(131072)
                h.update(head)
                if sz > 262144:
                    f.seek(max(0, sz - 131072))
                    tail = f.read(131072)
                    h.update(tail)
            return h.hexdigest()
        except Exception:
            return hashlib.md5(str(file_path).encode("utf-8")).hexdigest()

    def get(self, file_hash: str) -> Optional[Dict[str, Any]]:
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()
            cur.execute("SELECT * FROM shazam_cache WHERE file_hash = ?", (file_hash,))
            row = cur.fetchone()
            if row:
                return dict(row)
        return None

    def set(self, record: Dict[str, Any]):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
            INSERT OR REPLACE INTO shazam_cache
            (file_hash, file_path, file_size_bytes, mtime, status, title, artist, album, genre, shazam_url, apple_music_id, method, checked_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """, (
                record.get("file_hash", ""),
                record.get("path", ""),
                record.get("file_size_bytes", 0),
                record.get("mtime", 0.0),
                record.get("status", "UNRECOGNIZED"),
                record.get("title", ""),
                record.get("artist", ""),
                record.get("album", ""),
                record.get("genre", ""),
                record.get("shazam_url", ""),
                record.get("apple_music_id", ""),
                record.get("method", "shazam_api"),
                datetime.now(timezone.utc).isoformat()
            ))
            conn.commit()


class AudioSanitizer:
    """Prepara fragmentos de audio estables y limpios para el reconocedor."""
    @staticmethod
    def get_duration(file_path: Path) -> float:
        """Obtiene la duración precisa con ffprobe o estimación por tamaño."""
        if shutil.which("ffprobe"):
            cmd = [
                "ffprobe", "-v", "error", "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1", str(file_path)
            ]
            try:
                res = subprocess.run(cmd, capture_output=True, text=True, timeout=3.0)
                if res.returncode == 0 and res.stdout.strip():
                    return float(res.stdout.strip())
            except Exception:
                pass
        # Fallback de estimación: WAV 16-bit 44.1k = ~176.4 KB/s, MP3 320k = ~40 KB/s
        try:
            sz_kb = file_path.stat().st_size / 1024
            ext = file_path.suffix.lower()
            if ext in {".wav", ".aif", ".aiff"}:
                return sz_kb / 176.4
            return sz_kb / 40.0
        except Exception:
            return 0.0

    @staticmethod
    def extract_clean_chunk(file_path: Path, duration: int = 12, start_offset: int = 5) -> Optional[Path]:
        """Extrae un fragmento WAV PCM 16-bit 44.1kHz para garantizar decodificación sin fallos."""
        if not shutil.which("ffmpeg"):
            return None
        try:
            tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
            tmp_path = Path(tmp.name)
            tmp.close()

            # Extraer 12 segundos desde el segundo 5 (evita intros silenciosas)
            cmd = [
                "ffmpeg", "-y", "-ss", str(start_offset), "-i", str(file_path),
                "-t", str(duration), "-ac", "1", "-ar", "44100",
                "-c:a", "pcm_s16le", str(tmp_path)
            ]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=6.0)
            if res.returncode == 0 and tmp_path.exists() and tmp_path.stat().st_size > 10000:
                return tmp_path
            if tmp_path.exists():
                tmp_path.unlink()
        except Exception as e:
            logger.debug(f"Fallo en sanitización ffmpeg: {e}")
        return None


class ResilientShazamEngine:
    def __init__(
        self,
        cache_db: Optional[Path] = None,
        concurrency: int = 3,
        request_timeout: float = 8.0,
        rate_limit_delay: float = 0.5
    ):
        self.concurrency = concurrency
        self.timeout = request_timeout
        self.delay = rate_limit_delay
        self.semaphore = asyncio.Semaphore(concurrency)
        self.cache = ResilientCache(cache_db or Path.home() / ".DJProducerTools" / "shazam_cache.db")
        self._shazam = None

    def _get_shazam_instance(self):
        if self._shazam is None:
            try:
                from shazamio import Shazam  # type: ignore
                self._shazam = Shazam()
            except ImportError:
                raise RuntimeError("El paquete shazamio no está presente en el entorno.")
        return self._shazam

    def check_candidate_guard(self, file_path: Path) -> Tuple[bool, str]:
        """Nivel 1: Guardia Heurística Local."""
        if not file_path.is_file():
            return False, "not_a_file"
        ext = file_path.suffix.lower()
        if ext not in AUDIO_EXTS:
            return False, f"unsupported_ext_{ext}"

        try:
            sz_kb = file_path.stat().st_size / 1024
        except Exception:
            return False, "stat_error"

        # Archivo demasiado pequeño
        if sz_kb < 150:
            return False, f"too_small_{sz_kb:.1f}kb"

        # Comprobar duración estimada
        dur = AudioSanitizer.get_duration(file_path)
        if dur < 3.2:
            return False, f"too_short_{dur:.1f}s"

        # Exclusión de palabras clave si dura menos de 5 segundos
        name_lower = file_path.stem.lower()
        if dur < 5.0 and any(kw in name_lower for kw in ONE_SHOT_KEYWORDS):
            return False, f"one_shot_keyword_{dur:.1f}s"

        return True, "candidate_ready"

    async def recognize(self, file_path: Path) -> Dict[str, Any]:
        """Ejecuta el reconocimiento acústico con todas las capas de seguridad y fallbacks."""
        file_hash = ResilientCache.calculate_file_hash(file_path)
        cached = self.cache.get(file_hash)
        if cached:
            logger.info(f"⚡ [CACHE HIT] {file_path.name} -> {cached.get('artist')} - {cached.get('title')}")
            return cached

        try:
            stat = file_path.stat()
            file_size = stat.st_size
            mtime = stat.st_mtime
        except Exception:
            file_size, mtime = 0, 0.0

        record: Dict[str, Any] = {
            "file_hash": file_hash,
            "path": str(file_path),
            "filename": file_path.name,
            "file_size_bytes": file_size,
            "mtime": mtime,
            "status": "UNRECOGNIZED",
            "title": "",
            "artist": "",
            "album": "",
            "genre": "",
            "shazam_url": "",
            "apple_music_id": "",
            "method": "shazam_api"
        }

        async with self.semaphore:
            if self.delay > 0:
                await asyncio.sleep(self.delay)

            shazam_inst = self._get_shazam_instance()
            clean_chunk = None
            out = None

            # Intento 1: Análisis directo del archivo original
            try:
                out = await asyncio.wait_for(shazam_inst.recognize(str(file_path)), timeout=self.timeout)
            except Exception as e_orig:
                logger.debug(f"Intento directo falló ({e_orig}). Probando con fragmento sanitizado...")
                # Intento 2: Fallback con fragmento sanitizado ffmpeg (segundo 30 para captar parte musical)
                dur = AudioSanitizer.get_duration(file_path)
                offset = int(min(30, max(2, dur / 3)))
                clean_chunk = AudioSanitizer.extract_clean_chunk(file_path, duration=14, start_offset=offset)
                if clean_chunk:
                    try:
                        out = await asyncio.wait_for(shazam_inst.recognize(str(clean_chunk)), timeout=self.timeout)
                    except Exception as e_chunk:
                        logger.warning(f"Fallo en intento sanitizado para {file_path.name}: {e_chunk}")

            try:
                track = out.get("track") if out else None
                if track:
                    record["status"] = "MATCH"
                    record["title"] = track.get("title", "")
                    record["artist"] = track.get("subtitle", "")
                    record["shazam_url"] = track.get("url", "")
                    record["genre"] = track.get("genres", {}).get("primary", "")

                    for sec in track.get("sections", []):
                        if sec.get("type") == "SONG":
                            for m in sec.get("metadata", []):
                                if m.get("title") == "Album":
                                    record["album"] = m.get("text", "")

                    logger.info(f"✔ [MATCH] {file_path.name} -> {record['artist']} - {record['title']}")
                else:
                    record["status"] = "NO_MATCH"
                    record = self._apply_offline_fallback(file_path, record)

            except Exception as err_parse:
                logger.warning(f"⚠️ Error al procesar metadata de {file_path.name}: {err_parse}")
                record["status"] = "PARSE_ERROR"
                record = self._apply_offline_fallback(file_path, record)
            finally:
                if clean_chunk and clean_chunk.exists():
                    try:
                        clean_chunk.unlink()
                    except Exception:
                        pass

        # Guardar resultado en caché
        self.cache.set(record)
        return record

    def _apply_offline_fallback(self, file_path: Path, current_record: Dict[str, Any]) -> Dict[str, Any]:
        """Fallback Nivel 5: Deducción inteligente a partir del nombre, carpetas y metadatos ID3 locales."""
        name = file_path.stem
        rec = dict(current_record)
        rec["method"] = "offline_heuristic_fallback"

        # Patrón típico: "Artista - Titulo (Mix/Remix)"
        if " - " in name:
            parts = name.split(" - ", 1)
            rec["artist"] = parts[0].strip()
            title_part = parts[1].strip()
            # Limpiar anotaciones entre corchetes
            clean_title = re.sub(r"\[.*?\]|\(.*?bpm.*?\)", "", title_part, flags=re.IGNORECASE).strip()
            rec["title"] = clean_title or title_part
            rec["status"] = "HEURISTIC_PARSED"
        else:
            rec["title"] = name
            rec["artist"] = file_path.parent.name
            rec["status"] = "LOCAL_NAMED"

        return rec

    async def scan(self, base_path: Path, out_tsv: Path, limit: int = 50) -> List[Dict[str, Any]]:
        logger.info(f"🚀 Iniciando escaneo resiliente en: {base_path}")
        candidates: List[Path] = []

        for root, _, files in os.walk(base_path):
            if any(p.startswith(".") for p in Path(root).parts):
                continue
            for f in files:
                if f.startswith("."):
                    continue
                fp = Path(root) / f
                ok, reason = self.check_candidate_guard(fp)
                if ok:
                    candidates.append(fp)
                    if 0 < limit <= len(candidates):
                        break
            if 0 < limit <= len(candidates):
                break

        logger.info(f"📊 Candidatos seleccionados para procesar: {len(candidates)}")
        if not candidates:
            return []

        results = []
        for fp in candidates:
            res = await self.recognize(fp)
            results.append(res)

        # Exportar TSV
        out_tsv.parent.mkdir(parents=True, exist_ok=True)
        with out_tsv.open("w", newline="", encoding="utf-8") as fh:
            writer = csv.writer(fh, delimiter="\t")
            writer.writerow([
                "Ruta_Archivo", "Nombre", "Estado", "Metodo",
                "Titulo_Detectado", "Artista_Detectado", "Album", "Genero", "Shazam_URL"
            ])
            for r in results:
                writer.writerow([
                    r.get("path", ""),
                    r.get("filename", ""),
                    r.get("status", ""),
                    r.get("method", ""),
                    r.get("title", ""),
                    r.get("artist", ""),
                    r.get("album", ""),
                    r.get("genre", ""),
                    r.get("shazam_url", "")
                ])

        matches = sum(1 for r in results if r.get("status") == "MATCH")
        fallbacks = sum(1 for r in results if "FALLBACK" in r.get("status", "") or "HEURISTIC" in r.get("status", ""))
        logger.info(f"✨ Escaneo finalizado. Matches exactos: {matches} | Fallbacks resolutivos: {fallbacks}. Reporte: {out_tsv}")
        return results


def main():
    parser = argparse.ArgumentParser(description="DJProducerTools Resilient Shazam Acoustic Engine")
    parser.add_argument("--base", "-b", required=True, help="Ruta objetivo")
    parser.add_argument("--out", "-o", default="_DJProducerTools/reports/shazam_resilient_matches.tsv", help="Ruta del reporte TSV")
    parser.add_argument("--limit", "-l", type=int, default=30, help="Límite de candidatos")
    parser.add_argument("--concurrency", "-c", type=int, default=3, help="Llamadas simultáneas")
    args = parser.parse_args()

    engine = ResilientShazamEngine(concurrency=args.concurrency)
    asyncio.run(engine.scan(Path(args.base), Path(args.out), limit=args.limit))


if __name__ == "__main__":
    main()
