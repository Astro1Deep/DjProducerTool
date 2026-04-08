import argparse
import os
import re
import unicodedata


def normalize_filename(filename):
    """Enhanced filename normalization with proper special character handling"""
    # First, normalize Unicode characters (NFD form to separate diacritics)
    normalized = unicodedata.normalize("NFD", filename)

    # Remove diacritical marks (accents, etc.) but keep base letters
    normalized = "".join(char for char in normalized if not unicodedata.combining(char))

    # Convert to NFC form for consistent representation
    normalized = unicodedata.normalize("NFC", normalized)

    # Replace problematic filesystem characters with safe alternatives
    # Keep letters (including international), numbers, dots, hyphens, underscores
    # Replace specific problematic characters
    replacements = {
        "/": "_",
        "\\": "_",
        ":": "_",
        "*": "_",
        "?": "_",
        '"': "_",
        "<": "_",
        ">": "_",
        "|": "_",
        "\n": "_",
        "\r": "_",
        "\t": "_",
    }

    for old, new in replacements.items():
        normalized = normalized.replace(old, new)

    # Remove any remaining control characters
    normalized = "".join(char for char in normalized if not unicodedata.category(char).startswith("C"))

    # Remove consecutive dots/hyphens/underscores
    normalized = re.sub(r"[._-]{2,}", "_", normalized)

    # Remove leading/trailing dots/hyphens/underscores
    normalized = normalized.strip("._-")

    # Ensure not empty after normalization
    if not normalized or normalized.isspace():
        normalized = "unnamed_file"

    return normalized


def normalize(base, out):
    print("Generating normalization plan...")
    with open(out, "w") as f:
        f.write("original\tnormalized\taction\n")
        for root, dirs, files in os.walk(base):
            for file in files:
                new_name = normalize_filename(file)
                if new_name != file:
                    rel_path = os.path.relpath(os.path.join(root, file), base)
                    f.write(f"{rel_path}\t{new_name}\tRENAME\n")
    print(f"Plan saved to {out}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    normalize(args.base, args.out)
