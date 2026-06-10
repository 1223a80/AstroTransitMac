import SwiftUI

/// A sidebar section with a clickable header that toggles collapse/expand.
/// Lightweight VStack + Divider layout, no GroupBox.
struct CollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.bottom, TS.Spacing.md)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: TS.Spacing.md) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(TS.Font.detail)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(TS.Font.sectionTitle)
                        .foregroundStyle(.primary)
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
