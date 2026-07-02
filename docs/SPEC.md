# CheerPlan v2 — Design & Build Prompt

> **How to use this document:** paste it (or attach it) as the opening prompt in a fresh
> repository to kick off CheerPlan v2. It is self-contained: it captures the product
> vision, everything we learned building v1, the domain logic that must be carried
> forward, and the architectural direction for the rewrite. Nothing from the v1 repo
> needs to be copied — treat v1 as reference material only.

---

## 1. The product

**CheerPlan helps race spectators see their runner as many times as possible.**

Watching a friend run a marathon sounds simple until you try it: you need to know where
the runner will be at what time, pick spots you can physically reach, and travel between
those spots faster than the runner covers the course between them — accounting for real
streets, closures, and crowds, not straight-line distance.

CheerPlan turns this into a solved problem:

1. The **runner** sets up the race: course (GPX), start time, pacing strategy.
2. The runner **shares the plan** with their supporters.
3. Each **supporter** picks viewing spots on the course map (or lets the app propose
   them) and gets a validated, timed itinerary: *"Spot 2 at km 14.5, runner arrives
   ~10:42, leave Spot 1 by 10:19, 21-min walk."*
4. On **race day**, live mode tracks progress, sends "time to move" notifications, and
   adapts when the runner is ahead of or behind plan.

The core value is the **feasibility engine**: for every leg between viewing spots it
compares the spectator's travel time against the runner's time between those course
points, and classifies each leg as **OK** (comfortable buffer), **Tight** (feasible,
minimal slack), or **Not Feasible** — with concrete fix suggestions when a plan breaks.

---

## 2. What v1 taught us

v1 was a SwiftUI iOS app (~10k lines, iOS 17+, MapKit, Live Activities). It proved the
concept end-to-end. Carry these lessons into v2.

### What worked — keep and carry forward

- **The domain model is right.** `Course` → `RunnerPlan` (course + pacing + start time)
  → `MeetPoint` (spot snapped to route) → `SupporterItinerary` (ordered spots +
  travel legs, each with a feasibility verdict). Don't reinvent this vocabulary.
- **The two-role split is right.** Runner mode (author and share a plan) and supporter
  mode (import, plan spots, go live) are genuinely different jobs. Keep them distinct.
- **Feasibility as a three-state traffic light** (OK / Tight / Not Feasible) with
  per-leg buffers was instantly understandable to users.
- **Auto-propose** (suggest N optimal spots given travel mode and start location) was
  the killer convenience feature — most users don't want to hand-pick spots.
- **Pure, testable service layer.** GPX parsing, ETA calculation, snapping,
  feasibility evaluation were all pure functions over value types. This made the math
  trustworthy. v2 should push this further (see §5).

### What was wrong — fix by design, not by patching

1. **Sharing was file-based and high-friction.** v1 exported `.cheerplan` files
   (zipped JSON) that had to be AirDropped/messaged and manually imported. Every extra
   step lost supporters — the people least motivated to fight an import flow.
   *v2: sharing must be a link.* Tapping it should open the plan (App Clip / universal
   link / web fallback), with the file format kept only as an offline escape hatch.
2. **"Live" mode wasn't live.** The runner's position was simulated purely from the
   planned pace. One "runner passed me" recalibration button was retrofitted late.
   *v2: design live tracking as a first-class subsystem from day one* — multiple
   position sources (manual check-ins, recalibration taps, optional runner location
   sharing, and a pluggable adapter for official race-timing feeds), all funneling into
   one ETA model.
3. **Singletons everywhere.** `PlanStorage.shared`, `SpectatorSettings.shared`
   (a mutable global with thread-safety issues) made state flow invisible and testing
   awkward. *v2: injected dependencies and `@Observable` app state — no mutable
   statics.*
4. **Persistence was ad-hoc.** Runner plans lived in JSON files, imported plans
   originally in UserDefaults (size limits, silent truncation), live-race state was
   initially not persisted at all — data loss during the most critical moment of the
   product. *v2: one database (SwiftData or GRDB) for everything, with live-race state
   persisted on every mutation and resumable after termination.*
5. **Travel estimates defaulted to naive math.** Straight-line distance × path
   multiplier, with real MapKit routes fetched only sometimes, and no transit support —
   yet public transit is how most city-marathon spectators actually move. *v2: real
   routing (walk/transit/drive/cycle) is the default; heuristics are the offline
   fallback, clearly labeled as estimates.*
6. **Views became monoliths.** ContentView.swift exceeded 1,000 lines with 10+ view
   types before it was split. Formatting helpers and feasibility colors were duplicated
   3–4×. *v2: enforce one-view-per-file and a shared design system from the first
   commit.*
7. **Race-day robustness was an afterthought.** No offline plan, notifications with no
   actionable detail, a UI not designed for glancing while jogging between spots in a
   crowd. *v2: race day is the flagship UX — big glanceable typography, Live
   Activity/Dynamic Island as a primary surface, offline-first, rich actionable
   notifications ("Leave now — 12 min walk NE to Spot 3 (km 15.2), runner arrives in
   18 min").*

---

## 3. Domain logic to carry forward (the crown jewels)

This is validated, debugged behavior. Re-implement it cleanly; don't re-derive it.

- **ETA math.** Runner position/time is a bijection given a pacing plan.
  Steady pace: direct O(1) computation. Variable (split-based) pace: binary search over
  cumulative segment times. Support both directions: time-at-distance and
  distance-at-time.
- **Route snapping.** Snap map taps to the nearest point **on the polyline segment**
  (perpendicular projection between consecutive track points), not to the nearest raw
  track point — coarse GPX files otherwise snap hundreds of meters off the drawn route.
- **Distance lookups.** Every track point carries a precomputed `distanceFromStart`;
  all point-at-distance queries binary-search these and interpolate. Never linear-scan
  with recomputed haversines.
- **Feasibility thresholds scale with the leg.** A fixed 2-minute buffer is wrong: use
  ~10% of estimated travel time with a floor of 2 minutes, and add mode-specific
  buffers (e.g., parking time for driving).
- **Fix suggestions must be multi-option.** When a leg is infeasible offer: remove
  destination spot, remove source spot, move the spot to the nearest feasible course
  distance, or change travel mode (including driving — v1 forgot it).
- **Loop courses.** Start and finish are often within ~50m; render a combined
  Start/Finish marker. Out-and-back and lapped courses mean a spectator standing still
  may see the runner more than once — the spot model must allow multiple pass-bys per
  physical location.
- **Race milestones.** Besides every km/mile, generate the culturally meaningful ones:
  5K, 10K, half (21.0975 km), 30K ("the wall"), 40K, finish — scaled to the course
  distance.
- **Multi-runner.** Spectators often follow several runners in one race. The spot
  optimizer should find locations where multiple runners can be seen from one spot
  (or a tight cluster), given each runner's pacing plan.
- **GPX realities.** Handle files with sparse points, missing elevation, `trk` vs
  `rte`, and duplicated points. Parse and *display* elevation (profile chart with meet
  points annotated) — v1 parsed it and showed nothing for months.
- **Formatting discipline.** Cache `DateFormatter`s statically; centralize
  duration/distance/pace formatting in one utility with unit support (km/mi).

---

## 4. v2 product scope

### Personas

- **The Runner** — authors the plan; wants supporters to actually show up in the right
  places; may share live location on race day.
- **The Supporter** — receives a link; wants maximum sightings for minimum stress;
  varying mobility (on foot, bike, transit, car, stroller in tow).
- **The Crew Captain** (new in v2) — coordinates several supporters and possibly
  several runners; assigns spots so the runner sees someone at every key point.

### Feature set

**MVP (must ship first):**
1. Import a course from GPX (file, or paste a URL); auto-detect distance, loops,
   elevation.
2. Runner plan: start time + pacing (steady, or per-split negative/positive); rename,
   edit, duplicate plans.
3. Link-based sharing (deep link opens plan in app; graceful web/App Clip preview for
   supporters without the app). `.cheerplan` file export retained as fallback.
4. Supporter spot planning: tap-to-add spots snapped to the route, auto-propose N
   spots, per-leg travel mode, feasibility traffic-lights, multi-option fixes,
   elevation profile.
5. Real routing for travel legs (walk/drive/cycle/transit) with offline heuristic
   fallback.
6. Race day live mode: persisted and resumable state, runner-position recalibration
   ("passed me at spot 2"), Live Activity + Dynamic Island, actionable move-now
   notifications, fully offline-capable once the plan is loaded.

**Fast follow:**
7. Multi-runner itineraries with shared-spot optimization.
8. Optional live runner location sharing (runner opts in; battery-conscious).
9. Crew coordination: see which supporter covers which spot.
10. Apple Watch companion for supporters (next spot, countdown, walk direction).

**Explicit non-goals (v2.0):** Android/web planning parity (web is view-only), social
network features, race discovery/calendar, training features, weather integration.

---

## 5. Technical direction

- **Platform:** iOS 18+ (raise the floor; unlocks modern SwiftUI, SwiftData maturity,
  improved MapKit APIs). Swift 6 with strict concurrency from day one.
- **Repo layout:** an Xcode app shell plus local Swift packages:
  - `CheerPlanCore` — **platform-agnostic** domain models + engine (GPX, ETA,
    snapping, feasibility, proposer, multi-runner optimizer). Pure value types, zero
    UIKit/SwiftUI/MapKit imports, exhaustive unit tests with real GPX fixtures
    (marathon, out-and-back, lapped criterium, sparse trail file). This package is the
    contract that lets a future web/watch/Android client reuse the math.
  - `CheerPlanData` — persistence (SwiftData or GRDB — pick one, no UserDefaults for
    documents), migrations, share-link encoding/decoding, `.cheerplan` import/export.
  - `CheerPlanUI` — design system: colors (incl. feasibility semantics), typography,
    reusable map annotations, formatters. One view per file, previews everywhere.
  - App targets: main app, widgets/Live Activity extension, App Clip (plan preview),
    watch app (later).
- **Architecture:** `@Observable` state objects injected via environment; services as
  protocol-typed dependencies (constructor-injected) so previews and tests use fakes.
  No singletons; no mutable statics. Live race engine is an actor owning the timing
  model, with a persisted event log (check-ins, recalibrations) so state reconstructs
  after relaunch.
- **Routing:** MapKit directions for walk/drive/cycle/transit with an on-disk cache
  keyed by (from, to, mode, time-bucket); heuristic estimator as fallback, results
  labeled "estimate" in the UI.
- **Share links:** plan payload encoded server-lessly if possible (CloudKit public
  database or a tiny link-redirect service); design the payload with a version field
  from the start.
- **Testing bar:** CheerPlanCore ≥90% coverage; snapshot tests for itinerary and
  race-day screens; one UI test for the golden path (import GPX → share → import link →
  auto-propose → go live).
- **Quality gates from commit one:** SwiftLint/SwiftFormat, CI running tests on every
  PR, no file >400 lines, user-visible errors for every failable operation (v1 shipped
  silent `print`-and-swallow error handling more than once).

---

## 6. UX principles for the redesign

1. **The map is the app.** Both roles live on the course map; lists and editors are
   sheets over it, not separate worlds.
2. **Race day is glanceable.** Design every race-day screen for a stressed person
   walking fast in a crowd: one primary number (countdown), one primary instruction
   (where to go), thumb-reach actions, huge type, works in bright sunlight.
3. **Never dead-end the user.** Every "Not Feasible" comes with tappable fixes. Every
   error states what happened and what to do. Every destructive action confirms or is
   undoable.
4. **Progressive disclosure of the math.** Default UI shows verdicts and times; a
   detail layer reveals buffers, assumed speeds, and route sources for the curious.
5. **Respect the supporter's investment.** Plans, spots, and live state survive app
   termination, phone restarts, and airplane mode. Losing a supporter's itinerary at
   km 30 is the one unforgivable bug.

---

## 7. Suggested build order

| Milestone | Deliverable | Proof |
|---|---|---|
| M1 | `CheerPlanCore` package: models + GPX + ETA + snapping + feasibility, fully tested | Tests green on real GPX fixtures |
| M2 | App shell: import GPX, view course map + elevation, create runner plan | Golden-path demo on device |
| M3 | Supporter planning: spots, auto-propose, real routing, feasibility + fixes | A validated itinerary for a real marathon course |
| M4 | Sharing: deep links + App Clip preview, file fallback | Link on phone A opens plan on phone B |
| M5 | Race day: live engine, persistence/resume, Live Activity, notifications | Simulated race end-to-end incl. force-quit recovery |
| M6 | Multi-runner + crew assignments | Two-runner combined itinerary demo |

Start with M1. Before writing code, restate the domain model in your own words and
list the GPX fixtures you'll test against — then build.
