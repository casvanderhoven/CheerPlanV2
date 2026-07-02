import ActivityKit
import SwiftUI
import WidgetKit

/// The race-day Live Activity: lock screen + Dynamic Island. The countdown is a
/// native timer text, so it ticks without any updates from the app.
struct RaceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RaceActivityAttributes.self) { context in
            lockScreen(context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.isGo ? "Leave now" : "Leave in")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        countdown(to: context.state.leaveBy)
                            .font(.title3.bold().monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Next: \(context.state.nextSpotLabel)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.state.runnerArrival, style: .time)
                            .font(.title3.bold())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.instruction)
                        .font(.caption)
                        .lineLimit(2)
                }
            } compactLeading: {
                Image(systemName: context.state.isGo ? "exclamationmark.triangle.fill" : "figure.run")
            } compactTrailing: {
                countdown(to: context.state.leaveBy)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: context.state.isGo ? "exclamationmark.triangle.fill" : "figure.run")
            }
        }
    }

    private func lockScreen(_ context: ActivityViewContext<RaceActivityAttributes>) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.isGo ? "Leave now for \(context.state.nextSpotLabel)" : "Next: \(context.state.nextSpotLabel)")
                    .font(.headline)
                countdown(to: context.state.leaveBy)
                    .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(context.attributes.runnerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("runner ~")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(context.state.runnerArrival, style: .time)
                    .font(.title3.bold())
            }
        }
        .padding()
    }

    private func countdown(to date: Date) -> some View {
        Text(timerInterval: Date.now...max(Date.now.addingTimeInterval(1), date), countsDown: true)
    }
}
