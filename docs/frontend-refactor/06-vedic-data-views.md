# 模块 06：吠陀缺失 View 补全

> **依赖**：01 (Design Tokens), 03 (Tab Bar)  
> **风险**：低（纯新增 View，不修改现有逻辑）  
> **新建文件**：6 个 View 文件  
> **修改文件**：`ContentView+ResultsPanes.swift`（吠陀 tab 定义区域）

## 背景

后端 `vedic` 模式返回 ~15 种数据结构，`VedicResultModels.swift` 中已定义全部 Codable 模型。但前端只展示了 5 种：

| 已有 tab | 展示的数据 |
|----------|-----------|
| 综览 (overview) | rasiChart, planets, meta |
| Daśā | vimshottari |
| Ṣaḍbala | shadbala |
| Yōga | yogas |
| Navāṃśa | navamsa |

以下数据**已解码但完全无 UI**：

| 数据 | Model 类型 | 优先级 |
|------|-----------|--------|
| panchanga + solarDay | `VedicPanchanga`, `VedicSolarDay` | 🔴 高 |
| arudha | `[String: VedicArudhaPada]` | 🔴 高 |
| jaiminiKarakas | `VedicJaiminiKarakas` | 🔴 高 |
| ashtakavarga | `VedicAshtakavarga` | 🟡 中 |
| divisionalCharts | `[String: VedicDivisionalChart]` | 🟡 中 |
| planetRelationships | `VedicRelationships` | 🟡 中 |
| upagrahas | `[VedicUpagraha]` | 🟢 低 |
| specialLagnas | `[VedicSpecialLagna]` | 🟢 低 |
| moonChart | `VedicDerivedChart` | 🟢 低 |
| bhavaChart | `VedicDerivedChart` | 🟢 低 |
| yoginiDasa | `YoginiDasaResult` | 🟡 中 |
| ashtottariDasa | `AshtottariDasaResult` | 🟡 中 |

## 重构后的 Tab 结构

```
主 tab 行（水平滚动）：
overview | Pañcāṅga | Daśā | Ṣaḍbala | Yōga | Navāṃśa | Varga | Jaimini | Aṣṭakavarga | Relationships

更多菜单：
Moon Chart | Bhava | Upagrahas | Special Lagnas | AI | Diagnostics | JSON
```

在 `ContentView+ResultsPanes.swift` 中修改：

```swift
// 旧代码（约 line 915）
tabRows: [[(id: "overview", title: "综览"), (id: "dasa", title: "Daśā"), ...]]

// 新代码
tabs: [
    (id: "overview", title: "综览"),
    (id: "panchanga", title: "Pañcāṅga"),
    (id: "dasa", title: "Daśā"),
    (id: "shadbala", title: "Ṣaḍbala"),
    (id: "yoga", title: "Yōga"),
    (id: "navamsa", title: "Navāṃśa"),
    (id: "varga", title: "Varga"),
    (id: "jaimini", title: "Jaimini"),
    (id: "ashtakavarga", title: "Aṣṭakavarga"),
    (id: "relationships", title: "关系"),
],
moreTabs: [
    (id: "moon_chart", title: "Moon Chart"),
    (id: "bhava", title: "Bhava"),
    (id: "upagrahas", title: "副行星"),
    (id: "special_lagnas", title: "特殊 Lagna"),
    (id: "ai", title: "AI 分析"),
    (id: "diagnostics", title: "诊断"),
    (id: "json", title: "JSON"),
]
```

---

## 各 View 实现规范

### 通用 pattern

所有新 View 遵循同一模式：

```swift
struct VedicXxxView: View {
    let data: VedicXxxModel  // 接受模型作为参数

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                // 内容
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TS.Padding.resultContent)
        }
    }
}
```

在 `ContentView+ResultsPanes.swift` 的 `switch vedicSelectedTab` 中添加 case：

```swift
case "panchanga":
    if let panchanga = result.panchanga {
        VedicPanchangaView(panchanga: panchanga, solarDay: result.solarDay)
    } else {
        Text("开启完整计算以获得 Pañcāṅga 数据").foregroundStyle(.secondary)
    }
```

### tabTitle 映射

在 `vedicTabTitle` computed property 中添加对应的 case：

```swift
case "panchanga": return "Pañcāṅga"
case "varga": return "分割图"
case "jaimini": return "Jaimini"
case "ashtakavarga": return "Aṣṭakavarga"
case "relationships": return "行星关系"
case "moon_chart": return "Moon Chart"
case "bhava": return "Bhava Chart"
case "upagrahas": return "副行星"
case "special_lagnas": return "特殊 Lagna"
```

---

## 文件 1：VedicPanchangaView.swift

**展示**：`VedicPanchanga` + `VedicSolarDay`

```swift
import SwiftUI

struct VedicPanchangaView: View {
    let panchanga: VedicPanchanga
    let solarDay: VedicSolarDay?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                Text("Pañcāṅga 五支").font(TS.Font.pageTitle)

                panchangaGrid

                if let solarDay {
                    solarDaySection(solarDay)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TS.Padding.resultContent)
        }
    }

    private var panchangaGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), alignment: .leading),
            GridItem(.flexible(), alignment: .leading)
        ], spacing: TS.Spacing.md) {
            ForEach(panchanga.items, id: \.label) { item in
                VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                    Text(item.label).font(TS.Font.label).foregroundStyle(.secondary)
                    Text(item.value).font(TS.Font.body)
                    if let lord = item.lord {
                        Text("主星: \(lord)").font(TS.Font.detail).foregroundStyle(.secondary)
                    }
                }
                .padding(TS.Padding.cardInner)
                .background(TS.SemanticColor.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: TS.Radius.card))
            }
        }
    }

    private func solarDaySection(_ day: VedicSolarDay) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            Text("日出 / 日落").font(TS.Font.sectionTitle)
            HStack(spacing: TS.Spacing.xl) {
                Label(day.sunrise, systemImage: "sunrise")
                Label(day.sunset, systemImage: "sunset")
            }
            .font(TS.Font.body)
        }
    }
}
```

**注意**：先 `grep` 确认 `VedicPanchanga` 和 `VedicPanchangaItem` 的具体字段名。上面的 `.items`, `.label`, `.value`, `.lord` 是根据模型推测的——以 `VedicResultModels.swift` 实际定义为准。

---

## 文件 2：VedicDivisionalChartView.swift

**展示**：`[String: VedicDivisionalChart]`

```swift
import SwiftUI

struct VedicDivisionalChartView: View {
    let charts: [String: VedicDivisionalChart]
    @State private var selectedChart = "D9"

    private var sortedKeys: [String] {
        charts.keys.sorted { a, b in
            let numA = Int(a.dropFirst()) ?? 0
            let numB = Int(b.dropFirst()) ?? 0
            return numA < numB
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            // 分割图选择器
            Picker("分割图", selection: $selectedChart) {
                ForEach(sortedKeys, id: \.self) { key in
                    Text(key).tag(key)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, TS.Padding.resultContent)

            // 选中图的行星表
            if let chart = charts[selectedChart] {
                chartTable(chart)
            } else {
                Text("选择分割图查看").foregroundStyle(.secondary)
            }
        }
    }

    private func chartTable(_ chart: VedicDivisionalChart) -> some View {
        Table(chart.planets.values.sorted { $0.bodyId < $1.bodyId }) {
            TableColumn("天体") { Text($0.name) }
            TableColumn("星座") { Text($0.sign) }
            TableColumn("度数") { Text($0.degreeText) }
            TableColumn("Nakṣatra") { pos in
                if let nak = pos.nakshatra {
                    Text("\(nak.name) Pada \(nak.pada)")
                }
            }
        }
    }
}
```

**注意**：`VedicDivisionalChart` 的字段（`.planets`）以 `VedicResultModels.swift` 实际定义为准。如果是 `[VedicDivisionalPlanet]` 而非字典，调整为 `ForEach`。

---

## 文件 3：VedicJaiminiView.swift

**展示**：`VedicJaiminiKarakas` + `[String: VedicArudhaPada]`

将 Jaimini 的两个核心概念合并在一个 tab 里：

```swift
import SwiftUI

struct VedicJaiminiView: View {
    let karakas: VedicJaiminiKarakas?
    let arudha: [String: VedicArudhaPada]?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                if let karakas {
                    karakaSection(karakas)
                }

                if let arudha, !arudha.isEmpty {
                    arudhaSection(arudha)
                }

                if karakas == nil && (arudha == nil || arudha!.isEmpty) {
                    Text("开启完整计算以获得 Jaimini 数据").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TS.Padding.resultContent)
        }
    }

    private func karakaSection(_ k: VedicJaiminiKarakas) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text("Chara Kāraka（变动主星）").font(TS.Font.pageTitle)

            // 遍历 karakas.charaKarakas 列表
            // 每行显示：karaka 名称（AK/AmK/BK...）+ 对应行星 + 度数
            ForEach(k.charaKarakas) { karaka in
                HStack {
                    Text(karaka.karakaName)
                        .font(TS.Font.sectionTitle)
                        .frame(width: 120, alignment: .leading)
                    Text(karaka.planetName)
                        .font(TS.Font.body)
                    Spacer()
                    Text(karaka.degree ?? "")
                        .font(TS.Font.mono)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func arudhaSection(_ padas: [String: VedicArudhaPada]) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text("Ārūḍha Pada").font(TS.Font.pageTitle)

            let sorted = padas.sorted { a, b in
                let numA = Int(a.key.dropFirst()) ?? 0
                let numB = Int(b.key.dropFirst()) ?? 0
                return numA < numB
            }

            ForEach(sorted, id: \.key) { key, pada in
                HStack {
                    Text(key)
                        .font(TS.Font.sectionTitle)
                        .frame(width: 60, alignment: .leading)
                    Text(pada.rasi)
                        .font(TS.Font.body)
                    Spacer()
                    Text("宫 \(pada.house)")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
```

**注意**：字段名（`.charaKarakas`, `.karakaName`, `.planetName`, `.rasi`, `.house`）以 `VedicResultModels.swift` 实际定义为准。执行前**必须 `grep` 确认**。

---

## 文件 4：VedicAshtakavargaView.swift

**展示**：`VedicAshtakavarga`（BAV 点数矩阵 + SAV 总分）

这是一个矩阵型展示，推荐用 `Grid` 或 `Table`：

```swift
import SwiftUI

struct VedicAshtakavargaView: View {
    let data: VedicAshtakavarga

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                Text("Aṣṭakavarga").font(TS.Font.pageTitle)

                // SAV 总表
                if let sav = data.sav {
                    savSection(sav)
                }

                // BAV 各行星分表
                ForEach(data.bav.sorted(by: { $0.key < $1.key }), id: \.key) { planetId, bav in
                    bavSection(planetId: planetId, bav: bav)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TS.Padding.resultContent)
        }
    }

    // 实现 SAV 和 BAV 的表格展示
    // SAV: 12 宫的总 bindu 分数
    // BAV: 每颗行星在 12 宫的 bindu 分数
    // 具体字段以 VedicResultModels.swift 中 VedicSAV / VedicBAV 的定义为准
}
```

---

## 文件 5：VedicRelationshipsView.swift

**展示**：`VedicRelationships`（自然友谊、临时友谊、综合关系）

```swift
import SwiftUI

struct VedicRelationshipsView: View {
    let relationships: VedicRelationships

    @State private var selectedSection = "compound"

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Picker("关系类型", selection: $selectedSection) {
                Text("综合关系").tag("compound")
                Text("自然友谊").tag("naisargika")
                Text("临时友谊").tag("tatkalika")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, TS.Padding.resultContent)

            // 根据 selectedSection 切换展示
            // 每种关系展示为行星对的网格表
            // 具体字段以 VedicResultModels.swift 中的定义为准
        }
    }
}
```

---

## 文件 6：VedicMiscDataViews.swift

**展示**：低优先级数据集合（副行星、特殊 Lagna、Moon/Bhava Chart）

```swift
import SwiftUI

// MARK: - Upagrahas
struct VedicUpagrahaView: View {
    let upagrahas: [VedicUpagraha]

    var body: some View {
        Table(upagrahas) {
            TableColumn("名称") { Text($0.name) }
            TableColumn("星座") { Text($0.sign) }
            TableColumn("度数") { Text($0.degreeText) }
            TableColumn("Nakṣatra") { upa in
                Text(upa.nakshatra ?? "")
            }
        }
    }
}

// MARK: - Special Lagnas
struct VedicSpecialLagnaView: View {
    let lagnas: [VedicSpecialLagna]

    var body: some View {
        Table(lagnas) {
            TableColumn("Lagna") { Text($0.name) }
            TableColumn("星座") { Text($0.sign) }
            TableColumn("度数") { Text($0.degreeText) }
        }
    }
}

// MARK: - Derived Chart (Moon / Bhava)
struct VedicDerivedChartView: View {
    let title: String
    let chart: VedicDerivedChart

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text(title).font(TS.Font.pageTitle)
            // 展示 chart.planets 列表
            // 字段以 VedicResultModels.swift 中 VedicDerivedChart 定义为准
        }
    }
}
```

---

## Daśā Tab 增强

现有 "Daśā" tab 只展示 Vimshottari。增加内部 Picker 切换其他大运系统：

在 `ContentView+ResultsPanes.swift` 的 `case "dasa":` 中，替换为：

```swift
case "dasa":
    VedicDasaContainerView(
        vimshottari: result.vimshottari,
        yogini: result.yoginiDasa,
        ashtottari: result.ashtottariDasa
    )
```

新建容器或在 `VedicResultViews.swift` 中添加：

```swift
struct VedicDasaContainerView: View {
    let vimshottari: VimsottariResult?
    let yogini: YoginiDasaResult?
    let ashtottari: AshtottariDasaResult?

    @State private var selectedSystem = "vimshottari"

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Picker("大运系统", selection: $selectedSystem) {
                Text("Vimśottarī").tag("vimshottari")
                if yogini != nil { Text("Yoginī").tag("yogini") }
                if ashtottari != nil { Text("Aṣṭottarī").tag("ashtottari") }
            }
            .pickerStyle(.segmented)

            switch selectedSystem {
            case "vimshottari":
                if let dasa = vimshottari {
                    VedicDasaTimelineView(dasa: dasa)  // 复用现有
                } else {
                    Text("无 Vimśottarī 数据").foregroundStyle(.secondary)
                }
            case "yogini":
                if let dasa = yogini {
                    VedicYoginiDasaView(dasa: dasa)  // 新建，复用 DasaPeriodRow pattern
                }
            case "ashtottari":
                if let dasa = ashtottari {
                    VedicAshtottariDasaView(dasa: dasa)
                }
            default:
                EmptyView()
            }
        }
    }
}
```

Yogini 和 Ashtottari 的 View 复用 `VedicDasaTimelineView` 的 `DasaPeriodRow` pattern（已在 `VedicResultViews.swift` 中定义）。

---

## 执行顺序建议

1. 先改 `ContentView+ResultsPanes.swift` 的 tab 定义（添加 tab id + tabTitle 映射 + empty case）
2. 逐个创建 View 文件，每个文件完成后 `swift build`
3. 优先级：Panchanga → Jaimini → Ashtakavarga → Varga → Relationships → Misc → Dasa 增强

## 验证

```bash
swift build
swift test
# 打开 app，切到吠陀模式，确认新 tab 出现
# 点击每个新 tab，有数据时应正常展示，无数据时显示提示文字
```

## 关键提醒

- **必须先 `grep` 确认每个 Model 的字段名**，不要猜测
- 所有 Model 都在 `Sources/TransitStudio/VedicResultModels.swift`
- 所有字段都是 `Optional`，用 `if let` guard
- 复用现有组件：`InfoCard`、`Table`、`EmptyStateView`
