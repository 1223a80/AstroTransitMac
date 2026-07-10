import Foundation
import Testing
@testable import TransitStudio

@Suite("Audit frontend state regressions")
struct AuditFrontendStateTests {
    @Test func fractionalGMTOffsetsKeepMinutePrecision() {
        #expect(GMTOffset.timeZone(hours: 5.5).secondsFromGMT() == 19_800)
        #expect(GMTOffset.timeZone(hours: 5.75).secondsFromGMT() == 20_700)
        #expect(GMTOffset.label(hours: 5.5) == "GMT+5:30")
        #expect(GMTOffset.label(hours: -3.5) == "GMT-3:30")
        let date = ContentView.fixedDate(year: 1992, month: 6, day: 15, hour: 8, minute: 30, gmtOffset: -5)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = GMTOffset.timeZone(hours: -5)
        #expect(calendar.component(.hour, from: date) == 8)
    }

    @Test func natalProfileDecodesLegacyIntegerAndFractionalOffsets() throws {
        func profileData(offset: String) -> Data {
            Data("""
            {"id":"00000000-0000-0000-0000-000000000001","name":"Test","moment":{"year":2000,"month":1,"day":1,"hour":12,"minute":0,"timezone":"GMT+8"},"latitude":"0","longitude":"0","gmtOffset":\(offset),"chartStyle":"modern","houseSystem":"whole_sign","zodiac":"tropical","boundsSystem":"egyptian","triplicitySystem":"dorothean"}
            """.utf8)
        }
        let legacy = try JSONDecoder().decode(NatalProfile.self, from: profileData(offset: "8"))
        let fractional = try JSONDecoder().decode(NatalProfile.self, from: profileData(offset: "5.5"))
        #expect(legacy.gmtOffset == 8.0)
        #expect(fractional.gmtOffset == 5.5)
    }

    @MainActor
    @Test func natalAndMomentAIStorageAreIndependent() {
        let model = AIAnalysisViewModel()
        model.natalAnalysis = "natal"
        model.momentAnalysis = "moment"
        model.clear(modeKey: "natal")
        #expect(model.natalAnalysis.isEmpty)
        #expect(model.momentAnalysis == "moment")
    }

    @Test func rectifyProgressParserKeepsPartialLines() {
        let buffer = RectifyStderrBuffer()
        #expect(buffer.append(Data("{\"progress\":0.".utf8)).isEmpty)
        #expect(buffer.append(Data("5}\nnot-json\n{\"progress\":1.0}\n".utf8)) == [0.5, 1.0])
    }

    @MainActor
    @Test func invalidatingRectifyCancelsChildTasksAndAdvancesGenerations() async {
        let model = CalculationViewModel()
        let task = Task<Void, Never> { try? await Task.sleep(nanoseconds: 10_000_000_000) }
        model.rectifyLevel2Task = task
        let oldGeneration = model.rectifyLevel2Gen
        model.invalidateRectifyResults()
        await Task.yield()
        #expect(task.isCancelled)
        #expect(model.rectifyLevel2Gen == oldGeneration + 1)
    }
}
