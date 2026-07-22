import Foundation
import Testing
@testable import SpellbookCore

@Suite("Package naming and source roots")
struct PackageNamingTests {
    @Test("A Spotlight scope remains distinct from a trusted root at the same path")
    func distinguishesSpotlightScopeFromTrustedRoot() {
        let url = URL(filePath: "/Users/example/Code", directoryHint: .isDirectory)
        let trusted = SourceSearchRootRecord(url: url)
        let spotlight = SourceSearchRootRecord(url: url, isTrusted: false)

        #expect(trusted.id != spotlight.id)
        #expect(trusted.isTrusted)
        #expect(!spotlight.isTrusted)
    }
}
