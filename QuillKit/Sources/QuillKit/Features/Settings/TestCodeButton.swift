#if DEBUG
import SwiftUI

/// Debug builds only: sends this account's devices a made-up sign-in code through the push
/// relay, so the alert and the Live Activity can be tried without waiting for an email.
struct TestCodeButton: View {
    @Environment(AccountSession.self) private var session
    @State private var attempts = 0
    @State private var failed = false

    var body: some View {
        Button {
            Task {
                failed = await !session.sendTestCode()
                attempts += 1
            }
        } label: {
            HStack {
                Text("Test Code")
                    .foregroundStyle(Palette.label)
                Spacer(minLength: Spacing.s)
                Image(systemName: failed ? "exclamationmark.triangle" : "paperplane")
                    .foregroundStyle(failed ? Palette.warm : Palette.accent)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: attempts)
    }
}
#endif
