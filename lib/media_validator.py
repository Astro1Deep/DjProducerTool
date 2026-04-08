import argparse
import os
import subprocess


def validate(base, out):
    print(f"Validating media in {base}...")
    with open(out, "w") as f:
        for root, dirs, files in os.walk(base):
            for file in files:
                if file.lower().endswith((".mp3", ".wav", ".flac", ".m4a", ".mp4", ".mov")):
                    path = os.path.join(root, file)
                    # Simple check using ffprobe if available
                    try:
                        subprocess.run(
                            [
                                "ffprobe",
                                "-v",
                                "error",
                                "-show_entries",
                                "format=duration",
                                path,
                            ],
                            check=True,
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                        )
                    except (subprocess.CalledProcessError, FileNotFoundError):
                        f.write(f"{path}\tCORRUPT\n")
                        print(f"Corrupt: {path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    validate(args.base, args.out)
