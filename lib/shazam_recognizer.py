#!/usr/bin/env python3
"""
DJProducerTools - Módulo de Identificación Acústica con ShazamIO
Reconocimiento espectral de canciones, loops y muestras huérfanas mediante huella de audio.
Diseñado para operar en:
  1. Akai MPC Sample (MicroSD /Volumes/MPCSMPL) -> Identificación de samples y rips de vinilo.
  2. Serato DJ Pro (/Volumes/SanDisk SSD) -> Etiquetado de tracks sin ID3.
  3. Producción & Ableton (/Volumes/samsung PSSDT7) -> Trazabilidad y sample clearance.
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import json
import logging
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("djpt.shazam_recognizer")

# Extensiones de audio compatibles
AUDIO_EXTS = {".mp3", ".wav", ".flac", ".m4a", ".aif", ".aiff", ".ogg"}

# Términos de one-shots a excluir por defecto si son archivos pequeños (< 350 KB)
ONE_SHOT_KEYWORDS = {
    "kick", "kik", "snare", "snr", "clap", "clp", "hihat", "hh", "hat", 
    "rim", "rimshot", "snap", "tom", "cajon", "cowbell", "shaker"
}


class ShazamAudioRecognizer:
    def __init__(self, concurrency: int = 3, delay_between_calls: float = 0.5):
        self.concurrency = concurrency
        self.delay = delay_between_calls
        self.semaphore = asyncio.Semaphore(concurrency)
        self._shazam_instance = None

    def _get_shazam(self):
        if self._shazam_instance is None:
            try:
                from shazamio import Shazam  # type: ignore
                self._shazam_instance = Shazam()
            except ImportError:
                raise RuntimeError(
                    "El módulo 'shazamio' no está instalado. "
                    "Ejecuta con uv: uv run --with shazamio python3 ..."
                )
        return self._shazam_instance

    @staticmethod
    def is_candidate(file_path: Path, min_size_kb: int = 250) -> Tuple[bool, str]:
        """Evalúa si un archivo es apto para reconocimiento acústico (Zero Waste Filter)."""
        if not file_path.is_file():
            return False, "not_a_file"
        
        ext = file_path.suffix.lower()
        if ext not in AUDIO_EXTS:
            return False, f"unsupported_extension_{ext}"
            
        try:
            sz_kb = file_path.stat().st_size / 1024
        except Exception:
            return False, "stat_error"

        if sz_kb < min_size_kb:
            # Exclusión inteligente de one-shots diminutos
            name_lower = file_path.stem.lower()
            if any(kw in name_lower for kw in ONE_SHOT_KEYWORDS):
                return False, f"one_shot_too_short_{sz_kb:.1f}kb"
            # Si es menor a 150 KB generalmente no tiene suficientes frames
            if sz_kb < 150:
                return False, f"too_small_{sz_kb:.1f}kb"

        return True, "candidate"

    async def recognize_file(self, file_path: Path) -> Dict[str, Any]:
        """Envía el archivo a Shazam y formatea la respuesta de manera limpia."""
        shazam = self._get_shazam()
        result: Dict[str, Any] = {
            "path": str(file_path),
            "filename": file_path.name,
            "status": "UNRECOGNIZED",
            "title": "",
            "artist": "",
            "album": "",
            "genre": "",
            "shazam_url": "",
            "apple_music_id": "",
            "recognized_at": datetime.now(timezone.utc).isoformat()
        }

        async with self.semaphore:
            try:
                # Pausa controlada para respetar rate limits
                if self.delay > 0:
                    await asyncio.sleep(self.delay)

                out = await shazam.recognize(str(file_path))
                track = out.get("track")
                if track:
                    result["status"] = "MATCH"
                    result["title"] = track.get("title", "")
                    result["artist"] = track.get("subtitle", "")
                    result["shazam_url"] = track.get("url", "")
                    
                    # Extraer género si existe
                    genres = track.get("genres", {})
                    result["genre"] = genres.get("primary", "")
                    
                    # Extraer álbum de las secciones metadata
                    sections = track.get("sections", [])
                    for sec in sections:
                        if sec.get("type") == "SONG":
                            for meta in sec.get("metadata", []):
                                if meta.get("title") == "Album":
                                    result["album"] = meta.get("text", "")
                    
                    # Extraer Apple Music ID
                    providers = track.get("hub", {}).get("providers", [])
                    for prov in providers:
                        if prov.get("type") == "applemusic":
                            result["apple_music_id"] = prov.get("actions", [{}])[0].get("id", "")

                    logger.info(f"✔ [MATCH] {file_path.name} -> {result['artist']} - {result['title']}")
                else:
                    logger.debug(f"⚪ [NO MATCH] {file_path.name}")

            except Exception as e:
                result["status"] = "ERROR"
                result["error_message"] = str(e)
                logger.warning(f"⚠️ Error al procesar {file_path.name}: {e}")

        return result

    async def scan_collection(
        self,
        base_path: Path,
        out_tsv: Path,
        limit: int = 50,
        min_size_kb: int = 250
    ) -> List[Dict[str, Any]]:
        """Escanea una colección filtrando candidatos y generando reporte TSV."""
        logger.info(f"🔍 Escaneando candidatos en: {base_path}")
        candidates: List[Path] = []

        for root, _, files in os.walk(base_path):
            # Omitir carpetas ocultas y datos de proyectos temporales
            if any(part.startswith(".") for part in Path(root).parts):
                continue
            for f in files:
                if f.startswith("."):
                    continue
                fp = Path(root) / f
                ok, reason = self.is_candidate(fp, min_size_kb=min_size_kb)
                if ok:
                    candidates.append(fp)
                    if 0 < limit <= len(candidates):
                        break
            if 0 < limit <= len(candidates):
                break

        total_candidates = len(candidates)
        logger.info(f"📊 Total candidatos aptos seleccionados: {total_candidates}")

        if not candidates:
            return []

        tasks = [self.recognize_file(fp) for fp in candidates]
        results = await asyncio.gather(*tasks)

        # Guardar en TSV
        out_tsv.parent.mkdir(parents=True, exist_ok=True)
        with out_tsv.open("w", newline="", encoding="utf-8") as fh:
            writer = csv.writer(fh, delimiter="\t")
            writer.writerow([
                "Ruta_Archivo",
                "Nombre",
                "Estado",
                "Titulo_Original",
                "Artista_Original",
                "Album",
                "Genero",
                "Shazam_URL",
                "AppleMusic_ID",
                "Fecha_Reconocimiento"
            ])
            for r in results:
                writer.writerow([
                    r["path"],
                    r["filename"],
                    r["status"],
                    r["title"],
                    r["artist"],
                    r["album"],
                    r["genre"],
                    r["shazam_url"],
                    r["apple_music_id"],
                    r["recognized_at"]
                ])

        matches = sum(1 for r in results if r["status"] == "MATCH")
        logger.info(f"🎉 Proceso finalizado: {matches}/{total_candidates} identificados. Reporte: {out_tsv}")
        return results


def main():
    parser = argparse.ArgumentParser(description="DJProducerTools ShazamIO Acoustic Identifier")
    parser.add_argument("--base", "-b", required=True, help="Ruta base a escanear (SD, disco o carpeta)")
    parser.add_argument("--out", "-o", default="_DJProducerTools/reports/shazam_matches.tsv", help="Ruta del reporte TSV de salida")
    parser.add_argument("--limit", "-l", type=int, default=30, help="Límite máximo de candidatos a procesar (0 para todos)")
    parser.add_argument("--concurrency", "-c", type=int, default=3, help="Número de llamadas simultáneas (1-5)")
    parser.add_argument("--min-size", type=int, default=300, help="Tamaño mínimo en KB para considerar candidato")
    args = parser.parse_args()

    base_path = Path(args.base).expanduser().resolve()
    out_path = Path(args.out).expanduser().resolve()

    if not base_path.exists():
        logger.error(f"La ruta base no existe: {base_path}")
        sys.exit(1)

    recognizer = ShazamAudioRecognizer(concurrency=args.concurrency)
    asyncio.run(recognizer.scan_collection(base_path, out_path, limit=args.limit, min_size_kb=args.min_size))


if __name__ == "__main__":
    main()
