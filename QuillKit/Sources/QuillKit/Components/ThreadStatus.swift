import SwiftUI

/// The trailing end of a row's first line: star, snooze clock and time.
struct ThreadStatus: View {
    @Environment(MailStore.self) private var store

    let thread: MailThread

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs + 2) {
            if thread.isStarred {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(Palette.warm)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Starred")
            }
            if thread.hasReturned(at: store.now) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryLabel)
                    .accessibilityLabel("Back from snooze")
            }
            Text(store.timestamp.short(thread.date))
                .textRole(.meta)
                .fontWeight(thread.isUnread ? .semibold : .regular)
                .foregroundStyle(thread.isUnread ? Palette.accent : Palette.secondaryLabel)
        }
        .animation(Motion.quick, value: thread.isStarred)
    }
}
