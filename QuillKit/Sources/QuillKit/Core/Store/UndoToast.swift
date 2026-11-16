import Foundation

/// A short notice for the last triage action, with what is needed to reverse it.
struct UndoToast: Identifiable, Equatable, Sendable {
    let id = UUID()
    let title: String
    let symbol: String
    /// The threads as they were before the action.
    let previous: [MailThread]
}
