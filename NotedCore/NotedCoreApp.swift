import SwiftUI

@main
struct NotedCoreApp: App {
    // Keep the legacy singletons initializing at launch (parity), but the ROOT is now the offline
    // rearchitecture UI driven by NotedCoreKit.
    @StateObject private var appState = CoreAppState.shared
    @State private var shift = ShiftViewModel()

    var body: some Scene {
        WindowGroup {
            ShiftListView(model: shift)
        }
    }
}
