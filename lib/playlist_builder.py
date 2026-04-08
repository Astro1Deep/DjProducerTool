import argparse
import os


def build(base):
    print(f"Building playlists in {base}...")
    for root, dirs, files in os.walk(base):
        audio_files = [f for f in files if f.lower().endswith((".mp3", ".wav", ".flac", ".m4a"))]
        if audio_files:
            pl_path = os.path.join(root, "playlist.m3u8")
            with open(pl_path, "w") as f:
                for af in audio_files:
                    f.write(f"{af}\n")
            print(f"Created {pl_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    args = parser.parse_args()
    build(args.base)
