import argparse
import os


def build(base, out):
    print("Building tags plan...")
    with open(out, "w") as f:
        for root, dirs, files in os.walk(base):
            for file in files:
                if file.lower().endswith((".mp3", ".flac")):
                    f.write(f"{os.path.join(root, file)}\tUnknown\n")
    print(f"Plan saved to {out}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    build(args.base, args.out)
