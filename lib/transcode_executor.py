import argparse


def execute(plan, dry_run):
    print(f"Executing transcode plan (Dry run: {dry_run})...")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    execute(args.plan, args.dry_run)
