import Foundation

enum GoogleAuthError: LocalizedError, Equatable {
    /// There is no usable sign-in: none was made, or Google withdrew it.
    case signedOut
    /// Google sent the person back without a usable answer.
    case invalidCallback
    case denied(String)
    /// The person signed in but left Gmail access unticked on Google's permission page.
    case mailNotAllowed
    case server(String)

    var errorDescription: String? {
        switch self {
        case .signedOut: "You’re signed out of Google."
        case .invalidCallback: "Google’s reply couldn’t be read."
        case .mailNotAllowed: "Quill wasn’t given access to Gmail. Sign in again and tick the Gmail box on Google’s page."
        case .denied(let reason): "Google didn’t allow the sign-in (\(reason))."
        case .server(let message): message.isEmpty ? "Google couldn’t complete the sign-in." : message
        }
    }
}
