import argparse
import os
import shutil


def _is_within_base(path, base_path):
    """Return True when path is under base_path."""
    try:
        return os.path.commonpath([os.path.realpath(path), os.path.realpath(base_path)]) == os.path.realpath(base_path)
    except ValueError:
        return False


def execute(plan, quar_dir, dry_run=False):
    print(f"Executing quarantine plan... (Dry run: {dry_run})")
    base_path = os.environ.get("BASE_PATH", "")
    allow_outside = os.environ.get("DJPT_ALLOW_OUTSIDE", "0") == "1"

    if not os.path.exists(quar_dir):
        os.makedirs(quar_dir)

    with open(plan, "r") as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) >= 3:
                h, action, src = parts[0], parts[1], parts[2]
                if action == "QUARANTINE":
                    if base_path and not allow_outside and not _is_within_base(src, base_path):
                        print(f"[SKIP] Outside BASE_PATH: {src}")
                        continue

                    dest_dir = os.path.join(quar_dir, h)
                    dest_file = os.path.join(dest_dir, os.path.basename(src))
                    if dry_run:
                        print(f"[DRY] Move {src} -> {dest_file}")
                    else:
                        if not os.path.exists(dest_dir):
                            os.makedirs(dest_dir)
                        try:
                            shutil.move(src, dest_file)
                            print(f"[MOVE] {src} -> {dest_file}")
                        except Exception as e:
                            print(f"[ERR] {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan", required=True)
    parser.add_argument("--quar-dir", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    execute(args.plan, args.quar_dir, args.dry_run)
