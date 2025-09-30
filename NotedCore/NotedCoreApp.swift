import SwiftUI

@main
struct NotedCoreApp: App {
    @StateObject private var appState = CoreAppState.shared
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @StateObject private var persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}
