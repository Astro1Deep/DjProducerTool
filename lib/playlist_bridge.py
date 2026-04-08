#!/usr/bin/env python3
import argparse
import csv
import subprocess
from pathlib import Path


def _resolve_track(line: str, playlist_path: Path) -> Path:
    candidate = Path(line)
    if candidate.is_absolute():
        return candidate
    return (playlist_path.parent / candidate).resolve()


def _parse_playlist(playlist: Path):
    tracks = []
    with playlist.open("r", encoding="utf-8", errors="ignore") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            tracks.append(_resolve_track(line, playlist))
    return tracks


def _duration_seconds(path: Path) -> float:
    try:
        proc = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(path),
            ],
            capture_output=True,
            text=True,
            check=False,
            timeout=8,
        )
        if proc.returncode != 0:
            return 0.0
        return float(proc.stdout.strip() or 0.0)
    except Exception:
        return 0.0


def osc(playlist_path: str, plan_path: str) -> int:
    playlist = Path(playlist_path).expanduser().resolve()
    plan = Path(plan_path).expanduser().resolve()

    if not playlist.exists():
        print(f"Playlist not found: {playlist}")
        return 1

    tracks = _parse_playlist(playlist)
    plan.parent.mkdir(parents=True, exist_ok=True)

    start = 0.0
    with plan.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh, delimiter="	")
        writer.writerow(
            [
                "index",
                "start_sec",
                "duration_sec",
                "end_sec",
                "cue_name",
                "file",
            ]
        )
        for idx, track in enumerate(tracks, 1):
            dur = _duration_seconds(track)
            end = start + dur
            writer.writerow(
                [
                    idx,
                    f"{start:.3f}",
                    f"{dur:.3f}",
                    f"{end:.3f}",
                    f"cue_{idx:03d}",
                    str(track),
                ]
            )
            start = end

    print(f"OSC plan generated: {plan}")
    return 0


def dmx(playlist_path: str, plan_path: str, channel_base: str) -> int:
    playlist = Path(playlist_path).expanduser().resolve()
    plan = Path(plan_path).expanduser().resolve()

    if not playlist.exists():
        print(f"Playlist not found: {playlist}")
        return 1

    try:
        base_ch = int(channel_base)
    except ValueError:
        print(f"Invalid channel base: {channel_base}")
        return 1

    scenes = ["INTRO", "BUILD", "DROP", "BREAK", "OUTRO"]
    tracks = _parse_playlist(playlist)

    start = 0.0
    plan.parent.mkdir(parents=True, exist_ok=True)
    with plan.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh, delimiter="	")
        writer.writerow(
            [
                "index",
                "start_sec",
                "duration_sec",
                "scene",
                "channel_base",
                "file",
            ]
        )
        for idx, track in enumerate(tracks, 1):
            dur = _duration_seconds(track)
            scene = scenes[(idx - 1) % len(scenes)]
            writer.writerow([idx, f"{start:.3f}", f"{dur:.3f}", scene, base_ch, str(track)])
            start += dur

    print(f"DMX plan generated: {plan}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Playlist bridge for OSC/DMX plan generation")
    subparsers = parser.add_subparsers(dest="command", required=True)

    p_osc = subparsers.add_parser("osc")
    p_osc.add_argument("pl")
    p_osc.add_argument("plan")

    p_dmx = subparsers.add_parser("dmx")
    p_dmx.add_argument("pl")
    p_dmx.add_argument("plan")
    p_dmx.add_argument("ch")

    args = parser.parse_args()

    if args.command == "osc":
        return osc(args.pl, args.plan)
    return dmx(args.pl, args.plan, args.ch)


if __name__ == "__main__":
    raise SystemExit(main())
