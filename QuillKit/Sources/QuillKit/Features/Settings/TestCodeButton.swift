#if DEBUG
import SwiftUI

/// Lets the app target start a Live Activity on this device without the relay, for the Test Code button.
public enum LiveActivityTest {
    /// Starts one, and returns what went wrong, or nil when it started.
    @MainActor public static var start: (@MainActor () -> String?)?
}

/// Debug builds only: sends this account's devices a made-up sign-in code through the push
/// relay, so the alert and the Live Activity can be tried without waiting for an email.
struct TestCodeButton: View {
    @Environment(AccountSession.self) private var session
    @State private var attempts = 0
    @State private var failed = false
    @State private var errorMessage: String?

    var body: some View {
        let trace = (UserDefaults.standard.stringArray(forKey: "liveActivityTrace") ?? []).joined(separator: "\n")
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                Task {
                    let localError = LiveActivityTest.start?()
                    let pushed = await session.sendTestCode()
                    errorMessage = localError
                    failed = !pushed || localError != nil
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
            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Palette.destructive)
            }
            if !trace.isEmpty {
                Text(trace)
                    .font(.caption.monospaced())
                    .foregroundStyle(Palette.secondaryLabel)
                    .id(attempts)
            }
        }
    }
}
#endif
