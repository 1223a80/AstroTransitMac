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
        #expect(ModernSubMode.midpoint.defaultResultTab == "axes")
        #expect(ModernSubMode.progressedComposite.defaultResultTab == "radix_composite_planets")
        #expect(ModernSubMode.relocation.defaultResultTab == "biwheel")
        #expect(ModernSubMode.modernCycles.defaultResultTab == "events")
        #expect(ModernSubMode.declinationTiming.defaultResultTab == "events")
        #expect(ModernSubMode.retrogradeCycles.defaultResultTab == "cycles")
        #expect(ModernSubMode.classicalVisibility.defaultResultTab == "heliacal")
        #expect(ModernSubMode.astrocartography.defaultResultTab == "lines")
        #expect(ModernSubMode.localSpace.defaultResultTab == "directions")
    }

    @Test func resetModernSelectedTabUsesSubModeDefault() {
        let vm = CalculationViewModel()
        vm.modernSelectedTab = "lunation"
        vm.resetModernSelectedTab(for: .synastry)
        #expect(vm.modernSelectedTab == "cross_aspects")
        vm.resetModernSelectedTab(for: .solarArc)
        #expect(vm.modernSelectedTab == "sa_planets")
        vm.resetModernSelectedTab(for: .midpoint)
        #expect(vm.modernSelectedTab == "axes")
        vm.resetModernSelectedTab(for: .progressedComposite)
        #expect(vm.modernSelectedTab == "radix_composite_planets")
    }
}
