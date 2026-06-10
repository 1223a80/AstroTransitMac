import SwiftUI

extension ContentView {
    var targetSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                Picker("目标点来源", selection: $targetSource) {
                    ForEach(Self.targetSourceOptions) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.segmented)

                if targetSource == "natal" {
                    natalTargetSelector
                } else {
                    TextEditor(text: $scanTargetsText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 180)
                }
        }
    }

    var natalTargetSelector: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            if !hasNatalSourceForCurrentMode {
                Text("请先在本命设置中保存并排盘，或切换到自定义手动输入目标点。")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
            } else {
                targetToggleSection(
                    title: "行星",
                    ids: targetPlanetOptions.map(\.id),
                    names: Dictionary(uniqueKeysWithValues: targetPlanetOptions.map { ($0.id, $0.name) }),
                    selection: $selectedTargetPlanets
                )
                targetAsteroidSection
                targetToggleSection(
                    title: "虚点 / 轴点",
                    ids: targetVirtualAndAngleOptions.map(\.id),
                    names: Dictionary(uniqueKeysWithValues: targetVirtualAndAngleOptions.map { ($0.id, $0.name) }),
                    selection: $selectedTargetAngles
                )
                targetHouseSection
                targetToggleSection(
                    title: "Lots",
                    ids: targetLotOptions.map(\.id),
                    names: Dictionary(uniqueKeysWithValues: targetLotOptions.map { ($0.id, $0.name) }),
                    selection: $selectedTargetLots
                )
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    Text("自定义 Lots / 目标点")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $customLotTargetsText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 82)
                        .overlay(
                            RoundedRectangle(cornerRadius: TS.Radius.chip)
                                .stroke(Color.secondary.opacity(0.25))
                        )
                    Text("一行一个，例如：Lot of Marriage = Libra 12°30")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                    Text("当目标点来源为“本命盘”时，这里填写并识别成功的目标会追加到已勾选本命目标后一同扫描。")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var targetAsteroidSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                Text("自定义小行星编号")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
                TextField("如 433, 1181, 3811", text: $customAsteroids)
                    .textFieldStyle(.roundedBorder)
                Text("修改编号后请先回到本命设置重新排盘，排盘后会在下面显示可勾选的小行星目标。")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
            }

            selectionHeader(
                "小行星",
                selectAll: { selectedTargetAsteroids = Set(targetAsteroidOptions.map(\.id)) },
                selectNone: { selectedTargetAsteroids.removeAll() }
            )

            if targetAsteroidOptions.isEmpty {
                Text("当前本命盘结果里没有小行星位置。")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: TS.Spacing.md)], alignment: .leading, spacing: TS.Spacing.md) {
                    ForEach(targetAsteroidOptions) { option in
                        Toggle(option.name, isOn: Binding(
                            get: { selectedTargetAsteroids.contains(option.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedTargetAsteroids.insert(option.id)
                                } else {
                                    selectedTargetAsteroids.remove(option.id)
                                }
                            }
                        ))
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
    }

    func targetToggleSection(
        title: String,
        ids: [String],
        names: [String: String],
        selection: Binding<Set<String>>
    ) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            selectionHeader(
                title,
                selectAll: { selection.wrappedValue = Set(ids) },
                selectNone: { selection.wrappedValue.removeAll() }
            )
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: TS.Spacing.md)], alignment: .leading, spacing: TS.Spacing.md) {
                ForEach(ids, id: \.self) { id in
                    Toggle(names[id] ?? id, isOn: toggleBinding(for: id, in: selection))
                        .toggleStyle(.checkbox)
                }
            }
        }
    }

    var targetHouseSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            let houses = targetHouseOptions.map(\.house)
            selectionHeader(
                "宫头",
                selectAll: { selectedTargetHouses = Set(houses) },
                selectNone: { selectedTargetHouses.removeAll() }
            )
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: TS.Spacing.md)], alignment: .leading, spacing: TS.Spacing.md) {
                ForEach(houses, id: \.self) { house in
                    Toggle("\(house)宫", isOn: Binding(
                        get: { selectedTargetHouses.contains(house) },
                        set: { isSelected in
                            if isSelected {
                                selectedTargetHouses.insert(house)
                            } else {
                                selectedTargetHouses.remove(house)
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                }
            }
        }
    }

    var customAsteroidSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
                TextField("如 433, 1181, 3811", text: $customAsteroids)
                    .textFieldStyle(.roundedBorder)
                Text(appState.autoDownloadAsteroids ? "计算前会自动检查并下载缺失的小行星星历。" : "自动下载已关闭，缺文件时按设置中的策略处理。")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
                if !calcVM.asteroidPreparationMessage.isEmpty {
                    Text(calcVM.asteroidPreparationMessage)
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
        }
    }

    var aspectSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                selectionHeader(
                    "相位",
                    selectAll: { selectedAspects = Set(aspectOptions.map(\.id)) },
                    selectNone: { selectedAspects.removeAll() }
                )
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: TS.Spacing.md)], alignment: .leading, spacing: TS.Spacing.md) {
                    ForEach(aspectOptions) { aspect in
                        Toggle("\(aspect.name) \(Int(aspect.angle))°", isOn: toggleBinding(for: aspect.id, in: $selectedAspects))
                            .toggleStyle(.checkbox)
                    }
                }

                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    Text("自定义相位度数")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                    TextField("如 30,45,144", text: $customAspectDegrees)
                        .textFieldStyle(.roundedBorder)
                    Text("可输入多个角度，逗号、空格或换行分隔；有效范围 0-180°。")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }

                if mode == .moment {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        HStack {
                            Text("统一容许度").foregroundStyle(.secondary)
                            Spacer()
                            Text("\(globalOrb, specifier: "%.1f")°").monospacedDigit()
                        }
                        Slider(value: $globalOrb, in: 0...10, step: 0.1)
                    }
                }
        }
    }

}
