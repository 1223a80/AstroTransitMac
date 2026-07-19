import SwiftUI

extension ContentView {
    // MARK: - Modern Sub-Mode Result Panes

    var synastryResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .synastry(let r) = result {
                SynastryResultPane(result: r, selectedTab: $calcVM.modernSelectedTab)
            } else {
                EmptyStateView(title: "等待 Synastry 计算", systemImage: "person.2", description: "填写两人出生信息后开始计算。")
            }
        }
    }

    var compositeResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .composite(let r) = result {
                CompositeDavisonResultPane(
                    title: "Composite",
                    result: r,
                    selectedTab: $calcVM.modernSelectedTab,
                    onOpenTiming: { openRelationshipTiming(type: "composite", result: r) }
                )
            } else {
                EmptyStateView(title: "等待 Composite 计算", systemImage: "circle.hexagongrid", description: "填写两人出生信息后开始计算。")
            }
        }
    }

    var davisonResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .davison(let r) = result {
                CompositeDavisonResultPane(
                    title: "Davison",
                    result: r,
                    selectedTab: $calcVM.modernSelectedTab,
                    onOpenTiming: { openRelationshipTiming(type: "davison", result: r) }
                )
            } else {
                EmptyStateView(title: "等待 Davison 计算", systemImage: "arrow.triangle.merge", description: "填写两人出生信息后开始计算。")
            }
        }
    }

    var progressionResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .progression(let r) = result {
                ProgressionResultPane(result: r, selectedTab: $calcVM.modernSelectedTab)
            } else {
                EmptyStateView(title: "等待次限推进计算", systemImage: "forward.fill", description: "填写出生和参考时间后开始计算。")
            }
        }
    }

    var progressedCompositeResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .progressedComposite(let r) = result {
                ProgressedCompositeResultPane(result: r, selectedTab: $calcVM.modernSelectedTab)
            } else {
                EmptyStateView(
                    title: "等待推进组合盘计算",
                    systemImage: "arrow.triangle.2.circlepath.circle",
                    description: "填写人物 A、人物 B 和 reference 后开始计算。"
                )
            }
        }
    }

    var solarArcResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .solarArc(let r) = result {
                SolarArcResultPane(result: r, selectedTab: $calcVM.modernSelectedTab)
            } else {
                EmptyStateView(title: "等待 Solar Arc 计算", systemImage: "sun.max", description: "填写出生和参考时间后开始计算。")
            }
        }
    }

    var harmonicResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .harmonic(let r) = result {
                HarmonicResultPane(result: r, selectedTab: $calcVM.modernSelectedTab)
            } else {
                EmptyStateView(title: "等待 Harmonic 计算", systemImage: "music.note.list", description: "选择调和阶数后开始计算。")
            }
        }
    }

    var modernReturnResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .returnChart(let r) = result {
                ModernReturnResultPane(result: r, selectedTab: $calcVM.modernSelectedTab)
            } else {
                EmptyStateView(title: "等待返照盘计算", systemImage: "arrow.clockwise.circle", description: "填写本命盘和参考时间后开始计算。")
            }
        }
    }

    var midpointResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .midpoint(let midpoint) = result {
                MidpointResultPane(
                    result: midpoint,
                    selectedTab: $calcVM.modernSelectedTab,
                    onSendAxesToTiming: { axisIDs in
                        openMidpointAxesInTiming(result: midpoint, axisIDs: axisIDs)
                    }
                )
            } else {
                EmptyStateView(
                    title: "等待中点计算",
                    systemImage: "circle.grid.cross",
                    description: "选择本命点集、focus 与单时点激活来源后开始计算。"
                )
            }
        }
    }

    var relocationResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .relocation(let r) = result {
                RelocationResultPane(result: r, selectedTab: $calcVM.modernSelectedTab)
            } else {
                EmptyStateView(
                    title: "等待迁移盘计算",
                    systemImage: "airplane.departure",
                    description: "填写本命与迁移地点后开始计算。"
                )
            }
        }
    }

    var modernCyclesResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .modernCycles(let r) = result {
                ModernCyclesResultPane(result: r, selectedTab: $calcVM.modernSelectedTab)
            } else {
                EmptyStateView(
                    title: "等待朔望/食相扫描",
                    systemImage: "moon.stars",
                    description: "设定时间窗与周期类型后开始扫描。"
                )
            }
        }
    }

    var astrocartographyResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .astrocartography(let r) = result {
                AstrocartographyResultPane(result: r, selectedTab: $calcVM.modernSelectedTab)
            } else {
                EmptyStateView(
                    title: "等待天体地图计算",
                    systemImage: "globe.americas",
                    description: "选择时刻与天体后计算 A*C*G 线。"
                )
            }
        }
    }

    var localSpaceResultsPane: some View {
        Group {
            if let result = calcVM.modernResultData, case .localSpace(let r) = result {
                LocalSpaceResultPane(result: r, selectedTab: $calcVM.modernSelectedTab)
            } else {
                EmptyStateView(
                    title: "等待 Local Space 计算",
                    systemImage: "location.north.line",
                    description: "选择观察点与天体后计算方位。"
                )
            }
        }
    }

    func openMidpointAxesInTiming(result: MidpointResult, axisIDs: [String]) {
        let selectedIDs = Set(axisIDs)
        let pairs = result.axes
            .filter { selectedIDs.contains($0.id) }
            .map { MidpointPairRequest(pointAID: $0.pointAID, pointBID: $0.pointBID) }
        guard !pairs.isEmpty else { return }

        timingMidpointPairs = Set(pairs)
        timingTargetBodies.removeAll()
        timingTargetAngles.removeAll()
        timingTargetHouseCusps.removeAll()
        timingTargetLots.removeAll()
        timingUseCustomAsteroids = false
        calcVM.modernTimingResult = nil
        practiceMode = .modern
        mode = .scan
        scanWorkspaceMode = "modern_timing"
    }

    func openRelationshipTiming<T: ChartResultFields>(type: String, result: T) {
        guard let personA = modernLastRelationshipPersonA,
              let personB = modernLastRelationshipPersonB else {
            calcVM.errorMessage = "当前关系盘没有可复用的精确人物时刻；请先重新计算该关系盘。"
            return
        }
        guard let pointSet = result.meta.effectivePointSet else {
            calcVM.errorMessage = "当前关系盘没有返回 effective point set，无法安全构造 target_chart。"
            return
        }
        guard let houseSystem = modernLastRelationshipHouseSystem,
              let zodiac = modernLastRelationshipZodiac else {
            calcVM.errorMessage = "当前关系盘没有保存当次宫制/黄道，无法安全复现 target_chart。"
            return
        }

        modernTimingTargetChart = ModernTimingTargetChart(
            type: type,
            personA: personA,
            personB: personB,
            pointSet: pointSet,
            houseSystem: houseSystem,
            zodiac: zodiac
        )
        modernTimingTargetMethod = result.meta.method

        // Relationship Timing v1 is transit-aspect only. Clear the other
        // techniques and transit lifecycle types so hidden previous settings
        // cannot leak into the nested relationship target request.
        timingEnabledTechniques = ["transit"]
        timingTransitEventTypes = ["aspect"]
        calcVM.modernTimingResult = nil
        calcVM.modernTimingSelectedTab = "timeline"
        practiceMode = .modern
        mode = .scan
        scanWorkspaceMode = "modern_timing"
    }

    func clearRelationshipTimingTarget() {
        modernTimingTargetChart = nil
        modernTimingTargetMethod = ""
        calcVM.modernTimingResult = nil
        calcVM.modernTimingSelectedTab = "timeline"
    }
}
