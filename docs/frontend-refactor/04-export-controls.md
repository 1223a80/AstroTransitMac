# 模块 04：导出控件整理

> **依赖**：01 (Design Tokens), 03 (Tab Bar)  
> **风险**：低  
> **修改文件**：  
> - `Sources/TransitStudio/ExportControls.swift` — 删除（死代码）  
> - `Sources/TransitStudio/ResultToolbarViews.swift` — 微调 ExportMenu（已在模块 03 中处理大部分）

## 目标

1. 删除死代码 `ExportControls.swift`
2. 确认 `ResultPaneToolbar` 的导出区域已经合理（一个 "复制 Markdown" 按钮 + 一个 "导出" 下拉菜单）

## 步骤

### 1. 确认 ExportControls 无调用者

```bash
grep -rn "ExportControls" Sources/TransitStudio/ --include="*.swift"
```

预期结果：只有 `ExportControls.swift:3` 自身定义，无其他文件引用。

### 2. 删除 ExportControls.swift

```bash
rm Sources/TransitStudio/ExportControls.swift
```

### 3. 验证

```bash
swift build
```

如果 build 失败，说明有遗漏的调用者——找到它，将其替换为 `ExportMenu`（已定义在 `ResultToolbarViews.swift`）。

### 4. 整理 ExportMenu（可选优化）

当前 `ExportMenu` 已经是合理的 `Menu` 下拉：

```swift
struct ExportMenu: View {
    let markdownProvider: () -> String
    let jsonProvider: () -> String
    let csvProvider: () -> String
    var basename = "astro_export"

    var body: some View {
        Menu {
            CopyMarkdownButton(title: "复制 JSON", textProvider: jsonProvider)
            CopyMarkdownButton(title: "复制 CSV", textProvider: csvProvider)
            Divider()
            SaveTextButton(title: "保存 JSON", ...)
            SaveTextButton(title: "保存 CSV", ...)
        } label: {
            Label("导出", systemImage: "square.and.arrow.up")
        }
    }
}
```

如果模块 03 已经完成了 token 化，这里只需确认 ExportMenu 也使用了 `TS.Font.label`。如果尚未 token 化，在此模块中完成。

## 不要做的事

- ❌ 不要改变 `ResultPaneToolbar` 的导出逻辑（模块 03 已处理）
- ❌ 不要改变 `CopyMarkdownButton` 或 `SaveTextButton` 的行为
