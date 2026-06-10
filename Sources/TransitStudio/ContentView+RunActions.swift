import SwiftUI

extension ContentView {
    @MainActor
    func runCurrentMode() async {
        switch mode {
        case .settings:
            if practiceMode == .classical {
                await runClassical()
            } else if practiceMode == .vedic {
                await runVedic()
            } else {
                switch modernSubMode {
                case .natal: await runModernNatal()
                case .synastry: await runSynastry()
                case .composite: await runComposite()
                case .davison: await runDavison()
                case .progression: await runProgressions()
                case .solarArc: await runSolarArc()
                case .harmonic: await runHarmonic()
                }
            }
        case .horary:
            await runHorary()
        case .moment:
            await runCalculation()
        case .scan:
            await runScan()
        case .rectify:
            await runRectify()
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
        _ operation: () async throws -> Void
    ) async {
        calcVM.isRunning = true
        calcVM.errorMessage = nil
        calcVM.asteroidPreparationMessage = ""
        if let progressWork {
            startEstimatedProgress(totalWork: progressWork, label: progressLabel)
        }
        defer {
            calcVM.isRunning = false
            if progressWork != nil {
                finishProgress()
            }
        }
        do {
            try await operation()
        } catch {
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

    func makePersonPair(
        latitudeA: Double, longitudeA: Double,
        latitudeB: Double, longitudeB: Double
    ) -> (personA: PersonSettings, personB: PersonSettings) {
        (
            PersonSettings(name: "Person A", moment: makeMoment(from: natalDate), latitude: latitudeA, longitude: longitudeA),
            PersonSettings(name: "Person B", moment: makeMoment(from: modernPersonBDate), latitude: latitudeB, longitude: longitudeB)
        )
    }

    // MARK: - Modern Run Actions

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
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.calculate(request: request, pythonPath: appState.pythonPath)
            calcVM.fullNatalResult = result
            calcVM.momentResult = filteredModernNatalResult(from: result, asteroidIDs: asteroidIDs)
            syncScanTargetsFromNatalChart()
        }
    }

    @MainActor
    func runSynastry() async {
        guard let a = requireCoordinates(birthLatitude, birthLongitude),
              let b = requireCoordinates(modernPersonBLatitude, modernPersonBLongitude) else { return }
        await performRun {
            let pair = makePersonPair(latitudeA: a.latitude, longitudeA: a.longitude, latitudeB: b.latitude, longitudeB: b.longitude)
            let request = SynastryRequest(
                mode: "synastry",
                personA: pair.personA,
                personB: pair.personB,
                houseSystem: selectedHouseSystem, zodiac: selectedZodiac, nodeMode: modernNodeMode,
                aspects: selectedAspectRequests(orb: globalOrb), ephemerisPath: normalizedEphemerisPath,
                noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.synastry(request: request, pythonPath: appState.pythonPath)
            calcVM.modernResultData = .synastry(result)
        }
    }

    @MainActor
    func runComposite() async {
        guard let a = requireCoordinates(birthLatitude, birthLongitude),
              let b = requireCoordinates(modernPersonBLatitude, modernPersonBLongitude) else { return }
        await performRun {
            let pair = makePersonPair(latitudeA: a.latitude, longitudeA: a.longitude, latitudeB: b.latitude, longitudeB: b.longitude)
            let request = CompositeRequest(
                mode: "composite",
                personA: pair.personA,
                personB: pair.personB,
                houseSystem: selectedHouseSystem, zodiac: selectedZodiac, nodeMode: modernNodeMode,
                aspects: selectedAspectRequests(orb: globalOrb), ephemerisPath: normalizedEphemerisPath,
                noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.composite(request: request, pythonPath: appState.pythonPath)
            calcVM.modernResultData = .composite(result)
        }
    }

    @MainActor
    func runDavison() async {
        guard let a = requireCoordinates(birthLatitude, birthLongitude),
              let b = requireCoordinates(modernPersonBLatitude, modernPersonBLongitude) else { return }
        await performRun {
            let pair = makePersonPair(latitudeA: a.latitude, longitudeA: a.longitude, latitudeB: b.latitude, longitudeB: b.longitude)
            let request = DavisonRequest(
                mode: "davison",
                personA: pair.personA,
                personB: pair.personB,
                houseSystem: selectedHouseSystem, zodiac: selectedZodiac, nodeMode: modernNodeMode,
                aspects: selectedAspectRequests(orb: globalOrb), ephemerisPath: normalizedEphemerisPath,
                noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.davison(request: request, pythonPath: appState.pythonPath)
            calcVM.modernResultData = .davison(result)
        }
    }

    @MainActor
    func runProgressions() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
        await performRun {
            let request = ProgressionRequest(
                mode: "progression",
                birth: makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude),
                reference: makeMoment(from: classicalReferenceDate),
                nodeMode: modernNodeMode, aspects: selectedAspectRequests(orb: globalOrb),
                ephemerisPath: normalizedEphemerisPath, noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.progression(request: request, pythonPath: appState.pythonPath)
            calcVM.modernResultData = .progression(result)
        }
    }

    @MainActor
    func runSolarArc() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
        await performRun {
            let request = SolarArcRequest(
                mode: "solar_arc",
                birth: makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude),
                reference: makeMoment(from: classicalReferenceDate),
                nodeMode: modernNodeMode, aspects: selectedAspectRequests(orb: globalOrb),
                patternsEnabled: false,
                ephemerisPath: normalizedEphemerisPath, noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.solarArc(request: request, pythonPath: appState.pythonPath)
            calcVM.modernResultData = .solarArc(result)
        }
    }

    @MainActor
    func runHarmonic() async {
        guard let coords = requireCoordinates(birthLatitude, birthLongitude) else { return }
        await performRun {
            let request = HarmonicRequest(
                mode: "harmonic",
                birth: makeBirthSettings(latitude: coords.latitude, longitude: coords.longitude),
                harmonicOrder: modernHarmonicOrder, nodeMode: modernNodeMode,
                aspects: selectedAspectRequests(orb: globalOrb),
                ephemerisPath: normalizedEphemerisPath, noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.harmonic(request: request, pythonPath: appState.pythonPath)
            calcVM.modernResultData = .harmonic(result)
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
                requireEphemeris: appState.requireEphemeris
            )
            calcVM.momentResult = try await BackendClient.calculate(request: request, pythonPath: appState.pythonPath)
        }
    }

    @MainActor
    func runScan() async {
        guard scanEndDate > scanStartDate else {
            calcVM.errorMessage = "结束时间必须晚于开始时间。"
            return
        }

        await performRun(progressWork: estimatedScanWork(), progressLabel: "扫描窗口") {
            let label = scanWindowLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let transitBodies = scanTransitBodyIDs()
            let targetText = resolvedScanTargetText()
            let asteroidIDs = parseAsteroids(customAsteroids)
            let effectiveEphemerisPath = try await prepareAsteroidsIfNeeded(asteroidIDs)
            let request = ScanRequest(
                mode: "scan",
                scanKind: selectedScanKind,
                label: label.isEmpty ? "Transit window" : label,
                start: makeMoment(from: scanStartDate),
                end: makeMoment(from: scanEndDate),
                transitBodies: transitBodies,
                customAsteroids: asteroidIDs,
                aspects: selectedAspectRequests(orb: 0),
                targetText: targetText,
                ephemerisPath: effectiveEphemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris,
                moonFilter: scanMoonFilter
            )
            calcVM.scanResult = try await BackendClient.scan(request: request, pythonPath: appState.pythonPath)
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
                    moment: makeMoment(from: horaryDate),
                    latitude: coords.latitude,
                    longitude: coords.longitude,
                    houseSystem: selectedHouseSystem,
                    zodiac: selectedZodiac,
                    boundsSystem: selectedBoundsSystem,
                    triplicitySystem: selectedTriplicitySystem
                ),
                placeName: horaryPlaceName.trimmingCharacters(in: .whitespacesAndNewlines),
                questionText: question,
                aspectOrb: classicalAspectOrb,
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
        } catch {
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
        } catch {
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
