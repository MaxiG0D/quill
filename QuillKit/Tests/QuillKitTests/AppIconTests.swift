import Foundation
import Testing
@testable import QuillKit

struct AppIconTests {
    @Test func primaryIconHasNoAlternateName() {
        #expect(AppIcon.primary == .paper)
        #expect(AppIcon.paper.alternateName == nil)
    }

    @Test(arguments: [
        (AppIcon.terracotta, "AppIcon-Terracotta"),
        (.indigo, "AppIcon-Indigo"),
        (.oxblood, "AppIcon-Oxblood"),
        (.midnight, "AppIcon-Midnight"),
        (.forest, "AppIcon-Forest"),
        (.paperTerracotta, "AppIcon-PaperTerracotta")
    ])
    func alternateNamesMatchTheAssetCatalog(icon: AppIcon, expected: String) {
        #expect(icon.alternateName == expected)
    }

    @Test func storedIconFallsBackToThePrimary() throws {
        let defaults = try #require(UserDefaults(suiteName: "AppIconTests"))
        defaults.removePersistentDomain(forName: "AppIconTests")
        #expect(AppIcon.stored(in: defaults) == .paper)
        defaults.set("oxblood", forKey: AppIcon.storageKey)
        #expect(AppIcon.stored(in: defaults) == .oxblood)
        defaults.set("gone", forKey: AppIcon.storageKey)
        #expect(AppIcon.stored(in: defaults) == .paper)
        defaults.removePersistentDomain(forName: "AppIconTests")
    }
}
