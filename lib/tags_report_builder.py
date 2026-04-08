import argparse


def build(plan, out):
    print("Building tags report...")
    with open(out, "w") as f:
        f.write("Tag\tCount\n")
    print(f"Report saved to {out}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    build(args.plan, args.out)
