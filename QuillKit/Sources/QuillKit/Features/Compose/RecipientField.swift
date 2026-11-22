import SwiftUI

/// A To, Cc or Bcc line: recipient tokens, a field for typing more, and suggestions from known contacts.
struct RecipientField: View {
    @Environment(MailStore.self) private var store

    let title: String
    @Binding var recipients: [Contact]
    @Binding var entry: String
    var autoFocus = false
    var onSubmitEmpty: (() -> Void)? = nil

    @State private var selectedID: Contact.ID?
    @State private var hasInvalidEntry = false
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
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .foregroundStyle(hasInvalidEntry ? Palette.destructive : Palette.label)
                        .focused($isFocused)
                        .emailEntry()
                        .submitLabel(.next)
                        .onSubmit(submit)
                        .onKeyPress(.delete) { handleDelete() }
                        .frame(minHeight: 32)
                }
            }
            .padding(.vertical, Spacing.xs)
            .frame(minHeight: 50)
            .contentShape(.rect)
            .onTapGesture(perform: focus)

            ForEach(suggestions) { contact in
                RecipientSuggestionRow(contact: contact) {
                    add(contact)
                }
                .transition(.opacity)
            }
        }
        .animation(Motion.quick, value: recipients)
        .animation(Motion.quick, value: selectedID)
        .animation(Motion.quick, value: suggestions)
        .onChange(of: entry) {
            hasInvalidEntry = false
            if !entry.isEmpty {
                selectedID = nil
            }
            commitIfSeparated()
        }
        .onChange(of: isFocused) {
            if !isFocused {
                commit(allowSuggestion: false)
                selectedID = nil
            }
        }
        .task {
            if autoFocus {
                isFocused = true
            }
        }
    }

    /// True when the string looks like a valid email address (`local@domain.tld` with no spaces).
    static func isValidEmail(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace) else { return false }
        let parts = text.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        guard let dot = domain.lastIndex(of: "."),
              dot > domain.startIndex,
              domain.index(after: dot) < domain.endIndex,
              !domain.contains("..") else { return false }
        return true
    }

    /// Commits a typed string into `recipients` if it matches a known contact or is a valid address.
    @discardableResult
    static func commit(
        entry: inout String,
        into recipients: inout [Contact],
        knownContacts: [Contact],
        allowSuggestion: Bool = false
    ) -> Bool {
        let text = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return true }
        let existing = Set(recipients.map { $0.email.lowercased() })
        if let known = knownContacts.first(where: {
            $0.email.caseInsensitiveCompare(text) == .orderedSame || $0.name.caseInsensitiveCompare(text) == .orderedSame
        }) {
            if !existing.contains(known.email.lowercased()) {
                recipients.append(known)
            }
            entry = ""
            return true
        }
        if isValidEmail(text) {
            if !existing.contains(text.lowercased()) {
                recipients.append(Contact(name: "", email: text))
            }
            entry = ""
            return true
        }
        if allowSuggestion,
           let suggestion = knownContacts.first(where: {
               !existing.contains($0.email.lowercased())
                   && ($0.name.localizedStandardContains(text) || $0.email.localizedStandardContains(text))
           }) {
            recipients.append(suggestion)
            entry = ""
            return true
        }
        return false
    }

    /// Known contacts matching what has been typed, leaving out anyone already added.
    private var suggestions: [Contact] {
        let text = entry.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return [] }
        let existing = Set(recipients.map { $0.email.lowercased() })
        return store.knownContacts
            .filter { !existing.contains($0.email.lowercased()) }
            .filter { $0.name.localizedStandardContains(text) || $0.email.localizedStandardContains(text) }
            .prefix(3)
            .map { $0 }
    }

    private func focus() {
        isFocused = true
    }

    private func tap(_ contact: Contact) {
        if selectedID == contact.id {
            recipients.removeAll { $0.email.caseInsensitiveCompare(contact.email) == .orderedSame }
            selectedID = nil
        } else {
            selectedID = contact.id
        }
    }

    private func add(_ contact: Contact) {
        if !recipients.contains(where: { $0.email.caseInsensitiveCompare(contact.email) == .orderedSame }) {
            recipients.append(contact)
        }
        entry = ""
        hasInvalidEntry = false
        selectedID = nil
    }

    private func handleDelete() -> KeyPress.Result {
        guard entry.isEmpty, let last = recipients.last else { return .ignored }
        if selectedID == last.id {
            recipients.removeLast()
            selectedID = nil
        } else {
            selectedID = last.id
        }
        return .handled
    }

    private func submit() {
        if entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onSubmitEmpty?()
        } else {
            commit(allowSuggestion: true)
        }
    }

    /// Turns the typed text into a recipient when it ends in a comma or semicolon.
    private func commitIfSeparated() {
        guard let last = entry.last, last == "," || last == ";" else { return }
        entry.removeLast()
        commit(allowSuggestion: false)
    }

    /// Adds the typed text as a recipient if it names a known contact or is a valid address.
    private func commit(allowSuggestion: Bool) {
        let committed = Self.commit(
            entry: &entry,
            into: &recipients,
            knownContacts: store.knownContacts,
            allowSuggestion: allowSuggestion
        )
        hasInvalidEntry = !committed && !entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if committed {
            selectedID = nil
        }
    }
}

private struct RecipientSuggestionRow: View {
    let contact: Contact
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
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
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xs)
            .background(isHovering ? Palette.fill : .clear, in: .rect(cornerRadius: Radius.small))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
