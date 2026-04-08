import csv
import json
import logging
import os
import shutil
import time
from pathlib import Path

from peewee import fn

try:
    from .config import Config
    from .db import FileIndex, db
except ImportError:
    from core.config import Config  # type: ignore
    from core.db import FileIndex, db  # type: ignore


class Deduper:
    def __init__(self):
        self.db = db

    def find_dupes(self):
        return (
            FileIndex.select(FileIndex.sha256, fn.COUNT(FileIndex.id).alias("count"))
            .where(FileIndex.sha256.is_null(False))
            .group_by(FileIndex.sha256)
            .having(fn.COUNT(FileIndex.id) > 1)
        )

    def generate_plan(self, output_name="dupes_plan.tsv"):
        plan_dir = Config.STATE_DIR / "plans"
        plan_dir.mkdir(parents=True, exist_ok=True)
        plan_path = plan_dir / output_name
        tmp_path = plan_path.with_suffix(".tmp")

        dupes_query = self.find_dupes()

        count = 0
        stale_paths = 0
        missing_files = 0

        with open(tmp_path, "w", newline="") as handle:
            writer = csv.writer(handle, delimiter="\t")
            writer.writerow(["hash", "action", "path", "reason", "mtime", "exists"])

            for dupe_row in dupes_query:
                files = (
                    FileIndex.select()
                    .where(FileIndex.sha256 == dupe_row.sha256)
                    .order_by(FileIndex.mtime.desc())
                )
                files = list(files)
                if not files:
                    continue

                valid_files = []
                for file_record in files:
                    file_path = Path(file_record.full_path)
                    if file_path.exists():
                        actual_mtime = file_path.stat().st_mtime
                        db_mtime = file_record.mtime
                        if abs(actual_mtime - db_mtime) > 1:
                            stale_paths += 1
                            logging.warning(
                                "Stale path detected: %s (DB mtime: %s, actual: %s)",
                                file_path,
                                db_mtime,
                                actual_mtime,
                            )
                        valid_files.append(file_record)
                    else:
                        missing_files += 1
                        logging.warning("Missing file in plan: %s", file_path)

                if not valid_files:
                    continue

                valid_files.sort(key=lambda row: (-row.mtime, len(row.full_path)))
                keep = valid_files[0]
                writer.writerow(
                    [
                        keep.sha256,
                        "KEEP",
                        keep.full_path,
                        "Newest mtime (primary), shortest path (secondary)",
                        keep.mtime,
                        "True",
                    ]
                )

                for remove in valid_files[1:]:
                    writer.writerow([remove.sha256, "QUARANTINE", remove.full_path, "Duplicate", remove.mtime, "True"])
                count += 1

        os.replace(tmp_path, plan_path)

        if stale_paths > 0 or missing_files > 0:
            logging.info(
                "Plan generated with %s stale paths and %s missing files",
                stale_paths,
                missing_files,
            )

        json_path = plan_path.with_suffix(".json")
        try:
            plan_json = []
            with open(plan_path, newline="") as handle:
                reader = csv.DictReader(handle, delimiter="\t")
                for row in reader:
                    plan_json.append(row)
            json_tmp = json_path.with_suffix(".json.tmp")
            with open(json_tmp, "w", encoding="utf-8") as handle:
                json.dump(plan_json, handle, ensure_ascii=False, indent=2)
            os.replace(json_tmp, json_path)
        except Exception:
            pass

        return plan_path, count, {"stale_paths": stale_paths, "missing_files": missing_files}

    def apply_plan(self, plan_file: Path = None, dry_run: bool = True):
        plan_file = Path(plan_file or (Config.STATE_DIR / "plans" / "dupes_plan.tsv"))
        if not plan_file.exists():
            raise FileNotFoundError(f"Plan file not found: {plan_file}")

        quarantine_root = Config.STATE_DIR / "quarantine" / time.strftime("%Y%m%d_%H%M%S")
        quarantine_root.mkdir(parents=True, exist_ok=True)

        moves = []
        skipped_missing = 0

        with open(plan_file, newline="") as handle:
            reader = csv.DictReader(handle, delimiter="\t")
            for row in reader:
                if row.get("action") == "QUARANTINE":
                    src = Path(row["path"]).expanduser()
                    if not src.exists():
                        skipped_missing += 1
                        logging.warning("Skipping missing file in apply: %s", src)
                        continue
                    dst = quarantine_root / src.name
                    idx = 1
                    while dst.exists():
                        dst = quarantine_root / f"{src.stem}_{idx}{src.suffix}"
                        idx += 1
                    moves.append((src, dst))

        if skipped_missing > 0:
            logging.info("Skipped %s missing files during apply", skipped_missing)

        with db.atomic():
            for src, dst in moves:
                if dry_run:
                    continue
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(src), str(dst))

        return {
            "quarantine_dir": quarantine_root,
            "moved": 0 if dry_run else len(moves),
            "planned": len(moves),
            "skipped_missing": skipped_missing,
        }
