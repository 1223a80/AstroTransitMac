import SwiftUI

extension ContentView {
    var sidebar: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                Text(sidebarTitle)
                    .font(.title3.weight(.semibold))
                sidebarModeControls
                if mode != .rectify {
                    runSection
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    func sectionBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { !collapsedSections.contains(id) },
            set: { if $0 { collapsedSections.remove(id) } else { collapsedSections.insert(id) } }
        )
    }

    var sidebarModeControls: AnyView {
        switch mode {
        case .settings:
            if practiceMode == .classical {
                return AnyView(classicalSettingsSection)
            } else if practiceMode == .vedic {
                return AnyView(vedicSettingsSection)
            }
            return AnyView(modernSettingsSidebar)
        case .horary:
            return AnyView(VStack(alignment: .leading, spacing: 18) {
                collapsible("Horary 问题") { horaryQuestionSection }
                collapsible("地点") { horaryLocationSection }
                collapsible("古典参数") { classicalParameterSection }
            })
        case .moment:
            return AnyView(VStack(alignment: .leading, spacing: 18) {
                collapsible("时间") { momentTimeSection }
                collapsible("当前本命盘") { natalSummarySection }
                collapsible("时间点模板") {
                    momentPresetTemplateSection(
                        title: "时间点模板",
                        template: momentConfigTemplateJSON,
                        text: $momentConfigText,
                        apply: applyMomentConfigTemplate
                    )
                }
                collapsible("本命天体") { bodySection(title: "本命天体", selection: $selectedNatalBodies) }
                collapsible("行运天体") { bodySection(title: "行运天体", selection: $selectedTransitBodies) }
                collapsible("自定义小行星") { customAsteroidSection }
                collapsible("相位") { aspectSection }
            })
        case .scan:
            return AnyView(VStack(alignment: .leading, spacing: 18) {
                collapsible("窗口") { scanWindowSection }
                collapsible("当前本命盘") { natalSummarySection }
                collapsible("扫描模板") {
                    scanPresetTemplateSection(
                        title: "扫描模板",
                        template: scanConfigTemplateJSON,
                        text: $scanConfigText,
                        apply: applyScanConfigTemplate
                    )
                }
                collapsible("扫描行运体") { bodySection(title: "扫描行运体", selection: $selectedTransitBodies) }
                if selectedScanKind == "aspect" {
                    collapsible("目标点") { targetSection }
                    collapsible("相位") { aspectSection }
                }
                collapsible("自定义小行星") { customAsteroidSection }
            })
        case .rectify:
            return AnyView(rectifySidebar)
        }
    }

    @ViewBuilder
    func collapsible<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        CollapsibleSection(title: title, isExpanded: sectionBinding("\(mode.rawValue)_\(title)"), content: content)
    }

    var rectifySidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            collapsible("出生资料") {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("日期", value: dateString)
                    LabeledContent("时间", value: rectifyTimeString)
                    LabeledContent("时区", value: timezoneLabel)
                    LabeledContent("纬度", value: birthLatitude)
                    LabeledContent("经度", value: birthLongitude)
                    LabeledContent("宫制", value: houseSystemLabel)
                    LabeledContent("黄道", value: zodiacLabel)
                    LabeledContent("Bounds", value: boundsLabel)
                    LabeledContent("Triplicity", value: triplicityLabel)
                }
                .font(.callout)
                .monospacedDigit()
            }

            runSection

            if let response = rectifyResponse {
                collapsible("计算结果") {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("候选数", value: "\(response.totalCandidates)")
                        if let w = response.windowMinutes {
                            LabeledContent("窗口", value: "±\(w) 分钟")
                        }
                    }
                    .font(.callout)
                    .monospacedDigit()
                }
            }
        }
    }

    var rectifyTimeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.timeZone = selectedTimeZone
        return f.string(from: natalDate)
    }

    var scanSidebarActionBar: some View {
        HStack {
            Spacer()
            Button {
                Task { await runCurrentMode() }
            } label: {
                Label(isRunning ? "扫描中" : "扫描窗口", systemImage: isRunning ? "hourglass" : "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(runDisabled)
        }
    }

    var momentTimeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            dateTimeInputRow("行运时间", date: $transitDate)
        }
    }

    var horaryQuestionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("起盘时间").foregroundStyle(.secondary)
                DateTimeInput(date: $horaryDate)
                Button("现在") { horaryDate = Date() }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("问题文本")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $horaryQuestionText)
                    .font(.body)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    )
            }
        }
    }

    var horaryLocationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                Button {
                    currentLocationManager.requestCurrentLocation { result in
                        switch result {
                        case .success(let payload):
                            horaryPlaceName = payload.0
                            horaryLatitude = String(format: "%.4f", payload.1)
                            horaryLongitude = String(format: "%.4f", payload.2)
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label(currentLocationManager.isLocating ? "定位中" : "获取当前位置",
                          systemImage: currentLocationManager.isLocating ? "location.fill.viewfinder" : "location")
                }
                .disabled(currentLocationManager.isLocating)
            }
            Text(currentLocationManager.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("地点名").foregroundStyle(.secondary)
                    TextField("例如 Shanghai, CN", text: $horaryPlaceName)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("纬度").foregroundStyle(.secondary)
                    TextField("31.2304", text: $horaryLatitude)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("经度").foregroundStyle(.secondary)
                    TextField("121.4737", text: $horaryLongitude)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    var scanWindowSection: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                Text("名称").foregroundStyle(.secondary)
                TextField("May-Jun 2026", text: $scanWindowLabel)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text("类型").foregroundStyle(.secondary)
                Picker("", selection: $selectedScanKind) {
                    ForEach(Self.scanKindOptions) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .labelsHidden()
            }
            GridRow {
                Text("月亮").foregroundStyle(.secondary)
                Picker("", selection: $scanMoonFilter) {
                    ForEach(Self.moonFilterOptions) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .labelsHidden()
            }
            GridRow {
                Text("开始").foregroundStyle(.secondary)
                DateTimeInput(date: $scanStartDate)
            }
            GridRow {
                Text("结束").foregroundStyle(.secondary)
                DateTimeInput(date: $scanEndDate)
            }
        }
    }

    var natalProfileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("资料名称", text: $natalProfileName)
                    .textFieldStyle(.roundedBorder)
                Button("保存") { saveNatalProfile() }
                Button("删除") { deleteSelectedNatalProfile() }
                    .disabled(selectedNatalProfileID.isEmpty)
            }
            HStack {
                Picker("已保存", selection: $selectedNatalProfileID) {
                    Text("选择资料").tag("")
                    ForEach(natalProfiles) { profile in
                        Text(profile.name).tag(profile.id.uuidString)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                Button("载入") { loadSelectedNatalProfile() }
                    .disabled(selectedNatalProfileID.isEmpty)
            }
        }
    }

    var natalSettingsSection: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                Text("出生").foregroundStyle(.secondary)
                DateTimeInput(date: $natalDate)
            }
            GridRow {
                Text("时区").foregroundStyle(.secondary)
                gmtOffsetControl
            }
            GridRow {
                Text("纬度").foregroundStyle(.secondary)
                TextField("31.2304", text: $birthLatitude)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text("经度").foregroundStyle(.secondary)
                TextField("121.4737", text: $birthLongitude)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    var natalSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(dateTimeText(natalDate))  \(timezoneLabel)")
                .monospacedDigit()
            Text("纬度 \(birthLatitude) / 经度 \(birthLongitude)")
                .foregroundStyle(.secondary)
            Button("返回本命设置") { mode = .settings }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var classicalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            collapsible("本命盘资料") { natalProfileSection }
            collapsible("本命盘") { natalSettingsSection }
            collapsible("参考时间") {
                VStack(alignment: .leading, spacing: 10) {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                        GridRow {
                            Text("参考").foregroundStyle(.secondary)
                            DateTimeInput(date: $classicalReferenceDate)
                        }
                    }
                    Text("用于 annual profection、solar return 以及其他时间技法的落点判断。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            collapsible("古典参数") { classicalParameterSection }
        }
    }

    var vedicSettingsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            collapsible("本命盘资料") { natalProfileSection }
            collapsible("本命盘") { natalSettingsSection }
            collapsible("参考时间") {
                VStack(alignment: .leading, spacing: 10) {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                        GridRow {
                            Text("参考").foregroundStyle(.secondary)
                            DateTimeInput(date: $classicalReferenceDate)
                        }
                    }
                    Text("用于 Daśā 当前期判断。").font(.caption).foregroundStyle(.secondary)
                }
            }
            collapsible("吠陀参数") {
                VStack(alignment: .leading, spacing: 10) {
                    pickerRow("Ayanāṃśa", selection: $vedicAyanamsha, options: Self.ayanamshaOptions)
                    Toggle("完整计算", isOn: $vedicFullMode)
                        .font(.caption)
                }
            }
        }
    }

    private var modernSettingsSidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch modernSubMode {
            case .natal:
                collapsible("本命盘资料") { natalProfileSection }
                collapsible("本命盘") { natalSettingsSection }
                collapsible("自定义小行星") { customAsteroidSection }
                collapsible("本命天体") { bodySection(title: "本命天体", selection: $selectedNatalBodies) }
            case .synastry, .composite, .davison:
                relationChartSidebar
            case .progression, .solarArc:
                timeBasedSidebar
            case .harmonic:
                harmonicSidebar
            }
        }
    }

    private var relationChartSidebar: some View {
        Group {
            collapsible("人物A") { personASection }
            collapsible("人物B") { personBSection }
            collapsible("占星参数") { modernParameterSection }
        }
    }

    private var timeBasedSidebar: some View {
        Group {
            collapsible("本命盘") { natalSettingsSection }
            collapsible("参考时间") {
                VStack(alignment: .leading, spacing: 10) {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                        GridRow {
                            Text("参考").foregroundStyle(.secondary)
                            DateTimeInput(date: $classicalReferenceDate)
                        }
                    }
                }
            }
            collapsible("参数") { modernParameterSection }
        }
    }

    private var harmonicSidebar: some View {
        Group {
            collapsible("本命盘") { natalSettingsSection }
            collapsible("Harmonic 参数") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("阶数").foregroundStyle(.secondary)
                        Spacer()
                        Stepper("H\(modernHarmonicOrder)", value: $modernHarmonicOrder, in: 1...9)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var personASection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("出生").foregroundStyle(.secondary)
                    DateTimeInput(date: $natalDate)
                }
                GridRow {
                    Text("纬度").foregroundStyle(.secondary)
                    TextField("31.2304", text: $birthLatitude).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("经度").foregroundStyle(.secondary)
                    TextField("121.4737", text: $birthLongitude).textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var personBSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("出生").foregroundStyle(.secondary)
                    DateTimeInput(date: $modernPersonBDate)
                }
                GridRow {
                    Text("纬度").foregroundStyle(.secondary)
                    TextField("40.7128", text: $modernPersonBLatitude).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("经度").foregroundStyle(.secondary)
                    TextField("-74.0060", text: $modernPersonBLongitude).textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var modernParameterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            pickerRow("宫制", selection: $selectedHouseSystem, options: Self.houseSystemOptions)
            pickerRow("黄道", selection: $selectedZodiac, options: Self.zodiacOptions)
            pickerRow("节点", selection: $modernNodeMode, options: Self.nodeModeOptions)
            modernAspectSection
        }
    }

    private var modernAspectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("相位").foregroundStyle(.secondary).font(.caption)
                Spacer()
                HStack(spacing: 4) {
                    Button("全选") { selectedAspects = Set(aspectOptions.map(\.id)) }.font(.caption)
                    Button("全不选") { selectedAspects = [] }.font(.caption)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(aspectOptions) { aspect in
                    Toggle(aspect.name, isOn: toggleBinding(for: aspect.id, in: $selectedAspects))
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
            }
            HStack {
                Text("容许度").foregroundStyle(.secondary).font(.caption)
                Spacer()
                Text("\(globalOrb, specifier: "%.1f")°").monospacedDigit()
            }
            Slider(value: $globalOrb, in: 0...10, step: 0.5)
        }
    }

    var sidebarTitle: String {
        if mode == .settings {
            return "\(practiceMode.title) \(mode.title)"
        }
        return mode.title
    }

    var classicalParameterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            pickerRow("宫制", selection: $selectedHouseSystem, options: Self.houseSystemOptions)
            pickerRow("黄道", selection: $selectedZodiac, options: Self.zodiacOptions)
            pickerRow("界", selection: $selectedBoundsSystem, options: Self.boundsOptions)
            pickerRow("三分主", selection: $selectedTriplicitySystem, options: Self.triplicityOptions)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("相位容许度").foregroundStyle(.secondary)
                    Spacer()
                    Text("\(classicalAspectOrb, specifier: "%.1f")°").monospacedDigit()
                }
                Slider(value: $classicalAspectOrb, in: 0...10, step: 0.1)
            }
        }
    }

    func dateTimeInputRow(_ title: String, date: Binding<Date>) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).foregroundStyle(.secondary)
            DateTimeInput(date: date)
        }
    }

    var gmtOffsetControl: some View {
        Stepper(value: $gmtOffset, in: -12...14) {
            Text(timezoneLabel).monospacedDigit()
        }
    }

    func pickerRow(_ title: String, selection: Binding<String>, options: [PickerOption]) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .labelsHidden()
            .frame(width: 210)
        }
    }

    func bodySection(title: String, selection: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(BodyGroup.allCases) { group in
                VStack(alignment: .leading, spacing: 6) {
                    selectionHeader(
                        group.title,
                        selectAll: { selection.wrappedValue.formUnion(bodyOptions.filter { $0.group == group }.map(\.id)) },
                        selectNone: { selection.wrappedValue.subtract(bodyOptions.filter { $0.group == group }.map(\.id)) }
                    )
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(bodyOptions.filter { $0.group == group }) { body in
                            Toggle(body.name, isOn: toggleBinding(for: body.id, in: selection))
                                .toggleStyle(.checkbox)
                        }
                    }
                }
            }
        }
    }

    func selectionHeader(_ title: String, selectAll: @escaping () -> Void, selectNone: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("全选", action: selectAll).font(.caption)
            Button("全不选", action: selectNone).font(.caption)
        }
    }

    func selectionTemplateSection(title: String, template: String, text: Binding<String>, apply: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                CopyMarkdownButton(markdown: template, title: "复制参考格式")
                Button("解析回填", action: apply)
            }
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .frame(height: 150)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
            Text("粘贴行式模板，格式为 KEY=VALUE；逗号分隔列表，`CUSTOM_TARGETS` 用 `|` 分隔多条目标。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    func momentPresetTemplateSection(title: String, template: String, text: Binding<String>, apply: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("预设名称", text: $momentPresetName).textFieldStyle(.roundedBorder)
                Button("保存") { saveMomentPreset() }
                Button("删除") { deleteSelectedMomentPreset() }
                    .disabled(selectedMomentPresetID.isEmpty)
            }
            HStack {
                Picker("已保存预设", selection: $selectedMomentPresetID) {
                    Text("选择预设").tag("")
                    ForEach(momentPresets) { preset in
                        Text(preset.name).tag(preset.id.uuidString)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                Button("载入") { loadSelectedMomentPreset() }
                    .disabled(selectedMomentPresetID.isEmpty)
            }
            HStack {
                CopyMarkdownButton(markdown: template, title: "复制参考格式")
                Button("解析回填", action: apply)
            }
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .frame(height: 150)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
            Text("粘贴行式模板，格式为 KEY=VALUE；逗号分隔列表，`CUSTOM_TARGETS` 用 `|` 分隔多条目标。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    func scanPresetTemplateSection(title: String, template: String, text: Binding<String>, apply: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("预设名称", text: $scanPresetName).textFieldStyle(.roundedBorder)
                Button("保存") { saveScanPreset() }
                Button("删除") { deleteSelectedScanPreset() }
                    .disabled(selectedScanPresetID.isEmpty)
            }
            HStack {
                Picker("已保存预设", selection: $selectedScanPresetID) {
                    Text("选择预设").tag("")
                    ForEach(scanPresets) { preset in
                        Text(preset.name).tag(preset.id.uuidString)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                Button("载入") { loadSelectedScanPreset() }
                    .disabled(selectedScanPresetID.isEmpty)
            }
            HStack {
                CopyMarkdownButton(markdown: template, title: "复制参考格式")
                Button("解析回填", action: apply)
            }
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .frame(height: 150)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
            Text("粘贴行式模板，格式为 KEY=VALUE；逗号分隔列表，`CUSTOM_TARGETS` 用 `|` 分隔多条目标。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = selectedTimeZone
        return f.string(from: natalDate)
    }

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = selectedTimeZone
        return f.string(from: natalDate)
    }

    var houseSystemLabel: String {
        ContentView.houseSystemOptions.first(where: { $0.id == selectedHouseSystem })?.title ?? selectedHouseSystem
    }

    var zodiacLabel: String {
        ContentView.zodiacOptions.first(where: { $0.id == selectedZodiac })?.title ?? selectedZodiac
    }

    var boundsLabel: String {
        ContentView.boundsOptions.first(where: { $0.id == selectedBoundsSystem })?.title ?? selectedBoundsSystem
    }

    var triplicityLabel: String {
        ContentView.triplicityOptions.first(where: { $0.id == selectedTriplicitySystem })?.title ?? selectedTriplicitySystem
    }

    var rectifyInputHash: Int {
        var hasher = Hasher()
        hasher.combine(natalDate)
        hasher.combine(gmtOffset)
        hasher.combine(birthLatitude)
        hasher.combine(birthLongitude)
        hasher.combine(selectedHouseSystem)
        hasher.combine(selectedZodiac)
        hasher.combine(selectedBoundsSystem)
        hasher.combine(selectedTriplicitySystem)
        return hasher.finalize()
    }
}
