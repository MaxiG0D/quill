import SwiftUI

/// Gmail's inbox tabs as a row of capsules under the Inbox title. Absent when the
/// account does not sort its mail into tabs.
struct CategoryTabs: View {
    @Environment(MailStore.self) private var store

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(store.inboxCategories) { category in
                    let isOn = store.category == category
                    Button {
                        withAnimation(Motion.list) { store.show(category) }
                    } label: {
                        Text(category.title)
                            .textRole(.chip)
                            .foregroundStyle(isOn ? Palette.onFill : Palette.secondaryLabel)
                            .padding(.horizontal, Spacing.s)
                            .padding(.vertical, Spacing.xxs + 2)
                            .background(isOn ? Palette.accentFill : Palette.fill, in: .capsule)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }
}
