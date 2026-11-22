import SwiftUI

/// Configures the email signature automatically appended to outgoing mail.
struct SignatureSettingsCard: View {
    @Bindable var preferences: MailPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Toggle(isOn: $preferences.signatureEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Email Signature")
                        .font(.body)
                        .foregroundStyle(Palette.label)
                    Text("Added automatically to new messages and replies.")
                        .textRole(.meta)
                        .foregroundStyle(Palette.secondaryLabel)
                }
            }
            if preferences.signatureEnabled {
                TextEditor(text: $preferences.signature)
                    .font(.callout)
                    .foregroundStyle(Palette.label)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.xs)
                    .frame(minHeight: 72, maxHeight: 120)
                    .background(Palette.fill, in: .rect(cornerRadius: Radius.small))
                    .overlay(alignment: .topLeading) {
                        if preferences.signature.isEmpty {
                            Text("Sent from Quill")
                                .font(.callout)
                                .foregroundStyle(Palette.tertiaryLabel)
                                .padding(Spacing.s)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
    }
}
