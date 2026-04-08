import argparse
import os


def classify(base, out):
    print("Classifying samples...")
    with open(out, "w") as f:
        for root, dirs, files in os.walk(base):
            for file in files:
                lower = file.lower()
                type_ = "OTHER"
                if "kick" in lower:
                    type_ = "KICK"
                elif "snare" in lower:
                    type_ = "SNARE"
                elif "hat" in lower:
                    type_ = "HAT"
                elif "bass" in lower:
                    type_ = "BASS"

                if type_ != "OTHER":
                    f.write(f"{os.path.join(root, file)}\t{type_}\n")
    print(f"Plan saved to {out}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    classify(args.base, args.out)
