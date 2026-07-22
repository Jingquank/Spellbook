import SpellbookCore
import SwiftUI
import Testing
@testable import SpellbookUI

@Suite("Interface appearance")
struct InterfaceAppearanceTests {
    @Test("Interface scale adjusts normal system sizes")
    func adjustsNormalSystemSizes() {
        #expect(InterfaceTextScale.small.resolvedDynamicTypeSize(from: .large) == .medium)
        #expect(InterfaceTextScale.standard.resolvedDynamicTypeSize(from: .large) == .large)
        #expect(InterfaceTextScale.large.resolvedDynamicTypeSize(from: .large) == .xLarge)
    }

    @Test("Interface scale preserves system accessibility sizes")
    func preservesAccessibilitySizes() {
        #expect(
            InterfaceTextScale.small.resolvedDynamicTypeSize(from: .accessibility3)
                == .accessibility3
        )
    }
}
