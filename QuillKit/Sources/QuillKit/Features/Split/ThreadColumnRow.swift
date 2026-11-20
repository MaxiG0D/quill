import SwiftUI

/// A thread in the wide layout's list column. Selected rows sit on the accent tint.
struct ThreadColumnRow: View {
    @Environment(MailStore.self) private var store

    let thread: MailThread
    /// The row whose swipe buttons are showing; one at a time.
    @Binding var openID: MailThread.ID?
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
        .modifier(RowSwipe(thread: thread, openID: $openID))
        #endif
        .transition(.asymmetric(insertion: .identity, removal: .opacity))
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
        openID = nil
        store.select(thread.id)
    }
}

#if !os(macOS)
/// The wide layout's rows live in a scroll view, not a List, so they get no system swipe actions.
/// This follows the finger like List does. Swipe left: Archive and Delete show and stay open, and
/// a full swipe slides the row off and archives. Swipe right: Read and Pin, and a full swipe
/// toggles read.
private struct RowSwipe: ViewModifier {
    @Environment(MailStore.self) private var store

    let thread: MailThread
    @Binding var openID: MailThread.ID?

    @State private var offset = 0.0
    @State private var width = 320.0
    @State private var decided = false
    @State private var horizontal = false
    @State private var base = 0.0

    private let button = 76.0
    private var reveal: Double { button * 2 }
    private var full: Double { max(width * 0.55, reveal + 60) }

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(offset == 0)
            .overlay {
                if offset != 0 {
                    Color.clear.contentShape(.rect).onTapGesture { close() }
                }
            }
            .offset(x: offset)
            .background { backdrop }
            .onGeometryChange(for: Double.self) { $0.size.width } action: { width = $0 }
            .simultaneousGesture(drag)
            .onChange(of: openID) { _, id in
                if id != thread.id, offset != 0 { close(clearing: false) }
            }
    }

    private var backdrop: some View {
        HStack(spacing: 0) {
            if offset > 0 {
                action(thread.isUnread ? "Read" : "Unread", thread.isUnread ? "envelope.open" : "envelope.badge", Palette.accentFill) {
                    withAnimation(Motion.quick) { store.toggleUnread(thread.id) }
                    close()
                }
                action(thread.isPinned ? "Unpin" : "Pin", thread.isPinned ? "pin.slash" : "pin", Palette.warmFill) {
                    withAnimation(Motion.list) { store.togglePin(thread.id) }
                    close()
                }
                Spacer(minLength: 0)
            } else if offset < 0 {
                Spacer(minLength: 0)
                action("Archive", "archivebox", Palette.accentFill) { slideOff(removes: store.archiveRemovesRow) { store.archive(thread.id) } }
                action("Delete", "trash", Palette.destructiveFill) { slideOff(removes: true) { store.trash(thread.id) } }
            }
        }
        .clipShape(.rect(cornerRadius: Radius.medium))
    }

    private func action(_ title: String, _ symbol: String, _ tint: Color, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption2)
            }
            .foregroundStyle(.white)
            .frame(width: button)
            .frame(maxHeight: .infinity)
            .background(tint)
        }
        .buttonStyle(.plain)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                if !decided {
                    decided = true
                    horizontal = abs(value.translation.width) > abs(value.translation.height) * 1.5
                    base = offset
                    if horizontal { openID = nil }
                }
                if horizontal { offset = base + value.translation.width }
            }
            .onEnded { value in
                defer { decided = false; horizontal = false }
                guard horizontal else { return }
                let end = base + value.translation.width
                let thrown = base + value.predictedEndTranslation.width
                if end < -full || thrown < -width * 0.6 {
                    slideOff(removes: store.archiveRemovesRow) { store.archive(thread.id) }
                } else if end > full {
                    withAnimation(Motion.quick) { store.toggleUnread(thread.id) }
                    close()
                } else if end < -reveal / 2 {
                    rest(at: -reveal)
                } else if end > reveal / 2 {
                    rest(at: reveal)
                } else {
                    close()
                }
            }
    }

    private func rest(at target: Double) {
        withAnimation(Motion.expand) { offset = target }
        openID = thread.id
    }

    private func close(clearing: Bool = true) {
        withAnimation(Motion.expand) { offset = 0 }
        if clearing, openID == thread.id { openID = nil }
    }

    /// Slides the row off with the finger's momentum, then removes it in an animation so the rows
    /// below glide up. A row that stays in this list (a label, Starred) springs back instead.
    private func slideOff(removes: Bool, _ change: @escaping () -> Void) {
        guard removes else {
            change()
            close()
            return
        }
        withAnimation(Motion.list) { offset = -width }
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(Motion.list) { change() }
        }
    }
}
#endif
