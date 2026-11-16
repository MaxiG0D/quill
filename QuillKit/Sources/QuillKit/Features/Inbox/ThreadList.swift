import SwiftUI

/// The compact layout's mailbox: a large title over dated cards of threads.
struct ThreadList: View {
    @Environment(MailStore.self) private var store

    /// Set once the large title has scrolled under the navigation bar.
    @Binding var isTitleCovered: Bool

    var body: some View {
        List {
            MailboxTitle(title: store.title, count: store.unreadCount)
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
        .contentMargins(.top, 0, for: .scrollContent)
        .overlay {
            if isEmpty {
                InboxZero()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(Motion.list, value: isEmpty)
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
        store.phase == .loaded && store.sections.isEmpty
    }
}
