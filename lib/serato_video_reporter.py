import argparse


def report(base, out):
    print("Generating Serato video report...")
    with open(out, "w") as f:
        f.write("File\tFormat\tStatus\n")
    print(f"Report saved to {out}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    report(args.base, args.out)
