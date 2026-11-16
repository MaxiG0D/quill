import SwiftUI

/// Turns new-mail notifications on and off. When the system has them blocked, turning
/// them on leads to the system's own settings, the only place that can unblock them.
struct NotificationSwitch: View {
    let notifier: MailNotifier
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        HStack {
            Text("New Mail")
                .foregroundStyle(Palette.label)
            Spacer(minLength: Spacing.s)
            Toggle("New Mail", isOn: Binding(get: { notifier.isOn }, set: change))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Palette.accent)
        }
        .task(id: scenePhase) {
            // Coming back from the system's settings may have changed the answer.
            await notifier.readPermission()
        }
    }

    private func change(_ isOn: Bool) {
        Task {
            if await !notifier.setOn(isOn), let url = SystemNotificationSettings.url {
                openURL(url)
            }
        }
    }
}

#Preview {
    NotificationSwitch(notifier: MailNotifier())
        .padding()
}
