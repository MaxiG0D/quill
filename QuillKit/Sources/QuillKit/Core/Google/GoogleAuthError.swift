import Foundation

enum GoogleAuthError: LocalizedError, Equatable {
    /// There is no usable sign-in: none was made, or Google withdrew it.
    case signedOut
    /// Google sent the person back without a usable answer.
    case invalidCallback
    case denied(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .signedOut: "You’re signed out of Google."
        case .invalidCallback: "Google’s reply couldn’t be read."
        case .denied(let reason): "Google didn’t allow the sign-in (\(reason))."
        case .server(let message): message.isEmpty ? "Google couldn’t complete the sign-in." : message
        }
    }
}
