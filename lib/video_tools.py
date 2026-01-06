#!/usr/bin/env python3
"""
Video tooling for DJProducerTools.
- inventory: list video files with resolution/codec/duration/size
- transcode_plan: suggest ffmpeg commands for Serato-friendly outputs
"""
import csv
import json
import subprocess
import sys
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple

VIDEO_EXTS = {".mp4", ".mov", ".mkv", ".avi", ".m4v"}
TARGET_BITRATE_VIDEO = 6_000_000  # ~6 Mbps for 1080p
TARGET_BITRATE_AUDIO = 192_000    # 192 kbps AAC


def detect_hw_encoder() -> Tuple[str, str]:
    """Return (encoder_name, ffmpeg_opts) preferring hw accel if available."""
    try:
        out = subprocess.check_output(["ffmpeg", "-hide_banner", "-encoders"], stderr=subprocess.STDOUT, text=True)
    except Exception:
        return "libx264", "-c:v libx264 -preset medium -crf 20"
    if "h264_videotoolbox" in out:
        return "h264_videotoolbox", "-c:v h264_videotoolbox -b:v 6M"
    if "h264_nvenc" in out:
        return "h264_nvenc", "-c:v h264_nvenc -preset p4 -b:v 6M"
    return "libx264", "-c:v libx264 -preset medium -crf 20"


def ffprobe_info(path: Path) -> Dict[str, Any]:
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=width,height,codec_name,bit_rate",
        "-show_entries",
        "format=duration,size",
        "-of",
        "json",
        str(path),
    ]
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
        data = json.loads(out)
    except Exception:
        return {}
    info: Dict[str, Any] = {}
    stream = (data.get("streams") or [{}])[0]
    fmt = data.get("format") or {}
    info["width"] = stream.get("width")
    info["height"] = stream.get("height")
    info["vcodec"] = stream.get("codec_name")
    info["v_bitrate"] = stream.get("bit_rate")
    info["duration"] = fmt.get("duration")
    info["size"] = fmt.get("size")
    return info


def inventory(root: Path, out_tsv: Path, out_json: Optional[Path] = None) -> None:
    files: List[Path] = [p for p in root.rglob("*") if p.suffix.lower() in VIDEO_EXTS and p.is_file()]
    out_json = out_json or out_tsv.with_suffix(".json")
    entries: List[Dict[str, Any]] = []
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "width", "height", "vcodec", "duration_sec", "size_bytes"])
        for p in files:
            info = ffprobe_info(p)
            duration = info.get("duration")
            size_bytes = info.get("size") or p.stat().st_size
            row = {
                "path": str(p),
                "width": info.get("width") or None,
                "height": info.get("height") or None,
                "vcodec": info.get("vcodec") or "",
                "duration_sec": float(duration) if duration is not None else None,
                "size_bytes": int(size_bytes) if size_bytes is not None else None,
            }
            entries.append(row)
            w.writerow(
                [
                    row["path"],
                    row["width"] or "",
                    row["height"] or "",
                    row["vcodec"],
                    row["duration_sec"] or "",
                    row["size_bytes"] or "",
                ]
            )
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(entries, indent=2), encoding="utf-8")


def transcode_plan(root: Path, out_tsv: Path, preset: str = "h264_1080p", out_json: Optional[Path] = None, codec: str = "auto") -> None:
    files: List[Path] = [p for p in root.rglob("*") if p.suffix.lower() in VIDEO_EXTS and p.is_file()]
    out_json = out_json or out_tsv.with_suffix(".json")
    entries: List[Dict[str, Any]] = []
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    hw_enc, hw_opts = detect_hw_encoder()
    if codec != "auto":
        if codec == "videotoolbox":
            hw_enc, hw_opts = "h264_videotoolbox", "-c:v h264_videotoolbox -b:v 6M"
        elif codec == "nvenc":
            hw_enc, hw_opts = "h264_nvenc", "-c:v h264_nvenc -preset p4 -b:v 6M"
        else:
            hw_enc, hw_opts = "libx264", "-c:v libx264 -preset medium -crf 20"
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "action", "ffmpeg_cmd", "est_size_mb", "est_time_sec", "codec"])
        for p in files:
            info = ffprobe_info(p)
            width = info.get("width") or 0
            height = info.get("height") or 0
            vcodec = (info.get("vcodec") or "").lower()
            duration = float(info.get("duration")) if info.get("duration") else None
            needs = vcodec != "h264" or width > 1920 or height > 1080
            if not needs:
                row = {
                    "path": str(p),
                    "action": "KEEP",
                    "ffmpeg_cmd": "",
                    "est_size_mb": None,
                    "est_time_sec": None,
                }
                entries.append(row)
                w.writerow([row["path"], row["action"], row["ffmpeg_cmd"], "", ""])
                continue
            out_name = p.with_suffix(".serato.mp4")
            target_bitrate = TARGET_BITRATE_VIDEO + TARGET_BITRATE_AUDIO
            est_size_mb = None
            est_time_sec = None
            if duration:
                est_size_mb = round(duration * target_bitrate / 8 / 1_000_000, 2)
                # Assuming ~1.5x realtime on modest CPU/GPU; leave as hint
                est_time_sec = round(duration * 1.5, 2)
            cmd = (
                f'ffmpeg -y -i "{p}" {hw_opts} '
                f'-vf "scale=min(1920\\,iw):min(1080\\,ih):force_original_aspect_ratio=decrease" '
                f'-c:a aac -b:a 192k "{out_name}"'
            )
            row = {
                "path": str(p),
                "action": preset,
                "ffmpeg_cmd": cmd,
                "est_size_mb": est_size_mb,
                "est_time_sec": est_time_sec,
                "codec": hw_enc,
            }
            entries.append(row)
            w.writerow(
                [
                    row["path"],
                    row["action"],
                    row["ffmpeg_cmd"],
                    row["est_size_mb"] if row["est_size_mb"] is not None else "",
                    row["est_time_sec"] if row["est_time_sec"] is not None else "",
                    row["codec"],
                ]
            )
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(entries, indent=2), encoding="utf-8")


def main():
    if len(sys.argv) < 4:
        print(
            "Usage: video_tools.py [inventory|transcode_plan] <base_path> <out_tsv> [preset] [codec] [out_json]",
            file=sys.stderr,
        )
        sys.exit(1)
    mode = sys.argv[1]
    base = Path(sys.argv[2]).expanduser()
    out_tsv = Path(sys.argv[3]).expanduser()
    out_json = None
    preset_arg = "h264_1080p"
    codec_arg = "auto"
    if len(sys.argv) > 4:
        # If 4th arg looks like json, treat as out_json; otherwise preset
        if sys.argv[4].endswith(".json"):
            out_json = Path(sys.argv[4]).expanduser()
        else:
            preset_arg = sys.argv[4]
    if len(sys.argv) > 5:
        codec_arg = sys.argv[5]
    if len(sys.argv) > 6:
        out_json = Path(sys.argv[6]).expanduser()

    if mode == "inventory":
        inventory(base, out_tsv, out_json)
    elif mode == "transcode_plan":
        transcode_plan(base, out_tsv, preset_arg, out_json, codec_arg)
    else:
        print(f"Unknown mode: {mode}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
