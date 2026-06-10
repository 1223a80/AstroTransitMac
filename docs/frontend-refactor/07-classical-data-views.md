# 模块 07：古典隐藏字段补全

> **依赖**：01 (Design Tokens), 03 (Tab Bar)  
> **风险**：低（纯新增，嵌入已有 tab）  
> **修改文件**：`Sources/TransitStudio/ClassicalResultViews.swift`（timing tab 区域）

## 背景

后端 `classical` 模式返回两个高价值字段，Model 已在 `ClassicalResultModels.swift` 中定义，但没有任何 UI 展示：

### BirthdayTransition（生日过渡检测）

```swift
// ClassicalResultModels.swift:64-80
struct BirthdayTransition: Codable {
    let detected: Bool
    let note: String
    let profectionAge: Int?
    let profectionStart: String?
    let currentSolarReturn: String?
    let nextSolarReturn: String?
}
```

当出生日在参考日期前后时（年主切换时机），后端会计算太阳回归日和小限切换日。

### ActivatedLordFocus（当前年主聚焦）

```swift
// ClassicalResultModels.swift:82-102
struct ActivatedLordFocus: Codable {
    let lordID: String
    let lordName: String
    let natalCondition: String?
    let natalScore: Int?
    let natalHouse: Int?
    let returnTitle: String?
    let returnExactLocal: String?
    let keywords: String?
}
```

显示当前小限年主的状态评分、本命宫位、返照日期和关键词。

## 实现方案

在 `ClassicalResultViews.swift` 的 `ClassicalTimingView` 顶部插入两个卡片。不新建文件——直接在 timing view 内部添加。

### 在 ClassicalTimingView 中添加

找到 `ClassicalTimingView` 的 `body`（在 `ClassicalResultViews.swift` 中搜索），在现有内容**最上方**插入：

```swift
// 在 ClassicalTimingView body 的 VStack 顶部添加：

// Birthday Transition 卡片
if let transition = result.birthdayTransition, transition.detected {
    birthdayTransitionCard(transition)
}

// Activated Lord Focus 卡片
if let lordFocus = result.activatedLordFocus {
    activatedLordCard(lordFocus)
}
```

### birthdayTransitionCard 实现

```swift
@ViewBuilder
private func birthdayTransitionCard(_ transition: BirthdayTransition) -> some View {
    VStack(alignment: .leading, spacing: TS.Spacing.md) {
        Label("生日过渡期", systemImage: "calendar.badge.exclamationmark")
            .font(TS.Font.sectionTitle)
            .foregroundStyle(TS.SemanticColor.warning)

        Text(transition.note)
            .font(TS.Font.body)

        HStack(spacing: TS.Spacing.xl) {
            if let age = transition.profectionAge {
                VStack(alignment: .leading) {
                    Text("小限年龄").font(TS.Font.label).foregroundStyle(.secondary)
                    Text("\(age)").font(TS.Font.body)
                }
            }
            if let start = transition.profectionStart {
                VStack(alignment: .leading) {
                    Text("小限起始").font(TS.Font.label).foregroundStyle(.secondary)
                    Text(start).font(TS.Font.mono)
                }
            }
        }

        HStack(spacing: TS.Spacing.xl) {
            if let current = transition.currentSolarReturn {
                VStack(alignment: .leading) {
                    Text("当前太阳回归").font(TS.Font.label).foregroundStyle(.secondary)
                    Text(current).font(TS.Font.mono)
                }
            }
            if let next = transition.nextSolarReturn {
                VStack(alignment: .leading) {
                    Text("下次太阳回归").font(TS.Font.label).foregroundStyle(.secondary)
                    Text(next).font(TS.Font.mono)
                }
            }
        }
    }
    .padding(TS.Padding.sectionGap)
    .background(TS.SemanticColor.warning.opacity(TS.Opacity.muted))
    .clipShape(RoundedRectangle(cornerRadius: TS.Radius.card))
}
```

### activatedLordCard 实现

```swift
@ViewBuilder
private func activatedLordCard(_ lord: ActivatedLordFocus) -> some View {
    VStack(alignment: .leading, spacing: TS.Spacing.md) {
        HStack {
            Label("年主聚焦: \(lord.lordName)", systemImage: "star.circle")
                .font(TS.Font.sectionTitle)
            Spacer()
            if let score = lord.natalScore {
                Text("评分 \(score)")
                    .font(TS.Font.label)
                    .padding(.horizontal, TS.Padding.chipHorizontal)
                    .padding(.vertical, TS.Spacing.xs)
                    .background(TS.SemanticColor.accentSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: TS.Radius.chip))
            }
        }

        HStack(spacing: TS.Spacing.xl) {
            if let condition = lord.natalCondition {
                VStack(alignment: .leading) {
                    Text("本命状态").font(TS.Font.label).foregroundStyle(.secondary)
                    Text(condition).font(TS.Font.body)
                }
            }
            if let house = lord.natalHouse {
                VStack(alignment: .leading) {
                    Text("本命宫位").font(TS.Font.label).foregroundStyle(.secondary)
                    Text("第 \(house) 宫").font(TS.Font.body)
                }
            }
        }

        if let returnTitle = lord.returnTitle {
            VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                Text(returnTitle).font(TS.Font.body)
                if let exact = lord.returnExactLocal {
                    Text(exact).font(TS.Font.mono).foregroundStyle(.secondary)
                }
            }
        }

        if let keywords = lord.keywords, !keywords.isEmpty {
            Text(keywords)
                .font(TS.Font.label)
                .foregroundStyle(.secondary)
        }
    }
    .padding(TS.Padding.sectionGap)
    .background(TS.SemanticColor.cardBackground)
    .clipShape(RoundedRectangle(cornerRadius: TS.Radius.card))
}
```

## 验证前必须确认

```bash
# 确认 ClassicalResult 确实有这两个字段
grep -n "birthdayTransition\|activatedLordFocus" Sources/TransitStudio/ClassicalResultModels.swift

# 确认 ClassicalTimingView 在哪个文件
grep -rn "ClassicalTimingView" Sources/TransitStudio/ --include="*.swift"
```

## 验证

```bash
swift build

# 跑古典排盘，确认 timing tab 顶部出现卡片（如果后端返回了数据）
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('birthdayTransition:', d.get('birthday_transition'))
print('activatedLordFocus:', d.get('activated_lord_focus'))
"
```

## 不要做的事

- ❌ 不要新建独立 tab——这两个字段语义上属于 timing（时间技法）
- ❌ 不要修改 Model 层——`BirthdayTransition` 和 `ActivatedLordFocus` 已经正确定义
- ❌ 不要修改后端——数据已经在返回
