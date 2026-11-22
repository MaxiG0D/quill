import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Full sender and recipient details for an expanded message, with tap-to-copy and compose.
struct MessageRecipientDetails: View {
    @Environment(Router.self) private var router: Router?

    let message: Message
    let dateText: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            row("From", contacts: [message.sender])
            if !message.to.isEmpty {
                row("To", contacts: message.to)
            }
            if !message.cc.isEmpty {
                row("Cc", contacts: message.cc)
            }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text("Date")
                    .textRole(.meta)
                    .foregroundStyle(Palette.secondaryLabel)
                    .frame(width: 38, alignment: .leading)
                Text(dateText)
                    .textRole(.meta)
                    .foregroundStyle(Palette.label)
            }
        }
        .padding(Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.fill.opacity(0.6), in: .rect(cornerRadius: Radius.small, style: .continuous))
    }

    private func row(_ label: String, contacts: [Contact]) -> some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Text(label)
                .textRole(.meta)
                .foregroundStyle(Palette.secondaryLabel)
                .frame(width: 38, alignment: .leading)
                .padding(.top, 2)
            FlowLayout(spacing: Spacing.xs) {
                ForEach(contacts) { contact in
                    Menu {
                        Button("Copy Address", systemImage: "doc.on.doc") {
                            copyAddress(contact.email)
                        }
                        if let router {
                            Button("New Message", systemImage: "square.and.pencil") {
                                router.draft = Draft(to: [contact])
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if !contact.name.isEmpty {
                                Text(contact.name)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Palette.label)
                            }
                            Text(contact.email)
                                .foregroundStyle(Palette.secondaryLabel)
                        }
                        .textRole(.meta)
                        .lineLimit(1)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Palette.surface, in: .capsule)
                    }
                    .menuIndicator(.hidden)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func copyAddress(_ email: String) {
        #if os(iOS)
        UIPasteboard.general.string = email
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(email, forType: .string)
        #endif
    }
}
