import shutil


def diag():
    tools = ["ffmpeg", "ffprobe", "rsync", "python3", "pip"]
    print("Tools Diagnostic:")
    for t in tools:
        path = shutil.which(t)
        status = "OK" if path else "MISSING"
        print(f"  {t}: {status} ({path})")


if __name__ == "__main__":
    diag()
