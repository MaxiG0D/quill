import CoreLocation
import Foundation
#if os(iOS)
import UIKit
#endif

/// Where address cards open. Unset, it is Google Maps when its iPhone app is installed, otherwise Apple Maps.
enum MapsApp: String, CaseIterable, Identifiable, Sendable {
    case apple, google

    static let storageKey = "maps.app"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: String(localized: "Apple Maps")
        case .google: String(localized: "Google Maps")
        }
    }

    @MainActor
    static var current: MapsApp {
        if let stored = UserDefaults.standard.string(forKey: storageKey).flatMap(MapsApp.init) {
            return stored
        }
        return hasGoogleMapsApp ? .google : .apple
    }

    @MainActor
    private static var hasGoogleMapsApp: Bool {
        #if os(iOS)
        guard let url = URL(string: "comgooglemaps://") else { return false }
        return UIApplication.shared.canOpenURL(url)
        #else
        return false
        #endif
    }

    /// The link that shows `address`, or the way there.
    @MainActor
    func url(for address: String, at coordinate: CLLocationCoordinate2D, directions: Bool) -> URL? {
        let point = "\(coordinate.latitude),\(coordinate.longitude)"
        switch self {
        case .apple:
            return Self.link("https://maps.apple.com/", directions
                ? ["daddr": address]
                : ["q": address, "ll": point])
        case .google:
            if Self.hasGoogleMapsApp {
                return Self.link("comgooglemaps://", directions
                    ? ["daddr": address]
                    : ["q": address, "center": point])
            }
            return directions
                ? Self.link("https://www.google.com/maps/dir/", ["api": "1", "destination": address])
                : Self.link("https://www.google.com/maps/search/", ["api": "1", "query": address])
        }
    }

    private static func link(_ base: String, _ query: KeyValuePairs<String, String>) -> URL? {
        var components = URLComponents(string: base)
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components?.url
    }
}
