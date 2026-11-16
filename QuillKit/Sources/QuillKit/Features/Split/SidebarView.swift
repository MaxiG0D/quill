import SwiftUI

/// The first column of the wide layout: mailboxes, labels and the account.
struct SidebarView: View {
    @Environment(MailStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
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
            .overlay(alignment: .top) {
                Palette.separator.frame(height: Metrics.hairline)
            }
        }
        .navigationTitle("")
    }
}
