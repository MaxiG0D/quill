import Foundation

/// Persists the list of signed-in Google accounts and which account is active.
struct AccountRegistry {
    private let defaults: UserDefaults
    private static let accountsKey = "accounts.records"
    private static let activeKey = "accounts.activeID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var accounts: [AccountRecord] {
        get {
            guard let data = defaults.data(forKey: Self.accountsKey),
                  let decoded = try? JSONDecoder().decode([AccountRecord].self, from: data) else {
                return []
            }
            return decoded
        }
        nonmutating set {
            let encoded = try? JSONEncoder().encode(newValue)
            defaults.set(encoded, forKey: Self.accountsKey)
        }
    }

    var activeID: String? {
        get { defaults.string(forKey: Self.activeKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.activeKey) }
    }

    /// Ensures an account exists in the registry, updating its profile metadata when known.
    func upsert(_ record: AccountRecord) {
        var list = accounts
        if let index = list.firstIndex(where: { $0.id == record.id || $0.keychainAccount == record.keychainAccount }) {
            list[index] = record
        } else {
            list.append(record)
        }
        accounts = list
    }

    func remove(id: String) {
        var list = accounts
        list.removeAll { $0.id == id }
        accounts = list
        if activeID == id {
            activeID = list.first?.id
        }
    }

    /// A filesystem-safe archive filename for an account.
    static func archiveFilename(for email: String, isPrimary: Bool = false) -> String {
        if isPrimary || email.isEmpty { return "mailbox.json" }
        let safe = email.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "_" }.joined()
        return "mailbox-\(safe).json"
    }

    static func keychainAccount(for email: String, isPrimary: Bool = false) -> String {
        if isPrimary || email.isEmpty { return "default" }
        return "google.\(email.lowercased())"
    }
}
