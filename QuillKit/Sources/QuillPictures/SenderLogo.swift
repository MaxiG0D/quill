import Foundation

/// Where a company's logo comes from when its mail has no person's picture.
public enum SenderLogo {
    /// Mail providers whose addresses belong to people, not to the provider, in any country.
    private static let providers: Set<String> = [
        "gmail", "googlemail", "yahoo", "ymail", "rocketmail", "outlook", "hotmail", "live", "msn",
        "icloud", "aol", "protonmail", "gmx", "yandex", "fastmail",
    ]

    /// The same, for providers whose name alone could be a company's.
    private static let providerSites: Set<String> = [
        "me.com", "mac.com", "proton.me", "pm.me", "mail.com", "hey.com", "videotron.ca", "bell.net",
        "sympatico.ca", "rogers.com", "shaw.ca", "telus.net",
    ]

    /// Second-level names that sit under a country, as in "example.co.uk".
    private static let shared: Set<String> = ["co", "com", "org", "net", "gov", "gouv", "ac", "edu", "qc", "on", "bc", "ab"]

    /// The site a sender's logo belongs to: "news.example.com" is "example.com".
    /// Nil for addresses at a personal mail provider.
    public static func domain(for address: String) -> String? {
        guard let host = address.lowercased().split(separator: "@").last, address.contains("@") else { return nil }
        let labels = host.split(separator: ".")
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty }) else { return nil }
        let isUnderCountry = labels.count >= 3 && labels[labels.count - 1].count == 2 && shared.contains(String(labels[labels.count - 2]))
        let parts = labels.suffix(isUnderCountry ? 3 : 2)
        let site = parts.joined(separator: ".")
        guard let name = parts.first, !providers.contains(String(name)), !providerSites.contains(site) else { return nil }
        return site
    }

    /// The site's icon from Google, which already sees every sender of a Gmail account.
    public static func url(for domain: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/s2/favicons")
        components?.queryItems = [URLQueryItem(name: "domain", value: domain), URLQueryItem(name: "sz", value: "128")]
        return components?.url
    }
}
