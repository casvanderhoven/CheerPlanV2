# CheerPlan Domain — the model in our own words

This document restates the domain model (spec §7 asks for exactly that before any code)
and records the math that `CheerPlanCore` implements. Units are SI throughout the
engine: **meters** and **seconds**. Kilometers/miles exist only at the formatting edge.

## The story in one paragraph

A **Course** is an ordered polyline of geographic points, each annotated with its
distance from the start. A **RunnerPlan** binds a course to a start time and a
**PacingStrategy**, which makes the runner's position a *function of time* (and time a
function of position — the two are a bijection). A supporter chooses **MeetPoints** —
locations snapped onto the course polyline, each identified by the course distance of
one specific *pass* of the runner. An ordered list of meet points plus the travel
between them forms a **SupporterItinerary**: for every **TravelLeg** the engine
compares when the spectator can arrive against when the runner will arrive, and issues
a **FeasibilityVerdict** — OK, Tight, or Not Feasible — with the buffer that justifies
it. On race day, **RunnerObservations** from any **PositionSource** feed a
**ProgressEstimator** that recalibrates every arrival time in the itinerary.

## Vocabulary (carried from v1 — do not reinvent)

| Type | What it is | Key invariants |
|---|---|---|
| `Coordinate` | WGS84 lat/lon pair | plain value |
| `TrackPoint` | coordinate + optional elevation + `distanceFromStart` | distances precomputed once, non-decreasing |
| `Course` | named, ordered `[TrackPoint]` | ≥2 unique points; consecutive duplicates removed at construction |
| `PacingStrategy` | `.steady(secondsPerKilometer)` or `.splits([Split])` | splits cover the course; last pace extends if they fall short |
| `RunnerPlan` | course + start time + pacing | position⇄time bijection via `PaceModel` |
| `MeetPoint` | a spot **on** the course: snapped coordinate + course distance | course distance identifies *which pass* (out-and-back/laps ⇒ same coordinate, different distances) |
| `PlannedSpot` | meet point + the travel mode used to reach it | itinerary building block |
| `TravelLeg` | origin (start location or previous spot) → meet point, with times and verdict | departure ≥ runner's pass at origin |
| `SupporterItinerary` | ordered spots + evaluated legs | spots ordered by course distance of their pass |
| `FeasibilityVerdict` | status (ok/tight/notFeasible) + buffer + required buffer | see thresholds below |
| `Milestone` | culturally meaningful course distance | 5K/10K/half/30K/40K/finish + every km/mi |
| `RunnerObservation` | (course distance, timestamp, source) | sources: check-in, recalibration, runner location, timing feed |

## The math

### ETA bijection (`PaceModel`)

A pacing strategy is normalized into monotonic breakpoints `(dᵢ, tᵢ)` — cumulative
distance and cumulative elapsed time. Steady pace has two breakpoints; split-based pace
has one per split boundary. Both directions are piecewise-linear interpolation:

- `time(atDistance d)`: binary-search `d` in the distance array, interpolate.
  Steady pace degenerates to O(1) `d × pace`.
- `distance(atTime t)`: binary-search `t` in the time array, interpolate.

Both are clamped to `[0, courseDistance]` / `[0, totalDuration]` and are exact inverses
of each other on that interval (property-tested).

### Route snapping (`CourseGeometry.snap`)

Never snap to the nearest raw track point. For each polyline segment `A→B`, project the
tap point `P` perpendicularly in a local flat (equirectangular) plane:

```
t = clamp(dot(P−A, B−A) / |B−A|², 0, 1)
S = A + t(B−A)
```

Keep the segment with the smallest `|P−S|`. The snapped course distance is
`A.distanceFromStart + t × (B.distanceFromStart − A.distanceFromStart)` — interpolated
from the *stored* cumulative distances, never recomputed haversines.

### Distance lookups (`CourseGeometry.point(atDistance:)`)

Every `TrackPoint` carries `distanceFromStart`, computed once at course construction.
Point-at-distance binary-searches that array and interpolates coordinate and elevation.
No linear scans.

### Pass-bys (loops, laps, out-and-back)

A physical location can be adjacent to several disjoint stretches of the course.
`passBys(near:within:)` collects every segment within the radius, groups contiguous
segment runs (a gap in course distance starts a new group), and returns the best snap
per group — one `SnapResult` per pass, ordered by course distance. A course is a
**loop** when start and finish are within 50 m (render a combined Start/Finish marker).

### Feasibility thresholds (`FeasibilityEngine`)

For a leg into spot `s` with travel estimate `T`:

```
spectatorArrival = departure + T.duration
buffer           = runnerArrival(s) − spectatorArrival
required         = max(120 s, 0.10 × T.duration) + mode.arrivalBuffer
```

- `mode.arrivalBuffer`: driving +300 s (parking), transit +120 s (connection risk),
  walking/cycling +0.
- **OK** if `buffer ≥ required` · **Tight** if `0 ≤ buffer < required` ·
  **Not Feasible** if `buffer < 0`.
- Departure from a spot = the runner's pass time there (+ optional dwell); the first
  leg departs from the spectator's start location at their earliest departure time
  (default: race start).
- Every leg also carries `latestDeparture = runnerArrival − T.duration` — the
  "leave by" moment used for notifications.

Multi-runner: to see *all* runners at a spot, arrive before the **first** runner
(`runnerArrival = min` over plans) and depart after the **last** (`departure = max`).

### Travel estimates

`TravelTimeProvider` is the async seam. Real routing (MapKit walk/drive/cycle/transit)
lives in the app layer (M3). The built-in `HeuristicTravelEstimator` is the offline
fallback: `haversine × pathMultiplier / modeSpeed + fixedOverhead`, always tagged
`isEstimate = true` so the UI can label it.

### Fix suggestions (`FixSuggester`) — always multi-option

For an infeasible leg, offer every applicable option:
1. remove the destination spot;
2. remove the source spot (when the origin is a spot);
3. move the destination to the **nearest feasible course distance** (scan forward in
   250 m steps, re-evaluate, stop at the first feasible pass before the next spot);
4. change travel mode — every other mode that turns the leg feasible, **driving
   included** (v1 forgot it).

### Auto-propose (`SpotProposer`)

Candidates = milestones ∪ every 500 m, each snapped via point-at-distance. Greedy walk:
from the current origin (start location, then each chosen spot), take the *earliest*
candidate ≥ `minSpacing` (default 1 km) past the previous spot whose leg evaluates OK —
earliest-feasible maximizes the number of sightings. Within a 1.5 km lookahead of that
earliest-OK candidate, prefer an iconic milestone (finish > half/5K/10K/30K/40K > plain
km marker), then the larger buffer. Fall back to Tight if nothing is OK; stop when the
course ends or the requested count is reached. Multi-runner proposals use the
window rule above so one spot covers every runner.

### Live recalibration (`ProgressEstimator`)

Observations are anchored at the latest one `(d₀, t₀)`. The pace ratio `r` (>1 = slower
than plan) blends the cumulative ratio `(t₀ − start) / plannedTime(d₀)` with the ratio
over the two most recent observations (weighted toward recent, clamped to [0.3, 3]):

```
projectedArrival(d) = t₀ + r × (plannedTime(d) − plannedTime(d₀))
estimatedDistance(now) = plannedDistance(atTime: plannedTime(d₀) + (now − t₀)/r)
scheduleDelta = t₀ − (start + plannedTime(d₀))     // + = behind plan
```

With no observations the estimator degrades gracefully to the planned model (`r = 1`).

## GPX fixtures (listed before coding, per spec §7)

| Fixture | Shape | What it proves |
|---|---|---|
| `marathon-city.gpx` | 42.2 km point-to-point `trk`, ~2 000 pts, elevation | realistic scale, distance accuracy, elevation parsing |
| `out-and-back-10k.gpx` | 5 km out, same path back | two pass-bys per location, loop detection (start=finish) |
| `criterium-3laps.gpx` | 3 laps of a ~2 km circuit | lap pass-bys (3 per location), start/finish < 50 m |
| `trail-sparse.gpx` | coarse 40-pt `rte`, no elevation | `rte` support, segment-projection snapping on sparse data, missing elevation |
| `messy.gpx` | duplicate consecutive points, mixed missing `<ele>`, odd whitespace | parser robustness, dedup |
| `invalid.gpx` | not XML | typed error, no silent failure |
| `empty.gpx` | valid GPX, zero points | typed error, no silent failure |
