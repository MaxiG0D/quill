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
                Button(action: compose) {
                    Label("Compose Email", systemImage: "square.and.pencil")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Palette.onFill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Palette.warmFill, in: .rect(cornerRadius: Radius.medium))
                }
                .buttonStyle(.pressable)
                .padding(.bottom, Spacing.m)
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
