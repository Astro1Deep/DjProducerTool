import argparse
import os


def find_libs(base):
    print(f"Searching DJ libs in {base}...")
    targets = ["_Serato_", "Traktor", "Rekordbox", "Ableton"]
    for root, dirs, files in os.walk(base):
        for d in dirs:
            if any(t in d for t in targets):
                print(f"Found: {os.path.join(root, d)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    args = parser.parse_args()
    find_libs(args.base)
