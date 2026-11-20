import SwiftUI

/// A thread in the wide layout's list column. Selected rows sit on the accent tint.
struct ThreadColumnRow: View {
    @Environment(MailStore.self) private var store

    let thread: MailThread
    var query = ""
    var excerpt: String?

    var body: some View {
        Button(action: select) {
            MailRow(thread: thread, avatarSize: avatarSize, query: query, excerpt: excerpt)
                .padding(Spacing.s)
                .background(background, in: .rect(cornerRadius: Radius.medium))
        }
        .buttonStyle(.plain)
        .contextMenu {
            ThreadActions(thread: thread)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(Motion.quick, value: isSelected)
        #if !os(macOS)
        .modifier(RowSwipe(thread: thread))
        #endif
    }

    private var isSelected: Bool {
        store.selectedThreadID == thread.id
    }

    private var background: Color {
        isSelected ? Palette.accentTint : .clear
    }

    private var avatarSize: MonogramAvatar.Size {
        #if os(macOS)
        .compact
        #else
        .medium
        #endif
    }

    private func select() {
        store.select(thread.id)
    }
}

#if !os(macOS)
/// The wide layout's rows live in a scroll view, not a List, so they get no system swipe actions.
/// This follows the finger like List does: a full swipe left archives (the row slides off), a
/// swipe right toggles read.
private struct RowSwipe: ViewModifier {
    @Environment(MailStore.self) private var store

    let thread: MailThread

    @State private var offset = 0.0
    @State private var width = 320.0
    @State private var decided = false
    @State private var horizontal = false

    private let trigger = 110.0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background { backdrop }
            .onGeometryChange(for: Double.self) { $0.size.width } action: { width = $0 }
            .simultaneousGesture(drag)
    }

    private var backdrop: some View {
        let archiving = offset < 0
        return ZStack(alignment: archiving ? .trailing : .leading) {
            RoundedRectangle(cornerRadius: Radius.medium).fill(Palette.accentFill)
            Image(systemName: archiving ? "archivebox" : (thread.isUnread ? "envelope.open" : "envelope.badge"))
                .font(.title3)
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.m)
        }
        .opacity(offset == 0 ? 0 : 1)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                if !decided {
                    decided = true
                    horizontal = abs(value.translation.width) > abs(value.translation.height) * 1.5
                }
                if horizontal { offset = value.translation.width }
            }
            .onEnded { value in
                defer { decided = false; horizontal = false }
                guard horizontal else { return }
                let thrown = value.predictedEndTranslation.width
                if value.translation.width < -trigger || thrown < -width / 2 {
                    archive()
                } else if value.translation.width > trigger {
                    withAnimation(Motion.quick) { store.toggleUnread(thread.id) }
                    withAnimation(Motion.expand) { offset = 0 }
                } else {
                    withAnimation(Motion.expand) { offset = 0 }
                }
            }
    }

    private func archive() {
        if store.archiveRemovesRow {
            withAnimation(Motion.list) { offset = -width }
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                store.archive(thread.id)
            }
        } else {
            store.archive(thread.id)
            withAnimation(Motion.expand) { offset = 0 }
        }
    }
}
#endif
