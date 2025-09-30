#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

struct EncounterEntry: TimelineEntry { let date: Date }

struct EncounterProvider: TimelineProvider {
    func placeholder(in context: Context) -> EncounterEntry { EncounterEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (EncounterEntry) -> ()) { completion(EncounterEntry(date: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<EncounterEntry>) -> ()) {
        let entries = [EncounterEntry(date: Date())]
        completion(Timeline(entries: entries, policy: .after(Date().addingTimeInterval(60))))
    }
}

struct EncounterComplicationEntryView: View {
    var entry: EncounterProvider.Entry
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "mic.fill")
            Text("NotedCore").font(.caption2)
        }
    }
}

@main
struct EncounterComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "EncounterComplication", provider: EncounterProvider()) { entry in
            EncounterComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("NotedCore")
        .description("Start/Stop from your watch.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#endif
