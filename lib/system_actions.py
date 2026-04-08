import argparse


def status(**kwargs):
    print("System Status (Python Module):")
    for k, v in kwargs.items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command")

    p_status = subparsers.add_parser("status")
    p_status.add_argument("--base-path")
    p_status.add_argument("--state-dir")
    p_status.add_argument("--reports-dir")
    p_status.add_argument("--plans-dir")
    p_status.add_argument("--quar-dir")
    p_status.add_argument("--venv-dir")
    p_status.add_argument("--shared-corpus-dir")
    p_status.add_argument("--extra-source-roots")
    p_status.add_argument("--safe-mode")
    p_status.add_argument("--dj-safe-lock")
    p_status.add_argument("--dryrun-force")

    args = parser.parse_args()

    if args.command == "status":
        status(**vars(args))
