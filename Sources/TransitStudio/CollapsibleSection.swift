import SwiftUI

/// A sidebar section with a clickable header that toggles collapse/expand.
/// Almanac style: a thin top rule, a small uppercase eyebrow label, and a
/// disclosure chevron. No heavy GroupBox chrome.
struct CollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(TS.SemanticColor.lineSoft)
                .frame(height: 1)
                .padding(.bottom, TS.Spacing.md)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: TS.Spacing.md) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(TS.SemanticColor.inkFaint)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text(title.uppercased())
                        .font(TS.Font.eyebrow)
                        .tracking(1.2)
                        .foregroundStyle(TS.SemanticColor.inkSoft)
                    Spacer()
                }
                .contentShape(Rectangle())
                .padding(.vertical, TS.Spacing.xs)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .padding(.top, TS.Spacing.md)
                    .transition(.opacity)
            }
        }
    }
}
