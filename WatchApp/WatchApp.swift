import SwiftUI

@main
struct NotedCoreWatchApp: App {
    @StateObject var encounterManager = WatchEncounterManager.shared
    
    var body: some Scene {
        WindowGroup { 
            WatchMainView()
                .environmentObject(encounterManager)
        }
    }
}

