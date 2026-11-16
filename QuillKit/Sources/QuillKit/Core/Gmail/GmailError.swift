import Foundation

enum GmailError: LocalizedError, Equatable {
    case status(Int, String)
    case attachmentsUnsupported

    var errorDescription: String? {
        switch self {
        case .status(let code, let message):
            message.isEmpty ? "Gmail returned an error (\(code))." : message
        case .attachmentsUnsupported:
            "Quill can’t send attachments yet."
        }
    }
}
