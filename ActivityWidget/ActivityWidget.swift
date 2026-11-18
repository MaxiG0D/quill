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

/// A sign-in code at a glance, for a minute. Copy is on the alert; the ✕ closes it.
struct SignInCodeLiveActivity: Widget {
    private let teal = Color(red: 0x0B / 255, green: 0x6E / 255, blue: 0x69 / 255)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SignInCodeAttributes.self) { context in
            HStack(spacing: 12) {
                monogram(context.state.sender)
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
                    detail(context.state)
                }
                Spacer(minLength: 8)
                closeButton(context.state)
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
                    closeButton(context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    detail(context.state)
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

    /// Ends the code's Live Activity here and on every other device.
    private func closeButton(_ state: SignInCodeAttributes.ContentState) -> some View {
        Button(intent: CloseCodeIntent(code: state.code)) {
            Image(systemName: "xmark")
                .font(.footnote.weight(.bold))
                .frame(width: 30, height: 30)
                .background(.secondary.opacity(0.25), in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Close")
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

    /// What the email is about and how long the code lasts, in one quiet line.
    @ViewBuilder
    private func detail(_ state: SignInCodeAttributes.ContentState) -> some View {
        HStack(spacing: 6) {
            if let subject = state.subject, !subject.isEmpty {
                Text(subject)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let expiry = state.expiresAt.map({ Date(timeIntervalSince1970: $0) }), expiry > .now {
                Text(expiry, style: .timer)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 52, alignment: .trailing)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
