import SwiftUI
import WatchConnectivity
#if os(watchOS)
import WatchKit
#endif

@main
struct NotedWatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager.shared
    @StateObject private var voiceHandler = VoiceCommandHandler.shared
    
    init() {
        // Configure app appearance
        configureAppearance()
        
        // Initialize services
        initializeServices()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .environmentObject(voiceHandler)
                .onAppear {
                    setupWatchConnectivity()
                }
        }
    }
    
    private func configureAppearance() {
        // Navigation bar appearance is not available on watchOS
        #if !os(watchOS)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        UIView.appearance().tintColor = UIColor.systemBlue
        #endif
    }
    
    private func initializeServices() {
        // Initialize Watch Connectivity
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = sessionManager
            session.activate()
        }
        
        // Set up voice handler with session manager
        voiceHandler.setSessionManager(sessionManager)
        
        print("✅ NotedWatch App initialized")
        print("📱 Watch Connectivity: \(WCSession.isSupported() ? "Supported" : "Not Supported")")
    }
    
    private func setupWatchConnectivity() {
        // Request initial status from iPhone
        if sessionManager.isReachable {
            print("📱 iPhone is reachable, requesting status...")
        } else {
            print("📱 iPhone not reachable, waiting for connection...")
        }
    }
}