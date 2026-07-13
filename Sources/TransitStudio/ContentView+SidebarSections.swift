import SwiftUI

extension ContentView {
    var sidebar: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                HStack(spacing: TS.Spacing.md) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TS.SemanticColor.gold)
                    Text("参数 · \(sidebarTitle)")
                        .font(TS.Font.sectionTitle)
                        .foregroundStyle(TS.SemanticColor.ink)
                    // Keep clear of the collapse/pin buttons overlaid top-trailing.
                    Spacer(minLength: 56)
                }
                sidebarModeControls
                if mode != .rectify && mode != .scan {
                    runSection
                }
            }
            .padding(TS.Padding.sidebarContent)
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
            return AnyView(VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                collapsible("Horary 问题") { horaryQuestionSection }
                collapsible("地点") { horaryLocationSection }
                collapsible("古典参数") { classicalParameterSection }
            })
        case .moment:
            return AnyView(VStack(alignment: .leading, spacing: TS.Spacing.xl) {
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
            return AnyView(VStack(alignment: .leading, spacing: TS.Spacing.xl) {
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
        VStack(alignment: .leading, spacing: TS.Spacing.xl) {
            collapsible("出生资料") {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
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
                .font(TS.Font.body)
                .monospacedDigit()
            }

            runSection

            if let response = calcVM.rectifyResponse {
                collapsible("计算结果") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        LabeledContent("候选数", value: "\(response.totalCandidates)")
                        if let w = response.windowMinutes {
                            LabeledContent("窗口", value: "±\(w) 分钟")
                        }
                    }
                    .font(TS.Font.body)
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

    var momentTimeSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            dateTimeInputRow("行运时间", date: $transitDate)
        }
    }

    var horaryQuestionSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            HStack {
                Text("起盘时间").foregroundStyle(.secondary)
                DateTimeInput(date: $horaryDate, timeZone: timeZone(for: horaryGmtOffset))
                Button("现在") { horaryDate = Date() }
            }
            HStack {
                Text("起盘时区").foregroundStyle(.secondary)
                Spacer()
                gmtOffsetControl($horaryGmtOffset)
            }
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                Text("问题文本")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
                TextEditor(text: $horaryQuestionText)
                    .font(TS.Font.body)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: TS.Radius.chip)
                            .stroke(Color.secondary.opacity(0.25))
                    )
            }
        }
    }

    var horaryLocationSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            HStack {
                Spacer()
                Button {
                    currentLocationManager.requestCurrentLocation { result in
                        switch result {
                        case .success(let payload):
                            horaryPlaceName = payload.placeName
                            horaryLatitude = String(format: "%.4f", payload.latitude)
                            horaryLongitude = String(format: "%.4f", payload.longitude)
                            if let timeZone = payload.timeZone {
                                horaryGmtOffset = Double(timeZone.secondsFromGMT(for: horaryDate)) / 3600.0
                            }
                        case .failure(let error):
                            calcVM.errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label(currentLocationManager.isLocating ? "定位中" : "获取当前位置",
                          systemImage: currentLocationManager.isLocating ? "location.fill.viewfinder" : "location")
                }
                .disabled(currentLocationManager.isLocating)
            }
            Text(currentLocationManager.statusText)
                .font(TS.Font.label)
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.lg) {
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
        Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.lg) {
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
                DateTimeInput(date: $scanStartDate, timeZone: selectedTimeZone)
            }
            GridRow {
                Text("结束").foregroundStyle(.secondary)
                DateTimeInput(date: $scanEndDate, timeZone: selectedTimeZone)
            }
        }
    }

    var natalProfileSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
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
        Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.lg) {
            GridRow {
                Text("出生").foregroundStyle(.secondary)
                DateTimeInput(date: $natalDate, timeZone: selectedTimeZone)
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
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text("\(dateTimeText(natalDate))  \(timezoneLabel)")
                .monospacedDigit()
            Text("纬度 \(birthLatitude) / 经度 \(birthLongitude)")
                .foregroundStyle(.secondary)
            Button("返回本命设置") { mode = .settings }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var classicalSettingsSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.xl) {
            collapsible("本命盘资料") { natalProfileSection }
            collapsible("本命盘") { natalSettingsSection }
            collapsible("参考时间") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.lg) {
                        GridRow {
                            Text("参考").foregroundStyle(.secondary)
                            DateTimeInput(date: $classicalReferenceDate, timeZone: selectedTimeZone)
                        }
                    }
                    Text("用于 annual profection、solar return 以及其他时间技法的落点判断。")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
            collapsible("古典参数") { classicalParameterSection }
        }
    }

    var vedicSettingsSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.xl) {
            collapsible("本命盘资料") { natalProfileSection }
            collapsible("本命盘") { natalSettingsSection }
            collapsible("参考时间") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.lg) {
                        GridRow {
                            Text("参考").foregroundStyle(.secondary)
                            DateTimeInput(date: $classicalReferenceDate, timeZone: selectedTimeZone)
                        }
                    }
                    Text("用于 Daśā 当前期判断。").font(TS.Font.label).foregroundStyle(.secondary)
                }
            }
            collapsible("吠陀参数") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    pickerRow("Ayanāṃśa", selection: $vedicAyanamsha, options: Self.ayanamshaOptions)
                    Toggle("完整计算", isOn: $vedicFullMode)
                        .font(TS.Font.label)
                }
            }
        }
    }

    private var modernSettingsSidebar: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.xl) {
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
            case .returnChart:
                returnSidebar
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
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.lg) {
                        GridRow {
                            Text("参考").foregroundStyle(.secondary)
                            DateTimeInput(date: $classicalReferenceDate, timeZone: selectedTimeZone)
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
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
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

    private var returnSidebar: some View {
        Group {
            collapsible("本命盘") { natalSettingsSection }
            collapsible("返照参数") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    Picker("类型", selection: $modernReturnBodyID) {
                        Text("Solar Return").tag("SUN")
                        Text("Lunar Return").tag("MOON")
                    }
                    .pickerStyle(.segmented)
                    Picker("地点来源", selection: $modernReturnLocationSource) {
                        Text("出生地").tag("birth")
                        Text("自定义地点").tag("custom")
                    }
                    .pickerStyle(.segmented)
                    if modernReturnLocationSource == "custom" {
                        Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.sm) {
                            GridRow {
                                Text("名称").foregroundStyle(.secondary)
                                TextField("地点名称", text: $modernReturnLocationName)
                                    .textFieldStyle(.roundedBorder)
                            }
                            GridRow {
                                Text("纬度").foregroundStyle(.secondary)
                                TextField("31.2304", text: $modernReturnLocationLatitude)
                                    .textFieldStyle(.roundedBorder)
                            }
                            GridRow {
                                Text("经度").foregroundStyle(.secondary)
                                TextField("121.4737", text: $modernReturnLocationLongitude)
                                    .textFieldStyle(.roundedBorder)
                            }
                            GridRow {
                                Text("时区").foregroundStyle(.secondary)
                                TextField("Asia/Shanghai", text: $modernReturnLocationTimezone)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.lg) {
                        GridRow {
                            Text("参考").foregroundStyle(.secondary)
                            DateTimeInput(date: $classicalReferenceDate, timeZone: selectedTimeZone)
                        }
                    }
                    Text("以本命太阳或月亮的黄经回归点为返照时刻；时间输入必须完整。")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
            collapsible("占星参数") { modernParameterSection }
            collapsible("自定义小行星") { customAsteroidSection }
        }
    }

    private var personASection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.lg) {
                GridRow {
                    Text("出生").foregroundStyle(.secondary)
                    DateTimeInput(date: $natalDate, timeZone: selectedTimeZone)
                }
                GridRow {
                    Text("时区").foregroundStyle(.secondary)
                    gmtOffsetControl($gmtOffset)
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
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.lg) {
                GridRow {
                    Text("出生").foregroundStyle(.secondary)
                    DateTimeInput(date: $modernPersonBDate, timeZone: timeZone(for: modernPersonBGmtOffset))
                }
                GridRow {
                    Text("时区").foregroundStyle(.secondary)
                    gmtOffsetControl($modernPersonBGmtOffset)
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
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            pickerRow("宫制", selection: $selectedHouseSystem, options: Self.houseSystemOptions)
            pickerRow("黄道", selection: $selectedZodiac, options: Self.zodiacOptions)
            pickerRow("节点", selection: $modernNodeMode, options: Self.nodeModeOptions)
            modernAspectSection
        }
    }

    private var modernAspectSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            HStack {
                Text("相位").foregroundStyle(.secondary).font(TS.Font.label)
                Spacer()
                HStack(spacing: TS.Spacing.sm) {
                    Button("全选") { selectedAspects = Set(aspectOptions.map(\.id)) }.font(TS.Font.label)
                    Button("全不选") { selectedAspects = [] }.font(TS.Font.label)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: TS.Spacing.md)], alignment: .leading, spacing: TS.Spacing.md) {
                ForEach(aspectOptions) { aspect in
                    Toggle(aspect.name, isOn: toggleBinding(for: aspect.id, in: $selectedAspects))
                        .toggleStyle(.checkbox)
                        .font(TS.Font.label)
                }
            }
            HStack {
                Text("容许度").foregroundStyle(.secondary).font(TS.Font.label)
                Spacer()
                Text("\(globalOrb, specifier: "%.1f")°").monospacedDigit()
            }
            Slider(value: $globalOrb, in: 0...10, step: 0.5)
        }
    }

    var sidebarTitle: String {
        if mode == .settings {
            return "\(practiceMode.title)\(mode.title)"
        }
        return mode.title
    }

    var classicalParameterSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            pickerRow("宫制", selection: $selectedHouseSystem, options: Self.houseSystemOptions)
            pickerRow("黄道", selection: $selectedZodiac, options: Self.zodiacOptions)
            pickerRow("界", selection: $selectedBoundsSystem, options: Self.boundsOptions)
            pickerRow("三分主", selection: $selectedTriplicitySystem, options: Self.triplicityOptions)
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
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
        HStack(alignment: .firstTextBaseline, spacing: TS.Spacing.lg) {
            Text(title).foregroundStyle(.secondary)
            DateTimeInput(date: date, timeZone: selectedTimeZone)
        }
    }

    var gmtOffsetControl: some View {
        gmtOffsetControl($gmtOffset)
    }

    func gmtOffsetControl(_ offset: Binding<Double>) -> some View {
        Stepper(value: offset, in: -12...14, step: 0.25) {
            Text(timezoneLabel(for: offset.wrappedValue)).monospacedDigit()
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
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ForEach(BodyGroup.allCases) { group in
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    selectionHeader(
                        group.title,
                        selectAll: { selection.wrappedValue.formUnion(bodyOptions.filter { $0.group == group }.map(\.id)) },
                        selectNone: { selection.wrappedValue.subtract(bodyOptions.filter { $0.group == group }.map(\.id)) }
                    )
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: TS.Spacing.md)], alignment: .leading, spacing: TS.Spacing.md) {
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
            Text(title).font(TS.Font.label).foregroundStyle(.secondary)
            Spacer()
            Button("全选", action: selectAll).font(TS.Font.label)
            Button("全不选", action: selectNone).font(TS.Font.label)
        }
    }

    func selectionTemplateSection(title: String, template: String, text: Binding<String>, apply: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            HStack {
                CopyMarkdownButton(markdown: template, title: "复制参考格式")
                Button("解析回填", action: apply)
            }
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .frame(height: 150)
                .overlay(RoundedRectangle(cornerRadius: TS.Radius.chip).stroke(Color.secondary.opacity(0.25)))
            Text("粘贴行式模板，格式为 KEY=VALUE；逗号分隔列表，`CUSTOM_TARGETS` 用 `|` 分隔多条目标。")
                .font(TS.Font.label).foregroundStyle(.secondary)
        }
    }

    func momentPresetTemplateSection(title: String, template: String, text: Binding<String>, apply: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
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
                .overlay(RoundedRectangle(cornerRadius: TS.Radius.chip).stroke(Color.secondary.opacity(0.25)))
            Text("粘贴行式模板，格式为 KEY=VALUE；逗号分隔列表，`CUSTOM_TARGETS` 用 `|` 分隔多条目标。")
                .font(TS.Font.label).foregroundStyle(.secondary)
        }
    }

    func scanPresetTemplateSection(title: String, template: String, text: Binding<String>, apply: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
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
                .overlay(RoundedRectangle(cornerRadius: TS.Radius.chip).stroke(Color.secondary.opacity(0.25)))
            Text("粘贴行式模板，格式为 KEY=VALUE；逗号分隔列表，`CUSTOM_TARGETS` 用 `|` 分隔多条目标。")
                .font(TS.Font.label).foregroundStyle(.secondary)
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
