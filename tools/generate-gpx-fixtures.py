#!/usr/bin/env python3
"""Deterministic GPX fixture generator for CheerPlanCoreTests."""
import math
import os

R = 6_371_000.0
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "CheerPlanCore", "Tests", "CheerPlanCoreTests", "Fixtures")
os.makedirs(OUT, exist_ok=True)

HEADER = '<?xml version="1.0" encoding="UTF-8"?>\n<gpx version="1.1" creator="CheerPlan fixtures" xmlns="http://www.topografix.com/GPX/1/1">\n'


def step(lat, lon, heading_deg, meters):
    theta = math.radians(heading_deg)
    dlat = meters * math.cos(theta) / R * 180 / math.pi
    dlon = meters * math.sin(theta) / (R * math.cos(math.radians(lat))) * 180 / math.pi
    return lat + dlat, lon + dlon


def haversine(a, b):
    lat1, lon1, lat2, lon2 = map(math.radians, [a[0], a[1], b[0], b[1]])
    h = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    return 2 * R * math.asin(min(1, math.sqrt(h)))


def write_gpx(filename, name, points, kind="trk"):
    """points: list of (lat, lon, ele_or_None)"""
    parts = [HEADER, f"  <metadata><name>{name}</name></metadata>\n"]
    if kind == "trk":
        parts.append("  <trk><trkseg>\n")
        tag = "trkpt"
    else:
        parts.append("  <rte>\n")
        tag = "rtept"
    for lat, lon, ele in points:
        if ele is None:
            parts.append(f'    <{tag} lat="{lat:.7f}" lon="{lon:.7f}"/>\n')
        else:
            parts.append(f'    <{tag} lat="{lat:.7f}" lon="{lon:.7f}"><ele>{ele:.1f}</ele></{tag}>\n')
    parts.append("  </trkseg></trk>\n" if kind == "trk" else "  </rte>\n")
    parts.append("</gpx>\n")
    path = os.path.join(OUT, filename)
    with open(path, "w") as f:
        f.write("".join(parts))
    coords = [(p[0], p[1]) for p in points]
    total = sum(haversine(coords[i], coords[i + 1]) for i in range(len(coords) - 1))
    closure = haversine(coords[0], coords[-1])
    print(f"{filename}: {len(points)} pts, total={total:.1f} m, start-finish={closure:.1f} m")


# 1. marathon-city.gpx — 2000 steps x 21.1 m = 42.2 km, drifting NE, never self-crossing
points = []
lat, lon = 52.3700000, 4.9000000
for i in range(2001):
    ele = 10 + 20 * math.sin(i / 100) + 5 * math.sin(i / 17)
    points.append((lat, lon, ele))
    heading = 45 + 30 * math.sin(i / 150)
    lat, lon = step(lat, lon, heading, 21.1)
write_gpx("marathon-city.gpx", "Fixture City Marathon", points[:2001])

# 2. out-and-back-10k.gpx — 5 km due north, back on the same path
out = []
lat, lon = 52.0000000, 5.0000000
for i in range(201):  # 200 x 25 m = 5000 m out
    out.append((lat, lon, 3.0 + i * 0.05))
    lat, lon = step(lat, lon, 0, 25)
full = out + out[-2::-1]  # turnaround point appears once
write_gpx("out-and-back-10k.gpx", "Fixture Out and Back 10K", full)

# 3. criterium-3laps.gpx — 3 laps of a 2 km circuit (circle), start == finish
laps = []
clat, clon = 48.8500000, 2.3500000
r = 2000 / (2 * math.pi)
n_per_lap = 100
for i in range(3 * n_per_lap + 1):
    theta = 2 * math.pi * i / n_per_lap
    plat = clat + r * math.cos(theta) / R * 180 / math.pi
    plon = clon + r * math.sin(theta) / (R * math.cos(math.radians(clat))) * 180 / math.pi
    laps.append((plat, plon, 35.0))
write_gpx("criterium-3laps.gpx", "Fixture Criterium", laps)

# 4. trail-sparse.gpx — coarse 40-point route, 200 m spacing, zigzag, no elevation
trail = []
lat, lon = 46.5000000, 8.0000000
for i in range(40):
    trail.append((lat, lon, None))
    heading = 40 + (35 if i % 2 == 0 else -35)
    lat, lon = step(lat, lon, heading, 200)
write_gpx("trail-sparse.gpx", "Fixture Sparse Trail", trail, kind="rte")

# 5. messy.gpx — hand-crafted horrors: duplicates, mixed elevation, odd whitespace
mlat, mlon = 51.5000000, -0.1000000
mpts = []
for i in range(10):
    mpts.append((mlat, mlon))
    mlat, mlon = step(mlat, mlon, 90, 100)
messy = HEADER
messy += "  <metadata>\n     <name>  Messy Course  </name>\n  </metadata>\n"
messy += "  <trk><trkseg>\n"
for i, (plat, plon) in enumerate(mpts):
    if i == 3:
        # exact duplicate, twice, attribute order swapped, no elevation
        messy += f'      <trkpt lon="{plon:.7f}" lat="{plat:.7f}"><ele>12.0</ele></trkpt>\n'
        messy += f'    <trkpt lat="{plat:.7f}"   lon="{plon:.7f}" />\n'
        messy += f'<trkpt lon="{plon:.7f}" lat="{plat:.7f}"></trkpt>\n'
    elif i % 2 == 0:
        messy += f'    <trkpt lat="{plat:.7f}" lon="{plon:.7f}">\n        <ele>\n          {10.0 + i:.1f}\n        </ele>\n    </trkpt>\n'
    else:
        messy += f'    <trkpt lat="{plat:.7f}" lon="{plon:.7f}"/>\n'
messy += "  <!-- a comment, why not -->\n  </trkseg></trk>\n</gpx>\n"
with open(os.path.join(OUT, "messy.gpx"), "w") as f:
    f.write(messy)
total = sum(haversine(mpts[i], mpts[i + 1]) for i in range(len(mpts) - 1))
print(f"messy.gpx: 10 unique pts (+2 dupes), total={total:.1f} m")

# 6. invalid.gpx / 7. empty.gpx
with open(os.path.join(OUT, "invalid.gpx"), "w") as f:
    f.write("This is not XML at all <<<gpx>>> {json?}\n")
with open(os.path.join(OUT, "empty.gpx"), "w") as f:
    f.write(HEADER + "  <trk><trkseg></trkseg></trk>\n</gpx>\n")
print("invalid.gpx, empty.gpx written")
