import SwiftUI

/// Shown in place of an empty mailbox while its mail is still on the way, so it does not read as empty.
struct MailLoadingIndicator: View {
    var body: some View {
        ProgressView()
            .controlSize(.small)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .transition(.opacity)
            .accessibilityLabel("Loading mail")
    }
}
