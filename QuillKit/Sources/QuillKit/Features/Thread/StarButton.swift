import SwiftUI

/// Toggles a thread's star, with a bounce when it changes.
struct StarButton: View {
    @Environment(MailStore.self) private var store

    let thread: MailThread

    var body: some View {
        Button(
            thread.isStarred ? "Remove Star" : "Star",
            systemImage: thread.isStarred ? "star.fill" : "star",
            action: toggle
        )
        .symbolEffect(.bounce, value: thread.isStarred)
        .contentTransition(.symbolEffect(.replace))
        .tint(thread.isStarred ? Palette.warm : Palette.accent)
    }

    private func toggle() {
        withAnimation(Motion.quick) {
            store.toggleStar(thread.id)
        }
    }
}
