import SwiftUI

/// The first column of the wide layout: the app mark, mailboxes, labels and the account.
struct SidebarView: View {
    @Environment(MailStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                AppMark()
                    .padding(.leading, Spacing.xs)
                    .padding(.bottom, Spacing.m)
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
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .overlay(alignment: .top) {
                Palette.separator.frame(height: Metrics.hairline)
            }
            .accessibilityElement(children: .combine)
        }
        .navigationTitle("")
    }
}
