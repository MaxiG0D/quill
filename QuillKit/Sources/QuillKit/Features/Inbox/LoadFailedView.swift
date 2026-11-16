import SwiftUI

/// Shown when mail could not be loaded and there is nothing cached to show instead.
struct LoadFailedView: View {
    @Environment(MailStore.self) private var store

    var body: some View {
        ContentUnavailableView {
            Label("Couldn’t Load Mail", systemImage: "wifi.exclamationmark")
        } description: {
            // The service's own words: the only clue to what went wrong.
            if case .failed(let reason) = store.phase {
                Text(reason)
                    .textSelection(.enabled)
            }
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(Palette.accentFill)
        }
    }

    private func retry() {
        Task { await store.load() }
    }
}
