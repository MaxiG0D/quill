import SwiftUI

/// The first column of the wide layout: Compose on the Mac, then mailboxes, labels and the account.
struct SidebarView: View {
    @Environment(MailStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                // iPad keeps Compose floating over the list, within the thumb's reach.
                #if os(macOS)
                // Laid out as a sidebar row, so it lines up with the mailboxes below it.
                Button(action: compose) {
                    HStack(spacing: Spacing.s) {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text("Compose Email")
                            .font(.title3.weight(.medium))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Palette.warm)
                    .padding(.horizontal, Spacing.s)
                    .frame(minHeight: Metrics.target + 8)
                    .background(Palette.warm.opacity(0.12), in: .rect(cornerRadius: Radius.small))
                    .contentShape(.rect)
                }
                .buttonStyle(.pressable)
                .padding(.bottom, Spacing.xs)
                #endif
                MailboxRows()
                Text("Labels")
                    .textRole(.section)
                    .foregroundStyle(Palette.label)
                    .padding(.leading, Spacing.s)
                    .padding(.top, Spacing.l)
                    .padding(.bottom, Spacing.xxs)
                    .accessibilityAddTraits(.isHeader)
                LabelRows()
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: Spacing.s) {
                MonogramAvatar(store.account, size: .small)
                Text(store.account.displayName)
                    .font(.body)
                    .foregroundStyle(Palette.label)
                Spacer()
                SettingsButton()
            }
            .padding(.leading, Spacing.m)
            .padding(.trailing, Spacing.xs)
            .padding(.vertical, Spacing.s)
            // Opaque enough that the labels scrolling underneath never show through the name.
            .background(.bar)
            .overlay(alignment: .top) {
                Palette.separator.frame(height: Metrics.hairline)
            }
        }
        .navigationTitle("")
    }

    private func compose() {
        router.draft = Draft()
    }
}
