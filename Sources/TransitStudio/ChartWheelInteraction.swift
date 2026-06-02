import SwiftUI

class ChartWheelSelection: ObservableObject {
    @Published var hoveredPointID: String? = nil
    @Published var selectedPointID: String? = nil
}

struct ChartWheelInteraction: ViewModifier {
    let data: ChartWheelData
    let geometry: ChartWheelGeometry
    @ObservedObject var selection: ChartWheelSelection

    private var pointLayouts: [String: WheelPointLayout] {
        wheelPointLayouts(for: data.points, geometry: geometry)
    }

    func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    selection.hoveredPointID = hitTest(location)
                case .ended:
                    selection.hoveredPointID = nil
                }
            }
            .onTapGesture { location in
                if let hit = hitTest(location) {
                    if selection.selectedPointID == hit {
                        selection.selectedPointID = nil
                    } else {
                        selection.selectedPointID = hit
                    }
                } else {
                    selection.selectedPointID = nil
                }
            }
    }

    private func hitTest(_ location: CGPoint) -> String? {
        var closest: (id: String, dist: CGFloat)? = nil
        for point in data.points {
            let r = pointLayouts[point.id]?.anchorRadius ?? planetRingRadius(for: point)
            let pt = geometry.point(for: point.longitude, at: r)
            let dx = location.x - pt.x
            let dy = location.y - pt.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < 16 {
                if closest == nil || dist < closest!.dist {
                    closest = (point.id, dist)
                }
            }
        }
        return closest?.id
    }

    private func planetRingRadius(for point: ChartWheelData.WheelPoint) -> CGFloat {
        point.isTransit ? geometry.transitPointRadius : geometry.natalPointRadius
    }
}
