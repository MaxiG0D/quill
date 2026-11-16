import SwiftUI

/// A hairline along the top of the mailbox that fills as mail arrives, and goes once it is all here.
struct SyncProgressBar: View {
    @Environment(MailStore.self) private var store

    var body: some View {
        ZStack {
            if let progress = store.syncProgress {
                Capsule()
                    .fill(Palette.accentTint)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Palette.accent)
                            // A sliver shows from the start, so the bar reads as moving before the first mail lands.
                            .containerRelativeFrame(.horizontal) { width, _ in
                                width * max(0.04, min(progress, 1))
                            }
                    }
                    .frame(height: 3)
                    .clipShape(.capsule)
                    .padding(.horizontal, Spacing.s)
                    .transition(.opacity)
                    .accessibilityElement()
                    .accessibilityLabel("Loading mail")
                    .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
            }
        }
        .animation(Motion.scene, value: store.syncProgress)
        .allowsHitTesting(false)
    }
}
