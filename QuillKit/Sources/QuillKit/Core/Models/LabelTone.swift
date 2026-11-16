/// The five tonal families shared by labels and monogram avatars.
enum LabelTone: String, CaseIterable, Codable, Sendable {
    case teal, slate, amber, plum, olive

    /// A stable tone for content that has none assigned, such as a new sender.
    static func stable(for seed: String) -> LabelTone {
        let sum = seed.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 9973 }
        return allCases[sum % allCases.count]
    }
}
