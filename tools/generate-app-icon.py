#!/usr/bin/env python3
"""Deterministic CheerPlan app icon: brand-blue gradient, a white course line
with feasibility-colored spot dots, and a checkered finish flag.
Pure stdlib (zlib/struct) — no image libraries needed. RGB only (App Store
icons must not contain alpha)."""
import math
import os
import struct
import zlib

SIZE = 1024
OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "App", "Sources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png",
)

# Palette (matches CheerPlanUI)
BG_TOP = (24, 56, 128)
BG_BOTTOM = (51, 115, 242)   # CheerPlanColors.course
WHITE = (255, 255, 255)
NAVY = (18, 36, 84)
OK_GREEN = (33, 176, 77)     # CheerPlanColors.ok
TIGHT_AMBER = (242, 156, 18)  # CheerPlanColors.tight

# Course polyline (y grows downward), start bottom-left → flag top-right
ROUTE = [(210, 850), (430, 570), (640, 665), (800, 340)]
ROUTE_RADIUS = 42
START_DOT = (ROUTE[0], 40, WHITE, None)
SPOT_DOTS = [
    (ROUTE[1], 62, WHITE, OK_GREEN),
    (ROUTE[2], 62, WHITE, TIGHT_AMBER),
]
POLE_TOP = 175
POLE_X, POLE_W = ROUTE[3][0], 9
FLAG = (POLE_X + POLE_W, POLE_TOP, POLE_X + POLE_W + 165, POLE_TOP + 112)  # x0,y0,x1,y1
FLAG_COLS, FLAG_ROWS = 4, 3
AA = 2.0  # antialias falloff in pixels


def seg_distance(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    length_sq = dx * dx + dy * dy
    t = 0.0 if length_sq == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length_sq))
    sx, sy = ax + t * dx, ay + t * dy
    return math.hypot(px - sx, py - sy)


def coverage(distance, radius):
    """1 inside, 0 outside, smooth ramp of width AA at the edge."""
    if distance <= radius - AA:
        return 1.0
    if distance >= radius + AA:
        return 0.0
    return (radius + AA - distance) / (2 * AA)


def blend(base, top, alpha):
    return tuple(int(round(base[i] + (top[i] - base[i]) * alpha)) for i in range(3))


def pixel(x, y):
    t = y / (SIZE - 1)
    color = blend(BG_TOP, BG_BOTTOM, t)

    # Checkered flag (hard-edged, axis-aligned)
    fx0, fy0, fx1, fy1 = FLAG
    if fx0 <= x < fx1 and fy0 <= y < fy1:
        col = int((x - fx0) / (fx1 - fx0) * FLAG_COLS)
        row = int((y - fy0) / (fy1 - fy0) * FLAG_ROWS)
        color = WHITE if (col + row) % 2 == 0 else NAVY

    # Flag pole
    if POLE_X - POLE_W <= x <= POLE_X + POLE_W and POLE_TOP <= y <= ROUTE[3][1]:
        color = WHITE

    # Course line
    distance = min(
        seg_distance(x, y, *ROUTE[i], *ROUTE[i + 1]) for i in range(len(ROUTE) - 1)
    )
    alpha = coverage(distance, ROUTE_RADIUS)
    if alpha > 0:
        color = blend(color, WHITE, alpha)

    # Spot dots (white ring, colored center) and the start dot
    for (cx, cy), radius, ring, center in [START_DOT] + SPOT_DOTS:
        d = math.hypot(x - cx, y - cy)
        a = coverage(d, radius)
        if a > 0:
            color = blend(color, ring, a)
        if center is not None:
            a = coverage(d, radius - 20)
            if a > 0:
                color = blend(color, center, a)
    return color


def write_png(path):
    rows = bytearray()
    for y in range(SIZE):
        rows.append(0)  # filter: none
        for x in range(SIZE):
            rows.extend(pixel(x, y))

    def chunk(tag, payload):
        return (
            struct.pack(">I", len(payload))
            + tag
            + payload
            + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)  # 8-bit RGB
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
        + chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)
    print(f"{path}: {SIZE}x{SIZE}, {len(png)} bytes")


if __name__ == "__main__":
    write_png(os.path.abspath(OUT))
