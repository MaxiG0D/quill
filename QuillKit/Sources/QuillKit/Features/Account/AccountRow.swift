import AuthenticationServices
import SwiftUI

/// Signed-in Google accounts in Settings, with account switching, adding, and sign-out.
struct AccountRow: View {
    @Environment(AccountSession.self) private var session
    @Environment(Router.self) private var router: Router?
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    let account: Contact

    @State private var signingOutRecord: AccountRecord?
    @State private var isConfirmingDefaultSignOut = false
    @State private var isBusy = false

    private var records: [AccountRecord] {
        session.accounts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if records.isEmpty {
                singleAccountRow(
                    contact: account,
                    isActive: true,
                    onSelect: nil,
                    onSignOut: { isConfirmingDefaultSignOut = true }
                )
            } else {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    if index > 0 {
                        Divider().overlay(Palette.separator)
                    }
                    let isActive = record.id == session.activeAccountID
                    singleAccountRow(
                        contact: record.contact,
                        isActive: isActive,
                        onSelect: isActive ? nil : { switchTo(record.id) },
                        onSignOut: { signingOutRecord = record }
                    )
                }
            }

            Divider().overlay(Palette.separator)

            Button {
                addAccount()
            } label: {
                HStack(spacing: Spacing.s) {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                        .foregroundStyle(Palette.accent)
                    Text("Add Another Account")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Palette.accent)
                    Spacer()
                    if session.isSigningIn {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(isBusy || session.isSigningIn)
        }
        .accessibilityElement(children: .contain)
        .confirmationDialog(
            "Sign out of \(signingOutRecord?.email ?? account.email)?",
            isPresented: isConfirmingRecordSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                if let id = signingOutRecord?.id {
                    signOut(accountID: id)
                }
            }
            Button("Cancel", role: .cancel) { signingOutRecord = nil }
        } message: {
            Text("Mail for this account will be removed from this device until you sign in again.")
        }
        .confirmationDialog(
            "Sign out of \(account.email)?",
            isPresented: $isConfirmingDefaultSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) { signOut(accountID: nil) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your mail will be removed from this device until you sign in again.")
        }
    }

    private func singleAccountRow(
        contact: Contact,
        isActive: Bool,
        onSelect: (() -> Void)?,
        onSignOut: @escaping () -> Void
    ) -> some View {
        HStack(spacing: Spacing.s) {
            Group {
                if let onSelect {
                    Button(action: onSelect) {
                        accountIdentity(contact: contact, isActive: isActive)
                    }
                    .buttonStyle(.plain)
                    .disabled(isBusy)
                } else {
                    accountIdentity(contact: contact, isActive: isActive)
                }
            }
            Spacer(minLength: Spacing.s)
            Button("Sign Out", role: .destructive, action: onSignOut)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isBusy)
        }
    }

    private func accountIdentity(contact: Contact, isActive: Bool) -> some View {
        HStack(spacing: Spacing.s) {
            MonogramAvatar(contact)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    if !contact.name.isEmpty {
                        Text(contact.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Palette.label)
                            .lineLimit(1)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.85)
                            .layoutPriority(1)
                    }
                    if isActive && records.count > 1 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Palette.accent)
                            .accessibilityLabel("Active account")
                    }
                }
                Text(contact.email)
                    .font(contact.name.isEmpty ? .body : .subheadline)
                    .foregroundStyle(contact.name.isEmpty ? Palette.label : Palette.secondaryLabel)
                    .lineLimit(1)
            }
        }
        .contentShape(.rect)
    }

    private var isConfirmingRecordSignOut: Binding<Bool> {
        Binding(
            get: { signingOutRecord != nil },
            set: { if !$0 { signingOutRecord = nil } }
        )
    }

    private func switchTo(_ id: String) {
        guard !isBusy else { return }
        isBusy = true
        Task {
            router?.reset()
            await session.switchAccount(to: id)
            isBusy = false
        }
    }

    private func addAccount() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            router?.reset()
            await session.addAccount(using: webAuthenticationSession)
            isBusy = false
        }
    }

    private func signOut(accountID: String?) {
        guard !isBusy else { return }
        isBusy = true
        let isRemovingActive = accountID == nil || accountID == session.activeAccountID
        Task {
            if isRemovingActive {
                router?.reset()
            }
            await session.signOut(accountID: accountID)
            signingOutRecord = nil
            isBusy = false
        }
    }
}

#Preview {
    AccountRow(account: SampleData.account)
        .environment(AccountSession())
        .padding()
}
