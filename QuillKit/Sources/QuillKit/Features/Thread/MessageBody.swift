import MapKit
import QuickLook
import SwiftUI

/// A message's content, as designed HTML or as text, and its attachments.
struct MessageBody: View {
    @Environment(MailStore.self) private var store: MailStore?
    @Environment(Router.self) private var router: Router?

    let message: Message
    /// The conversation's subject, read with the message to find events.
    var subject = ""

    @State private var showsQuoted = false
    @State private var loadingAttachmentID: Attachment.ID?
    @State private var previewURL: URL?
    @State private var downloadedURLs: [Attachment.ID: URL] = [:]
    @State private var place: CLLocationCoordinate2D?

    /// The message as text, with anything it quotes behind a toggle.
    @ViewBuilder
    private var text: some View {
        Text(LinkedText.make(message.body))
            .textRole(.reading)
            .lineSpacing(5)
            .foregroundStyle(Palette.label)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)

        if let quoted = message.quoted {
            QuotedTextToggle(isExpanded: $showsQuoted)
            if showsQuoted {
                Text(LinkedText.make(quoted))
                    .font(.callout)
                    .lineSpacing(3)
                    .foregroundStyle(Palette.secondaryLabel)
                    .textSelection(.enabled)
                    .padding(.leading, Spacing.s)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Palette.accentTint)
                            .frame(width: 3)
                    }
                    .padding(.bottom, Spacing.xs)
                    .transition(.opacity)
            }
        }
    }

    var body: some View {
        let now = store?.now ?? .now
        let codeSource = message.body.isEmpty ? (message.snippet ?? "") : message.body
        let address = MailAddressCache.address(in: message)
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let code = SignInCode.find(in: subject.isEmpty ? codeSource : "\(subject)\n\(codeSource)") {
                SignInCodeChip(code: code)
                    .padding(.bottom, Spacing.xs)
            }
            if let event = MailEventCache.event(in: message, subject: subject), event.isUpcoming(at: now) {
                EventCard(
                    event: event,
                    details: EventDetails.make(
                        title: EventCalendar.title(subject: subject, sender: message.sender.displayName),
                        sender: message.sender.displayName,
                        text: message.body.isEmpty ? message.snippet ?? "" : message.body
                    ),
                    messageID: message.id
                )
                .padding(.bottom, Spacing.xs)
            }
            if let address, let place {
                AddressCard(address: address, coordinate: place)
                    .padding(.bottom, Spacing.xs)
                    .transition(.opacity)
            }
            if let html = message.html {
                HTMLMessageView(html: html, inlineImages: message.inlineImages)
            } else {
                text
                    .tint(Palette.link)
                    .environment(\.openURL, OpenURLAction { url in
                        if let router, let draft = Draft(mailto: url) {
                            router.compose(draft)
                            return .handled
                        }
                        return .systemAction
                    })
            }

            ForEach(message.attachments) { attachment in
                AttachmentRow(
                    attachment: attachment,
                    isLoading: loadingAttachmentID == attachment.id,
                    onOpen: attachment.isAvailable ? { openAttachment(attachment) } : nil
                ) {
                    if attachment.isAvailable {
                        Button("Preview", systemImage: "eye") {
                            openAttachment(attachment)
                        }
                    }
                    if let url = downloadedURLs[attachment.id] {
                        ShareLink(item: url)
                    } else if attachment.isAvailable {
                        Button("Download", systemImage: "arrow.down.circle") {
                            downloadAttachment(attachment)
                        }
                    } else {
                        ShareLink(item: attachment.filename)
                    }
                }
                .frame(maxWidth: 340)
            }
        }
        .quickLookPreview($previewURL)
        .task(id: address) {
            guard let address else { place = nil; return }
            let found = await AddressPlaces.locate(address.full)
            withAnimation(Motion.quick) { place = found }
        }
    }

    private func openAttachment(_ attachment: Attachment) {
        if let cached = downloadedURLs[attachment.id], FileManager.default.fileExists(atPath: cached.path) {
            previewURL = cached
            return
        }
        Task {
            if let url = await fetchToTempFile(attachment) {
                previewURL = url
            }
        }
    }

    private func downloadAttachment(_ attachment: Attachment) {
        Task {
            _ = await fetchToTempFile(attachment)
        }
    }

    private func fetchToTempFile(_ attachment: Attachment) async -> URL? {
        guard let store else { return nil }
        loadingAttachmentID = attachment.id
        defer { if loadingAttachmentID == attachment.id { loadingAttachmentID = nil } }
        do {
            let fileURL = try await store.previewFileURL(for: attachment)
            downloadedURLs[attachment.id] = fileURL
            return fileURL
        } catch {
            store.alert = error.localizedDescription
            return nil
        }
    }
}
