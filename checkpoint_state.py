import argparse
import shutil
import subprocess
from datetime import datetime
from pathlib import Path


def df_summary(targets: list[Path]) -> list[str]:
    rows = []
    for target in targets:
        if target.exists():
            try:
                result = subprocess.run(["df", "-h", str(target)], capture_output=True, text=True, check=True)
                rows.append(result.stdout.strip())
            except subprocess.CalledProcessError as exc:
                rows.append(f"df failed for {target}: {exc.stderr.strip()}")
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description="Save checkpoint of key files + disk state.")
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--state-dir", type=Path, default=None)
    parser.add_argument("--desc", type=str, default="manual checkpoint")
    parser.add_argument("--df-targets", nargs="*", type=Path, default=[])
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

    log_file = dest / "checkpoint.log"
    with log_file.open("w", encoding="utf-8") as handle:
        handle.write(f"{datetime.now().isoformat()} - {args.desc}\n")
        for candidate in files_to_copy:
            if candidate.exists():
                target = dest / candidate.name
                shutil.copy2(candidate, target)
                handle.write(f"copied {candidate} -> {target}\n")

        handle.write("df summary:\n")
        for row in df_summary([base] + args.df_targets):
            handle.write(row + "\n")

    print(f"[CHECKPOINT] saved to {dest}")


if __name__ == "__main__":
    main()
