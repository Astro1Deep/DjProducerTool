import argparse
import os


def scan(base, out):
    print(f"Intelligent scan of {base}...")
    with open(out, "w") as f:
        for root, dirs, files in os.walk(base):
            for file in files:
                f.write(f"{os.path.join(root, file)}\n")
    print(f"Scan saved to {out}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    scan(args.base, args.out)
