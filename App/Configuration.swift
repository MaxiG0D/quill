/// The values that connect this build of Quill to outside services.
enum Configuration {
    /// The iOS OAuth client ID from Google Cloud Console, ending in `.apps.googleusercontent.com`.
    /// While it is empty, Quill opens the sample mailbox instead of signing in to Gmail.
    static let googleClientID = ""
}
