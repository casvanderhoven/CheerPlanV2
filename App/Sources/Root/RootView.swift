import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            PlanListView()
        }
        .task {
            if let startupError = appState.startupError {
                appState.errorMessage = startupError
            }
            await appState.loadPlans()
        }
        .alert("Something went wrong", isPresented: errorPresented) {
            Button("OK", role: .cancel) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { appState.errorMessage != nil },
            set: { presented in
                if !presented {
                    appState.errorMessage = nil
                }
            }
        )
    }
}

#Preview {
    RootView()
        .environment(AppState(dependencies: .preview()))
}
