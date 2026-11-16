import Foundation

enum GmailError: LocalizedError, Equatable {
    case status(Int, String)
    /// Gmail's per-minute allowance for the account is spent. It refills within a minute.
    case rateLimited
    case attachmentsUnsupported

    var errorDescription: String? {
        switch self {
        case .status(let code, let message):
            message.isEmpty ? "Gmail returned an error (\(code))." : message
        case .rateLimited:
            "Gmail is asking Quill to slow down. Try again in a minute."
        case .attachmentsUnsupported:
            "Quill can’t send attachments yet."
        }
    }
}
