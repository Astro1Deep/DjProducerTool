import argparse
import json


def build(input_file, out_tsv, out_json):
    print(f"Building dupes plan from {input_file}")
    hashes = {}
    try:
        with open(input_file, "r") as f:
            for line in f:
                parts = line.strip().split("\t")
                if len(parts) >= 3:
                    h, _, path = parts[0], parts[1], parts[2]
                    if h not in hashes:
                        hashes[h] = []
                    hashes[h].append(path)
    except FileNotFoundError:
        print("Hash index not found.")
        return

    entries = []
    with open(out_tsv, "w") as f:
        for h, paths in hashes.items():
            if len(paths) > 1:
                # Keep first, quarantine rest
                f.write(f"{h}\tKEEP\t{paths[0]}\n")
                entries.append({"hash": h, "action": "KEEP", "path": paths[0]})
                for p in paths[1:]:
                    f.write(f"{h}\tQUARANTINE\t{p}\n")
                    entries.append({"hash": h, "action": "QUARANTINE", "path": p})

    with open(out_json, "w") as f:
        json.dump({"type": "dupes_plan", "entries": entries}, f, indent=2)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--out-tsv", required=True)
    parser.add_argument("--out-json", required=True)
    args = parser.parse_args()
    build(args.input, args.out_tsv, args.out_json)
