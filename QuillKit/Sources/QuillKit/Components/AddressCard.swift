import MapKit
import SwiftUI

/// A street address found in a message, as a small map over the address. Tapping it opens Maps.
struct AddressCard: View {
    let address: MailAddress
    let coordinate: CLLocationCoordinate2D

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            open(directions: false)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                map
                VStack(alignment: .leading, spacing: 1) {
                    Text(address.street)
                        .font(.headline)
                        .foregroundStyle(Palette.label)
                    if !address.locality.isEmpty {
                        Text(address.locality)
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondaryLabel)
                    }
                }
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xs + 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Palette.accentTint)
            .clipShape(.rect(cornerRadius: Radius.medium))
            .contentShape(.rect(cornerRadius: Radius.medium))
        }
        .buttonStyle(.pressable)
        .frame(maxWidth: 440, alignment: .leading)
        .help("Open in \(MapsApp.current.title)")
        .accessibilityLabel(address.full)
        .accessibilityHint("Opens in \(MapsApp.current.title)")
        .contextMenu {
            Button("Open in \(MapsApp.current.title)", systemImage: "map") { open(directions: false) }
            Button("Directions", systemImage: "arrow.triangle.turn.up.right.diamond") { open(directions: true) }
            Button("Copy Address", systemImage: "doc.on.doc") { copy() }
        }
    }

    private var map: some View {
        Map(
            initialPosition: .camera(MapCamera(centerCoordinate: coordinate, distance: 1200)),
            interactionModes: []
        ) {
            Marker("", systemImage: "mappin", coordinate: coordinate)
                .tint(Palette.accentFill)
                .annotationTitles(.hidden)
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
        .allowsHitTesting(false)
        .frame(height: 120)
        .accessibilityHidden(true)
    }

    private func open(directions: Bool) {
        if let url = MapsApp.current.url(for: address.full, at: coordinate, directions: directions) {
            openURL(url)
        }
    }

    private func copy() {
        #if os(iOS)
        UIPasteboard.general.string = address.full
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address.full, forType: .string)
        #endif
    }
}

/// Where addresses are on the map. An address Maps cannot place gets no card,
/// which also drops text that only looked like an address.
@MainActor
enum AddressPlaces {
    private static var found: [String: CLLocationCoordinate2D?] = [:]

    static func locate(_ address: String) async -> CLLocationCoordinate2D? {
        if let cached = found[address] { return cached }
        var coordinate: CLLocationCoordinate2D?
        do {
            if let request = MKGeocodingRequest(addressString: address) {
                coordinate = try await request.mapItems.first?.location.coordinate
            }
        } catch {
            // Offline or rate limited: try again next time the message opens.
            return nil
        }
        if found.count > 500 { found.removeAll() }
        found[address] = coordinate
        return coordinate
    }
}
