import Foundation
import Testing
@testable import SpellbookCore

@Suite("Managed operation compatibility")
struct ManagedOperationCompatibilityTests {
    @Test("Historical edit and apply operation kinds still decode")
    func historicalKindsDecode() throws {
        let decoder = JSONDecoder()
        #expect(try decoder.decode(ManagedOperationKind.self, from: Data(#""edit""#.utf8)) == .edit)
        #expect(try decoder.decode(ManagedOperationKind.self, from: Data(#""apply""#.utf8)) == .apply)
    }
}
