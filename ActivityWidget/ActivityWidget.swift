import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct QuillActivityBundle: WidgetBundle {
    var body: some Widget {
        SignInCodeLiveActivity()
    }
}

/// A sign-in code, with a Copy button, for as long as it is worth showing.
struct SignInCodeLiveActivity: Widget {
    private let teal = Color(red: 0x0B / 255, green: 0x6E / 255, blue: 0x69 / 255)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SignInCodeAttributes.self) { context in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.sender)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.85)
                        .layoutPriority(1)
                    Text(context.state.display)
                        .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 8)
                copyButton(context.state)
            }
            .padding(16)
            .opacity(context.isStale ? 0.5 : 1)
            .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    monogram(context.state.sender)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.display)
                        .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    copyButton(context.state)
                }
            } compactLeading: {
                Image(systemName: "key.fill")
                    .foregroundStyle(teal)
            } compactTrailing: {
                Text(context.state.code)
                    .font(.system(.body, design: .rounded).monospacedDigit().weight(.semibold))
            } minimal: {
                Image(systemName: "key.fill")
                    .foregroundStyle(teal)
            }
        }
    }

    /// The sender's first letter on a soft teal disc, the same mark Quill's mail list uses.
    private func monogram(_ sender: String) -> some View {
        Text(sender.first.map { String($0).uppercased() } ?? "?")
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(teal)
            .frame(width: 44, height: 44)
            .background(teal.opacity(0.18), in: .circle)
            .accessibilityHidden(true)
    }

    private func copyButton(_ state: SignInCodeAttributes.ContentState) -> some View {
        Button(intent: CopyCodeIntent(code: state.code)) {
            Image(systemName: "doc.on.doc")
                .font(.headline)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(teal, in: .circle)
        .accessibilityLabel("Copy code")
    }
}
