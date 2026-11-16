import ImageIO
import Observation
import SwiftUI

/// Finds a picture for each sender: the person's own from the account's Google contacts,
/// or else the logo of the site the mail came from. Senders with neither keep their initials.
@MainActor
@Observable
final class SenderPictures {
    /// Pictures found so far, by lowercased address.
    private var found: [String: SenderPicture] = [:]
    /// Goes up when the contacts arrive or the account changes, so avatars look again.
    private(set) var revision = 0

    @ObservationIgnored private let http: (any HTTPClient)?
    /// Contact pictures, by lowercased address.
    @ObservationIgnored private var people: [String: URL] = [:]
    /// Addresses already looked up.
    @ObservationIgnored private var settled: Set<String> = []
    /// Logos by site, once known.
    @ObservationIgnored private var logos: [String: Logo] = [:]
    @ObservationIgnored private var logoFetches: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var loading: Task<Void, Never>?

    /// A logo smaller than this would blur in the largest avatar.
    private static let smallestLogo = 64

    /// Without `http` no picture is ever fetched, which keeps sample mail and screenshots still.
    init(http: (any HTTPClient)? = nil) {
        self.http = http
    }

    func picture(for contact: Contact) -> SenderPicture? {
        found[contact.email.lowercased()]
    }

    /// Reads the account's contacts for their pictures.
    func load(from api: GmailAPI) {
        loading?.cancel()
        loading = Task {
            let photos = await api.contactPhotos()
            guard !Task.isCancelled, !photos.isEmpty else { return }
            people = photos
            // Anyone looked up before now may have a picture after all.
            settled.subtract(photos.keys)
            revision += 1
        }
    }

    /// Forgets everything, for when the account signs out.
    func forget() {
        loading?.cancel()
        loading = nil
        logoFetches.values.forEach { $0.cancel() }
        logoFetches = [:]
        people = [:]
        settled = []
        logos = [:]
        found = [:]
        revision += 1
    }

    /// Looks for the contact's picture, once. A lookup that could not finish is tried again
    /// the next time the contact appears.
    func resolve(_ contact: Contact) async {
        guard let http else { return }
        let address = contact.email.lowercased()
        guard settled.insert(address).inserted else { return }
        do {
            if let url = contact.photoURL ?? people[address], let image = try await Self.image(at: url, http: http) {
                keep(SenderPicture(image: image, kind: .person), for: address)
            } else if let domain = SenderLogo.domain(for: address) {
                switch await logo(for: domain, http: http) {
                case .found(let logo)?: keep(logo, for: address)
                case .missing?: break
                case nil: settled.remove(address)
                }
            }
        } catch {
            settled.remove(address)
        }
    }

    private func keep(_ picture: SenderPicture, for address: String) {
        // Not after signing out, and a person's picture is never replaced by a logo that was slower to arrive.
        guard settled.contains(address), picture.kind == .person || found[address]?.kind != .person else { return }
        found[address] = picture
    }

    /// The site's logo, fetched once however many senders share it. Nil when it could not be fetched this time.
    private func logo(for domain: String, http: any HTTPClient) async -> Logo? {
        if let known = logos[domain] {
            return known
        }
        let fetch = logoFetches[domain] ?? Task {
            defer { logoFetches[domain] = nil }
            guard let url = SenderLogo.url(for: domain) else {
                logos[domain] = Logo.missing
                return
            }
            do {
                let image = try await Self.image(at: url, http: http, smallestSide: Self.smallestLogo)
                guard !Task.isCancelled else { return }
                logos[domain] = image.map { Logo.found(SenderPicture(image: $0, kind: .logo)) } ?? Logo.missing
            } catch {
                // Left unknown, so the next sender from this site asks again.
            }
        }
        logoFetches[domain] = fetch
        await fetch.value
        return logos[domain]
    }

    /// The picture at `url`. Nil when there is none or it is too small, and an error when
    /// the answer might be different next time.
    private static func image(at url: URL, http: any HTTPClient, smallestSide: Int = 1) async throws -> Image? {
        let (data, response) = try await http.send(URLRequest(url: url))
        switch response.statusCode {
        case 200:
            return decoded(data, smallestSide: smallestSide)
        case 429, 500...:
            throw URLError(.badServerResponse)
        default:
            // Google answers 404, with a stand-in globe, for a site it has no icon for.
            return nil
        }
    }

    /// The largest picture in the data, since an icon file can hold several sizes.
    private static func decoded(_ data: Data, smallestSide: Int) -> Image? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let images = (0..<CGImageSourceGetCount(source)).compactMap { CGImageSourceCreateImageAtIndex(source, $0, nil) }
        guard let largest = images.max(by: { $0.width < $1.width }), min(largest.width, largest.height) >= smallestSide else {
            return nil
        }
        return Image(decorative: largest, scale: 1)
    }

    private enum Logo {
        case found(SenderPicture)
        /// The site has no logo worth showing.
        case missing
    }
}
