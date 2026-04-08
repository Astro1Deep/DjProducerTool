#!/usr/bin/env python3
"""
DJProducerTools - Advanced Sample Recovery System
Sistema avanzado de recuperación de samples para Ableton Live
"""

import sys
import json
import hashlib
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Any
from dataclasses import dataclass, field
from datetime import datetime
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import difflib

# Importar el analizador principal (opcional). Si no existe, definimos
# clases fallback para no romper import ni tests.
try:
    from ableton_advanced_analyzer import AbletonAnalyzer, SampleInfo  # type: ignore
    ABLETON_ANALYZER_AVAILABLE = True
except ImportError:
    ABLETON_ANALYZER_AVAILABLE = False

    @dataclass
    class SampleInfo:  # minimal fallback model
        sample_path: str
        hash: str = ""
        size: int = 0

    class AbletonAnalyzer:  # pragma: no cover - fallback shim
        def __init__(self, *args, **kwargs):
            pass

        def analyze(self, *args, **kwargs):
            raise RuntimeError("AbletonAnalyzer dependency not available")


@dataclass
class SampleDatabase:
    """Base de datos de samples para recuperación"""

    hashes: Dict[str, Any] = field(default_factory=dict)
    files: Dict[str, Any] = field(default_factory=dict)
    sample_paths: List[str] = field(default_factory=list)
    hash_cache: Dict[str, str] = field(default_factory=dict)


@dataclass
class RecoveryCandidate:
    """Candidato para recuperación de sample"""

    file_path: str
    sample_path: str
    hash_match: float
    name_similarity: float
    path_similarity: float
    size_match: float
    confidence: float


class AdvancedSampleRecovery:
    """Sistema avanzado de recuperación de samples"""

    def __init__(self, analyzer: Optional[AbletonAnalyzer] = None, base_path: Optional[str] = None):
        self.analyzer = analyzer
        self.database = SampleDatabase()
        self.confidence_threshold = 0.3
        self.max_candidates = 10
        self.base_path = Path(base_path) if base_path else Path.cwd()

    def build_sample_database(self, search_paths: Optional[Any] = None) -> Dict[str, Any]:
        """Construye la base de datos de samples"""
        if search_paths is None:
            search_paths = []
        elif isinstance(search_paths, (str, Path)):
            search_paths = [search_paths]

        print("🔍 Construyendo base de datos de samples...")

        # Buscar archivos de audio
        audio_extensions = {".wav", ".mp3", ".flac", ".m4a", ".aac", ".ogg"}
        all_samples = []

        for search_path in search_paths:
            path = Path(search_path)
            if path.exists():
                for ext in audio_extensions:
                    all_samples.extend(path.rglob(f"*{ext}"))

        # Procesar samples en paralelo
        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = []
            for sample_path in all_samples:
                future = executor.submit(self._process_sample, sample_path)
                futures.append(future)

            for future in as_completed(futures):
                try:
                    result = future.result()
                    if result:
                        self.database.files[result["file"]] = result
                        self.database.hashes[result["hash"]] = result
                        self.database.sample_paths.append(result["file"])
                except Exception as e:
                    print(f"Error procesando sample: {e}")

        print(f"✅ Base de datos construida: {len(self.database.files)} samples")
        return {
            "total_samples": len(self.database.files),
            "search_paths": search_paths,
            "timestamp": datetime.now().isoformat(),
        }

    def _process_sample(self, sample_path: Path) -> Optional[Dict[str, Any]]:
        """Procesa un sample individual"""
        try:
            file_path = str(sample_path)
            file_hash = self._calculate_file_hash(file_path)
            file_size = sample_path.stat().st_size

            return {
                "file": file_path,
                "hash": file_hash,
                "size": file_size,
                "name": sample_path.name,
                "path": str(sample_path.parent),
            }
        except Exception:
            return None

    def _calculate_file_hash(self, file_path: str) -> str:
        """Calcula hash SHA-256 de un archivo"""
        hash_obj = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_obj.update(chunk)
        return hash_obj.hexdigest()

    def find_recovery_candidates(self, missing_sample: SampleInfo) -> List[RecoveryCandidate]:
        """Busca candidatos para recuperación"""
        candidates: List[RecoveryCandidate] = []

        # 1. Búsqueda por hash exacto
        hash_candidates = self._find_hash_matches(missing_sample)
        candidates.extend(hash_candidates)

        # 2. Búsqueda por nombre similar
        name_candidates = self._find_fuzzy_name_matches(missing_sample)
        candidates.extend(name_candidates)

        # 3. Búsqueda por similitud de ruta
        path_candidates = self._find_path_similarity_matches(missing_sample)
        candidates.extend(path_candidates)

        # 4. Búsqueda por tamaño
        size_candidates = self._find_size_matches(missing_sample)
        candidates.extend(size_candidates)

        # Ordenar por confianza y eliminar duplicados
        unique_candidates = {}
        for candidate in candidates:
            key = candidate.file_path
            if key not in unique_candidates or candidate.confidence > unique_candidates[key].confidence:
                unique_candidates[key] = candidate

        sorted_candidates = sorted(
            unique_candidates.values(),
            key=lambda x: x.confidence,
            reverse=True,
        )

        return sorted_candidates[: self.max_candidates]

    def _find_hash_matches(self, missing_sample: SampleInfo) -> List[RecoveryCandidate]:
        """Busca coincidencias exactas de hash"""
        candidates: List[RecoveryCandidate] = []

        if missing_sample.hash in self.database.hashes:
            file_info = self.database.hashes[missing_sample.hash]
            candidate = RecoveryCandidate(
                file_path=file_info["file"],
                sample_path=missing_sample.sample_path,
                hash_match=1.0,
                name_similarity=0.0,
                path_similarity=0.0,
                size_match=1.0,
                confidence=1.0,
            )
            candidates.append(candidate)

        return candidates

    def _find_fuzzy_name_matches(self, missing_sample: SampleInfo) -> List[RecoveryCandidate]:
        """Busca coincidencias por nombre similar"""
        candidates: List[RecoveryCandidate] = []
        missing_name = Path(missing_sample.sample_path).stem.lower()

        for file_path, file_info in self.database.files.items():
            file_name = Path(file_path).stem.lower()
            similarity = difflib.SequenceMatcher(None, missing_name, file_name).ratio()

            if similarity > 0.5:
                candidate = RecoveryCandidate(
                    file_path=file_path,
                    sample_path=missing_sample.sample_path,
                    hash_match=0.0,
                    name_similarity=similarity,
                    path_similarity=0.0,
                    size_match=0.0,
                    confidence=similarity * 0.6,
                )
                candidates.append(candidate)

        return candidates

    def _find_path_similarity_matches(self, missing_sample: SampleInfo) -> List[RecoveryCandidate]:
        """Busca coincidencias por similitud de ruta"""
        candidates: List[RecoveryCandidate] = []
        missing_parts = Path(missing_sample.sample_path).parts

        for file_path, file_info in self.database.files.items():
            file_parts = Path(file_path).parts
            similarity = self._calculate_path_similarity(missing_parts, file_parts)

            if similarity > 0.3:
                candidate = RecoveryCandidate(
                    file_path=file_path,
                    sample_path=missing_sample.sample_path,
                    hash_match=0.0,
                    name_similarity=0.0,
                    path_similarity=similarity,
                    size_match=0.0,
                    confidence=similarity * 0.4,
                )
                candidates.append(candidate)

        return candidates

    def _find_size_matches(self, missing_sample: SampleInfo) -> List[RecoveryCandidate]:
        """Busca coincidencias por tamaño similar"""
        candidates: List[RecoveryCandidate] = []

        if not hasattr(missing_sample, "size"):
            return candidates

        for file_path, file_info in self.database.files.items():
            size_diff = abs(file_info["size"] - missing_sample.size)
            size_similarity = 1.0 - (size_diff / max(file_info["size"], missing_sample.size))

            if size_similarity > 0.8:
                candidate = RecoveryCandidate(
                    file_path=file_path,
                    sample_path=missing_sample.sample_path,
                    hash_match=0.0,
                    name_similarity=0.0,
                    path_similarity=0.0,
                    size_match=size_similarity,
                    confidence=size_similarity * 0.3,
                )
                candidates.append(candidate)

        return candidates

    def _calculate_path_similarity(self, path1: Tuple, path2: Tuple) -> float:
        """Calcula similitud entre dos rutas"""
        if not path1 or not path2:
            return 0.0

        # Similitud de partes comunes
        common_parts = set(path1) & set(path2)
        total_parts = set(path1) | set(path2)

        if not total_parts:
            return 0.0

        return len(common_parts) / len(total_parts)

    def generate_recovery_plan(self, missing_samples: List[SampleInfo]) -> Dict[str, Any]:
        """Genera planes de recuperación para samples faltantes"""
        recovery_plans = {}

        for i, missing_sample in enumerate(missing_samples):
            candidates = self.find_recovery_candidates(missing_sample)

            if candidates:
                best_candidate = candidates[0]
                action = self._determine_recovery_action(best_candidate)

                recovery_plans[missing_sample.sample_path] = {
                    "missing_sample": missing_sample,
                    "candidates": candidates,
                    "best_candidate": best_candidate,
                    "recommended_action": action,
                    "confidence": best_candidate.confidence,
                }
            else:
                recovery_plans[missing_sample.sample_path] = {
                    "missing_sample": missing_sample,
                    "candidates": [],
                    "best_candidate": None,
                    "recommended_action": "manual_search",
                    "confidence": 0.0,
                }

        return recovery_plans

    def _determine_recovery_action(self, candidate: RecoveryCandidate) -> str:
        """Determina la acción de recuperación recomendada"""
        if candidate.confidence >= 0.9:
            return "copy"
        elif candidate.confidence >= 0.7:
            return "symlink"
        elif candidate.confidence >= 0.5:
            return "manual_review"
        else:
            return "manual_search"

    def execute_recovery_plan(self, recovery_plans: Any, dry_run: bool = False) -> Dict[str, Any]:
        """Ejecuta los planes de recuperación"""
        if isinstance(recovery_plans, list):
            recovery_plans = {str(i): plan for i, plan in enumerate(recovery_plans)}
        results: Dict[str, Any] = {}

        for _, plan in recovery_plans.items():
            target = plan.get("path") or str(self.base_path / "_Recovered_Samples" / plan["name"])
            target_path = Path(target)
            target_path.parent.mkdir(parents=True, exist_ok=True)

            source_path = None
            if plan.get("hash"):
                source_path = self.database.hashes.get(plan["hash"], {}).get("file")
            if not source_path:
                for info in self.database.files.values():
                    if Path(info["file"]).name == plan["name"]:
                        source_path = info["file"]
                        break

            if source_path and Path(source_path).exists():
                target_path.write_bytes(Path(source_path).read_bytes())
                results[str(target_path)] = {"status": "recovered", "source": source_path}
            else:
                results[str(target_path)] = {"status": "failed", "reason": "source_missing"}

        recovered = sum(1 for r in results.values() if r["status"] == "recovered")
        failed = sum(1 for r in results.values() if r["status"] == "failed")

        return {
            "recovered": recovered,
            "failed": failed,
            "details": results,
            "timestamp": datetime.now().isoformat(),
        }

    def _execute_action(self, action: str, source: str, target: str) -> bool:
        """Ejecuta una acción de recuperación"""
        try:
            target_path = Path(target)
            target_path.parent.mkdir(parents=True, exist_ok=True)

            if action == "copy":
                import shutil

                shutil.copy2(source, target)
                return True
            elif action == "symlink":
                if not target_path.exists():
                    target_path.symlink_to(Path(source))
                return True
            else:
                return False
        except Exception:
            return False

    def get_recovery_statistics(self, recovery_plans: Dict[str, Any]) -> Dict[str, Any]:
        """Obtiene estadísticas de recuperación"""
        total_samples = len(recovery_plans)
        high_confidence = sum(1 for plan in recovery_plans.values() if plan["confidence"] >= 0.7)
        medium_confidence = sum(1 for plan in recovery_plans.values() if 0.5 <= plan["confidence"] < 0.7)
        low_confidence = sum(1 for plan in recovery_plans.values() if plan["confidence"] < 0.5)

        confidence_stats: Dict[str, Any] = {
            "total_samples": total_samples,
            "high_confidence": high_confidence,
            "medium_confidence": medium_confidence,
            "low_confidence": low_confidence,
            "average_confidence": sum(plan["confidence"] for plan in recovery_plans.values()) / total_samples
            if total_samples > 0
            else 0,
        }

        return confidence_stats


def main():
    """Función principal"""
    parser = argparse.ArgumentParser(description="Sistema avanzado de recuperación de samples")
    parser.add_argument(
        "--build-database",
        action="store_true",
        help="Construir base de datos de samples",
    )
    parser.add_argument("--search-paths", nargs="+", help="Rutas de búsqueda para samples")
    parser.add_argument("--project", help="Proyecto Ableton para analizar")
    parser.add_argument("--dry-run", action="store_true", help="Ejecutar en modo simulación")
    parser.add_argument("--output", help="Archivo de salida para resultados")

    args = parser.parse_args()

    recovery = AdvancedSampleRecovery()

    if args.build_database:
        database_info = recovery.build_sample_database(args.search_paths)
        print(f"Base de datos construida: {database_info}")

    if args.project:
        # Analizar proyecto y encontrar samples faltantes
        analyzer = AbletonAnalyzer(args.project)
        missing_samples = analyzer.find_missing_samples()

        if missing_samples:
            print(f"Se encontraron {len(missing_samples)} samples faltantes")

            # Generar planes de recuperación
            recovery_plans = recovery.generate_recovery_plan(missing_samples)

            # Ejecutar recuperación
            results = recovery.execute_recovery_plan(recovery_plans, args.dry_run)

            # Mostrar estadísticas
            stats = recovery.get_recovery_statistics(recovery_plans)
            print(f"Estadísticas de recuperación: {stats}")

            # Guardar resultados
            if args.output:
                with open(args.output, "w") as f:
                    json.dump(
                        {
                            "project": args.project,
                            "missing_samples": len(missing_samples),
                            "recovery_plans": recovery_plans,
                            "recovery_results": results,
                            "statistics": stats,
                        },
                        f,
                        indent=2,
                    )
                print(f"Resultados guardados en: {args.output}")
        else:
            print("No se encontraron samples faltantes")


if __name__ == "__main__":
    main()
