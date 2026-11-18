#if os(iOS)
import SwiftUI

/// Turns the sign-in code Live Activity on and off, and tells the push relay at once.
struct LiveActivitySwitch: View {
    @Environment(AccountSession.self) private var session
    @AppStorage(LiveActivitySetting.key) private var isOn = true

    var body: some View {
        HStack {
            Text("Live Activity")
                .foregroundStyle(Palette.label)
            Spacer(minLength: Spacing.s)
            Toggle("Live Activity", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Palette.accent)
        }
        .onChange(of: isOn) {
            Task { await session.liveActivityChanged() }
        }
    }
}
#endif
