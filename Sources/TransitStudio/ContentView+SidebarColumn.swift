import SwiftUI

extension ContentView {
    static let defaultMiddleSidebarWidth: CGFloat = 430
    static let minMiddleSidebarWidth: CGFloat = 320
    static let maxMiddleSidebarWidth: CGFloat = 560
    static let middleSidebarCollapseThreshold: CGFloat = 260
    static let collapsedMiddleSidebarHandleWidth: CGFloat = 22

    var middleSidebarColumn: some View {
        sidebar
            .frame(width: clampedMiddleSidebarWidth)
            .background(.thinMaterial)
            .overlay(alignment: .topTrailing) {
                middleSidebarCollapseButton
                    .padding(.top, TS.Spacing.md)
                    .padding(.trailing, TS.Spacing.md)
            }
            .overlay(alignment: .trailing) {
                middleSidebarResizeHandle
            }
    }

    var collapsedMiddleSidebarToggle: some View {
        VStack {
            Button {
                expandMiddleSidebar()
            } label: {
                Image(systemName: "sidebar.right")
                    .font(TS.Font.label.weight(.semibold))
                    .frame(width: 18, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("展开侧边栏")

            Spacer(minLength: 0)
        }
        .frame(width: Self.collapsedMiddleSidebarHandleWidth)
        .background(.thinMaterial)
    }

    var middleSidebarCollapseButton: some View {
        Button {
            collapseMiddleSidebar()
        } label: {
            Image(systemName: "sidebar.left")
                .font(TS.Font.label.weight(.semibold))
                .frame(width: 24, height: 24)
                .background(TS.SemanticColor.cardBackground, in: RoundedRectangle(cornerRadius: TS.Radius.chip))
        }
        .buttonStyle(.plain)
        .help("收起侧边栏")
    }

    var middleSidebarResizeHandle: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if middleSidebarDragStartWidth == nil {
                            middleSidebarDragStartWidth = clampedMiddleSidebarWidth
                        }

                        let baseWidth = middleSidebarDragStartWidth ?? clampedMiddleSidebarWidth
                        let proposedWidth = baseWidth + value.translation.width
                        updateMiddleSidebarWidth(proposedWidth)
                    }
                    .onEnded { value in
                        defer { middleSidebarDragStartWidth = nil }

                        let baseWidth = middleSidebarDragStartWidth ?? clampedMiddleSidebarWidth
                        let proposedWidth = baseWidth + value.translation.width

                        if proposedWidth <= Self.middleSidebarCollapseThreshold {
                            collapseMiddleSidebar()
                            return
                        }

                        let finalWidth = clampMiddleSidebarWidth(proposedWidth)
                        middleSidebarWidth = finalWidth
                        middleSidebarLastExpandedWidth = finalWidth
                    }
            )
            .overlay(alignment: .center) {
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 3, height: 56)
            }
    }

    var clampedMiddleSidebarWidth: CGFloat {
        clampMiddleSidebarWidth(middleSidebarWidth)
    }

    func clampMiddleSidebarWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, Self.minMiddleSidebarWidth), Self.maxMiddleSidebarWidth)
    }

    func collapseMiddleSidebar() {
        middleSidebarLastExpandedWidth = clampedMiddleSidebarWidth
        isMiddleSidebarCollapsed = true
        middleSidebarDragStartWidth = nil
    }

    func expandMiddleSidebar() {
        let restoreWidth = middleSidebarLastExpandedWidth > Self.middleSidebarCollapseThreshold
            ? middleSidebarLastExpandedWidth
            : Self.defaultMiddleSidebarWidth
        middleSidebarWidth = clampMiddleSidebarWidth(restoreWidth)
        isMiddleSidebarCollapsed = false
        middleSidebarDragStartWidth = nil
    }

    func updateMiddleSidebarWidth(_ proposedWidth: CGFloat) {
        if proposedWidth <= Self.middleSidebarCollapseThreshold {
            collapseMiddleSidebar()
            return
        }

        let clampedWidth = clampMiddleSidebarWidth(proposedWidth)
        middleSidebarWidth = clampedWidth
        middleSidebarLastExpandedWidth = clampedWidth
        isMiddleSidebarCollapsed = false
    }
}
