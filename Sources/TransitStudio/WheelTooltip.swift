import SwiftUI

struct WheelTooltip: View {
    let point: ChartWheelData.WheelPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(point.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(primaryText)
            Text(point.degreeText)
                .font(.system(size: 11))
                .foregroundColor(secondaryText)
            Text("第\(point.house)宫")
                .font(.system(size: 11))
                .foregroundColor(secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(mainWhite)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(lineGray.opacity(0.25), lineWidth: 0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}
