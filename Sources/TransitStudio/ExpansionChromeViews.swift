import SwiftUI

// MARK: - Expansion chrome (PR2 · KD6)

enum ExpansionBadge: String, Equatable {
    case audit
    case auditLocalOnly
    case proxy
    case factMatrix
    case multiProfile

    var label: String {
        switch self {
        case .audit: return "审计"
        case .auditLocalOnly: return "审计 · 本地一致"
        case .proxy: return "代理"
        case .factMatrix: return "事实矩阵"
        case .multiProfile: return "多 profile"
        }
    }
}

struct ExpansionChromeModel: Equatable {
    var title: String
    var methodLine: String?
    var profileChips: [String]
    var badge: ExpansionBadge?
    var detailCaption: String?
    var configSummary: [(String, String)]

    init(
        title: String,
        methodLine: String? = nil,
        profileChips: [String] = [],
        badge: ExpansionBadge? = nil,
        detailCaption: String? = nil,
        configSummary: [(String, String)] = []
    ) {
        self.title = title
        self.methodLine = methodLine
        self.profileChips = profileChips
        self.badge = badge
        self.detailCaption = detailCaption
        self.configSummary = configSummary
    }

    static func == (lhs: ExpansionChromeModel, rhs: ExpansionChromeModel) -> Bool {
        lhs.title == rhs.title
            && lhs.methodLine == rhs.methodLine
            && lhs.profileChips == rhs.profileChips
            && lhs.badge == rhs.badge
            && lhs.detailCaption == rhs.detailCaption
            && lhs.configSummary.map(\.0) == rhs.configSummary.map(\.0)
            && lhs.configSummary.map(\.1) == rhs.configSummary.map(\.1)
    }
}

/// Per-mode chrome factory — does **not** use assumptions-string regex as sole proxy detection.
enum ExpansionChromeFactory {
    static func chrome(for mode: ModernSubMode, metaMethod: String?, extras: ExpansionChromeExtras = .init()) -> ExpansionChromeModel {
        switch mode {
        case .declinationTiming:
            return ExpansionChromeModel(
                title: mode.title,
                methodLine: metaMethod,
                profileChips: compactChips([metaMethod, extras.oobThresholdMethod]),
                detailCaption: extras.oobThresholdMethod.map { "OOB 阈值：\($0)" }
            )
        case .retrogradeCycles:
            return ExpansionChromeModel(
                title: mode.title,
                methodLine: metaMethod,
                profileChips: compactChips([metaMethod]),
                detailCaption: "站度/阴影定义见侧栏与计算假设"
            )
        case .classicalVisibility:
            return ExpansionChromeModel(
                title: mode.title,
                methodLine: metaMethod,
                profileChips: compactChips([metaMethod])
            )
        case .planetarySynodic:
            return ExpansionChromeModel(
                title: mode.title,
                methodLine: metaMethod,
                profileChips: compactChips([metaMethod])
            )
        case .hellenisticConditionAudit:
            return ExpansionChromeModel(
                title: mode.title,
                methodLine: metaMethod,
                profileChips: compactChips([metaMethod, extras.sourceProfile]),
                badge: .audit,
                detailCaption: "条件证据，不做综合打分"
            )
        case .draconicHeliocentric:
            return ExpansionChromeModel(
                title: mode.title,
                methodLine: metaMethod,
                profileChips: compactChips([metaMethod]),
                detailCaption: "Draconic：北交平移；日心为 heliocentric 坐标"
            )
        case .classicalDerivatives:
            return ExpansionChromeModel(
                title: mode.title,
                methodLine: metaMethod,
                profileChips: compactChips([metaMethod] + extras.rowMethodKeys),
                badge: extras.hasProxyMethodKey ? .proxy : nil,
                detailCaption: extras.hasProxyMethodKey ? "含 monomoiria 代理 method_key" : nil
            )
        case .timeLordsExtended:
            return ExpansionChromeModel(
                title: mode.title,
                methodLine: metaMethod,
                profileChips: compactChips([metaMethod, extras.dailyMethodKey]),
                badge: extras.dailyMethodKey != nil ? .proxy : nil,
                detailCaption: extras.dailyNote ?? (extras.dailyMethodKey != nil ? "日小限为代理输出" : nil)
            )
        case .methodFamilies:
            return ExpansionChromeModel(
                title: mode.title,
                methodLine: metaMethod,
                profileChips: compactChips([metaMethod] + extras.profileIds),
                badge: extras.profileIds.contains(where: { $0.contains("armc") || $0.contains("361") }) ? .proxy : .multiProfile,
                detailCaption: "多 profile 对照"
            )
        case .primaryDirectionsAudit:
            let localOnly = extras.externalCrosscheckStatus == "local_se_consistent_only"
            return ExpansionChromeModel(
                title: mode.title,
                methodLine: extras.algorithmName ?? metaMethod,
                profileChips: compactChips([extras.algorithmKey, extras.algorithmName, metaMethod]),
                badge: localOnly ? .auditLocalOnly : .audit,
                detailCaption: extras.knownLimitsFirst ?? extras.externalCrosscheckNote
            )
        case .distributionsPd:
            return ExpansionChromeModel(
                title: mode.title,
                methodLine: metaMethod,
                profileChips: compactChips([metaMethod, extras.baselineAlgorithm]),
                badge: .multiProfile,
                detailCaption: extras.requiresB16Note ?? "沿界 + 主限多配置"
            )
        case .prenatalParans:
            return ExpansionChromeModel(
                title: mode.title,
                methodLine: metaMethod,
                profileChips: compactChips([metaMethod]),
                badge: extras.hasProxyMethodKey ? .proxy : nil,
                detailCaption: "本地升 / 上中天 / 落 / 下中天真实事件配对"
            )
        case .orbitalDial:
            return ExpansionChromeModel(
                title: mode.title,
                methodLine: metaMethod,
                profileChips: compactChips([metaMethod]),
                detailCaption: "行星交点/远近点 ≠ 月交点"
            )
        case .mundaneElectional:
            return ExpansionChromeModel(
                title: mode.title,
                methodLine: metaMethod,
                profileChips: compactChips([metaMethod]),
                badge: .factMatrix,
                detailCaption: "不排序吉时 · 仅事实矩阵"
            )
        default:
            return ExpansionChromeModel(title: mode.title, methodLine: metaMethod, profileChips: compactChips([metaMethod]))
        }
    }

    private static func compactChips(_ values: [String?]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for value in values.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }) where !value.isEmpty {
            if seen.insert(value).inserted {
                out.append(value)
            }
            if out.count >= 3 { break }
        }
        return out
    }
}

struct ExpansionChromeExtras: Equatable {
    var oobThresholdMethod: String? = nil
    var sourceProfile: String? = nil
    var rowMethodKeys: [String] = []
    var hasProxyMethodKey: Bool = false
    var dailyMethodKey: String? = nil
    var dailyNote: String? = nil
    var profileIds: [String] = []
    var algorithmName: String? = nil
    var algorithmKey: String? = nil
    var externalCrosscheckStatus: String? = nil
    var externalCrosscheckNote: String? = nil
    var knownLimitsFirst: String? = nil
    var baselineAlgorithm: String? = nil
    var requiresB16Note: String? = nil
    var paranCount: Int? = nil
}

struct MethodChromeBanner: View {
    let chrome: ExpansionChromeModel

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: TS.Spacing.md) {
                Text(chrome.title)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(TS.SemanticColor.ink)
                if let badge = chrome.badge {
                    Text(badge.label)
                        .font(TS.Font.label)
                        .foregroundStyle(TS.SemanticColor.warning)
                        .padding(.horizontal, TS.Padding.chipHorizontal)
                        .padding(.vertical, 2)
                        .background(TS.SemanticColor.warning.opacity(TS.Opacity.subtle), in: Capsule())
                }
                Spacer(minLength: 0)
            }
            if let methodLine = chrome.methodLine, !methodLine.isEmpty {
                Text(methodLine)
                    .font(TS.Font.monoSmall)
                    .foregroundStyle(TS.SemanticColor.inkSoft)
                    .textSelection(.enabled)
            }
            if !chrome.profileChips.isEmpty {
                HStack(spacing: TS.Spacing.sm) {
                    ForEach(chrome.profileChips, id: \.self) { chip in
                        Text(chip)
                            .font(TS.Font.label)
                            .foregroundStyle(TS.SemanticColor.goldDeep)
                            .padding(.horizontal, TS.Padding.chipHorizontal)
                            .padding(.vertical, 2)
                            .background(TS.SemanticColor.goldSoft, in: Capsule())
                    }
                }
            }
            if let detail = chrome.detailCaption, !detail.isEmpty {
                Text(detail)
                    .font(TS.Font.label)
                    .foregroundStyle(TS.SemanticColor.inkFaint)
            }
            if !chrome.configSummary.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(chrome.configSummary.enumerated()), id: \.offset) { _, pair in
                        Text("\(pair.0)：\(pair.1)")
                            .font(TS.Font.detail)
                            .foregroundStyle(TS.SemanticColor.inkSoft)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TS.Padding.cardInner)
        .background(TS.SemanticColor.cardBackground, in: RoundedRectangle(cornerRadius: TS.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: TS.Radius.card)
                .strokeBorder(TS.SemanticColor.line, lineWidth: 1)
        )
    }
}

// MARK: - Assumptions list

struct AssumptionsListView: View {
    let assumptions: [String]
    var emptyTitle: String = "无计算假设"
    var footer: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                Text("计算假设")
                    .font(TS.Font.sectionTitle)
                    .foregroundStyle(TS.SemanticColor.ink)
                if assumptions.isEmpty {
                    Text(emptyTitle)
                        .font(TS.Font.body)
                        .foregroundStyle(TS.SemanticColor.inkFaint)
                } else {
                    ForEach(Array(assumptions.enumerated()), id: \.offset) { _, item in
                        Text("• \(item)")
                            .font(TS.Font.body)
                            .foregroundStyle(TS.SemanticColor.inkSoft)
                            .textSelection(.enabled)
                    }
                }
                if let footer, !footer.isEmpty {
                    Text(footer)
                        .font(TS.Font.label)
                        .foregroundStyle(TS.SemanticColor.inkFaint)
                        .padding(.top, TS.Spacing.sm)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TS.Padding.cardInner)
        }
    }
}

// MARK: - Nested overview strip (embeds at top of default tab)

struct ExpansionOverviewStrip: View {
    let cards: [(title: String, value: String, subtitle: String)]

    var body: some View {
        if cards.isEmpty {
            EmptyView()
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120), spacing: TS.Spacing.md)],
                spacing: TS.Spacing.md
            ) {
                ForEach(Array(cards.prefix(6).enumerated()), id: \.offset) { _, card in
                    InfoCard(title: card.title, value: card.value, subtitle: card.subtitle)
                }
            }
        }
    }
}
