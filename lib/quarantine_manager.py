import argparse
import os
import shutil


def list_files(quar_dir):
    print(f"Listing files in {quar_dir}:")
    for root, dirs, files in os.walk(quar_dir):
        for file in files:
            print(os.path.join(root, file))


def restore(quar_dir, base_path, dry_run=False):
    print("Restoring files...")
    restore_dir = os.path.join(base_path, "_RESTORED_FROM_QUARANTINE")
    for root, dirs, files in os.walk(quar_dir):
        for file in files:
            src = os.path.join(root, file)
            # Simple restore structure
            dest = os.path.join(restore_dir, file)
            if dry_run:
                print(f"[DRY] Restore {src} -> {dest}")
            else:
                if not os.path.exists(restore_dir):
                    os.makedirs(restore_dir)
                shutil.move(src, dest)
                print(f"[RESTORE] {src} -> {dest}")


def purge(quar_dir, dry_run=False):
    print("Purging quarantine...")
    if dry_run:
        print(f"[DRY] Would delete {quar_dir}")
    else:
        shutil.rmtree(quar_dir)
        os.makedirs(quar_dir)
        print("Quarantine purged.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command")

    p_list = subparsers.add_parser("list")
    p_list.add_argument("--quar-dir")

    p_restore = subparsers.add_parser("restore")
    p_restore.add_argument("--quar-dir")
    p_restore.add_argument("--base-path")
    p_restore.add_argument("--dry-run", action="store_true")

    p_purge = subparsers.add_parser("purge")
    p_purge.add_argument("--quar-dir")
    p_purge.add_argument("--dry-run", action="store_true")

    args = parser.parse_args()

    if args.command == "list":
        list_files(args.quar_dir)
    elif args.command == "restore":
        restore(args.quar_dir, args.base_path, args.dry_run)
    elif args.command == "purge":
        purge(args.quar_dir, args.dry_run)
