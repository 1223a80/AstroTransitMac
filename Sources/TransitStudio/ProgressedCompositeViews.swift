import SwiftUI

struct ProgressedCompositeResultPane: View {
    let result: ProgressedCompositeResult
    @Binding var selectedTab: String

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { MarkdownExportBuilder.progressedComposite(result) },
                jsonProvider: { TextExportBuilder.progressedCompositeJSON(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "progressed_composite"
            )
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    /// The default tab is the independently calculated radix composite
    /// snapshot used by the progressed-to-radix aspect comparison.
    var tabs: [(String, String)] {
        [
            ("radix_composite_planets", "Radix Composite"),
            ("progressed_composite_planets", "Progressed Composite"),
            ("aspects", "推进→Radix 相位"),
        ]
    }

    var moreTabs: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var tabTitle: String {
        resultTabTitle(selectedTab, in: tabs, moreTabs)
    }

    @ViewBuilder
    var selectedResultView: some View {
        switch selectedTab {
        case "radix_composite_planets":
            PositionTableView(title: "Radix Composite 行星", positions: positionRows(result.radixCompositePlanets))
        case "progressed_composite_planets":
            PositionTableView(title: "Progressed Composite 行星", positions: positionRows(result.progressedCompositePlanets))
        case "aspects":
            AspectTableView(
                title: "Progressed Composite → Radix Composite 相位",
                leftColumnTitle: "推进组合点",
                rightColumnTitle: "Radix 组合点",
                aspects: result.progressedToRadixAspects
            )
        case "diagnostics":
            ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
        case "json":
            RawJSONView(value: result)
        default:
            PositionTableView(title: "Radix Composite 行星", positions: positionRows(result.radixCompositePlanets))
        }
    }

    private func positionRows(_ planets: [ProgressedCompositePlanet]) -> [PositionRow] {
        planets.map {
            PositionRow(
                bodyID: $0.bodyID,
                name: $0.name,
                longitude: $0.longitude,
                latitude: $0.latitude,
                declination: $0.declination,
                outOfBounds: $0.outOfBounds,
                speed: $0.speed,
                sign: $0.sign,
                degreeText: $0.degreeText,
                house: nil
            )
        }
    }

}
