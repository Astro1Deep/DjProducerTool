# coding: utf-8
import argparse
import shutil
import subprocess
from datetime import datetime
from pathlib import Path


def df_summary(targets: list[Path]) -> list[str]:
    """Runs 'df -h' on a list of target paths and returns the output."""
    rows = []
    for t in targets:
        if t.exists():
            try:
                result = subprocess.run(["df", "-h", str(t)], capture_output=True, text=True, check=True)
                rows.append(result.stdout.strip())
            except subprocess.CalledProcessError as e:
                rows.append(f"df failed for {t}: {e.stderr.strip()}")
    return rows


def main():
    parser = argparse.ArgumentParser(description="Save checkpoint of key files + disk state.")
    parser.add_argument(
        "--base", type=Path, required=True, help="Library base path (e.g., where _Serato_ is)."
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
    parser.add_argument(
        "--df-targets",
        nargs='*',  # 0 or more arguments
        type=Path,
        default=[],
        help="Optional list of extra paths to include in the 'df' summary.",
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

        # Build df targets: always include base, then add optional ones.
        df_targets = [base] + args.df_targets

        fh.write("df summary:\n")
        for line in df_summary(df_targets):
            fh.write(line + "\n")

    print(f"[CHECKPOINT] saved to {dest}")


if __name__ == "__main__":
    main()
