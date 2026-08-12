import SwiftUI

struct PrimaryDirectionRectifierView: View {
    let response: RectifyResponse
    let centerDate: Date
    let timeZone: TimeZone

    @Binding var level2Response: RectifyResponse?
    @Binding var level3Response: RectifyResponse?
    @Binding var s1Index: Int
    @Binding var s2Index: Int
    @Binding var activeLevel: Int
    @Binding var level3ResponseID: Int
    @Binding var evidenceResponse: RectificationEvidenceResponse?
    @Binding var isRunningEvidence: Bool
    @Binding var evidenceProgress: Double
    @Binding var evidenceProgressText: String

    let onComputeLevel2: (Int) -> Void
    let onComputeLevel3: (Int) -> Void
    let onComputeEvidence: ([RectificationEvidenceSourceEvent], Int) -> Void
    let onInvalidateEvidence: () -> Void

    @State private var s3Index = 0
    @State private var computeTask: Task<Void, Never>?
    @State private var selectedPanel = "directions"

    // Filter state
    @State private var filterKeyword = ""
    @State private var filterAgeMin = ""
    @State private var filterAgeMax = ""
    @State private var filterProm = ""
    @State private var filterSig = ""
    @State private var filterAspect = ""
    @State private var filterDir = ""
    @State private var filterTag = ""

    private var candidates: [RectifyResponse.Candidate] { response.candidates }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sliderSection
                .padding(.bottom, 6)
            Divider()
            Picker("工作区", selection: $selectedPanel) {
                Text("方向浏览").tag("directions")
                Text("事件证据").tag("evidence")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            Divider()
            if selectedPanel == "evidence" {
                RectificationEvidenceWorkspace(
                    candidateTime: activeLocalTimeString,
                    absoluteOffsetSeconds: absoluteOffsetSeconds,
                    timeZone: timeZone,
                    response: $evidenceResponse,
                    isRunning: $isRunningEvidence,
                    progress: $evidenceProgress,
                    progressText: $evidenceProgressText,
                    onCompute: onComputeEvidence
                )
            } else {
                filterBar
                    .padding(.vertical, 6)
                Divider()
                directionTable
            }
        }
        .onChange(of: level3ResponseID) { _ in
            guard let l3 = level3Response else { return }
            s3Index = l3.centerOffsetIndex
            activeLevel = 3
            evidenceResponse = nil
            onInvalidateEvidence()
        }
        .onDisappear {
            computeTask?.cancel()
        }
    }

    // MARK: - Real local time for active candidate

    /// Absolute offset in seconds from the original center birth time,
    /// accounting for all three levels of selection.
    private var absoluteOffsetSeconds: Int {
        guard let c1 = candidates.at(s1Index) else { return 0 }
        var total = c1.offsetMinutes * 60
        if activeLevel >= 2, let l2 = level2Response, let c2 = l2.candidates.at(s2Index) {
            total += c2.offsetSeconds ?? 0
        }
        if activeLevel >= 3, let l3 = level3Response, let c3 = l3.candidates.at(s3Index) {
            total += c3.offsetSeconds ?? 0
        }
        return total
    }

    private var activeLocalTimeString: String {
        let candidateDate = centerDate.addingTimeInterval(TimeInterval(absoluteOffsetSeconds))
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = timeZone
        return f.string(from: candidateDate)
    }

    // MARK: - Active candidate

    private var activeCandidate: RectifyResponse.Candidate? {
        if activeLevel >= 3, let l3 = level3Response, let c = l3.candidates.at(s3Index) {
            return c
        }
        if activeLevel >= 2, let l2 = level2Response, let c = l2.candidates.at(s2Index) {
            return c
        }
        return candidates.at(s1Index)
    }

    // MARK: - Slider section

    private var sliderSection: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            HStack {
                Text(activeLocalTimeString)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if activeLevel > 1 {
                    Text("(\(absoluteOffsetSeconds >= 0 ? "+" : "")\(absoluteOffsetSeconds)s)")
                        .font(TS.Font.detail)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if let c = activeCandidate {
                    Text("方向: \(c.primaryDirections.count)")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            let winMin = response.windowMinutes ?? 30
            sliderRow(
                label: "分钟",
                value: Binding(
                    get: { s1Index },
                    set: { s1Index = $0; scheduleS1Change() }
                ),
                range: 0...max(0, candidates.count - 1),
                minText: "-\(winMin)m",
                maxText: "+\(winMin)m",
                offsetText: { idx in
                    guard let c = candidates.at(idx) else { return "—" }
                    return "\(c.offsetMinutes >= 0 ? "+" : "")\(c.offsetMinutes)m"
                }
            )

            if let l2 = level2Response {
                sliderRow(
                    label: "5秒",
                    value: Binding(
                        get: { s2Index },
                        set: { s2Index = $0; scheduleS2Change() }
                    ),
                    range: 0...max(0, l2.candidates.count - 1),
                    minText: rangeLabel(l2.candidates.first, l2.candidates.last),
                    maxText: "",
                    offsetText: { idx in
                        guard let c = l2.candidates.at(idx), let s = c.offsetSeconds else { return "—" }
                        return "\(s >= 0 ? "+" : "")\(s)s"
                    }
                )
            } else {
                loadingRow("5秒", text: "选择分钟后自动计算")
            }

            if let l3 = level3Response {
                sliderRow(
                    label: "1秒",
                    value: Binding(
                        get: { s3Index },
                        set: {
                            s3Index = $0
                            activeLevel = 3
                            evidenceResponse = nil
                            onInvalidateEvidence()
                        }
                    ),
                    range: 0...max(0, l3.candidates.count - 1),
                    minText: rangeLabel(l3.candidates.first, l3.candidates.last),
                    maxText: "",
                    offsetText: { idx in
                        guard let c = l3.candidates.at(idx), let s = c.offsetSeconds else { return "—" }
                        return "\(s >= 0 ? "+" : "")\(s)s"
                    }
                )
            } else {
                loadingRow("1秒", text: "选择 5 秒槽后自动计算")
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    private func sliderRow(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        minText: String,
        maxText: String,
        offsetText: @escaping (Int) -> String
    ) -> some View {
        HStack(spacing: TS.Spacing.md) {
            Text(label)
                .font(TS.Font.detail)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            Text(minText)
                .font(TS.Font.detail)
                .foregroundStyle(.tertiary)
                .frame(width: 52, alignment: .trailing)
            if range.upperBound > range.lowerBound {
                Slider(value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0.rounded()) }
                ), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
            } else {
                Slider(value: .constant(0), in: 0...1, step: 1)
                    .disabled(true)
                    .allowsHitTesting(false)
            }
            Text(maxText)
                .font(TS.Font.detail)
                .foregroundStyle(.tertiary)
                .frame(width: 52, alignment: .leading)
            Text(offsetText(value.wrappedValue))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
    }

    private func loadingRow(_ label: String, text: String) -> some View {
        HStack(spacing: TS.Spacing.md) {
            Text(label)
                .font(TS.Font.detail)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            Text(text)
                .font(TS.Font.label)
                .foregroundStyle(.tertiary)
                .padding(.leading, 4)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func rangeLabel(_ first: RectifyResponse.Candidate?, _ last: RectifyResponse.Candidate?) -> String {
        guard let f = first?.offsetSeconds, let l = last?.offsetSeconds else { return "—" }
        return "\(f)s…\(l)s"
    }

    // MARK: - Debounced change handlers with stale guard

    private func scheduleS1Change() {
        computeTask?.cancel()
        activeLevel = 1
        level2Response = nil
        level3Response = nil
        evidenceResponse = nil
        onInvalidateEvidence()
        s2Index = 0
        s3Index = 0
        computeTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let c = candidates.at(s1Index) else { return }
            await MainActor.run { onComputeLevel2(c.offsetMinutes * 60) }
        }
    }

    private func scheduleS2Change() {
        computeTask?.cancel()
        activeLevel = 2
        level3Response = nil
        evidenceResponse = nil
        onInvalidateEvidence()
        s3Index = 0
        computeTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let l2 = level2Response,
                  let c = l2.candidates.at(s2Index) else { return }
            let baseSec = (candidates.at(s1Index)?.offsetMinutes ?? 0) * 60
            let fineSec = c.offsetSeconds ?? 0
            await MainActor.run { onComputeLevel3(baseSec + fineSec) }
        }
    }

    // MARK: - Filter bar (2 rows)

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            HStack(spacing: TS.Spacing.md) {
                FilterField(text: $filterKeyword, placeholder: "关键词", width: 120)
                FilterField(text: $filterAgeMin, placeholder: "最小年龄", width: 64)
                FilterField(text: $filterAgeMax, placeholder: "最大年龄", width: 64)
                FilterPicker(selection: $filterProm, options: promOptions, placeholder: "Prom")
                FilterPicker(selection: $filterSig, options: sigOptions, placeholder: "Sig")
                Spacer()
                if let c = activeCandidate {
                    let filtered = filteredDirections(c)
                    Text("\(filtered.count)/\(c.primaryDirections.count)")
                        .font(TS.Font.detail)
                        .foregroundStyle(.tertiary)
                }
            }
            HStack(spacing: TS.Spacing.md) {
                FilterPicker(selection: $filterAspect, options: aspectOptions, placeholder: "相位")
                FilterPicker(selection: $filterDir, options: dirOptions, placeholder: "方向")
                FilterField(text: $filterTag, placeholder: "标签", width: 100)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Table

    private var directionTable: some View {
        ScrollView([.horizontal, .vertical]) {
            let dirs = filteredDirections(activeCandidate)
            if dirs.isEmpty {
                VStack {
                    Spacer()
                    Text("无匹配结果").foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(Array(dirs.enumerated()), id: \.element.id) { _, d in
                            DirectionRow(direction: d)
                        }
                    } header: { tableHeader }
                }
            }
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            TableHeaderCell("年龄", width: 48)
            TableHeaderCell("日期", width: 100)
            TableHeaderCell("Prom", width: 50)
            TableHeaderCell("相位", width: 40)
            TableHeaderCell("Sig", width: 50)
            TableHeaderCell("方向", width: 50)
            TableHeaderCell("备注", width: 300)
            TableHeaderCell("偏移(天)", width: 64)
            TableHeaderCell("标签", width: 200)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func filteredDirections(_ cand: RectifyResponse.Candidate?) -> [RectifyResponse.Direction] {
        guard let cand else { return [] }
        return cand.primaryDirections.filter { d in
            if !filterKeyword.isEmpty {
                let hay = [d.promissor, d.significator, d.aspectName, d.note, d.directionType] + d.tags
                guard hay.joined(separator: " ").localizedCaseInsensitiveContains(filterKeyword) else { return false }
            }
            if let v = Double(filterAgeMin), d.ageFromAbsArc < v { return false }
            if let v = Double(filterAgeMax), d.ageFromAbsArc > v { return false }
            if !filterProm.isEmpty, d.promissor != filterProm { return false }
            if !filterSig.isEmpty, d.significator != filterSig { return false }
            if !filterAspect.isEmpty, d.aspectName != filterAspect { return false }
            if !filterDir.isEmpty, d.directionType != filterDir { return false }
            if !filterTag.isEmpty {
                guard d.tags.joined(separator: " ").localizedCaseInsensitiveContains(filterTag) else { return false }
            }
            return true
        }
    }

    private var promOptions: [String] { uniqueSorted(\.promissor, from: candidates) }
    private var sigOptions: [String] { uniqueSorted(\.significator, from: candidates) }
    private var aspectOptions: [String] { uniqueSorted(\.aspectName, from: candidates) }
    private var dirOptions: [String] { uniqueSorted(\.directionType, from: candidates) }

    private func uniqueSorted(_ keyPath: KeyPath<RectifyResponse.Direction, String>,
                               from candidates: [RectifyResponse.Candidate]) -> [String] {
        let values = Set(candidates.flatMap { $0.primaryDirections.map { $0[keyPath: keyPath] } })
        let priority = ["太阳","月亮","水星","金星","火星","木星","土星","ASC","MC","DSC","IC",
                        "合相","六合","刑相","拱相","冲相","direct","converse"]
        return values.sorted { a, b in
            let ia = priority.firstIndex(of: a) ?? Int.max
            let ib = priority.firstIndex(of: b) ?? Int.max
            if ia != ib { return ia < ib }
            return a.localizedCompare(b) == .orderedAscending
        }
    }
}

// MARK: - Sub-views

private struct DirectionRow: View {
    let direction: RectifyResponse.Direction
    var body: some View {
        HStack(spacing: 0) {
            TableDataCell(String(format: "%.1f", direction.ageFromAbsArc), width: 48)
            TableDataCell(direction.eventDateAfterBirth, width: 100)
            TableDataCell(direction.promissor, width: 50)
            TableDataCell(direction.aspectName, width: 40)
            TableDataCell(direction.significator, width: 50)
            TableDataCell(direction.directionType, width: 50)
                .foregroundStyle(direction.directionType == "direct" ? Color.green : Color.orange)
            TableDataCell(direction.note, width: 300)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            TableDataCell(String(format: "%.1f", direction.shiftVsCenterDays), width: 64)
                .foregroundStyle(direction.shiftVsCenterDays > 0 ? Color.red : Color.green)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TS.Spacing.xs) {
                    ForEach(direction.tags, id: \.self) { tag in
                        Text(tag)
                            .font(TS.Font.detail)
                            .padding(.horizontal, TS.Spacing.md)
                            .padding(.vertical, TS.Spacing.xs)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(TS.Radius.chip)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(width: 200, alignment: .leading)
        }
        .font(TS.Font.label)
        .padding(.vertical, 4)
    }
}

private struct TableHeaderCell: View {
    let title: String; let width: CGFloat
    init(_ title: String, width: CGFloat) { self.title = title; self.width = width }
    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 6)
    }
}

private struct TableDataCell: View {
    let text: String; let width: CGFloat
    init(_ text: String, width: CGFloat) { self.text = text; self.width = width }
    var body: some View {
        Text(text)
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 6)
    }
}

private struct FilterField: View {
    @Binding var text: String; let placeholder: String; let width: CGFloat
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain).font(TS.Font.label)
            .frame(width: width).padding(TS.Spacing.md)
            .background(Color.secondary.opacity(0.08)).cornerRadius(TS.Radius.chip)
    }
}

private struct FilterPicker: View {
    @Binding var selection: String; let options: [String]; let placeholder: String
    var body: some View {
        Picker(placeholder, selection: $selection) {
            Text("全部").tag("")
            ForEach(options, id: \.self) { opt in Text(opt).tag(opt) }
        }
        .pickerStyle(.menu).font(TS.Font.label).frame(width: 72)
    }
}

extension Array {
    func at(_ index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
