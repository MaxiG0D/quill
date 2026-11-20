import SwiftUI

/// The compact layout's mailbox: a large title over dated cards of threads.
struct ThreadList: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    /// Set once the large title has scrolled under the navigation bar.
    @Binding var isTitleCovered: Bool
    /// The space to leave above the title, measured from the top of the screen.
    /// Without one, the list starts below the navigation bar as usual.
    var topMargin: Double?

    var body: some View {
        List {
            Button(action: showMailboxes) {
                MailboxTitle(title: store.title, count: store.unreadCount, opensMailboxes: true)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .accessibilityHint("Mailboxes")
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.xxs, bottom: Spacing.xxs, trailing: 0))

            switch store.phase {
            case .idle, .loading:
                Section {
                    ForEach(0..<6, id: \.self) { _ in
                        SkeletonRow()
                            .listRowBackground(Palette.surface)
                    }
                }
            case .failed:
                LoadFailedView()
                    .listRowBackground(Color.clear)
            case .loaded:
                ForEach(store.sections) { section in
                    Section {
                        ForEach(section.threads) { thread in
                            ThreadListRow(thread: thread, isPinned: section.kind == .pinned)
                        }
                    } header: {
                        SectionHeader(kind: section.kind)
                            .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.xxs, bottom: Spacing.xs, trailing: 0))
                    }
                }
            }
        }
        .cardListStyle()
        .scrollContentBackground(.hidden)
        .contentMargins(.top, topMargin ?? 0, for: .scrollContent)
        .ignoresSafeArea(.container, edges: topMargin == nil ? [] : .top)
        .overlay {
            if isEmpty {
                InboxZero()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            SyncProgressBar()
        }
        .animation(Motion.list, value: isEmpty)
        .animation(Motion.list, value: store.sections)
        .refreshable {
            await store.refresh()
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 52
        } action: { _, isCovered in
            isTitleCovered = isCovered
        }
    }

    private var isEmpty: Bool {
        store.isSettled && store.sections.isEmpty
    }

    private func showMailboxes() {
        router.isShowingMailboxes = true
    }
}
