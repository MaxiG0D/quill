import SwiftUI

/// Narrows the list to unread, starred or attachment mail.
struct FilterMenu: View {
    @Environment(MailStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Menu {
            Picker("Filter", selection: $store.filter.animation(Motion.list)) {
                ForEach(InboxFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.symbol)
                        .tag(filter)
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease")
                .symbolVariant(store.filter == .all ? .none : .circle.fill)
        }
        .tint(Palette.accent)
    }
}
