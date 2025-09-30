import SwiftUI

struct ReminderBannerView: View {
    @ObservedObject var tracker = KeyUtteranceTracker.shared
    @State private var now: Date = Date()
    
    var body: some View {
        let due = dueReminders()
        if due.isEmpty { EmptyView() } else {
            let item = due.first!
            HStack(spacing: 10) {
                Image(systemName: "bell.badge.fill").foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reminder: \(item.title)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    if let due = item.detailDueString { Text(due).font(.system(size: 11)).foregroundColor(.white.opacity(0.8)) }
                }
                Spacer()
                Button("Snooze 5m") { snooze(item, minutes: 5) }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(Color.gray.opacity(0.3)).foregroundColor(.white).cornerRadius(6)
                Button("Done") { KeyUtteranceTracker.shared.markCompleted(item) }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(Color.green).foregroundColor(.white).cornerRadius(6)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .onAppear { startTimer() }
        }
    }
    
    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            now = Date()
        }
    }
    
    private func dueReminders() -> [KeyUtteranceTracker.ActionItem] {
        return tracker.items.filter { $0.shouldRemind }
    }
    
    private func snooze(_ item: KeyUtteranceTracker.ActionItem, minutes: Int) {
        KeyUtteranceTracker.shared.snooze(item, minutes: minutes)
    }
}

private extension KeyUtteranceTracker.ActionItem {
    var detailDueString: String? { return nil }
    var shouldRemind: Bool {
        return !completed && (dueDate != nil && Date() >= dueDate!)
    }
}

