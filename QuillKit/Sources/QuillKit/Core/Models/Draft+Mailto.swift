import Foundation

extension Draft {
    /// A new message filled from a `mailto:` link (RFC 6068): recipients, subject and body.
    /// Returns nil for any other kind of link.
    init?(mailto url: URL) {
        guard url.scheme?.lowercased() == "mailto",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = components.queryItems ?? []
        func values(_ name: String) -> [String] {
            items.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }.compactMap(\.value)
        }
        func contacts(_ fields: [String]) -> [Contact] {
            var seen = Set<String>()
            return fields
                .flatMap { AddressList.contacts(in: $0) }
                .filter { seen.insert($0.email).inserted }
        }
        let path = components.percentEncodedPath.removingPercentEncoding ?? components.path
        self.init(
            to: contacts([path] + values("to")),
            cc: contacts(values("cc")),
            bcc: contacts(values("bcc")),
            subject: values("subject").first?.normalizingLineBreaks.replacing("\n", with: " ") ?? "",
            body: values("body").first?.normalizingLineBreaks ?? ""
        )
    }
}

private extension String {
    var normalizingLineBreaks: String {
        replacing("\r\n", with: "\n").replacing("\r", with: "\n")
    }
}
