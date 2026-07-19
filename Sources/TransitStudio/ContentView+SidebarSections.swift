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
                if practiceMode == .modern {
                    Picker("工作区", selection: $scanWorkspaceMode) {
                        Text("精确扫描").tag("exact_scan")
                        Text("综合时间线").tag("modern_timing")
                    }
                    .pickerStyle(.segmented)
                }

                if isModernTimingWorkspace {
                    collapsible("窗口与时区") { modernTimingWindowSection }
                    if modernTimingTargetChart != nil {
                        collapsible("关系目标") { modernTimingRelationshipTargetSection }
                    } else {
                        collapsible("精确出生资料") { natalSummarySection }
                        collapsible("本命目标点集") { modernTimingTargetSection }
                    }
                    if modernTimingTargetChart != nil {
                        collapsible("关系盘 Timing 技法") { modernTimingRelationshipTechniqueSection }
                    } else {
                        collapsible("行运技法") { modernTimingTransitSection }
                        collapsible("次限推进技法") { modernTimingProgressionSection }
                        collapsible("太阳弧技法") { modernTimingSolarArcSection }
                    }
                } else {
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
                }
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

    var modernTimingWindowSection: some View {
        Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.lg) {
            GridRow {
                Text("开始").foregroundStyle(.secondary)
                DateTimeInput(date: $scanStartDate, timeZone: selectedTimeZone)
            }
            GridRow {
                Text("结束").foregroundStyle(.secondary)
                DateTimeInput(date: $scanEndDate, timeZone: selectedTimeZone)
            }
            GridRow {
                Text("展示时区").foregroundStyle(.secondary)
                TextField("Asia/Shanghai", text: $timingDisplayTimezone)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text("窗口输入时区").foregroundStyle(.secondary)
                Text(timezoneLabel).monospacedDigit()
            }
        }
    }

    var modernTimingTargetSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("综合时间线只接受精确出生时间；不提供模糊时间、未知时间或正午兜底。")
                .font(TS.Font.label)
                .foregroundStyle(.secondary)
            bodySection(title: "本命实体", selection: $timingTargetBodies)
            selectionHeader(
                "本命轴点",
                selectAll: { timingTargetAngles = Set(Self.modernTimingAngleOptions.map(\.id)) },
                selectNone: { timingTargetAngles.removeAll() }
            )
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: TS.Spacing.md)], alignment: .leading, spacing: TS.Spacing.md) {
                ForEach(Self.modernTimingAngleOptions) { option in
                    Toggle(option.title, isOn: toggleBinding(for: option.id, in: $timingTargetAngles))
                        .toggleStyle(.checkbox)
                }
            }
            selectionHeader(
                "本命宫头",
                selectAll: { timingTargetHouseCusps = Set(1...12) },
                selectNone: { timingTargetHouseCusps.removeAll() }
            )
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: TS.Spacing.md)], alignment: .leading, spacing: TS.Spacing.md) {
                ForEach(1...12, id: \.self) { house in
                    Toggle("\(house) 宫", isOn: Binding(
                        get: { timingTargetHouseCusps.contains(house) },
                        set: { selected in
                            if selected { timingTargetHouseCusps.insert(house) }
                            else { timingTargetHouseCusps.remove(house) }
                        }
                    ))
                    .toggleStyle(.checkbox)
                }
            }
            selectionHeader(
                "本命阿拉伯点",
                selectAll: { timingTargetLots = Set(targetLotOptions.map(\.id)) },
                selectNone: { timingTargetLots.removeAll() }
            )
            if targetLotOptions.isEmpty {
                Text("先计算现代本命盘后，可在这里复用其有效 Lots 作为时间线目标。")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: TS.Spacing.md)], alignment: .leading, spacing: TS.Spacing.md) {
                    ForEach(targetLotOptions) { option in
                        Toggle(option.name, isOn: toggleBinding(for: option.id, in: $timingTargetLots))
                            .toggleStyle(.checkbox)
                    }
                }
            }
            HStack {
                Text("中点轴目标").font(TS.Font.label).foregroundStyle(.secondary)
                Spacer()
                Button("清空") { timingMidpointPairs.removeAll() }
                    .font(TS.Font.label)
                    .disabled(timingMidpointPairs.isEmpty)
            }
            if timingMidpointPairs.isEmpty {
                Text("可从中点结果页选择轴并预填；默认不自动选择全部中点轴。")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: TS.Spacing.sm) {
                    ForEach(timingMidpointPairs.sorted { $0.axisID < $1.axisID }, id: \.axisID) { pair in
                        HStack {
                            Text(pair.axisID)
                                .font(TS.Font.monoSmall)
                                .textSelection(.enabled)
                            Spacer(minLength: 0)
                            Button {
                                timingMidpointPairs.remove(pair)
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Toggle("将自定义小行星作为普通目标", isOn: $timingUseCustomAsteroids)
                .font(TS.Font.label)
            customAsteroidSection
                .disabled(!timingUseCustomAsteroids)
                .opacity(timingUseCustomAsteroids ? 1 : 0.55)
        }
    }

    var modernTimingRelationshipTargetSection: some View {
        Group {
            if let target = modernTimingTargetChart {
                let personA = target.personA
                let personB = target.personB
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    LabeledContent("类型", value: target.type)
                    LabeledContent("方法", value: modernTimingTargetMethod.isEmpty ? "—" : modernTimingTargetMethod)
                    LabeledContent("宫制", value: target.houseSystem ?? "—")
                    LabeledContent("黄道", value: target.zodiac ?? "—")
                    Divider()
                    Text("人物 A · \(personA.name)").font(TS.Font.label).foregroundStyle(.secondary)
                    Text(exactMomentText(personA.moment)).monospacedDigit()
                    Text("纬度 \(personA.latitude) / 经度 \(personA.longitude)")
                        .foregroundStyle(.secondary)
                    Text("人物 B · \(personB.name)").font(TS.Font.label).foregroundStyle(.secondary)
                    Text(exactMomentText(personB.moment)).monospacedDigit()
                    Text("纬度 \(personB.latitude) / 经度 \(personB.longitude)")
                        .foregroundStyle(.secondary)
                    Divider()
                    Text("effective point set").font(TS.Font.label).foregroundStyle(.secondary)
                    Text(pointSetSummary(target.pointSet))
                        .font(TS.Font.monoSmall)
                        .textSelection(.enabled)
                    Text("nested target_chart.point_set 是本次 Timing 的权威点集；不会发送 target_point_set。")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                    Button("清回本命") { clearRelationshipTimingTarget() }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    var modernTimingTransitSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Toggle("启用 Transit", isOn: toggleBinding(for: "transit", in: $timingEnabledTechniques))
                .toggleStyle(.checkbox)
            if timingEnabledTechniques.contains("transit") {
                bodySection(title: "移动天体", selection: $timingTransitBodies)
                modernTimingEventTypeSection(
                    options: [
                        PickerOption(id: "aspect", title: "对本命精确相位"),
                        PickerOption(id: "ingress", title: "入座"),
                        PickerOption(id: "station", title: "留逆")
                    ],
                    selection: $timingTransitEventTypes
                )
                modernTimingAspectSection(selection: $timingTransitAspects, orb: $timingTransitOrb)
            }
        }
    }

    var modernTimingRelationshipTechniqueSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("关系 target v1 仅支持 Transit 对关系盘目标点的精确相位；不会发送入座、留逆、Secondary Progression 或 Solar Arc。")
                .font(TS.Font.label)
                .foregroundStyle(.secondary)
            bodySection(title: "移动天体", selection: $timingTransitBodies)
            modernTimingAspectSection(selection: $timingTransitAspects, orb: $timingTransitOrb)
        }
    }

    var modernTimingProgressionSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Toggle("启用 Secondary Progression", isOn: toggleBinding(for: "secondary_progression", in: $timingEnabledTechniques))
                .toggleStyle(.checkbox)
            if timingEnabledTechniques.contains("secondary_progression") {
                bodySection(title: "推进天体", selection: $timingProgressionBodies)
                modernTimingEventTypeSection(
                    options: [
                        PickerOption(id: "aspect", title: "对本命精确相位"),
                        PickerOption(id: "moon_ingress", title: "推进月亮入座"),
                        PickerOption(id: "lunation", title: "推进月相")
                    ],
                    selection: $timingProgressionEventTypes
                )
                modernTimingAspectSection(selection: $timingProgressionAspects, orb: $timingProgressionOrb)
            }
        }
    }

    var modernTimingSolarArcSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Toggle("启用 Solar Arc", isOn: toggleBinding(for: "solar_arc", in: $timingEnabledTechniques))
                .toggleStyle(.checkbox)
            if timingEnabledTechniques.contains("solar_arc") {
                bodySection(title: "太阳弧实体", selection: $timingSolarArcPoints)
                selectionHeader(
                    "太阳弧轴点",
                    selectAll: { timingSolarArcPoints.formUnion(Self.modernTimingAngleOptions.map(\.id)) },
                    selectNone: { timingSolarArcPoints.subtract(Self.modernTimingAngleOptions.map(\.id)) }
                )
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: TS.Spacing.md)], alignment: .leading, spacing: TS.Spacing.md) {
                    ForEach(Self.modernTimingAngleOptions) { option in
                        Toggle(option.title, isOn: toggleBinding(for: option.id, in: $timingSolarArcPoints))
                            .toggleStyle(.checkbox)
                    }
                }
                modernTimingAspectSection(selection: $timingSolarArcAspects, orb: $timingSolarArcOrb)
            }
        }
    }

    func modernTimingEventTypeSection(
        options: [PickerOption],
        selection: Binding<Set<String>>
    ) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text("事件类型").font(TS.Font.label).foregroundStyle(.secondary)
            ForEach(options) { option in
                Toggle(option.title, isOn: toggleBinding(for: option.id, in: selection))
                    .toggleStyle(.checkbox)
            }
        }
    }

    func modernTimingAspectSection(
        selection: Binding<Set<String>>,
        orb: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            selectionHeader(
                "技法相位",
                selectAll: { selection.wrappedValue = Set(aspectOptions.map(\.id)) },
                selectNone: { selection.wrappedValue.removeAll() }
            )
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: TS.Spacing.md)], alignment: .leading, spacing: TS.Spacing.md) {
                ForEach(aspectOptions) { aspect in
                    Toggle("\(aspect.name) \(Int(aspect.angle))°", isOn: toggleBinding(for: aspect.id, in: selection))
                        .toggleStyle(.checkbox)
                }
            }
            HStack {
                Text("容许度").foregroundStyle(.secondary)
                Spacer()
                Text("\(orb.wrappedValue, specifier: "%.1f")°").monospacedDigit()
            }
            Slider(value: orb, in: 0...10, step: 0.1)
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
            case .progressedComposite:
                progressedCompositeSidebar
            case .progression, .solarArc:
                timeBasedSidebar
            case .harmonic:
                harmonicSidebar
            case .returnChart:
                returnSidebar
            case .midpoint:
                midpointSidebar
            case .relocation:
                relocationSidebar
            case .modernCycles:
                modernCyclesSidebar
            case .declinationTiming:
                declinationTimingSidebar
            case .retrogradeCycles:
                retrogradeCyclesSidebar
            case .classicalVisibility:
                classicalVisibilitySidebar
            case .astrocartography:
                astrocartographySidebar
            case .localSpace:
                localSpaceSidebar
            }
        }
    }

    private var relocationSidebar: some View {
        Group {
            collapsible("本命盘") { natalSettingsSection }
            collapsible("迁移地点") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    TextField("地点名", text: $relocationPlaceName)
                    TextField("纬度", text: $relocationLatitude)
                    TextField("经度", text: $relocationLongitude)
                    TextField("时区 (IANA)", text: $relocationTimezone)
                    Text("出生时刻只在出生地时区解释一次；新地点时区仅用于当地显示。")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
            collapsible("宫制/黄道") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    pickerRow("宫制", selection: $selectedHouseSystem, options: Self.houseSystemOptions)
                    pickerRow("黄道", selection: $selectedZodiac, options: Self.zodiacOptions)
                }
            }
            collapsible("点集") {
                bodySection(title: "行星", selection: $relocationBodies)
            }
        }
    }

    private var modernCyclesSidebar: some View {
        Group {
            collapsible("时间窗") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    DateTimeInput(date: $scanStartDate, timeZone: selectedTimeZone)
                    DateTimeInput(date: $scanEndDate, timeZone: selectedTimeZone)
                    Text("使用扫描窗口的起止时间。")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
            collapsible("周期类型") {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    ForEach(["new_moon", "full_moon", "solar_eclipse", "lunar_eclipse"], id: \.self) { type in
                        Toggle(type, isOn: Binding(
                            get: { cyclesSelectedTypes.contains(type) },
                            set: { enabled in
                                if enabled { cyclesSelectedTypes.insert(type) }
                                else { cyclesSelectedTypes.remove(type) }
                            }
                        ))
                    }
                }
            }
            collapsible("可见性 / 本命接触") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    Picker("可见性", selection: $cyclesVisibility) {
                        Text("全球").tag("global")
                        Text("地点").tag("location")
                    }
                    .pickerStyle(.segmented)
                    Toggle("计算对本命点接触", isOn: $cyclesIncludeNatalContacts)
                    if cyclesVisibility == "location" {
                        Text("观察点使用本命经纬度。")
                            .font(TS.Font.label)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var classicalVisibilitySidebar: some View {
        Group {
            collapsible("时刻与地点") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    DateTimeInput(date: $natalDate, timeZone: selectedTimeZone)
                    Text("使用本命经纬度作为观察点。")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
            collapsible("天体") {
                bodySection(title: "可见性天体", selection: $visibilityBodies)
            }
            collapsible("段落") {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    ForEach(["heliacal", "rise_set", "planetary_hours"], id: \.self) { item in
                        Toggle(item, isOn: Binding(
                            get: { visibilityInclude.contains(item) },
                            set: { enabled in
                                if enabled { visibilityInclude.insert(item) }
                                else { visibilityInclude.remove(item) }
                            }
                        ))
                    }
                }
            }
            collapsible("Heliacal 类型") {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    ForEach(["heliacal_rising", "heliacal_setting"], id: \.self) { item in
                        Toggle(item, isOn: Binding(
                            get: { visibilityHeliacalTypes.contains(item) },
                            set: { enabled in
                                if enabled { visibilityHeliacalTypes.insert(item) }
                                else { visibilityHeliacalTypes.remove(item) }
                            }
                        ))
                    }
                }
            }
        }
    }

    private var retrogradeCyclesSidebar: some View {
        Group {
            collapsible("时间窗") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    DateTimeInput(date: $scanStartDate, timeZone: selectedTimeZone)
                    DateTimeInput(date: $scanEndDate, timeZone: selectedTimeZone)
                    Text("阴影端点可在窗口外 pad 内解析；站度以窗口内为准。")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
            collapsible("天体") {
                bodySection(title: "逆行体", selection: $retrogradeBodies)
            }
            collapsible("说明") {
                Text("前/后阴影黄经取自真实顺行站与逆行站度数，不是固定天数。")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var declinationTimingSidebar: some View {
        Group {
            collapsible("本命盘") { natalSettingsSection }
            collapsible("时间窗") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    DateTimeInput(date: $scanStartDate, timeZone: selectedTimeZone)
                    DateTimeInput(date: $scanEndDate, timeZone: selectedTimeZone)
                    Text("使用扫描窗口的起止时间与显示时区。")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
            collapsible("行运体") {
                bodySection(title: "行运体", selection: $declinationMovingBodies)
            }
            collapsible("本命目标") {
                bodySection(title: "本命天体", selection: $declinationTargetBodies)
            }
            collapsible("本命轴点") {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    ForEach(["ASC", "MC", "DSC", "IC"], id: \.self) { angle in
                        Toggle(angle, isOn: Binding(
                            get: { declinationTargetAngles.contains(angle) },
                            set: { enabled in
                                if enabled { declinationTargetAngles.insert(angle) }
                                else { declinationTargetAngles.remove(angle) }
                            }
                        ))
                    }
                }
            }
            collapsible("事件类型") {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    ForEach(
                        ["parallel", "contraparallel", "oob_entry", "oob_exit", "declination_station"],
                        id: \.self
                    ) { type in
                        Toggle(type, isOn: Binding(
                            get: { declinationEventTypes.contains(type) },
                            set: { enabled in
                                if enabled { declinationEventTypes.insert(type) }
                                else { declinationEventTypes.remove(type) }
                            }
                        ))
                    }
                }
            }
            collapsible("容许度") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    HStack {
                        Text("赤纬 orb").foregroundStyle(.secondary)
                        Spacer()
                        Text("\(declinationOrb, specifier: "%.1f")°").monospacedDigit()
                    }
                    Slider(value: $declinationOrb, in: 0...3, step: 0.1)
                    Text("OOB 阈值使用事件时刻真实黄赤交角；平行/反平行使用上表容许度。")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var astrocartographySidebar: some View {
        Group {
            collapsible("时刻") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    DateTimeInput(date: $natalDate, timeZone: selectedTimeZone)
                    Text("使用本命时刻作为地图参考 UT。")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
            collapsible("天体（最多 10）") {
                bodySection(title: "行星", selection: $mapBodies)
            }
        }
    }

    private var localSpaceSidebar: some View {
        Group {
            collapsible("时刻") {
                DateTimeInput(date: $natalDate, timeZone: selectedTimeZone)
            }
            collapsible("观察点") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    TextField("名称（可选）", text: $localSpaceName)
                    TextField("纬度（空=本命）", text: $localSpaceLatitude)
                    TextField("经度（空=本命）", text: $localSpaceLongitude)
                }
            }
            collapsible("天体（最多 10）") {
                bodySection(title: "行星", selection: $mapBodies)
            }
        }
    }

    private var midpointSidebar: some View {
        Group {
            collapsible("本命盘") { natalSettingsSection }
            collapsible("中点点集") { midpointPointSetSection }
            collapsible("中点 Focus") { midpointFocusSection }
            collapsible("单时点激活") { midpointActivationSection }
            collapsible("中点参数") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    pickerRow("宫制", selection: $selectedHouseSystem, options: Self.houseSystemOptions)
                    pickerRow("黄道", selection: $selectedZodiac, options: Self.zodiacOptions)
                    pickerRow("节点", selection: $modernNodeMode, options: Self.nodeModeOptions)
                    HStack {
                        Text("Activation orb").foregroundStyle(.secondary)
                        Spacer()
                        Text("\(midpointActivationOrb, specifier: "%.1f")°").monospacedDigit()
                    }
                    Slider(value: $midpointActivationOrb, in: 0...5, step: 0.1)
                    Text("v1 固定使用 360° circular midpoint；direct / opposite 是同一 axis 的两个 branch。")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var midpointPointSetSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("中点功能只接受完整、精确的出生日期、时间、时区和地点。")
                .font(TS.Font.label)
                .foregroundStyle(.secondary)
            bodySection(title: "中点实体", selection: $midpointBodies)
            selectionHeader(
                "中点轴点",
                selectAll: { midpointAngles = Set(Self.modernTimingAngleOptions.map(\.id)) },
                selectNone: { midpointAngles.removeAll() }
            )
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: TS.Spacing.md)], alignment: .leading, spacing: TS.Spacing.md) {
                ForEach(Self.modernTimingAngleOptions) { option in
                    Toggle(option.title, isOn: toggleBinding(for: option.id, in: $midpointAngles))
                        .toggleStyle(.checkbox)
                }
            }
            selectionHeader(
                "中点宫头",
                selectAll: { midpointHouseCusps = Set(1...12) },
                selectNone: { midpointHouseCusps.removeAll() }
            )
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: TS.Spacing.md)], alignment: .leading, spacing: TS.Spacing.md) {
                ForEach(1...12, id: \.self) { house in
                    Toggle("\(house) 宫", isOn: Binding(
                        get: { midpointHouseCusps.contains(house) },
                        set: { selected in
                            if selected { midpointHouseCusps.insert(house) }
                            else { midpointHouseCusps.remove(house) }
                        }
                    ))
                    .toggleStyle(.checkbox)
                }
            }
            selectionHeader(
                "中点阿拉伯点",
                selectAll: { midpointLots = Set(targetLotOptions.map(\.id)) },
                selectNone: { midpointLots.removeAll() }
            )
            if targetLotOptions.isEmpty {
                Text("先计算现代本命盘后，可复用其有效 Lots。")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: TS.Spacing.md)], alignment: .leading, spacing: TS.Spacing.md) {
                    ForEach(targetLotOptions) { option in
                        Toggle(option.name, isOn: toggleBinding(for: option.id, in: $midpointLots))
                            .toggleStyle(.checkbox)
                    }
                }
            }
            customAsteroidSection
        }
    }

    private var midpointFocusSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            selectionHeader(
                "Focus points",
                selectAll: { midpointFocusPointIDs = midpointSelectedPointIDs },
                selectNone: { midpointFocusPointIDs.removeAll() }
            )
            if midpointSelectedPointIDs.isEmpty {
                Text("先在中点点集中选择至少两个点。")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: TS.Spacing.md)], alignment: .leading, spacing: TS.Spacing.md) {
                    ForEach(midpointSelectedPointIDs.sorted(), id: \.self) { pointID in
                        Toggle(pointID, isOn: toggleBinding(for: pointID, in: $midpointFocusPointIDs))
                            .toggleStyle(.checkbox)
                    }
                }
            }
        }
    }

    private var midpointActivationSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Toggle("计算 reference snapshot", isOn: $midpointIncludeReference)
            if midpointIncludeReference {
                Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.lg) {
                    GridRow {
                        Text("参考").foregroundStyle(.secondary)
                        DateTimeInput(date: $classicalReferenceDate, timeZone: selectedTimeZone)
                    }
                }
                selectionHeader(
                    "Activation sources",
                    selectAll: { midpointActivationSources = ["natal", "transit", "secondary_progression", "solar_arc"] },
                    selectNone: { midpointActivationSources.removeAll() }
                )
                ForEach([
                    PickerOption(id: "natal", title: "Natal"),
                    PickerOption(id: "transit", title: "Transit"),
                    PickerOption(id: "secondary_progression", title: "Secondary Progression"),
                    PickerOption(id: "solar_arc", title: "Solar Arc"),
                ]) { option in
                    Toggle(option.title, isOn: toggleBinding(for: option.id, in: $midpointActivationSources))
                        .toggleStyle(.checkbox)
                }
            } else {
                Text("不提供 reference：只返回 axes 与 natal focus trees，snapshot activations 为空。")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
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

    private var progressedCompositeSidebar: some View {
        Group {
            collapsible("人物A") { personASection }
            collapsible("人物B") { personBSection }
            collapsible("参考时间") {
                VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.lg) {
                        GridRow {
                            Text("参考").foregroundStyle(.secondary)
                            DateTimeInput(
                                date: $classicalReferenceDate,
                                timeZone: timeZone(for: progressedCompositeReferenceGmtOffset)
                            )
                        }
                        GridRow {
                            Text("时区").foregroundStyle(.secondary)
                            gmtOffsetControl($progressedCompositeReferenceGmtOffset)
                        }
                    }
                    Text("A、B 分别按各自出生 UTC 计算 secondary progressed UTC，再对同名行星取 circular midpoint。")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
            collapsible("推进关系盘点集") { progressedCompositePointSetSection }
            collapsible("现代参数") { modernParameterSection }
        }
    }

    private var progressedCompositePointSetSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("v1 仅接受行星、节点和自定义小行星；不计算角点、宫头、Lots 或中点轴。")
                .font(TS.Font.label)
                .foregroundStyle(.secondary)
            bodySection(title: "行星与节点", selection: $progressedCompositeBodies)
            Toggle("包含节点", isOn: $progressedCompositeIncludeNodes)
                .toggleStyle(.checkbox)
            Toggle("包含自定义小行星", isOn: $progressedCompositeUseCustomAsteroids)
                .toggleStyle(.checkbox)
            customAsteroidSection
                .disabled(!progressedCompositeUseCustomAsteroids)
                .opacity(progressedCompositeUseCustomAsteroids ? 1 : 0.55)
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
                        Text("太阳").tag("SUN")
                        Text("月亮").tag("MOON")
                        Text("水星").tag("MERCURY")
                        Text("金星").tag("VENUS")
                        Text("火星").tag("MARS")
                        Text("木星").tag("JUPITER")
                        Text("土星").tag("SATURN")
                        Text("天王").tag("URANUS")
                        Text("海王").tag("NEPTUNE")
                        Text("冥王").tag("PLUTO")
                        Text("凯龙").tag("CHIRON")
                    }
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
