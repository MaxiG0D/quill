/// The values that connect this build of Quill to outside services.
enum Configuration {
    /// The iOS OAuth client ID from Google Cloud Console, ending in `.apps.googleusercontent.com`.
    /// If it is emptied, Quill opens the sample mailbox instead of signing in to Gmail.
    static let googleClientID = "901760496122-hfia1nl8m2akopiss9b0ff3dd78fs8kk.apps.googleusercontent.com"
}
