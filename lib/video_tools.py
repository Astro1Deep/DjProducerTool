import argparse
import os


def inventory(base, out):
    print("Generating video inventory...")
    with open(out, "w") as f:
        for root, dirs, files in os.walk(base):
            for file in files:
                if file.lower().endswith((".mp4", ".mov", ".avi")):
                    f.write(f"{os.path.join(root, file)}\n")
    print(f"Inventory saved to {out}")


def transcode_plan(base, out, preset, codec):
    print(f"Generating transcode plan ({preset}, {codec})...")
    with open(out, "w") as f:
        f.write("File\tAction\tCommand\n")
    print(f"Plan saved to {out}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command")

    p_inv = subparsers.add_parser("inventory")
    p_inv.add_argument("base")
    p_inv.add_argument("out")

    p_plan = subparsers.add_parser("transcode_plan")
    p_plan.add_argument("base")
    p_plan.add_argument("out")
    p_plan.add_argument("preset")
    p_plan.add_argument("codec")

    args = parser.parse_args()

    if args.command == "inventory":
        inventory(args.base, args.out)
    elif args.command == "transcode_plan":
        transcode_plan(args.base, args.out, args.preset, args.codec)
