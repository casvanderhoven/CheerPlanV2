import CheerPlanData
import SwiftUI

@main
struct CheerPlanApp: App {
    @State private var appState: AppState

    init() {
        let dependencies = Dependencies.live()
        _appState = State(initialValue: AppState(dependencies: dependencies))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .onOpenURL { url in
                    Task { await appState.handleIncomingURL(url) }
                }
        }
    }
}
