import Foundation

/// Encodes fields the way a web form does, for OAuth's token endpoints.
enum FormEncoding {
    private static let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))

    static func body(_ fields: [(String, String)]) -> Data {
        let pairs = fields.map { "\(escape($0.0))=\(escape($0.1))" }
        return Data(pairs.joined(separator: "&").utf8)
    }

    private static func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
