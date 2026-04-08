import argparse


def lufs(base, out, target):
    print(f"Analyzing LUFS in {base} (Target: {target})...")
    with open(out, "w") as f:
        f.write("File\tLUFS\n")


def cues(base, out):
    print(f"Detecting cues in {base}...")
    with open(out, "w") as f:
        f.write("File\tCue\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command")

    p_lufs = subparsers.add_parser("lufs")
    p_lufs.add_argument("--base")
    p_lufs.add_argument("--out")
    p_lufs.add_argument("--target")

    p_cues = subparsers.add_parser("cues")
    p_cues.add_argument("--base")
    p_cues.add_argument("--out")

    args = parser.parse_args()

    if args.command == "lufs":
        lufs(args.base, args.out, args.target)
    elif args.command == "cues":
        cues(args.base, args.out)
