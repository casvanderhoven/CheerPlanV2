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
| **M1** | `CheerPlanCore` — models, GPX, ETA, snapping, feasibility, proposer, live estimator; fully tested | ✅ |
| **M2** | App shell (iOS 18+, SwiftUI): import GPX (file/URL), course map + elevation, runner plans, GRDB persistence | ✅ |
| **M3** | Supporter planning: tap-to-add spots, auto-propose, MapKit routing + offline cache, feasibility + fixes UI | ✅ |
| **M4** | Link sharing (serverless deep links) + `.cheerplan` files | ✅ (App Clip/web preview deferred) |
| **M5** | Race day: live engine + event log (force-quit-proof), glanceable screen, notifications, Live Activity | ✅ in review |
| **M6** | Multi-runner itineraries + crew assignments | ✅ in review (crew sync deferred) |

## Layout

- **`CheerPlanCore/`** — platform-agnostic domain models + engine. Foundation only;
  builds and tests on Linux and Apple platforms alike.
- **`CheerPlanData/`** — persistence (GRDB) behind the `PlanStore` protocol.
- **`CheerPlanUI/`** — design system: theme, feasibility pill, elevation profile chart.
- **`App/`** — the iOS app (XcodeGen `project.yml` + SwiftUI sources, one view per file).
- **`docs/`** — [SPEC.md](docs/SPEC.md) (the kickoff prompt, source of truth),
  [DOMAIN.md](docs/DOMAIN.md) (the domain model and math),
  [ARCHITECTURE.md](docs/ARCHITECTURE.md) (package map, rules, decisions log).

## Build & test

Engine tests run on any platform with Swift 6.0+:

```sh
cd CheerPlanCore && swift test
```

Run the app (macOS with Xcode 16+):

```sh
brew install xcodegen
xcodegen generate --spec App/project.yml --project App
open App/CheerPlan.xcodeproj   # build & run the CheerPlan scheme on a simulator/device
```

CI (`.github/workflows/ci.yml`): Core tests in a `swift:6.1` Linux container,
SwiftLint `--strict`, and a macOS job that tests `CheerPlanUI`/`CheerPlanData` and
builds the app for the iOS simulator — on every push and PR.
