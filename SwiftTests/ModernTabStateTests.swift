import Foundation
import Testing
@testable import TransitStudio

@MainActor
struct ModernTabStateTests {
    @Test func eachModernSubModeHasDistinctDefaultTabWhereNeeded() {
        #expect(ModernSubMode.natal.defaultResultTab == "natal_positions")
        #expect(ModernSubMode.synastry.defaultResultTab == "cross_aspects")
        #expect(ModernSubMode.composite.defaultResultTab == "planets")
        #expect(ModernSubMode.davison.defaultResultTab == "planets")
        #expect(ModernSubMode.progression.defaultResultTab == "progressed_planets")
        #expect(ModernSubMode.solarArc.defaultResultTab == "sa_planets")
        #expect(ModernSubMode.harmonic.defaultResultTab == "planets")
        #expect(ModernSubMode.returnChart.defaultResultTab == "current_return")
    }

    @Test func resetModernSelectedTabUsesSubModeDefault() {
        let vm = CalculationViewModel()
        vm.modernSelectedTab = "lunation"
        vm.resetModernSelectedTab(for: .synastry)
        #expect(vm.modernSelectedTab == "cross_aspects")
        vm.resetModernSelectedTab(for: .solarArc)
        #expect(vm.modernSelectedTab == "sa_planets")
    }
}
