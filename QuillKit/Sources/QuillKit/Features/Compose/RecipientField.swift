import SwiftUI

/// A To or Cc line: recipient tokens, a field for typing more, and suggestions from known contacts.
struct RecipientField: View {
    @Environment(MailStore.self) private var store

    let title: String
    @Binding var recipients: [Contact]

    @State private var entry = ""
    @State private var selectedID: Contact.ID?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(Palette.secondaryLabel)
                    .frame(minWidth: 28, alignment: .leading)
                FlowLayout(flexibleTrailingMinWidth: isFocused || recipients.isEmpty ? 96 : 2) {
                    ForEach(recipients) { contact in
                        RecipientToken(contact: contact, isSelected: selectedID == contact.id) {
                            tap(contact)
                        }
                    }
                    TextField(title, text: $entry, prompt: Text(verbatim: ""))
                        .font(.callout)
                        .focused($isFocused)
                        .emailEntry()
                        .submitLabel(.next)
                        .onSubmit(commit)
                        .frame(minHeight: 32)
                }
            }
            .padding(.vertical, Spacing.xs)
            .frame(minHeight: 50)
            .contentShape(.rect)
            .onTapGesture(perform: focus)

            ForEach(suggestions) { contact in
                Button {
                    add(contact)
                } label: {
                    HStack(spacing: Spacing.s) {
                        MonogramAvatar(contact, size: .compact)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(contact.displayName)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(Palette.label)
                            Text(contact.email)
                                .font(.footnote)
                                .foregroundStyle(Palette.secondaryLabel)
                        }
                        Spacer()
                    }
                    .padding(.vertical, Spacing.xs)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .animation(Motion.quick, value: recipients)
        .animation(Motion.quick, value: selectedID)
        .animation(Motion.quick, value: suggestions)
        .onChange(of: entry) {
            commitIfSeparated()
        }
        .onChange(of: isFocused) {
            if !isFocused {
                commit()
                selectedID = nil
            }
        }
    }

    /// Known contacts matching what has been typed, leaving out anyone already added.
    private var suggestions: [Contact] {
        let text = entry.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return [] }
        return store.knownContacts
            .filter { !recipients.contains($0) }
            .filter { $0.name.localizedStandardContains(text) || $0.email.localizedStandardContains(text) }
            .prefix(3)
            .map { $0 }
    }

    private func focus() {
        isFocused = true
    }

    private func tap(_ contact: Contact) {
        if selectedID == contact.id {
            recipients.removeAll { $0.id == contact.id }
            selectedID = nil
        } else {
            selectedID = contact.id
        }
    }

    private func add(_ contact: Contact) {
        if !recipients.contains(contact) {
            recipients.append(contact)
        }
        entry = ""
        selectedID = nil
    }

    /// Turns the typed text into a recipient when it ends in a comma or semicolon.
    private func commitIfSeparated() {
        guard let last = entry.last, last == "," || last == ";" else { return }
        entry.removeLast()
        commit()
    }

    /// Adds the typed text as a recipient if it names a known contact or is an address.
    private func commit() {
        let text = entry.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        if let known = store.knownContacts.first(where: {
            $0.email.caseInsensitiveCompare(text) == .orderedSame || $0.name.caseInsensitiveCompare(text) == .orderedSame
        }) {
            add(known)
        } else if text.contains("@") {
            add(Contact(name: "", email: text))
        } else if let suggestion = suggestions.first {
            add(suggestion)
        }
    }
}
