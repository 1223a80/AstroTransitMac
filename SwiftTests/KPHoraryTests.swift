import Foundation
import Testing
@testable import TransitStudio

@MainActor
struct KPHoraryTests {
    @Test func requestUsesIndependentSnakeCaseContract() throws {
        let request = KPHoraryRequest(
            mode: "kp_horary",
            chart: KPHoraryChartSettings(
                moment: ChartMoment(
                    year: 2026,
                    month: 8,
                    day: 12,
                    hour: 16,
                    minute: 0,
                    timezone: "GMT+8",
                    second: 7
                ),
                latitude: 31.2304,
                longitude: 121.4737
            ),
            questionText: "test question",
            placeName: "Shanghai",
            horaryNumber: 123,
            focusHouse: 7,
            nodeMode: "mean",
            ephemerisPath: nil,
            noAsteroids: false,
            requireEphemeris: "warn"
        )
        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["mode"] as? String == "kp_horary")
        #expect(object["question_text"] as? String == "test question")
        #expect(object["horary_number"] as? Int == 123)
        #expect(object["focus_house"] as? Int == 7)
        #expect(object["node_mode"] as? String == "mean")
        #expect(object["questionText"] == nil)
        let chart = try #require(object["chart"] as? [String: Any])
        let moment = try #require(chart["moment"] as? [String: Any])
        #expect(moment["second"] as? Int == 7)
    }

    @Test func kpNavigationAndTabContractIsComplete() {
        #expect(CalculationMode.kpHorary.rawValue == "kp_horary")
        #expect(CalculationMode.kpHorary.title == "KP 占卜")
        #expect(CalculationViewModel().kpHorarySelectedTab == "overview")
        #expect(KPHoraryResultPane.tabs.map(\.id) == [
            "overview", "planets", "houses", "planet_significators", "house_significators", "focus_house",
        ])
        #expect(KPHoraryResultPane.moreTabs.map(\.id) == ["diagnostics", "json"])
    }

    @Test func leavingVedicKPDoesNotLeakModeIntoOtherPractices() {
        let modern = PracticeModeTransition.apply(
            from: .vedic,
            to: .modern,
            modernSubMode: .natal,
            calculationMode: .kpHorary,
            workspace: .natalChart
        )
        #expect(modern.calculationMode == .settings)

        let classical = PracticeModeTransition.apply(
            from: .vedic,
            to: .classical,
            modernSubMode: .natal,
            calculationMode: .kpHorary,
            workspace: .natalChart
        )
        #expect(classical.calculationMode == .settings)
    }
}
