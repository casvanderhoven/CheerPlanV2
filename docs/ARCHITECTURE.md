# CheerPlan v2 — Architecture

Target: **iOS 18+, Swift 6, strict concurrency from day one** (spec §5).

## Package map and dependency rules

```
┌────────────────────────────────────────────────────────────┐
│ App targets: CheerPlan (app) · Widgets/Live Activity ·     │
│              App Clip (plan preview) · Watch (later)       │
└──────────────┬─────────────────┬───────────────────────────┘
               │                 │
        ┌──────▼──────┐   ┌──────▼──────┐
        │ CheerPlanUI │   │CheerPlanData│   persistence, migrations,
        │ design      │   │             │   share-link codec,
        │ system      │   │             │   .cheerplan import/export
        └──────┬──────┘   └──────┬──────┘
               │                 │
          ┌────▼─────────────────▼────┐
          │       CheerPlanCore       │   models + engine — Foundation ONLY
          └───────────────────────────┘
```

Rules, enforced by review and by construction:

- **`CheerPlanCore` imports nothing but Foundation** (and `FoundationXML` on Linux for
  the GPX parser). No UIKit, no SwiftUI, no MapKit, no CoreLocation. Pure `Sendable`
  value types and pure functions — this package is the contract that lets a future
  web/watch client reuse the math, and it is what makes the math testable on Linux CI.
- **No singletons, no mutable statics** anywhere. `@Observable` state objects are
  injected via the SwiftUI environment; services are protocol-typed,
  constructor-injected dependencies so previews and tests use fakes.
- **One database.** All documents — runner plans, imported plans, spots, live race
  state — live in a single store in `CheerPlanData`. No UserDefaults for documents.
  Live-race state persists on every mutation and is resumable after termination.
- **Async seams are protocols in Core.** `TravelTimeProvider` (real MapKit routing vs.
  the built-in heuristic estimator) and `PositionSource` (check-ins, recalibration,
  runner location sharing, official timing feeds) are defined in Core; implementations
  live in the app layer.
- **The live race engine (M5) is an actor** owning the timing model, with a persisted
  event log of observations so state reconstructs after relaunch. Core already models
  the events (`RunnerObservation`) and the math (`ProgressEstimator`); the actor and
  its log are app-layer.
- **Typed errors for every failable operation**, surfaced to the user. No
  print-and-swallow.
- **One view per file, no file over 400 lines** (SwiftLint-enforced), design system in
  `CheerPlanUI` from the first commit.

## Decisions log

| Decision | Choice | Rationale | Status |
|---|---|---|---|
| Persistence (SwiftData vs GRDB, spec says pick one) | **GRDB (recommendation)** | The live engine's event log and "persist on every mutation" favor explicit, synchronous write control; GRDB is fully testable off-device and battle-tested for migrations. | Proposed — final call at M2; veto welcome |
| Test framework | **Swift Testing** | Native to the Swift 6 toolchain, runs under `swift test` on Linux CI. | Adopted |
| Share-link payload | Versioned from day one; CloudKit public DB vs. tiny redirect service | Spec §5. | Open — decide at M4 |
| CI | Linux container job (`swift:6.1`) for Core tests + SwiftLint job; macOS app-build job added at M2 | Core is platform-agnostic, so the crown-jewel math is verified on every push without macOS minutes. | Adopted |

## Roadmap (spec §7)

| Milestone | Deliverable | Status |
|---|---|---|
| **M1** | `CheerPlanCore`: models + GPX + ETA + snapping + feasibility + proposer + live estimator, fully tested on real GPX fixtures | **This PR** |
| M2 | App shell: import GPX, course map + elevation, create runner plan | — |
| M3 | Supporter planning: spots, auto-propose, real MapKit routing, feasibility + fixes UI | — |
| M4 | Sharing: deep links + App Clip preview, `.cheerplan` fallback | — |
| M5 | Race day: live engine actor, persistence/resume, Live Activity, notifications | — |
| M6 | Multi-runner + crew assignments | — |

## Repository layout

```
CheerPlanV2/
├── CheerPlanCore/          # M1 — this PR. SwiftPM package, Linux-testable.
│   ├── Package.swift
│   ├── Sources/CheerPlanCore/{Models,GPX,Geometry,Pacing,Feasibility,Propose,Live,Format}
│   └── Tests/CheerPlanCoreTests/  (+ Fixtures/)
├── CheerPlanData/          # M2+
├── CheerPlanUI/            # M2+
├── App/                    # M2+ (XcodeGen or Xcode project, app + extension targets)
├── docs/                   # SPEC.md · DOMAIN.md · ARCHITECTURE.md
└── .github/workflows/ci.yml
```
