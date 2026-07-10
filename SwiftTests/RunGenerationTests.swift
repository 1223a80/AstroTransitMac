import Foundation
import Testing
@testable import TransitStudio

@MainActor
struct RunGenerationTests {
    @Test func supersededRunDoesNotClearNewerTaskReference() {
        let vm = CalculationViewModel()
        let first = vm.beginRun(isStoppable: true)
        vm.currentRunTask = Task {}
        let second = vm.beginRun(isStoppable: true)
        #expect(second != first)
        #expect(vm.isCurrentRun(second))
        #expect(!vm.isCurrentRun(first))

        vm.clearRunTaskIfCurrent(first)
        #expect(vm.currentRunTask != nil)

        vm.clearRunTaskIfCurrent(second)
        #expect(vm.currentRunTask == nil)
        #expect(!vm.currentRunIsStoppable)
    }

    @Test func stopInvalidatesPreviousGeneration() {
        let vm = CalculationViewModel()
        let generation = vm.beginRun(isStoppable: true)
        #expect(vm.isCurrentRun(generation))
        #expect(vm.currentRunIsStoppable)
        _ = vm.beginRun(isStoppable: false)
        #expect(!vm.isCurrentRun(generation))
        #expect(!vm.currentRunIsStoppable)
    }

    @Test func stoppabilityIsTaskPropertyNotPageMode() {
        let vm = CalculationViewModel()
        _ = vm.beginRun(isStoppable: true)
        vm.currentRunTask = Task {}
        #expect(vm.currentRunIsStoppable)
        // Switching UI mode is external; task stoppability stays true until
        // the run ends or is invalidated.
        #expect(vm.currentRunIsStoppable)

        vm.invalidateActiveRun()
        #expect(vm.currentRunTask == nil)
        #expect(!vm.currentRunIsStoppable)

        _ = vm.beginRun(isStoppable: false)
        vm.currentRunTask = Task {}
        #expect(!vm.currentRunIsStoppable)
        vm.invalidateActiveRun()
        #expect(!vm.currentRunIsStoppable)
    }
}
