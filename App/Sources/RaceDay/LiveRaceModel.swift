import CheerPlanCore
import CheerPlanData
import CheerPlanUI
import Foundation
import Observation

/// Race-day screen model: a thin, main-actor face over the `LiveRaceEngine`
/// actor. Every mutation goes through the engine (which persists the event log
/// before returning), then refreshes the snapshot, the scheduled notification,
/// and the Live Activity.
@MainActor
@Observable
final class LiveRaceModel: Identifiable {
    let id = UUID()
    let runnerPlan: RunnerPlan
    let itinerary: SupporterItinerary

    private let engine: LiveRaceEngine
    private let notifications = NotificationScheduler()
    private let liveActivity = LiveActivityController()

    private(set) var snapshot: RaceSnapshot?
    private(set) var isEnded = false
    var errorMessage: String?

    init(engine: LiveRaceEngine, runnerPlan: RunnerPlan, itinerary: SupporterItinerary) {
        self.engine = engine
        self.runnerPlan = runnerPlan
        self.itinerary = itinerary
    }

    func start() async {
        _ = await notifications.requestAuthorization()
        await tick()
        liveActivity.start(runnerName: runnerPlan.name, state: contentState())
        await rescheduleLeaveAlert()
    }

    /// Called once a second by the view's refresh loop.
    func tick() async {
        snapshot = await engine.snapshot(at: Date())
    }

    /// "Runner passed me" — a check-in at the next spot's course distance.
    func runnerPassedNextSpot() async {
        guard let index = snapshot?.nextLegIndex, itinerary.legs.indices.contains(index) else { return }
        let distance = itinerary.legs[index].destination.courseDistance
        await record(RunnerObservation(courseDistance: distance, timestamp: Date(), source: .checkIn))
    }

    func recalibrate(toDistance distance: Double) async {
        await record(RunnerObservation(courseDistance: distance, timestamp: Date(), source: .recalibration))
    }

    func endRace() async {
        do {
            try await engine.end()
        } catch {
            errorMessage = "Couldn't close the race session: \(error.localizedDescription)"
        }
        await notifications.cancelLeaveAlerts()
        await liveActivity.end()
        isEnded = true
    }

    /// "Leave now — 12 min drive NE to km 15.2 · runner ~10:42"
    func instruction(forLegAt index: Int, leaveNow: Bool) -> String {
        guard itinerary.legs.indices.contains(index) else { return "" }
        let leg = itinerary.legs[index]
        let minutes = max(1, Int((leg.estimate.duration / 60).rounded()))
        let bearing = leg.origin.coordinate.bearing(toward: leg.destination.coordinate)
        let direction = Formatters.compass(bearing: bearing)
        let mode = leg.estimate.mode.displayName.lowercased()
        let spot = spotLabel(forLegAt: index)
        let arrival = snapshot?.projectedArrivals.indices.contains(index) == true
            ? snapshot?.projectedArrivals[index] ?? leg.runnerArrival
            : leg.runnerArrival
        let prefix = leaveNow ? "Leave now — " : ""
        return "\(prefix)\(minutes) min \(mode) \(direction) to \(spot) · runner ~\(LocalizedFormatters.time(arrival))"
    }

    func spotLabel(forLegAt index: Int) -> String {
        guard itinerary.legs.indices.contains(index) else { return "" }
        let destination = itinerary.legs[index].destination
        return destination.name.isEmpty ? Formatters.distance(destination.courseDistance) : destination.name
    }

    // MARK: - Internals

    private func record(_ observation: RunnerObservation) async {
        do {
            try await engine.record(observation)
        } catch {
            errorMessage = "Couldn't persist that update (\(error.localizedDescription)) — "
                + "it applies now but may be lost if the app closes."
        }
        await tick()
        await rescheduleLeaveAlert()
        await liveActivity.update(state: contentState())
    }

    private func rescheduleLeaveAlert() async {
        guard let snapshot, let index = snapshot.nextLegIndex, let leaveBy = snapshot.leaveBy else {
            await notifications.cancelLeaveAlerts()
            return
        }
        do {
            try await notifications.scheduleLeaveAlert(
                legIndex: index,
                title: "Time to move",
                body: instruction(forLegAt: index, leaveNow: true),
                at: leaveBy
            )
        } catch {
            errorMessage = "Couldn't schedule the leave reminder: \(error.localizedDescription)"
        }
    }

    private func contentState() -> RaceActivityAttributes.ContentState? {
        guard let snapshot, let index = snapshot.nextLegIndex, let leaveBy = snapshot.leaveBy else { return nil }
        let isGo: Bool
        if case .go = snapshot.phase {
            isGo = true
        } else {
            isGo = false
        }
        return RaceActivityAttributes.ContentState(
            nextSpotLabel: spotLabel(forLegAt: index),
            leaveBy: leaveBy,
            runnerArrival: snapshot.projectedArrivals[index],
            isGo: isGo,
            instruction: instruction(forLegAt: index, leaveNow: isGo)
        )
    }
}
