import SwiftUI

extension ContentView {
    @MainActor
    func handleRunButtonTapped() {
        if calcVM.isRunning {
            stopCurrentRun()
        } else {
            startRunTask()
        }
    }

    /// Starts work on a tracked Task so the top-bar stop button can cancel it
    /// and only this generation may clear `currentRunTask` / `isRunning`.
    /// `isStoppable` is a property of the task, not of the currently visible page.
    @MainActor
    func startTrackedRun(isStoppable: Bool = true, _ work: @escaping @MainActor () async -> Void) {
        calcVM.currentRunTask?.cancel()
        let generation = calcVM.beginRun(isStoppable: isStoppable)
        calcVM.currentRunTask = Task {
            await work()
            await MainActor.run {
                calcVM.clearRunTaskIfCurrent(generation)
            }
        }
    }

    @MainActor
    func startRunTask(confirmedHeavyScan: Bool = false) {
        // Capture stoppability from the mode that *started* the run.
        let isStoppable = mode != .rectify
        startTrackedRun(isStoppable: isStoppable) {
            await runCurrentMode(confirmedHeavyScan: confirmedHeavyScan)
        }
    }

    @MainActor
    func stopCurrentRun() {
        guard calcVM.currentRunIsStoppable else { return }
        calcVM.currentRunTask?.cancel()
        // Invalidate in-flight cleanup so a superseded run cannot clear a newer
        // task reference or flip isRunning after the user already stopped.
        calcVM.invalidateActiveRun()
        if calcVM.isRunning {
            calcVM.isRunning = false
            finishProgress(cancelled: true)
            calcVM.errorMessage = "计算已停止。"
        }
    }

    @MainActor
    func runCurrentMode(confirmedHeavyScan: Bool = false) async {
        clearAnalysisForCurrentMode()
        switch mode {
        case .settings:
            if practiceMode == .classical {
                // Workspace is the only classical+settings authority (PR1 five gates).
                switch ClassicalSettingsGate.route(workspace: classicalSettingsWorkspace) {
                case .natalChart:
                    await runClassical()
                case .expansion(let expansionMode):
                    // Expansion writes modernResultData via the shared modern runners.
                    await runModernSubMode(expansionMode)
                }
            } else if practiceMode == .vedic {
                await runVedic()
            } else {
                await runModernSubMode(modernSubMode)
            }
        case .horary:
            await runHorary()
        case .moment:
            await runCalculation()
        case .scan:
            if isModernTimingWorkspace {
                await runModernTiming(confirmedHeavyScan: confirmedHeavyScan)
            } else {
                await runScan(confirmedHeavyScan: confirmedHeavyScan)
            }
        case .rectify:
            await runRectify()
        }
    }

    /// Shared modern/expansion dispatch — also used by classical expansion workspace.
    @MainActor
    func runModernSubMode(_ subMode: ModernSubMode) async {
        switch subMode {
        case .natal: await runModernNatal()
        case .synastry: await runSynastry()
        case .composite: await runComposite()
        case .davison: await runDavison()
        case .progression: await runProgressions()
        case .solarArc: await runSolarArc()
        case .harmonic: await runHarmonic()
        case .returnChart: await runModernReturn()
        case .midpoint: await runMidpoint()
        case .progressedComposite: await runProgressedComposite()
        case .relocation: await runRelocation()
        case .modernCycles: await runModernCycles()
        case .declinationTiming: await runDeclinationTiming()
        case .retrogradeCycles: await runRetrogradeCycles()
        case .classicalVisibility: await runClassicalVisibility()
        case .planetarySynodic: await runPlanetarySynodic()
        case .hellenisticConditionAudit: await runHellenisticConditionAudit()
        case .draconicHeliocentric: await runDraconicHeliocentric()
        case .classicalDerivatives: await runClassicalDerivatives()
        case .timeLordsExtended: await runTimeLordsExtended()
        case .methodFamilies: await runMethodFamilies()
        case .primaryDirectionsAudit: await runPrimaryDirectionsAudit()
        case .distributionsPd: await runDistributionsPd()
        case .prenatalParans: await runPrenatalParans()
        case .orbitalDial: await runOrbitalDial()
        case .mundaneElectional: await runMundaneElectional()
        case .astrocartography: await runAstrocartography()
        case .localSpace: await runLocalSpace()
        }
    }

    @MainActor
    func clearAnalysisForCurrentMode() {
        switch mode {
        case .settings:
            if practiceMode == .classical {
                switch ClassicalSettingsGate.route(workspace: classicalSettingsWorkspace) {
                case .natalChart:
                    aiVM.clear(modeKey: "classical")
                case .expansion:
                    // Expansion has no AI streamKey; do not clear or reuse "classical".
                    break
                }
            } else if practiceMode == .vedic {
                aiVM.clear(modeKey: "vedic")
            } else {
                aiVM.clear(modeKey: modernSubMode == .natal ? "natal" : modernSubMode.rawValue)
            }
        case .horary: aiVM.clear(modeKey: "horary")
        case .moment: aiVM.clear(modeKey: "moment")
        case .scan:
            if !isModernTimingWorkspace {
                aiVM.clear(modeKey: "scan")
            }
        case .rectify: break
        }
    }

    // MARK: - Shared Run Helpers

    /// Shared run-state bracket for every calculation action: resets error and
    /// asteroid status, flips `isRunning`, optionally drives the estimated
    /// progress bar, and reports thrown errors into `calcVM.errorMessage`.
    @MainActor
    func performRun(
        progressWork: Int? = nil,
        progressLabel: String = "",
        preRunWarning: String? = nil,
        liveProgress: Bool = false,
        _ operation: () async throws -> Void
    ) async {
        let generation = calcVM.runGeneration
        calcVM.isRunning = true
        calcVM.errorMessage = nil
        calcVM.warningMessage = preRunWarning
        calcVM.asteroidPreparationMessage = ""
        var wasCancelled = false
        if liveProgress {
            calcVM.calculationProgress = 0
            calcVM.calculationProgressText = "\(progressLabel) 0%"
        } else if let progressWork {
            startEstimatedProgress(totalWork: progressWork, label: progressLabel)
        }
        defer {
            if calcVM.isCurrentRun(generation) {
                calcVM.isRunning = false
                if progressWork != nil || liveProgress {
                    finishProgress(cancelled: wasCancelled || Task.isCancelled)
                }
            }
        }
        do {
            try await operation()
            guard calcVM.isCurrentRun(generation) else { return }
            if calcVM.errorMessage == nil && !isParamDrawerPinned {
                collapseMiddleSidebar()
            }
        } catch is CancellationError {
            guard calcVM.isCurrentRun(generation) else { return }
            wasCancelled = true
            calcVM.errorMessage = "计算已停止。"
        } catch {
            guard calcVM.isCurrentRun(generation) else { return }
            calcVM.errorMessage = error.localizedDescription
        }
    }

    /// Parses a latitude/longitude text pair, reporting a user-facing error
    /// and returning nil when either is not numeric.
    @MainActor
    func requireCoordinates(
        _ latitudeText: String,
        _ longitudeText: String,
        errorText: String = "经纬度需要是数字。"
    ) -> (latitude: Double, longitude: Double)? {
        guard let latitude = parseDouble(latitudeText), let longitude = parseDouble(longitudeText) else {
            calcVM.errorMessage = errorText
            return nil
        }
        return (latitude, longitude)
    }

    func makeBirthSettings(latitude: Double, longitude: Double, zodiac: String? = nil) -> BirthSettings {
        BirthSettings(
            moment: makeMoment(from: natalDate),
            latitude: latitude,
            longitude: longitude,
            houseSystem: selectedHouseSystem,
            zodiac: zodiac ?? selectedZodiac,
            boundsSystem: selectedBoundsSystem,
            triplicitySystem: selectedTriplicitySystem
        )
    }

    func makeBirthSettings(
        from person: PersonSettings,
        houseSystem: String? = nil,
        zodiac: String? = nil
    ) -> BirthSettings {
        BirthSettings(
            moment: person.moment,
            latitude: person.latitude,
            longitude: person.longitude,
            houseSystem: houseSystem ?? selectedHouseSystem,
            zodiac: zodiac ?? selectedZodiac,
            boundsSystem: selectedBoundsSystem,
            triplicitySystem: selectedTriplicitySystem
        )
    }

    func makePersonPair(
        latitudeA: Double, longitudeA: Double,
        latitudeB: Double, longitudeB: Double
    ) -> (personA: PersonSettings, personB: PersonSettings) {
        (
            PersonSettings(name: "Person A", moment: makeMoment(from: natalDate), latitude: latitudeA, longitude: longitudeA),
            PersonSettings(name: "Person B", moment: makeMoment(from: modernPersonBDate, gmtOffset: modernPersonBGmtOffset), latitude: latitudeB, longitude: longitudeB)
        )
    }

    // MARK: - Modern Run Actions

    private var modernDefaultBodyIDs: [String] {
        ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO"]
    }

    private func modernDefaultPointSet(asteroidIDs: [Int]) -> ModernPointSet {
        ModernPointSet(
            bodyIDs: modernDefaultBodyIDs,
            includeNodes: true,
            nodeMode: modernNodeMode,
            customAsteroids: asteroidIDs,
            angleIDs: ["ASC", "MC", "DSC", "IC"]
        )
    }

    private func modernNatalPointSet(asteroidIDs: [Int]) -> ModernPointSet {
        let nodeIDs: Set<String> = ["MEAN_NODE", "TRUE_NODE", "SOUTH_MEAN_NODE", "SOUTH_TRUE_NODE"]
        let selected = sortedBodyIDs(selectedNatalBodies)
        return ModernPointSet(
            bodyIDs: selected.filter { !nodeIDs.contains($0) },
            includeNodes: selected.contains(where: nodeIDs.contains),
            nodeMode: modernNodeMode,
            customAsteroids: asteroidIDs,
            angleIDs: ["ASC", "MC", "DSC", "VERTEX", "ANTIVERTEX", "EQUATORIAL_ASCENDANT"]
        )
    }

    @MainActor
    func runModernNatal() async {
        await performRun {
            let asteroidIDs = parseAsteroids(customAsteroids)
            let effectiveEphemerisPath = try await prepareAsteroidsIfNeeded(asteroidIDs)
            let request = TransitRequest(
                mode: "moment",
                natal: makeMoment(from: natalDate),
                transit: makeMoment(from: natalDate),
                birth: makeBirthSettingsIfValid(),
                natalBodies: allBuiltinBodyIDs,
                transitBodies: allBuiltinBodyIDs,
                customAsteroids: asteroidIDs,
                aspects: selectedAspectRequests(orb: globalOrb),
                ephemerisPath: effectiveEphemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris,
                sameChart: true,
                nodeMode: modernNodeMode,
                pointSet: modernNatalPointSet(asteroidIDs: asteroidIDs),
                patternsEnabled: true
            )
            let result = try await BackendClient.calculate(request: request, pythonPath: appState.pythonPath)
            calcVM.fullNatalResult = result
            calcVM.modernNatalResult = filteredModernNatalResult(from: result, asteroidIDs: asteroidIDs)
            syncScanTargetsFromNatalChart()
        }
    }

    @MainActor
    func runSynastry() async {
        guard let a = requireCoordinates(birthLatitude, birthLongitude),
              let b = requireCoordinates(modernPersonBLatitude, modernPersonBLongitude) else { return }
        await performRun {
            let asteroidIDs = parseAsteroids(customAsteroids)
            let effectiveEphemerisPath = try await prepareAsteroidsIfNeeded(asteroidIDs)
            let pair = makePersonPair(latitudeA: a.latitude, longitudeA: a.longitude, latitudeB: b.latitude, longitudeB: b.longitude)
            let request = SynastryRequest(
                mode: "synastry",
                personA: pair.personA,
                personB: pair.personB,
                houseSystem: selectedHouseSystem, zodiac: selectedZodiac, nodeMode: modernNodeMode,
                aspects: selectedAspectRequests(orb: globalOrb), ephemerisPath: effectiveEphemerisPath,
                noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris,
                pointSet: modernDefaultPointSet(asteroidIDs: asteroidIDs)
            )
            let result = try await BackendClient.synastry(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.synastry(result))
        }
    }

    @MainActor
    func runComposite() async {
        guard let a = requireCoordinates(birthLatitude, birthLongitude),
              let b = requireCoordinates(modernPersonBLatitude, modernPersonBLongitude) else { return }
        await performRun {
            let asteroidIDs = parseAsteroids(customAsteroids)
            let effectiveEphemerisPath = try await prepareAsteroidsIfNeeded(asteroidIDs)
            let pair = makePersonPair(latitudeA: a.latitude, longitudeA: a.longitude, latitudeB: b.latitude, longitudeB: b.longitude)
            let request = CompositeRequest(
                mode: "composite",
                personA: pair.personA,
                personB: pair.personB,
                houseSystem: selectedHouseSystem, zodiac: selectedZodiac, nodeMode: modernNodeMode,
                aspects: selectedAspectRequests(orb: globalOrb), ephemerisPath: effectiveEphemerisPath,
                noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris,
                pointSet: modernDefaultPointSet(asteroidIDs: asteroidIDs)
            )
            let result = try await BackendClient.composite(request: request, pythonPath: appState.pythonPath)
            modernLastRelationshipPersonA = pair.personA
            modernLastRelationshipPersonB = pair.personB
            modernLastRelationshipHouseSystem = request.houseSystem
            modernLastRelationshipZodiac = request.zodiac
            calcVM.setModernResultData(.composite(result))
        }
    }

    @MainActor
    func runDavison() async {
        guard let a = requireCoordinates(birthLatitude, birthLongitude),
              let b = requireCoordinates(modernPersonBLatitude, modernPersonBLongitude) else { return }
        await performRun {
            let asteroidIDs = parseAsteroids(customAsteroids)
            let effectiveEphemerisPath = try await prepareAsteroidsIfNeeded(asteroidIDs)
            let pair = makePersonPair(latitudeA: a.latitude, longitudeA: a.longitude, latitudeB: b.latitude, longitudeB: b.longitude)
            let request = DavisonRequest(
                mode: "davison",
                personA: pair.personA,
                personB: pair.personB,
                houseSystem: selectedHouseSystem, zodiac: selectedZodiac, nodeMode: modernNodeMode,
                aspects: selectedAspectRequests(orb: globalOrb), ephemerisPath: effectiveEphemerisPath,
                noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris,
                pointSet: modernDefaultPointSet(asteroidIDs: asteroidIDs)
            )
            let result = try await BackendClient.davison(request: request, pythonPath: appState.pythonPath)
            modernLastRelationshipPersonA = pair.personA
            modernLastRelationshipPersonB = pair.personB
            modernLastRelationshipHouseSystem = request.houseSystem
            modernLastRelationshipZodiac = request.zodiac
            calcVM.setModernResultData(.davison(result))
        }
    }

    @MainActor
    func runProgressedComposite() async {
        guard let a = requireCoordinates(birthLatitude, birthLongitude),
              let b = requireCoordinates(modernPersonBLatitude, modernPersonBLongitude) else { return }
        let asteroidIDs = progressedCompositeUseCustomAsteroids ? parseAsteroids(customAsteroids) : []
        let pointSet = progressedCompositePointSet(asteroidIDs: asteroidIDs)
        guard !pointSet.bodyIDs.isEmpty || pointSet.includeNodes || !pointSet.customAsteroids.isEmpty else {
            calcVM.errorMessage = "推进组合盘至少需要一个行星、节点或自定义小行星。"
            return
        }
        await performRun(progressLabel: "推进组合盘") {
            let effectiveEphemerisPath = try await prepareAsteroidsIfNeeded(asteroidIDs)
            let pair = makePersonPair(latitudeA: a.latitude, longitudeA: a.longitude, latitudeB: b.latitude, longitudeB: b.longitude)
            let request = ProgressedCompositeRequest(
                personA: pair.personA,
                personB: pair.personB,
                reference: makeMoment(
                    from: classicalReferenceDate,
                    gmtOffset: progressedCompositeReferenceGmtOffset
                ),
                pointSet: pointSet,
                zodiac: selectedZodiac,
                nodeMode: modernNodeMode,
                aspects: selectedAspectRequests(orb: globalOrb),
                ephemerisPath: effectiveEphemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.progressedComposite(
                request: request,
                pythonPath: appState.pythonPath
            )
            calcVM.setModernResultData(.progressedComposite(result))
        }
    }

    @MainActor
    func runRelocation() async {
        guard let birthCoords = requireCoordinates(birthLatitude, birthLongitude),
              let relocLat = parseDouble(relocationLatitude),
              let relocLon = parseDouble(relocationLongitude) else { return }
        let placeName = relocationPlaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let placeTZ = relocationTimezone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !placeName.isEmpty, !placeTZ.isEmpty else {
            calcVM.errorMessage = "迁移地点需要名称与时区。"
            return
        }
        await performRun(progressLabel: "迁移盘") {
            let pointSet = ModernPointSet(
                bodyIDs: sortedBodyIDs(relocationBodies),
                includeNodes: false,
                nodeMode: modernNodeMode,
                customAsteroids: [],
                angleIDs: ["ASC", "MC", "DSC", "IC"],
                houseCusps: [],
                lotIDs: []
            )
            let request = RelocationRequest(
                birth: RelocationBirth(
                    name: "Birth place",
                    moment: makeMoment(from: natalDate),
                    latitude: birthCoords.latitude,
                    longitude: birthCoords.longitude
                ),
                relocation: GeoPlace(
                    name: placeName,
                    latitude: relocLat,
                    longitude: relocLon,
                    timezone: placeTZ
                ),
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                nodeMode: modernNodeMode,
                pointSet: pointSet,
                aspects: selectedAspectRequests(orb: globalOrb),
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.relocation(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.relocation(result))
        }
    }

    @MainActor
    func runModernCycles() async {
        guard !cyclesSelectedTypes.isEmpty else {
            calcVM.errorMessage = "请至少选择一种周期类型。"
            return
        }
        await performRun(progressLabel: "朔望食相") {
            var location: GeoPlace?
            if cyclesVisibility == "location" {
                guard let coords = requireCoordinates(birthLatitude, birthLongitude) else {
                    throw NSError(
                        domain: "TransitStudio",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "地点可见性需要本命经纬度作为观察点。"]
                    )
                }
                location = GeoPlace(
                    name: "Observer",
                    latitude: coords.latitude,
                    longitude: coords.longitude,
                    timezone: timezoneLabel
                )
            }
            var birth: RelocationBirth?
            var targetPointSet: ModernPointSet?
            if cyclesIncludeNatalContacts, let coords = requireCoordinates(birthLatitude, birthLongitude) {
                birth = RelocationBirth(
                    name: "Natal",
                    moment: makeMoment(from: natalDate),
                    latitude: coords.latitude,
                    longitude: coords.longitude
                )
                targetPointSet = ModernPointSet(
                    bodyIDs: ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"],
                    includeNodes: false,
                    nodeMode: modernNodeMode,
                    customAsteroids: [],
                    angleIDs: [],
                    houseCusps: [],
                    lotIDs: []
                )
            }
            let request = ModernCyclesRequest(
                start: makeMoment(from: scanStartDate),
                end: makeMoment(from: scanEndDate),
                displayTimezone: timezoneLabel,
                cycleTypes: Array(cyclesSelectedTypes).sorted(),
                visibility: cyclesVisibility,
                location: location,
                birth: birth,
                targetPointSet: targetPointSet,
                contactAspects: selectedAspectRequests(orb: globalOrb),
                zodiac: selectedZodiac,
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.modernCycles(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.modernCycles(result))
        }
    }

    @MainActor
    func runDeclinationTiming() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
        guard !declinationMovingBodies.isEmpty else {
            calcVM.errorMessage = "请至少选择一个行运体。"
            return
        }
        guard !declinationEventTypes.isEmpty else {
            calcVM.errorMessage = "请至少选择一种赤纬事件类型。"
            return
        }
        await performRun(progressLabel: "赤纬事件") {
            let angleOrder = ["ASC", "MC", "DSC", "IC", "VERTEX", "ANTIVERTEX", "EQUATORIAL_ASCENDANT"]
            let targetPointSet = ModernPointSet(
                bodyIDs: sortedBodyIDs(declinationTargetBodies),
                includeNodes: false,
                nodeMode: modernNodeMode,
                customAsteroids: [],
                angleIDs: angleOrder.filter { declinationTargetAngles.contains($0) },
                houseCusps: [],
                lotIDs: []
            )
            let request = DeclinationTimingRequest(
                birth: makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude),
                start: makeMoment(from: scanStartDate),
                end: makeMoment(from: scanEndDate),
                displayTimezone: timezoneLabel,
                movingBodyIDs: sortedBodyIDs(declinationMovingBodies),
                eventTypes: Array(declinationEventTypes).sorted(),
                declinationOrb: declinationOrb,
                targetPointSet: targetPointSet,
                zodiac: selectedZodiac,
                nodeMode: modernNodeMode,
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.declinationTiming(
                request: request,
                pythonPath: appState.pythonPath
            )
            calcVM.setModernResultData(.declinationTiming(result))
        }
    }

    @MainActor
    func runRetrogradeCycles() async {
        guard !retrogradeBodies.isEmpty else {
            calcVM.errorMessage = "请至少选择一个会逆行的天体。"
            return
        }
        await performRun(progressLabel: "逆行阴影") {
            let request = RetrogradeCyclesRequest(
                start: makeMoment(from: scanStartDate),
                end: makeMoment(from: scanEndDate),
                displayTimezone: timezoneLabel,
                bodyIDs: sortedBodyIDs(retrogradeBodies),
                zodiac: selectedZodiac,
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.retrogradeCycles(
                request: request,
                pythonPath: appState.pythonPath
            )
            calcVM.setModernResultData(.retrogradeCycles(result))
        }
    }

    @MainActor
    func runClassicalVisibility() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
        await performRun(progressLabel: "可见相位/行星时") {
            let request = ClassicalVisibilityRequest(
                moment: makeMoment(from: natalDate),
                location: GeoPlace(
                    name: "Observer",
                    latitude: coords.latitude,
                    longitude: coords.longitude,
                    timezone: timezoneLabel,
                    altitudeM: 10
                ),
                displayTimezone: timezoneLabel,
                bodyIDs: sortedBodyIDs(visibilityBodies).isEmpty
                    ? ["MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]
                    : sortedBodyIDs(visibilityBodies),
                heliacalEventTypes: Array(visibilityHeliacalTypes).sorted(),
                include: Array(visibilityInclude).sorted(),
                observerAge: 36,
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.classicalVisibility(
                request: request,
                pythonPath: appState.pythonPath
            )
            calcVM.setModernResultData(.classicalVisibility(result))
        }
    }

    @MainActor
    func runPlanetarySynodic() async {
        guard synodicBodyA != synodicBodyB else {
            calcVM.errorMessage = "会合周期需要两个不同的天体。"
            return
        }
        await performRun(progressLabel: "会合周期") {
            var birth: RelocationBirth?
            var target: ModernPointSet?
            if synodicIncludeNatalContacts, let coords = requireCoordinates(birthLatitude, birthLongitude) {
                birth = RelocationBirth(
                    name: "Natal",
                    moment: makeMoment(from: natalDate),
                    latitude: coords.latitude,
                    longitude: coords.longitude
                )
                target = ModernPointSet(
                    bodyIDs: ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"],
                    includeNodes: false,
                    nodeMode: modernNodeMode,
                    customAsteroids: [],
                    angleIDs: [],
                    houseCusps: [],
                    lotIDs: []
                )
            }
            let request = PlanetarySynodicRequest(
                start: makeMoment(from: scanStartDate),
                end: makeMoment(from: scanEndDate),
                displayTimezone: timezoneLabel,
                pair: PlanetaryPair(bodyA: synodicBodyA, bodyB: synodicBodyB),
                phases: [
                    AspectRequest(id: "conjunction", name: "合相", angle: 0, orb: 0),
                    AspectRequest(id: "square", name: "刑相", angle: 90, orb: 0),
                    AspectRequest(id: "opposition", name: "冲相", angle: 180, orb: 0),
                    AspectRequest(id: "square_closing", name: "闭刑", angle: 270, orb: 0),
                ],
                birth: birth,
                targetPointSet: target,
                contactAspects: selectedAspectRequests(orb: 1.0),
                zodiac: selectedZodiac,
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.planetarySynodic(
                request: request,
                pythonPath: appState.pythonPath
            )
            calcVM.setModernResultData(.planetarySynodic(result))
        }
    }


    @MainActor
    func runHellenisticConditionAudit() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
        await performRun(progressLabel: "希腊状态审计") {
            let request = HellenisticConditionAuditRequest(
                birth: makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude),
                aspectOrb: globalOrb,
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.hellenisticConditionAudit(
                request: request,
                pythonPath: appState.pythonPath
            )
            calcVM.setModernResultData(.hellenisticConditionAudit(result))
        }
    }


    @MainActor
    func runDraconicHeliocentric() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
        await performRun(progressLabel: "Draconic/日心") {
            let request = DraconicHeliocentricRequest(
                birth: makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude),
                nodeMode: modernNodeMode,
                pointSet: ModernPointSet(
                    bodyIDs: sortedBodyIDs(selectedNatalBodies),
                    includeNodes: true,
                    nodeMode: modernNodeMode,
                    customAsteroids: [],
                    angleIDs: ["ASC", "MC"],
                    houseCusps: [],
                    lotIDs: []
                ),
                zodiac: selectedZodiac,
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.draconicHeliocentric(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.draconicHeliocentric(result))
        }
    }


    @MainActor
    func runClassicalDerivatives() async {
        await performRun(progressLabel: "派生盘/尊贵") {
            var birth: BirthSettings? = nil
            if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                birth = makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude)
            }
            let request = ExpansionGenericRequest(
                mode: "classical_derivatives",
                birth: birth,
                reference: makeMoment(from: natalDate),
                start: makeMoment(from: scanStartDate),
                end: makeMoment(from: scanEndDate),
                displayTimezone: timezoneLabel,
                location: {
                    if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                        return GeoPlace(name: "Observer", latitude: coords.latitude, longitude: coords.longitude, timezone: timezoneLabel)
                    }
                    return nil
                }(),
                bodyIDs: sortedBodyIDs(selectedNatalBodies),
                modulus: 90,
                maxAge: 90,
                topicHouse: 7,
                scanStepHours: 24,
                solarArcRateDegPerYear: 1.0,
                aspectOrb: globalOrb,
                significators: ["ASC", "SUN", "MOON"],
                paranRaOrbDeg: 1.0,
                pictureOrb: 1.0,
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.classicalDerivatives(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.classicalDerivatives(result))
        }
    }


    @MainActor
    func runTimeLordsExtended() async {
        await performRun(progressLabel: "时间主扩展") {
            var birth: BirthSettings? = nil
            if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                birth = makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude)
            }
            let request = ExpansionGenericRequest(
                mode: "time_lords_extended",
                birth: birth,
                reference: makeMoment(from: classicalReferenceDate),
                start: makeMoment(from: scanStartDate),
                end: makeMoment(from: scanEndDate),
                displayTimezone: timezoneLabel,
                location: {
                    if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                        return GeoPlace(name: "Observer", latitude: coords.latitude, longitude: coords.longitude, timezone: timezoneLabel)
                    }
                    return nil
                }(),
                bodyIDs: sortedBodyIDs(selectedNatalBodies),
                modulus: 90,
                maxAge: 90,
                topicHouse: mundaneTopicHouse,
                scanStepHours: mundaneScanStepHours,
                solarArcRateDegPerYear: 1.0,
                aspectOrb: globalOrb,
                significators: ["ASC", "SUN", "MOON"],
                paranRaOrbDeg: 1.0,
                pictureOrb: 1.0,
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.timeLordsExtended(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.timeLordsExtended(result))
        }
    }


    @MainActor
    func runMethodFamilies() async {
        await performRun(progressLabel: "推运方法族") {
            var birth: BirthSettings? = nil
            if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                birth = makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude)
            }
            let request = ExpansionGenericRequest(
                mode: "method_families",
                birth: birth,
                reference: makeMoment(from: classicalReferenceDate),
                start: makeMoment(from: scanStartDate),
                end: makeMoment(from: scanEndDate),
                displayTimezone: timezoneLabel,
                location: {
                    if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                        return GeoPlace(name: "Observer", latitude: coords.latitude, longitude: coords.longitude, timezone: timezoneLabel)
                    }
                    return nil
                }(),
                bodyIDs: sortedBodyIDs(selectedNatalBodies),
                modulus: 90,
                maxAge: 90,
                topicHouse: mundaneTopicHouse,
                scanStepHours: mundaneScanStepHours,
                solarArcRateDegPerYear: 1.0,
                aspectOrb: globalOrb,
                significators: ["ASC", "SUN", "MOON"],
                paranRaOrbDeg: 1.0,
                pictureOrb: 1.0,
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.methodFamilies(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.methodFamilies(result))
        }
    }


    @MainActor
    func runPrimaryDirectionsAudit() async {
        await performRun(progressLabel: "主限审计") {
            var birth: BirthSettings? = nil
            if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                birth = makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude)
            }
            let request = ExpansionGenericRequest(
                mode: "primary_directions_audit",
                birth: birth,
                reference: makeMoment(from: classicalReferenceDate),
                start: makeMoment(from: scanStartDate),
                end: makeMoment(from: scanEndDate),
                displayTimezone: timezoneLabel,
                location: {
                    if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                        return GeoPlace(name: "Observer", latitude: coords.latitude, longitude: coords.longitude, timezone: timezoneLabel)
                    }
                    return nil
                }(),
                bodyIDs: sortedBodyIDs(selectedNatalBodies),
                modulus: 90,
                maxAge: 90,
                topicHouse: mundaneTopicHouse,
                scanStepHours: mundaneScanStepHours,
                solarArcRateDegPerYear: 1.0,
                aspectOrb: globalOrb,
                significators: ["ASC", "SUN", "MOON"],
                paranRaOrbDeg: 1.0,
                pictureOrb: 1.0,
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.primaryDirectionsAudit(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.primaryDirectionsAudit(result))
        }
    }


    @MainActor
    func runDistributionsPd() async {
        await performRun(progressLabel: "沿界/主限扩展") {
            var birth: BirthSettings? = nil
            if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                birth = makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude)
            }
            let request = ExpansionGenericRequest(
                mode: "distributions_pd",
                birth: birth,
                reference: makeMoment(from: classicalReferenceDate),
                start: makeMoment(from: scanStartDate),
                end: makeMoment(from: scanEndDate),
                displayTimezone: timezoneLabel,
                location: {
                    if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                        return GeoPlace(name: "Observer", latitude: coords.latitude, longitude: coords.longitude, timezone: timezoneLabel)
                    }
                    return nil
                }(),
                bodyIDs: sortedBodyIDs(selectedNatalBodies),
                modulus: 90,
                maxAge: 90,
                topicHouse: mundaneTopicHouse,
                scanStepHours: mundaneScanStepHours,
                solarArcRateDegPerYear: 1.0,
                aspectOrb: globalOrb,
                significators: ["ASC", "SUN", "MOON"],
                paranRaOrbDeg: 1.0,
                pictureOrb: 1.0,
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.distributionsPd(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.distributionsPd(result))
        }
    }


    @MainActor
    func runPrenatalParans() async {
        await performRun(progressLabel: "产前朔望/Parans") {
            var birth: BirthSettings? = nil
            if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                birth = makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude)
            }
            let request = ExpansionGenericRequest(
                mode: "prenatal_parans",
                birth: birth,
                reference: makeMoment(from: natalDate),
                start: makeMoment(from: scanStartDate),
                end: makeMoment(from: scanEndDate),
                displayTimezone: timezoneLabel,
                location: {
                    if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                        return GeoPlace(name: "Observer", latitude: coords.latitude, longitude: coords.longitude, timezone: timezoneLabel)
                    }
                    return nil
                }(),
                bodyIDs: sortedBodyIDs(selectedNatalBodies),
                modulus: 90,
                maxAge: 90,
                topicHouse: 7,
                scanStepHours: 24,
                solarArcRateDegPerYear: 1.0,
                aspectOrb: globalOrb,
                significators: ["ASC", "SUN", "MOON"],
                paranRaOrbDeg: 1.0,
                paranEventOrbSeconds: 240.0,
                includeLegacyParanProxy: true,
                pictureOrb: 1.0,
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.prenatalParans(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.prenatalParans(result))
        }
    }


    @MainActor
    func runOrbitalDial() async {
        await performRun(progressLabel: "轨道点/Dial") {
            var birth: BirthSettings? = nil
            if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                birth = makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude)
            }
            let request = ExpansionGenericRequest(
                mode: "orbital_dial",
                birth: birth,
                reference: makeMoment(from: natalDate),
                start: makeMoment(from: scanStartDate),
                end: makeMoment(from: scanEndDate),
                displayTimezone: timezoneLabel,
                location: {
                    if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                        return GeoPlace(name: "Observer", latitude: coords.latitude, longitude: coords.longitude, timezone: timezoneLabel)
                    }
                    return nil
                }(),
                bodyIDs: sortedBodyIDs(selectedNatalBodies),
                modulus: 90,
                maxAge: 90,
                topicHouse: 7,
                scanStepHours: 24,
                solarArcRateDegPerYear: 1.0,
                aspectOrb: globalOrb,
                significators: ["ASC", "SUN", "MOON"],
                paranRaOrbDeg: 1.0,
                pictureOrb: 1.0,
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.orbitalDial(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.orbitalDial(result))
        }
    }


    @MainActor
    func runMundaneElectional() async {
        await performRun(progressLabel: "世俗/择时事实") {
            var birth: BirthSettings? = nil
            if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                birth = makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude)
            }
            let request = ExpansionGenericRequest(
                mode: "mundane_electional",
                birth: birth,
                reference: makeMoment(from: classicalReferenceDate),
                start: makeMoment(from: scanStartDate),
                end: makeMoment(from: scanEndDate),
                displayTimezone: timezoneLabel,
                location: {
                    if let coords = requireCoordinates(birthLatitude, birthLongitude) {
                        return GeoPlace(name: "Observer", latitude: coords.latitude, longitude: coords.longitude, timezone: timezoneLabel)
                    }
                    return nil
                }(),
                bodyIDs: sortedBodyIDs(selectedNatalBodies),
                modulus: 90,
                maxAge: 90,
                topicHouse: mundaneTopicHouse,
                scanStepHours: mundaneScanStepHours,
                solarArcRateDegPerYear: 1.0,
                aspectOrb: globalOrb,
                significators: ["ASC", "SUN", "MOON"],
                paranRaOrbDeg: 1.0,
                pictureOrb: 1.0,
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.mundaneElectional(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.mundaneElectional(result))
        }
    }

    @MainActor
    func runAstrocartography() async {
        guard !mapBodies.isEmpty else {
            calcVM.errorMessage = "请至少选择一个天体。"
            return
        }
        await performRun(progressLabel: "天体地图") {
            let request = AstrocartographyRequest(
                moment: makeMoment(from: natalDate),
                bodyIDs: sortedBodyIDs(mapBodies),
                angleKinds: ["ASC", "DSC", "MC", "IC"],
                zodiac: "tropical",
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.astrocartography(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.astrocartography(result))
        }
    }

    @MainActor
    func runLocalSpace() async {
        let latText = localSpaceLatitude.isEmpty ? birthLatitude : localSpaceLatitude
        let lonText = localSpaceLongitude.isEmpty ? birthLongitude : localSpaceLongitude
        guard let coords = requireCoordinates(latText, lonText) else { return }
        guard !mapBodies.isEmpty else {
            calcVM.errorMessage = "请至少选择一个天体。"
            return
        }
        await performRun(progressLabel: "Local Space") {
            let name = localSpaceName.trimmingCharacters(in: .whitespacesAndNewlines)
            let request = LocalSpaceRequest(
                moment: makeMoment(from: natalDate),
                location: GeoPlace(
                    name: name.isEmpty ? "Observer" : name,
                    latitude: coords.latitude,
                    longitude: coords.longitude,
                    timezone: timezoneLabel
                ),
                bodyIDs: sortedBodyIDs(mapBodies),
                zodiac: "tropical",
                ephemerisPath: appState.ephemerisPath.isEmpty ? nil : appState.ephemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.localSpace(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.localSpace(result))
        }
    }

    @MainActor
    func runProgressions() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
        await performRun {
            let asteroidIDs = parseAsteroids(customAsteroids)
            let effectiveEphemerisPath = try await prepareAsteroidsIfNeeded(asteroidIDs)
            let request = ProgressionRequest(
                mode: "progression",
                birth: makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude),
                reference: makeMoment(from: classicalReferenceDate),
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                nodeMode: modernNodeMode, aspects: selectedAspectRequests(orb: globalOrb),
                ephemerisPath: effectiveEphemerisPath, noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris,
                pointSet: modernDefaultPointSet(asteroidIDs: asteroidIDs)
            )
            let result = try await BackendClient.progression(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.progression(result))
        }
    }

    @MainActor
    func runSolarArc() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
        await performRun {
            let asteroidIDs = parseAsteroids(customAsteroids)
            let effectiveEphemerisPath = try await prepareAsteroidsIfNeeded(asteroidIDs)
            let request = SolarArcRequest(
                mode: "solar_arc",
                birth: makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude),
                reference: makeMoment(from: classicalReferenceDate),
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                nodeMode: modernNodeMode, aspects: selectedAspectRequests(orb: globalOrb),
                patternsEnabled: true,
                ephemerisPath: effectiveEphemerisPath, noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris,
                pointSet: modernDefaultPointSet(asteroidIDs: asteroidIDs)
            )
            let result = try await BackendClient.solarArc(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.solarArc(result))
        }
    }

    @MainActor
    func runHarmonic() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
        await performRun {
            let asteroidIDs = parseAsteroids(customAsteroids)
            let effectiveEphemerisPath = try await prepareAsteroidsIfNeeded(asteroidIDs)
            let request = HarmonicRequest(
                mode: "harmonic",
                birth: makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude),
                harmonicOrder: modernHarmonicOrder,
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                nodeMode: modernNodeMode,
                aspects: selectedAspectRequests(orb: globalOrb),
                ephemerisPath: effectiveEphemerisPath, noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris,
                pointSet: modernDefaultPointSet(asteroidIDs: asteroidIDs)
            )
            let result = try await BackendClient.harmonic(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.harmonic(result))
        }
    }

    @MainActor
    func runModernReturn() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
        let returnLocation: ModernReturnLocation?
        if modernReturnLocationSource == "custom" {
            guard let latitude = parseDouble(modernReturnLocationLatitude),
                  let longitude = parseDouble(modernReturnLocationLongitude) else {
                calcVM.errorMessage = "自定义返照地点的经纬度需要是数字。"
                return
            }
            let name = modernReturnLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
            let timezone = modernReturnLocationTimezone.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !timezone.isEmpty else {
                calcVM.errorMessage = "自定义返照地点必须填写名称和时区。"
                return
            }
            returnLocation = ModernReturnLocation(name: name, latitude: latitude, longitude: longitude, timezone: timezone)
        } else {
            returnLocation = nil
        }
        await performRun {
            let asteroidIDs = parseAsteroids(customAsteroids)
            let effectiveEphemerisPath = try await prepareAsteroidsIfNeeded(asteroidIDs)
            let request = ModernReturnRequest(
                returnBodyID: modernReturnBodyID,
                birth: makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude),
                reference: makeMoment(from: classicalReferenceDate),
                locationSource: modernReturnLocationSource,
                location: returnLocation,
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                nodeMode: modernNodeMode,
                pointSet: modernDefaultPointSet(asteroidIDs: asteroidIDs),
                aspects: selectedAspectRequests(orb: globalOrb),
                precessionCorrection: "none",
                ephemerisPath: effectiveEphemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.modernReturn(request: request, pythonPath: appState.pythonPath)
            calcVM.setModernResultData(.returnChart(result))
        }
    }

    @MainActor
    func runMidpoint() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
        guard midpointSelectedPointIDs.count >= 2 else {
            calcVM.errorMessage = "中点计算至少需要两个有效本命点。"
            return
        }
        let focusPointIDs = midpointEffectiveFocusPointIDs
        guard !focusPointIDs.isEmpty else {
            calcVM.errorMessage = "请至少选择一个属于当前中点点集的 focus point。"
            return
        }
        let activationSourceOrder = ["natal", "transit", "secondary_progression", "solar_arc"]
        let activationSources = activationSourceOrder.filter { midpointActivationSources.contains($0) }

        await performRun {
            let asteroidIDs = parseAsteroids(customAsteroids)
            let effectiveEphemerisPath = try await prepareAsteroidsIfNeeded(asteroidIDs)
            let request = MidpointRequest(
                birth: makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude),
                reference: midpointIncludeReference ? makeMoment(from: classicalReferenceDate) : nil,
                pointSet: midpointPointSet(asteroidIDs: asteroidIDs),
                focusPointIDs: focusPointIDs,
                activationSources: activationSources,
                activationOrb: midpointActivationOrb,
                modulus: 360,
                includeOppositeAxis: true,
                ephemerisPath: effectiveEphemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.midpoint(
                request: request,
                pythonPath: appState.pythonPath
            )
            calcVM.setModernResultData(.midpoint(result))
        }
    }

    @MainActor
    func runCalculation() async {
        await performRun {
            let asteroidIDs = parseAsteroids(customAsteroids)
            let effectiveEphemerisPath = try await prepareAsteroidsIfNeeded(asteroidIDs)
            let request = TransitRequest(
                mode: "moment",
                natal: makeMoment(from: natalDate),
                transit: makeMoment(from: transitDate),
                birth: makeBirthSettingsIfValid(),
                natalBodies: sortedBodyIDs(selectedNatalBodies),
                transitBodies: sortedBodyIDs(selectedTransitBodies),
                customAsteroids: asteroidIDs,
                aspects: selectedAspectRequests(orb: globalOrb),
                ephemerisPath: effectiveEphemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris,
                sameChart: false
            )
            calcVM.momentResult = try await BackendClient.calculate(request: request, pythonPath: appState.pythonPath)
        }
    }

    @MainActor
    func runScan(confirmedHeavyScan: Bool = false) async {
        guard scanEndDate > scanStartDate else {
            calcVM.errorMessage = "结束时间必须晚于开始时间。"
            return
        }
        calcVM.errorMessage = nil
        calcVM.warningMessage = nil

        let transitBodies = scanTransitBodyIDs()
        let targetText = resolvedScanTargetText()
        let asteroidIDs = parseAsteroids(customAsteroids)
        let aspects = selectedAspectRequests(orb: 0)
        guard !transitBodies.isEmpty || !asteroidIDs.isEmpty else {
            calcVM.errorMessage = selectedScanKind == "station"
                ? "留逆扫描至少需要选择一个可能发生留逆的行星（不含太阳、月亮）。"
                : "当前月亮筛选与天体选择下没有可扫描天体。"
            return
        }
        if selectedScanKind == "aspect" && (aspects.isEmpty || targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            calcVM.errorMessage = "相位扫描需要至少一个相位和一个有效目标点。"
            return
        }
        let estimate = scanWorkEstimate(
            transitBodies: transitBodies,
            targetText: targetText,
            asteroidIDs: asteroidIDs,
            aspects: aspects
        )
        if estimate.isBlocked {
            calcVM.errorMessage = estimate.blockedText
            return
        }
        if estimate.requiresConfirmation && !confirmedHeavyScan {
            pendingHeavyWorkConfirmation = .scan(estimate)
            return
        }

        await performRun(
            progressWork: estimate.workUnits,
            progressLabel: "扫描窗口",
            preRunWarning: estimate.warningText
        ) {
            let label = scanWindowLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let effectiveEphemerisPath = try await prepareAsteroidsIfNeeded(asteroidIDs)
            let request = ScanRequest(
                mode: "scan",
                scanKind: selectedScanKind,
                label: label.isEmpty ? "Transit window" : label,
                start: makeMoment(from: scanStartDate),
                end: makeMoment(from: scanEndDate),
                transitBodies: transitBodies,
                customAsteroids: asteroidIDs,
                aspects: aspects,
                targetText: targetText,
                ephemerisPath: effectiveEphemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris,
                moonFilter: scanMoonFilter,
                confirmedHeavyScan: confirmedHeavyScan,
                zodiac: practiceMode == .vedic ? "sidereal_\(vedicAyanamsha)" : selectedZodiac
            )
            calcVM.scanResult = try await BackendClient.scan(request: request, pythonPath: appState.pythonPath)
        }
    }

    @MainActor
    func runModernTiming(confirmedHeavyScan: Bool = false) async {
        guard scanEndDate > scanStartDate else {
            calcVM.errorMessage = "结束时间必须晚于开始时间。"
            return
        }
        let targetChart = modernTimingTargetChart
        let birthSettings: BirthSettings
        if let targetChart {
            let personA = targetChart.personA
            birthSettings = makeBirthSettings(
                from: personA,
                houseSystem: targetChart.houseSystem,
                zodiac: targetChart.zodiac
            )
        } else {
            guard let natalCoords = requireCoordinates(birthLatitude, birthLongitude) else { return }
            birthSettings = makeBirthSettings(latitude: natalCoords.latitude, longitude: natalCoords.longitude)
        }
        let displayTimezone = timingDisplayTimezone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayTimezone.isEmpty, TimeZone(identifier: displayTimezone) != nil else {
            calcVM.errorMessage = "综合时间线展示时区必须是有效 IANA 时区，例如 Asia/Shanghai。"
            return
        }

        // Nested relationship target data is authoritative. In particular,
        // do not let the ordinary Timing sidebar's custom-asteroid toggle
        // erase asteroids selected in the just-computed relationship snapshot.
        let asteroidIDs = targetChart?.pointSet.customAsteroids
            ?? (timingUseCustomAsteroids ? parseAsteroids(customAsteroids) : [])
        let targetPointSet = timingEffectiveTargetPointSet(asteroidIDs: asteroidIDs)
        let techniques = timingTechniqueRequests()
        guard !techniques.isEmpty else {
            calcVM.errorMessage = "请至少启用一种综合时间线技法。"
            return
        }
        for technique in techniques {
            guard !technique.movingBodyIDs.isEmpty else {
                calcVM.errorMessage = "\(technique.id) 至少需要一个移动点。"
                return
            }
            guard !technique.eventTypes.isEmpty else {
                calcVM.errorMessage = "\(technique.id) 至少需要一种事件类型。"
                return
            }
            if technique.eventTypes.contains("aspect") && technique.aspects.isEmpty {
                calcVM.errorMessage = "\(technique.id) 启用相位事件时必须选择至少一个相位。"
                return
            }
            if technique.id == "secondary_progression" {
                if technique.eventTypes.contains("moon_ingress") && !technique.movingBodyIDs.contains("MOON") {
                    calcVM.errorMessage = "推进月亮入座要求移动点包含月亮。"
                    return
                }
                if technique.eventTypes.contains("lunation")
                    && !(technique.movingBodyIDs.contains("SUN") && technique.movingBodyIDs.contains("MOON")) {
                    calcVM.errorMessage = "推进月相要求移动点同时包含太阳和月亮。"
                    return
                }
            }
        }

        let estimate = timingWorkEstimate(techniques: techniques, targetPointSet: targetPointSet)
        guard estimate.targetCount > 0 else {
            calcVM.errorMessage = "综合时间线至少需要一个本命目标点。"
            return
        }
        if estimate.isBlocked {
            calcVM.errorMessage = estimate.blockedText
            return
        }
        if estimate.requiresConfirmation && !confirmedHeavyScan {
            pendingHeavyWorkConfirmation = .modernTiming(estimate)
            return
        }

        let generation = calcVM.runGeneration
        await performRun(
            progressLabel: "综合时间线",
            preRunWarning: estimate.warningText,
            liveProgress: true
        ) {
            let effectiveEphemerisPath = try await prepareAsteroidsIfNeeded(asteroidIDs)
            let request = ModernTimingRequest(
                birth: birthSettings,
                start: makeMoment(from: scanStartDate),
                end: makeMoment(from: scanEndDate),
                displayTimezone: displayTimezone,
                targetPointSet: targetChart == nil ? targetPointSet : nil,
                targetChart: targetChart,
                techniques: techniques,
                confirmedHeavyScan: confirmedHeavyScan,
                ephemerisPath: effectiveEphemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.modernTiming(
                request: request,
                pythonPath: appState.pythonPath
            ) { update in
                Task { @MainActor in
                    guard calcVM.isCurrentRun(generation), !Task.isCancelled else { return }
                    calcVM.calculationProgress = update.progress
                    let label = update.label.map { " · \($0)" } ?? ""
                    calcVM.calculationProgressText = "综合时间线 \(Int(update.progress * 100))%\(label)"
                }
            }
            guard calcVM.isCurrentRun(generation), !Task.isCancelled else { return }
            calcVM.commitModernTimingResult(result, generation: generation)
        }
    }

    // MARK: - Classical

    private func makeClassicalRequest(latitude: Double, longitude: Double) -> ClassicalRequest {
        ClassicalRequest(
            mode: "classical",
            birth: makeBirthSettings(latitude: latitude, longitude: longitude),
            reference: makeMoment(from: classicalReferenceDate),
            aspectOrb: classicalAspectOrb,
            returnMode: nil,
            ephemerisPath: normalizedEphemerisPath,
            noAsteroids: appState.noAsteroids,
            requireEphemeris: appState.requireEphemeris
        )
    }

    @MainActor
    func runClassical() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
        await performRun(progressWork: 10, progressLabel: "古典计算") {
            let request = makeClassicalRequest(latitude: coords.latitude, longitude: coords.longitude)
            let result = try await BackendClient.classical(request: request, pythonPath: appState.pythonPath)
            calcVM.classicalResult = result
            syncScanTargetsFromNatalChart()
        }
    }

    @MainActor
    func runClassicalTiming() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
        aiVM.clear(modeKey: "classical")
        await performRun(progressWork: 4, progressLabel: "更新技法") {
            let request = makeClassicalRequest(latitude: coords.latitude, longitude: coords.longitude)
            let result = try await BackendClient.classical(request: request, pythonPath: appState.pythonPath)
            calcVM.classicalResult = result
        }
    }

    @MainActor
    func runHorary() async {
        guard let coords = requireCoordinates(horaryLatitude, horaryLongitude, errorText: "Horary 经纬度需要是数字。") else { return }
        let question = horaryQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else {
            calcVM.errorMessage = "请输入 Horary 问题文本。"
            return
        }

        await performRun {
            let request = HoraryRequest(
                mode: "horary",
                chart: HoraryChartSettings(
                    moment: makeMoment(from: horaryDate, gmtOffset: horaryGmtOffset),
                    latitude: coords.latitude,
                    longitude: coords.longitude,
                    houseSystem: horaryHouseSystem,
                    zodiac: selectedZodiac,
                    boundsSystem: selectedBoundsSystem,
                    triplicitySystem: selectedTriplicitySystem
                ),
                placeName: horaryPlaceName.trimmingCharacters(in: .whitespacesAndNewlines),
                questionText: question,
                aspectOrb: horaryAspectOrb,
                packetVersion: "2",
                ephemerisPath: normalizedEphemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            calcVM.horaryResult = try await BackendClient.horary(request: request, pythonPath: appState.pythonPath)
        }
    }

    // MARK: - Rectify

    /// Birth date and time strings in the rectify backend's expected formats.
    private func rectifyBirthStrings() -> (date: String, time: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = selectedTimeZone

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = selectedTimeZone

        return (dateFormatter.string(from: natalDate), timeFormatter.string(from: natalDate))
    }

    private func makeRectifyLevelRequest(
        offsetSeconds: Int,
        windowSeconds: Int,
        stepSeconds: Int,
        latitude: Double,
        longitude: Double
    ) -> RectifyLevel2Request {
        let birth = rectifyBirthStrings()
        return RectifyLevel2Request(
            birthDate: birth.date,
            centerTime: birth.time,
            timezone: timezoneLabel,
            latitude: latitude,
            longitude: longitude,
            houseSystem: selectedHouseSystem,
            zodiac: selectedZodiac,
            boundsSystem: selectedBoundsSystem,
            triplicitySystem: selectedTriplicitySystem,
            maxAge: 90,
            centerOffsetSeconds: offsetSeconds,
            windowSeconds: windowSeconds,
            stepSeconds: stepSeconds
        )
    }

    @MainActor
    func runRectify() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }

        await performRun(progressWork: 61, progressLabel: "生时矫正") {
            let birth = rectifyBirthStrings()
            let request = RectifyRequest(
                birthDate: birth.date,
                centerTime: birth.time,
                timezone: timezoneLabel,
                latitude: coords.latitude,
                longitude: coords.longitude,
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                boundsSystem: selectedBoundsSystem,
                triplicitySystem: selectedTriplicitySystem,
                maxAge: 90,
                windowMinutes: 30,
                stepMinutes: 1
            )

            // Invalidate any in-flight child requests BEFORE sending new level‑1 request
            calcVM.rectifyLevel2Task?.cancel()
            calcVM.rectifyLevel3Task?.cancel()
            calcVM.rectifyLevel2Gen += 1
            calcVM.rectifyLevel3Gen += 1
            calcVM.rectifyResponse = try await RectifyClient.fetch(
                request: request,
                pythonPath: appState.pythonPath,
                progressCallback: { [self] p in
                    Task { @MainActor in
                        calcVM.calculationProgress = p
                        calcVM.calculationProgressText = "生时矫正 \(Int(p * 100))%"
                    }
                }
            )
            calcVM.rectifyActiveLevel = 1
            calcVM.rectifyS1Index = calcVM.rectifyResponse?.centerOffsetIndex ?? 0
            calcVM.rectifyS2Index = 0
            calcVM.rectifyLevel2Response = nil
            calcVM.rectifyLevel3Response = nil
        }
    }

    @MainActor
    func runRectifyLevel2(offsetSeconds: Int) async {
        guard let lat = parseDouble(birthLatitude), let lng = parseDouble(birthLongitude) else { return }

        let gen = calcVM.rectifyLevel2Gen  // already incremented by the closure

        do {
            let request = makeRectifyLevelRequest(
                offsetSeconds: offsetSeconds, windowSeconds: 30, stepSeconds: 5,
                latitude: lat, longitude: lng
            )
            let response = try await RectifyClient.fetch(request: request, pythonPath: appState.pythonPath)
            guard gen == calcVM.rectifyLevel2Gen else { return } // stale response
            calcVM.rectifyLevel2Response = response
            calcVM.rectifyActiveLevel = 2
            calcVM.rectifyS2Index = response.centerOffsetIndex
        } catch is CancellationError {
            return
        } catch {
            guard gen == calcVM.rectifyLevel2Gen else { return }
            calcVM.errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func runRectifyLevel3(offsetSeconds: Int) async {
        guard let lat = parseDouble(birthLatitude), let lng = parseDouble(birthLongitude) else { return }

        let gen = calcVM.rectifyLevel3Gen  // already incremented by the closure

        do {
            let request = makeRectifyLevelRequest(
                offsetSeconds: offsetSeconds, windowSeconds: 5, stepSeconds: 1,
                latitude: lat, longitude: lng
            )
            let response = try await RectifyClient.fetch(request: request, pythonPath: appState.pythonPath)
            guard gen == calcVM.rectifyLevel3Gen else { return } // stale response
            calcVM.rectifyLevel3Response = response
            calcVM.rectifyActiveLevel = 3
            calcVM.rectifyLevel3ResponseID += 1
        } catch is CancellationError {
            return
        } catch {
            guard gen == calcVM.rectifyLevel3Gen else { return }
            calcVM.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Vedic Calculation

    @MainActor
    func runVedic() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
        await performRun {
            let request = VedicRequest(
                mode: "vedic",
                birth: makeBirthSettings(
                    latitude: coords.latitude,
                    longitude: coords.longitude,
                    zodiac: "sidereal_\(vedicAyanamsha)"
                ),
                reference: makeMoment(from: classicalReferenceDate),
                full: vedicFullMode,
                ephemerisPath: normalizedEphemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.vedic(request: request, pythonPath: appState.pythonPath)
            calcVM.vedicResult = result
        }
    }
}
