import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The message composer, presented as a sheet.
struct ComposeView: View {
    @Environment(MailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontResolutionContext) private var fontContext

    private let original: Draft

    @State private var draft: Draft
    @State private var text: AttributedString
    @State private var selection = AttributedTextSelection()
    @State private var toEntry = ""
    @State private var ccEntry = ""
    @State private var bccEntry = ""
    @State private var showsBcc: Bool
    @State private var showsQuoted: Bool
    @State private var photo: PhotosPickerItem?
    @State private var isSending = false
    @State private var isConfirmingCancel = false
    @State private var isImportingFile = false
    @State private var isDropTargeted = false
    @State private var errorMessage: String?
    @FocusState private var isSubjectFocused: Bool
    @FocusState private var isBodyFocused: Bool

    init(draft: Draft) {
        var prepared = draft
        if prepared.body.isEmpty,
           prepared.sourceDraftThreadID == nil,
           let signature = MailPreferences.shared.activeSignature {
            prepared.body = "\n\n\(signature)"
        }
        original = prepared
        _draft = State(initialValue: prepared)
        _text = State(initialValue: AttributedString(prepared.body))
        _showsBcc = State(initialValue: !prepared.bcc.isEmpty)
        _showsQuoted = State(initialValue: prepared.isForward)
    }

    var body: some View {
        VStack(spacing: 0) {
            ComposeHeader(
                title: draft.title,
                canSend: canSend,
                isSending: isSending,
                onCancel: cancel,
                onSend: send
            )
            .confirmationDialog("Draft", isPresented: $isConfirmingCancel) {
                Button("Delete Draft", role: .destructive, action: discard)
                Button("Save Draft", action: save)
                Button("Keep Editing", role: .cancel) {}
            }

            VStack(alignment: .leading, spacing: 0) {
                RecipientField(
                    title: "To",
                    recipients: $draft.to,
                    entry: $toEntry,
                    autoFocus: draft.to.isEmpty,
                    onSubmitEmpty: { isSubjectFocused = true }
                )
                Divider().overlay(Palette.separator)
                HStack(alignment: .center, spacing: Spacing.xs) {
                    RecipientField(
                        title: "Cc",
                        recipients: $draft.cc,
                        entry: $ccEntry,
                        onSubmitEmpty: { isSubjectFocused = true }
                    )
                    if !showsBcc {
                        Button("Bcc") {
                            withAnimation(Motion.quick) { showsBcc = true }
                        }
                        .textRole(.meta)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.secondaryLabel)
                        .buttonStyle(.plain)
                        .help("Add Bcc recipients")
                    }
                }
                if showsBcc {
                    Divider().overlay(Palette.separator)
                    RecipientField(
                        title: "Bcc",
                        recipients: $draft.bcc,
                        entry: $bccEntry,
                        onSubmitEmpty: { isSubjectFocused = true }
                    )
                }
                Divider().overlay(Palette.separator)
                TextField("Subject", text: $draft.subject)
                    .textFieldStyle(.plain)
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .foregroundStyle(Palette.label)
                    .focused($isSubjectFocused)
                    .submitLabel(.next)
                    .onSubmit { isBodyFocused = true }
                    .padding(.vertical, Spacing.m)
                Divider().overlay(Palette.separator)
            }
            .padding(.horizontal, Spacing.l)

            TextEditor(text: $text, selection: $selection)
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(Palette.label)
                .scrollContentBackground(.hidden)
                .focused($isBodyFocused)
                .padding(.horizontal, Spacing.m)
                .padding(.top, Spacing.xs)
                .frame(minHeight: 120)
                .accessibilityLabel("Message")

            if let quoted = draft.quoted, !quoted.isEmpty {
                quotedSection(quoted)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.s)
            }

            if !draft.attachments.isEmpty {
                VStack(spacing: Spacing.xs) {
                    ForEach(draft.attachments) { attachment in
                        AttachmentRow(attachment: attachment) {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                remove(attachment)
                            }
                        }
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.s)
            }
        }
        .tint(Palette.accent)
        .background(Palette.surface)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(Palette.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .padding(Spacing.xs)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !urls.isEmpty else { return false }
            attach(.success(urls))
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FormatBar(
                photo: $photo,
                isBold: activeFormatting.isBold,
                isItalic: activeFormatting.isItalic,
                onStyle: apply,
                onBold: toggleBold,
                onItalic: toggleItalic,
                onList: insertListItem,
                onAttach: importFile
            )
        }
        .animation(Motion.list, value: draft.attachments)
        .interactiveDismissDisabled(isDirty)
        .alert("Something Went Wrong", isPresented: isShowingError) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.item], allowsMultipleSelection: true, onCompletion: attach)
        .onChange(of: photo) {
            attachPhoto()
        }
        .onChange(of: text) {
            draft.body = String(text.characters)
            draft.htmlBody = renderedHTML(from: text)
        }
        .task {
            isBodyFocused = !draft.to.isEmpty
        }
    }

    private func quotedSection(_ quoted: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Button {
                    withAnimation(Motion.expand) { showsQuoted.toggle() }
                } label: {
                    Label(
                        draft.isForward ? "Forwarded message" : "Quoted message",
                        systemImage: showsQuoted ? "chevron.down" : "chevron.right"
                    )
                    .textRole(.meta)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.secondaryLabel)
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Remove quoted text", systemImage: "xmark") {
                    withAnimation(Motion.quick) { draft.quoted = nil }
                }
                .labelStyle(.iconOnly)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.secondaryLabel)
                .buttonStyle(.plain)
                .help("Remove quoted text")
            }
            if showsQuoted {
                ScrollView {
                    Text(quoted)
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 110)
                .padding(.leading, Spacing.s)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Palette.accentTint)
                        .frame(width: 3)
                }
            }
        }
        .padding(Spacing.s)
        .background(Palette.background.opacity(0.6), in: .rect(cornerRadius: Radius.small))
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var hasPendingText: Bool {
        ![toEntry, ccEntry, bccEntry].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var canSend: Bool {
        draft.canSend || [toEntry, ccEntry, bccEntry].contains(where: RecipientField.isValidEmail)
    }

    private var isDirty: Bool {
        (draft != original && !draft.isEmpty) || hasPendingText
    }

    private var activeFormatting: (isBold: Bool, isItalic: Bool) {
        let attributes = selection.typingAttributes(in: text)
        let resolved = (attributes.font ?? .default).resolve(in: fontContext)
        return (resolved.isBold, resolved.isItalic)
    }

    // MARK: Sending and closing

    private func commitPendingRecipients() -> Bool {
        let toOK = RecipientField.commit(entry: &toEntry, into: &draft.to, knownContacts: store.knownContacts)
        let ccOK = RecipientField.commit(entry: &ccEntry, into: &draft.cc, knownContacts: store.knownContacts)
        let bccOK = RecipientField.commit(entry: &bccEntry, into: &draft.bcc, knownContacts: store.knownContacts)
        return toOK && ccOK && bccOK
    }

    private func send() {
        guard commitPendingRecipients() else {
            errorMessage = "Please enter a valid email address for each recipient."
            return
        }
        guard draft.canSend else {
            errorMessage = "Add at least one recipient before sending."
            return
        }
        draft.body = String(text.characters)
        draft.htmlBody = renderedHTML(from: text)
        if MailPreferences.shared.undoSendEnabled {
            store.scheduleSend(draft)
            dismiss()
            return
        }
        isSending = true
        Task {
            if await store.send(draft) {
                dismiss()
            } else {
                // Present send errors inside this sheet so iOS does not swallow them behind it.
                errorMessage = store.alert ?? "Could not send message."
                store.alert = nil
            }
            isSending = false
        }
    }

    private func cancel() {
        if isDirty {
            isConfirmingCancel = true
        } else {
            dismiss()
        }
    }

    private func discard() {
        dismiss()
    }

    private func save() {
        _ = commitPendingRecipients()
        store.saveDraft(draft)
        dismiss()
    }

    // MARK: Formatting

    private func toggleBold() {
        text.transformAttributes(in: &selection) { container in
            let font = container.font ?? .default
            let resolved = font.resolve(in: fontContext)
            container.font = font.bold(!resolved.isBold)
        }
    }

    private func toggleItalic() {
        text.transformAttributes(in: &selection) { container in
            let font = container.font ?? .default
            let resolved = font.resolve(in: fontContext)
            container.font = font.italic(!resolved.isItalic)
        }
    }

    private func apply(_ style: ComposeTextStyle) {
        text.transformAttributes(in: &selection) { container in
            container.font = style.font
        }
    }

    private func insertListItem() {
        let prefix = text.characters.isEmpty ? "• " : "\n• "
        text.replaceSelection(&selection, withCharacters: prefix)
    }

    /// Converts styled composer text to HTML when rich formatting was applied; nil for plain text.
    private func renderedHTML(from attributed: AttributedString) -> String? {
        var hasFormatting = false
        var html = ""
        for run in attributed.runs {
            let chunk = String(attributed[run.range].characters)
            guard !chunk.isEmpty else { continue }
            var escaped = chunk
                .replacing("&", with: "&amp;")
                .replacing("<", with: "&lt;")
                .replacing(">", with: "&gt;")
                .replacing("\n", with: "<br>")
            if let font = run.font {
                let resolved = font.resolve(in: fontContext)
                if font == ComposeTextStyle.heading.font {
                    hasFormatting = true
                    escaped = "<span style=\"font-family:Georgia,serif;font-size:1.25em;font-weight:600;\">\(escaped)</span>"
                } else if font == ComposeTextStyle.small.font {
                    hasFormatting = true
                    escaped = "<small>\(escaped)</small>"
                }
                if resolved.isBold && font != ComposeTextStyle.heading.font {
                    hasFormatting = true
                    escaped = "<strong>\(escaped)</strong>"
                }
                if resolved.isItalic {
                    hasFormatting = true
                    escaped = "<em>\(escaped)</em>"
                }
            }
            html += escaped
        }
        return hasFormatting ? html : nil
    }

    // MARK: Attachments

    /// Gmail's maximum message size is 25 MB.
    private static let maxAttachmentBytes = 25 * 1024 * 1024

    private func importFile() {
        isImportingFile = true
    }

    private func attach(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try Data(contentsOf: url)
                    guard data.count <= Self.maxAttachmentBytes else {
                        errorMessage = "\(url.lastPathComponent) is larger than Gmail’s 25 MB limit."
                        continue
                    }
                    let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
                    draft.attachments.append(
                        Attachment(
                            filename: url.lastPathComponent,
                            byteCount: data.count,
                            mimeType: mimeType,
                            data: data
                        )
                    )
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func attachPhoto() {
        guard let item = photo else { return }
        photo = nil
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    errorMessage = "Could not load the selected photo."
                    return
                }
                guard data.count <= Self.maxAttachmentBytes else {
                    errorMessage = "That photo is larger than Gmail’s 25 MB limit."
                    return
                }
                let type = item.supportedContentTypes.first
                let ext = type?.preferredFilenameExtension ?? "jpg"
                let mimeType = type?.preferredMIMEType ?? "image/jpeg"
                let count = draft.attachments.count { $0.kind == .image }
                let name = count == 0 ? "Photo.\(ext)" : "Photo \(count + 1).\(ext)"
                draft.attachments.append(
                    Attachment(filename: name, byteCount: data.count, mimeType: mimeType, data: data)
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func remove(_ attachment: Attachment) {
        draft.attachments.removeAll { $0.id == attachment.id }
    }
}

#Preview {
    ComposeView(draft: Draft(to: [SampleData.priya], subject: "Re: Lease renewal"))
        .environment(MailStore(snapshot: SampleData.snapshot(now: .now)))
}
