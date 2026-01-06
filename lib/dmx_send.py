#!/usr/bin/env python3
"""
Send DMX frames from a TSV plan via ENTTEC DMX USB Pro (or dry-run).
Plan format: start_sec<TAB>scene<TAB>channels
channels example: "CH1=255,CH2=180,CH5=160"
"""
import argparse
import time
import sys
from pathlib import Path
from typing import Dict, List, Tuple


def parse_plan(path: Path) -> List[Tuple[float, Dict[int, int], str]]:
    entries: List[Tuple[float, Dict[int, int], str]] = []
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or line.lower().startswith("start_sec"):
                continue
            parts = line.split("\t")
            if len(parts) < 3:
                continue
            try:
                start = float(parts[0])
            except Exception:
                start = 0.0
            channels_raw = parts[2]
            ch_map: Dict[int, int] = {}
            for kv in channels_raw.split(","):
                if "=" not in kv:
                    continue
                k, v = kv.split("=", 1)
                try:
                    ch = int(k.upper().replace("CH", "").strip())
                    val = max(0, min(255, int(v.strip())))
                    ch_map[ch] = val
                except Exception:
                    continue
            entries.append((start, ch_map, parts[1]))
    entries.sort(key=lambda x: x[0])
    return entries


def build_dmx_packet(ch_map: Dict[int, int], universe_size: int = 512) -> bytes:
    data = bytearray([0] * universe_size)
    for ch, val in ch_map.items():
        if 1 <= ch <= universe_size:
            data[ch - 1] = val
    size = len(data)
    # ENTTEC DMX USB Pro packet: 0x7E, label=6, size LSB/MSB, data..., 0xE7
    packet = bytearray()
    packet.append(0x7E)
    packet.append(6)
    packet.append(size & 0xFF)
    packet.append((size >> 8) & 0xFF)
    packet.extend(data)
    packet.append(0xE7)
    return bytes(packet)


def send_plan(plan_path: Path, device: str, baud: int, dry_run: bool) -> None:
    entries = parse_plan(plan_path)
    if not entries:
        print("No entries to send", file=sys.stderr)
        return
    ser = None
    if not dry_run:
        try:
            import serial  # type: ignore
        except ImportError:
            print("pyserial no instalado; usa dry-run o instala con pip install pyserial", file=sys.stderr)
            dry_run = True
        if not dry_run:
            ser = serial.Serial(device, baudrate=baud, timeout=1)
    start_time = time.time()
    for start, ch_map, scene in entries:
        now = time.time() - start_time
        if now < start:
            time.sleep(start - now)
        packet = build_dmx_packet(ch_map)
        if dry_run or ser is None:
            print(f"[DRY] t={start:.2f}s scene={scene} channels={ch_map}")
        else:
            ser.write(packet)
    if ser:
        ser.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", required=True, help="TSV plan with start_sec,scene,channels")
    ap.add_argument("--device", default="/dev/tty.usbserial", help="DMX USB serial device")
    ap.add_argument("--baud", type=int, default=57600)
    ap.add_argument("--dry-run", action="store_true", help="Do not send, just print")
    args = ap.parse_args()
    send_plan(Path(args.plan), args.device, args.baud, args.dry_run)


if __name__ == "__main__":
    main()
