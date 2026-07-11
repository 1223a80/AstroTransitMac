import SwiftUI

struct ChartWheelView: View {
    let data: ChartWheelData
    @StateObject private var selection = ChartWheelSelection()
    // Canvas resolves dynamic colors at draw time; force a redraw when the
    // appearance flips so the wheel switches skins immediately.
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let frame = CGSize(width: side, height: side)
                let geom = ChartWheelGeometry(size: frame)
                let layouts = wheelPointLayouts(for: data.points, geometry: geom)

                ZStack {
                    ChartWheelCanvas(
                        data: data,
                        geometry: geom,
                        hoveredPointID: selection.hoveredPointID,
                        selectedPointID: selection.selectedPointID
                    )
                    .modifier(ChartWheelInteraction(data: data, geometry: geom, selection: selection))

                    if let id = selection.hoveredPointID ?? selection.selectedPointID,
                       let point = data.points.first(where: { $0.id == id }) {
                        let tooltipRadius = (layouts[id]?.labelRadius ?? geom.natalPointRadius) + 26
                        let tooltipPoint = geom.point(for: point.longitude, at: tooltipRadius)
                        WheelTooltip(point: point)
                            .position(x: tooltipPoint.x, y: tooltipPoint.y)
                    }
                }
                .frame(width: side, height: side)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            if !data.unresolvedAspectEndpoints.isEmpty {
                VStack {
                    HStack {
                        Label("有 \(data.unresolvedAspectEndpoints.count) 条相位端点无法解析", systemImage: "exclamationmark.triangle")
                            .font(TS.Font.label)
                            .foregroundStyle(.orange)
                            .help(data.unresolvedAspectEndpoints.joined(separator: "\n"))
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .id(colorScheme)
        .padding(TS.Padding.sidebarContent)
    }
}
