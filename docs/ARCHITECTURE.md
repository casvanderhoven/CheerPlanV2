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
| Persistence (SwiftData vs GRDB, spec says pick one) | **GRDB** | The live engine's event log and "persist on every mutation" favor explicit, synchronous write control; GRDB is fully testable off-device and battle-tested for migrations. All access goes through the `PlanStore` protocol (`CheerPlanData`), so previews/tests use `InMemoryPlanStore`. | Adopted (M2) |
| Test framework | **Swift Testing** | Native to the Swift 6 toolchain, runs under `swift test` on Linux CI. | Adopted |
| Share-link payload | Versioned from day one; CloudKit public DB vs. tiny redirect service | Spec §5. | Open — decide at M4 |
| CI | Linux container job (`swift:6.1`) for Core tests + SwiftLint job + macOS job (`macos-15`): CheerPlanUI/CheerPlanData `swift test`, XcodeGen project generation, simulator build of the app | Core is platform-agnostic and verified on every push; the macOS job proves the SwiftUI/MapKit/Charts and GRDB code compiles and passes tests. | Adopted |

## Roadmap (spec §7)

| Milestone | Deliverable | Status |
|---|---|---|
| **M1** | `CheerPlanCore`: models + GPX + ETA + snapping + feasibility + proposer + live estimator, fully tested on real GPX fixtures | **Done (PR #1)** |
| **M2** | App shell: import GPX (file/URL), course map + elevation, create/edit/duplicate runner plans, GRDB persistence | **This PR** |
| M3 | Supporter planning: spots, auto-propose, real MapKit routing, feasibility + fixes UI | — |
| M4 | Sharing: deep links + App Clip preview, `.cheerplan` fallback | — |
| M5 | Race day: live engine actor, persistence/resume, Live Activity, notifications | — |
| M6 | Multi-runner + crew assignments | — |

## Repository layout

```
CheerPlanV2/
├── CheerPlanCore/          # M1. SwiftPM package, Linux-testable.
│   ├── Package.swift
│   ├── Sources/CheerPlanCore/{Models,GPX,Geometry,Pacing,Feasibility,Propose,Live,Format}
│   └── Tests/CheerPlanCoreTests/  (+ Fixtures/)
├── CheerPlanData/          # M2. GRDB persistence behind the PlanStore protocol.
│   └── Sources/CheerPlanData/{Database,Stores}
├── CheerPlanUI/            # M2. Design system: theme, StatusPill, ElevationProfileView.
│   └── Sources/CheerPlanUI/{Theme,Components,Format}
├── App/                    # M2. XcodeGen project (project.yml) + SwiftUI app sources.
│   └── Sources/{Root,Runner,Course}  # one view per file
├── docs/                   # SPEC.md · DOMAIN.md · ARCHITECTURE.md
├── tools/                  # deterministic GPX fixture generator
└── .github/workflows/ci.yml
```

Generate the Xcode project locally with `xcodegen generate --spec App/project.yml --project App`
(`brew install xcodegen`), then open `App/CheerPlan.xcodeproj`. The `.xcodeproj` is
generated, never committed.
