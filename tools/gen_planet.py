#!/usr/bin/env python3
"""Generate resources/drawables/planet.png: a Bayer-dithered 1-bit planet horizon."""

import math
import struct
import zlib
from pathlib import Path

W, H = 176, 60
CX, CY, R = 40.0, 330.0, 310.0

BAYER = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]

WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)
CLEAR = (0, 0, 0, 0)


def pixel(x, y):
    d = math.hypot(x - CX, y - CY)
    sun = 1.0 - 0.65 * x / W
    threshold = (BAYER[y % 4][x % 4] + 0.5) / 16.0
    if d > R:
        out = d - R
        if out > 7:
            return CLEAR
        glow = 0.55 * math.exp(-out / 2.2) * sun
        return WHITE if glow > threshold else CLEAR
    depth = R - d
    limb = math.exp(-depth / 12.0)
    bands = 0.5 + 0.5 * math.sin(depth * 0.45 + x * 0.035)
    storm = math.exp(-((x - 118) ** 2 + (depth - 16) ** 2 * 6) / 60.0)
    b = (0.85 * limb + 0.22 * bands * math.exp(-depth / 30.0) + 0.5 * storm) * sun
    return WHITE if b > threshold else BLACK


def write_png(path, rows):
    raw = b"".join(b"\x00" + bytes(c for px in row for c in px) for row in rows)

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


if __name__ == "__main__":
    out = Path(__file__).resolve().parent.parent / "resources" / "drawables" / "planet.png"
    write_png(out, [[pixel(x, y) for x in range(W)] for y in range(H)])
    print(f"Wrote {out}")
