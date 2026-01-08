# coding: utf-8
import argparse
import shutil
import subprocess
from datetime import datetime
from pathlib import Path


def df_summary(targets):
    rows = []
    for t in targets:
        result = subprocess.run(["df", "-h", str(t)], capture_output=True, text=True, check=True)
        rows.append(result.stdout.strip())
    return rows


def main():
    parser = argparse.ArgumentParser(description="Save checkpoint of key files + disk state.")
    parser.add_argument(
        "--base",
        type=Path,
        default=Path("/Users/ivan/Desktop/0 SERATO BIBLIOTECA"),
        help="Library base path.",
    )
    parser.add_argument(
        "--state-dir",
        type=Path,
        default=None,
        help="Optional override for _DJProducerTools state dir.",
    )
    parser.add_argument(
        "--desc",
        type=str,
        default="manual checkpoint",
        help="Short description of this checkpoint.",
    )

    args = parser.parse_args()
    base = args.base
    state_dir = args.state_dir or base / "_DJProducerTools"
    chk_root = state_dir / "checkpoints"
    chk_root.mkdir(exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    dest = chk_root / timestamp
    dest.mkdir()
    files_to_copy = [
        state_dir / "reports" / "hash_index.tsv",
        state_dir / "reports" / "general_hash_dupes_report.txt",
        state_dir / "plans" / "general_hash_dupes_plan.tsv",
    ]
    if (state_dir / "plans" / "consolidation_plan.tsv").exists():
        files_to_copy.append(state_dir / "plans" / "consolidation_plan.tsv")
    if (state_dir / "external_hashes.tsv").exists():
        files_to_copy.append(state_dir / "external_hashes.tsv")
    log = dest / "checkpoint.log"
    with log.open("w", encoding="utf-8") as fh:
        fh.write(f"{datetime.now().isoformat()} - {args.desc}\n")
        for candidate in files_to_copy:
            if candidate.exists():
                target = dest / candidate.name
                shutil.copy2(candidate, target)
                fh.write(f"copied {candidate} -> {target}\n")
        fh.write("df summary:\n")
        for line in df_summary([base, Path("/Volumes/SanDisk SSD"), Path("/Volumes/samsung PSSDT7")]):
            fh.write(line + "\n")

    print(f"[CHECKPOINT] saved to {dest}")


if __name__ == "__main__":
    main()
