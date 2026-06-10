# 模块 02：CollapsibleSection 轻量化

> **依赖**：01 (Design Tokens)  
> **风险**：低  
> **修改文件**：`Sources/TransitStudio/CollapsibleSection.swift`（1 个文件）

## 目标

去掉 `GroupBox` 包装，消除侧边栏"盒中盒"的视觉压迫感。改为轻量级 VStack + Divider 分隔。

## 当前代码

```swift
// CollapsibleSection.swift (当前 38 行)
struct CollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content

    var body: some View {
        GroupBox {                          // ← 问题：GroupBox 有自己的背景和边框
            VStack(alignment: .leading, spacing: 0) {
                Button { ... } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    content
                        .padding(.top, 6)
                        .transition(.opacity)
                }
            }
        }
    }
}
```

## 修改后代码

```swift
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
```

## 关键改动

1. **移除 `GroupBox`** → 改为裸 `VStack`
2. **顶部加 `Divider()`** → 用线条分隔替代盒子边框
3. **采用 `TS.Spacing` / `TS.Font`** → 替换硬编码值
4. **保持 API 不变** — `CollapsibleSection(title:isExpanded:content:)` 签名完全不变，所有 ~20 个调用者无需修改

## 调用者确认

`CollapsibleSection` 通过 `ContentView+SidebarSections.swift` 的 `collapsible(_:content:)` helper 调用，覆盖所有侧边栏区块（时间、地点、天体选择、相位等）。API 不变，调用者无需改动。

## 验证

```bash
swift build
```

编译通过后，打开 app 检查侧边栏的折叠区块是否变轻——不再有灰色方框嵌套。
