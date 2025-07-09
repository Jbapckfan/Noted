//
//  NotedCoreApp.swift
//  NotedCore
//
//  Created by James Alford on 7/9/25.
//

import SwiftUI

@main
struct NotedCoreApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
