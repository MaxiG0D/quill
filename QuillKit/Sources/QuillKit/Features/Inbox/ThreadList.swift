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

    @State private var isConfirmingEmptyTrash = false

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Button(action: showMailboxes) {
                    MailboxTitle(title: store.title, count: store.headerCount, opensMailboxes: true)
                        .contentShape(.rect)
                }
                .buttonStyle(.pressable)
                .accessibilityHint("Mailboxes")
                if store.isInbox && !store.inboxCategories.isEmpty {
                    CategoryTabs()
                        .padding(.bottom, Spacing.xxs)
                }
                HStack(spacing: Spacing.xs) {
                    if store.filter != .all {
                        Button {
                            withAnimation(Motion.list) { store.filter = .all }
                        } label: {
                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: store.filter.symbol)
                                    .font(.caption.weight(.semibold))
                                Text(store.filter.title)
                                    .textRole(.chip)
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, Spacing.s)
                            .padding(.vertical, Spacing.xxs + 1)
                            .background(Palette.accentTint, in: .capsule)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel("Clear \(store.filter.title) filter")
                    }
                    if store.selection == .mailbox(.trash) && !store.sections.isEmpty {
                        Button(role: .destructive) {
                            isConfirmingEmptyTrash = true
                        } label: {
                            Label("Empty Trash", systemImage: "trash.slash")
                                .textRole(.chip)
                                .foregroundStyle(Palette.destructive)
                                .padding(.horizontal, Spacing.s)
                                .padding(.vertical, Spacing.xxs + 2)
                                .background(Palette.destructive.opacity(0.12), in: .capsule)
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
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
                EmptyView()
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
                if store.hasMoreThreads {
                    Button {
                        Task { await store.loadMore() }
                    } label: {
                        Group {
                            if store.isLoadingMore {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Load More")
                                    .textRole(.meta)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Palette.accent)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: Metrics.target)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isLoadingMore)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .confirmationDialog(
            "Empty Trash?",
            isPresented: $isConfirmingEmptyTrash,
            titleVisibility: .visible
        ) {
            Button("Empty Trash", role: .destructive) {
                withAnimation(Motion.list) { store.emptyTrash() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Messages in Trash will be permanently deleted.")
        }
        .cardListStyle()
        .scrollContentBackground(.hidden)
        .contentMargins(.top, topMargin ?? 0, for: .scrollContent)
        .closesSwipeRowsOnScroll()
        .ignoresSafeArea(.container, edges: topMargin == nil ? [] : .top)
        .overlay {
            if case .failed = store.phase {
                LoadFailedView()
                    .transition(.opacity)
            } else if isLoadingEmpty {
                MailLoadingIndicator()
            } else if isEmpty {
                if store.filter != .all {
                    VStack(spacing: Spacing.s) {
                        Text("No \(store.filter.title.lowercased()) mail")
                            .textRole(.section)
                            .foregroundStyle(Palette.secondaryLabel)
                        Button("Show All") {
                            withAnimation(Motion.list) { store.filter = .all }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                } else {
                    InboxZero()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
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

    private var isLoadingEmpty: Bool {
        !store.isSettled && store.sections.isEmpty
    }

    private func showMailboxes() {
        router.isShowingMailboxes = true
    }
}
