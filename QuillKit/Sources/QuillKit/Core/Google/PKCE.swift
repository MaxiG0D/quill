import CryptoKit
import Foundation

/// The proof key that ties a sign-in's two steps together (RFC 7636).
struct PKCE: Sendable {
    let verifier: String

    init() {
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max) }
        verifier = Data(bytes).base64URLEncoded
    }

    init(verifier: String) {
        self.verifier = verifier
    }

    var challenge: String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
    }
}
