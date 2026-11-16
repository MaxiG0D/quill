struct MailLabel: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var name: String
    var tone: LabelTone
}
