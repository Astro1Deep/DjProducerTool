import argparse
import os


def build(base, out):
    print(f"Building relink helper for {base}...")
    with open(out, "w") as f:
        for root, dirs, files in os.walk(base):
            for file in files:
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, base)
                f.write(f"{rel_path}\t{full_path}\n")
    print(f"Saved to {out}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    build(args.base, args.out)
