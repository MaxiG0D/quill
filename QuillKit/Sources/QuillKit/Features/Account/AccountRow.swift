import SwiftUI

/// The signed-in account in Settings, with the way out.
struct AccountRow: View {
    @Environment(AccountSession.self) private var session
    let account: Contact

    var body: some View {
        HStack(spacing: Spacing.s) {
            MonogramAvatar(account)
            VStack(alignment: .leading, spacing: 2) {
                if !account.name.isEmpty {
                    Text(account.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.label)
                }
                Text(account.email)
                    .font(account.name.isEmpty ? .body : .subheadline)
                    .foregroundStyle(account.name.isEmpty ? Palette.label : Palette.secondaryLabel)
            }
            .lineLimit(1)
            Spacer(minLength: Spacing.s)
            Button("Sign Out", role: .destructive, action: signOut)
                .buttonStyle(.bordered)
        }
        .accessibilityElement(children: .contain)
    }

    private func signOut() {
        Task {
            await session.signOut()
        }
    }
}

#Preview {
    AccountRow(account: SampleData.account)
        .environment(AccountSession())
        .padding()
}
