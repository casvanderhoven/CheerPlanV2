# CheerPlan v2

**CheerPlan helps race spectators see their runner as many times as possible.**

The runner sets up the race (GPX course, start time, pacing) and shares it as a link.
Each supporter picks viewing spots on the course map — or lets the app propose them —
and gets a validated, timed itinerary: *"Spot 2 at km 14.5, runner arrives ~10:42,
leave Spot 1 by 10:19, 21-min walk."* On race day, live mode tracks progress, sends
"time to move" notifications, and adapts when the runner is ahead of or behind plan.

The core value is the **feasibility engine**: every leg between viewing spots is
classified **OK / Tight / Not Feasible** by comparing the spectator's travel time
against the runner's, with concrete fix suggestions when a plan breaks.

This is the v2 rewrite. v1 (SwiftUI, iOS 17) proved the concept; the lessons learned
and the validated domain logic are captured in [docs/SPEC.md](docs/SPEC.md).

## Status

| Milestone | Deliverable | Status |
|---|---|---|
| **M1** | `CheerPlanCore` — models, GPX, ETA, snapping, feasibility, proposer, live estimator; fully tested | ✅ in review |
| M2 | App shell (iOS 18+, SwiftUI): import GPX, course map + elevation, runner plans | — |
| M3 | Supporter planning: spots, auto-propose, real routing, fixes UI | — |
| M4 | Link sharing + App Clip preview | — |
| M5 | Race day: live engine, resume, Live Activity, notifications | — |
| M6 | Multi-runner + crew | — |

## Layout

- **`CheerPlanCore/`** — platform-agnostic domain models + engine. Foundation only;
  builds and tests on Linux and Apple platforms alike.
- `CheerPlanData/`, `CheerPlanUI/`, `App/` — arrive with M2+.
- **`docs/`** — [SPEC.md](docs/SPEC.md) (the kickoff prompt, source of truth),
  [DOMAIN.md](docs/DOMAIN.md) (the domain model and math),
  [ARCHITECTURE.md](docs/ARCHITECTURE.md) (package map, rules, decisions log).

## Build & test

Requires Swift 6.0+ (any platform):

```sh
cd CheerPlanCore
swift test
```

CI runs the same tests in a `swift:6.1` Linux container plus SwiftLint on every push
and PR (`.github/workflows/ci.yml`).
