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

    @MainActor
    func runModernNatal() async {
        calcVM.isRunning = true
        calcVM.errorMessage = nil
        calcVM.asteroidPreparationMessage = ""
        defer { calcVM.isRunning = false }

        do {
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
        } catch {
            calcVM.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Modern Sub-Mode Run Actions

    @MainActor
    func runSynastry() async {
        guard let latA = parseDouble(birthLatitude), let lonA = parseDouble(birthLongitude),
              let latB = parseDouble(modernPersonBLatitude), let lonB = parseDouble(modernPersonBLongitude) else {
            calcVM.errorMessage = "经纬度需要是数字。"; return
        }
        calcVM.isRunning = true; calcVM.errorMessage = nil; defer { calcVM.isRunning = false }
        do {
            let request = SynastryRequest(
                mode: "synastry",
                personA: PersonSettings(name: "Person A", moment: makeMoment(from: natalDate), latitude: latA, longitude: lonA),
                personB: PersonSettings(name: "Person B", moment: makeMoment(from: modernPersonBDate), latitude: latB, longitude: lonB),
                houseSystem: selectedHouseSystem, zodiac: selectedZodiac, nodeMode: modernNodeMode,
                aspects: selectedAspectRequests(orb: globalOrb), ephemerisPath: normalizedEphemerisPath,
                noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.synastry(request: request, pythonPath: appState.pythonPath)
            calcVM.modernResultData = .synastry(result)
        } catch { calcVM.errorMessage = error.localizedDescription }
    }

    @MainActor
    func runComposite() async {
        guard let latA = parseDouble(birthLatitude), let lonA = parseDouble(birthLongitude),
              let latB = parseDouble(modernPersonBLatitude), let lonB = parseDouble(modernPersonBLongitude) else {
            calcVM.errorMessage = "经纬度需要是数字。"; return
        }
        calcVM.isRunning = true; calcVM.errorMessage = nil; defer { calcVM.isRunning = false }
        do {
            let request = CompositeRequest(
                mode: "composite",
                personA: PersonSettings(name: "Person A", moment: makeMoment(from: natalDate), latitude: latA, longitude: lonA),
                personB: PersonSettings(name: "Person B", moment: makeMoment(from: modernPersonBDate), latitude: latB, longitude: lonB),
                houseSystem: selectedHouseSystem, zodiac: selectedZodiac, nodeMode: modernNodeMode,
                aspects: selectedAspectRequests(orb: globalOrb), ephemerisPath: normalizedEphemerisPath,
                noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.composite(request: request, pythonPath: appState.pythonPath)
            calcVM.modernResultData = .composite(result)
        } catch { calcVM.errorMessage = error.localizedDescription }
    }

    @MainActor
    func runDavison() async {
        guard let latA = parseDouble(birthLatitude), let lonA = parseDouble(birthLongitude),
              let latB = parseDouble(modernPersonBLatitude), let lonB = parseDouble(modernPersonBLongitude) else {
            calcVM.errorMessage = "经纬度需要是数字。"; return
        }
        calcVM.isRunning = true; calcVM.errorMessage = nil; defer { calcVM.isRunning = false }
        do {
            let request = DavisonRequest(
                mode: "davison",
                personA: PersonSettings(name: "Person A", moment: makeMoment(from: natalDate), latitude: latA, longitude: lonA),
                personB: PersonSettings(name: "Person B", moment: makeMoment(from: modernPersonBDate), latitude: latB, longitude: lonB),
                houseSystem: selectedHouseSystem, zodiac: selectedZodiac, nodeMode: modernNodeMode,
                aspects: selectedAspectRequests(orb: globalOrb), ephemerisPath: normalizedEphemerisPath,
                noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.davison(request: request, pythonPath: appState.pythonPath)
            calcVM.modernResultData = .davison(result)
        } catch { calcVM.errorMessage = error.localizedDescription }
    }

    @MainActor
    func runProgressions() async {
        guard let lat = parseDouble(birthLatitude), let lon = parseDouble(birthLongitude) else {
            calcVM.errorMessage = "经纬度需要是数字。"; return
        }
        calcVM.isRunning = true; calcVM.errorMessage = nil; defer { calcVM.isRunning = false }
        do {
            let birth = BirthSettings(
                moment: makeMoment(from: natalDate), latitude: lat, longitude: lon,
                houseSystem: selectedHouseSystem, zodiac: selectedZodiac,
                boundsSystem: selectedBoundsSystem, triplicitySystem: selectedTriplicitySystem
            )
            let request = ProgressionRequest(
                mode: "progression", birth: birth, reference: makeMoment(from: classicalReferenceDate),
                nodeMode: modernNodeMode, aspects: selectedAspectRequests(orb: globalOrb),
                ephemerisPath: normalizedEphemerisPath, noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.progression(request: request, pythonPath: appState.pythonPath)
            calcVM.modernResultData = .progression(result)
        } catch { calcVM.errorMessage = error.localizedDescription }
    }

    @MainActor
    func runSolarArc() async {
        guard let lat = parseDouble(birthLatitude), let lon = parseDouble(birthLongitude) else {
            calcVM.errorMessage = "经纬度需要是数字。"; return
        }
        calcVM.isRunning = true; calcVM.errorMessage = nil; defer { calcVM.isRunning = false }
        do {
            let birth = BirthSettings(
                moment: makeMoment(from: natalDate), latitude: lat, longitude: lon,
                houseSystem: selectedHouseSystem, zodiac: selectedZodiac,
                boundsSystem: selectedBoundsSystem, triplicitySystem: selectedTriplicitySystem
            )
            let request = SolarArcRequest(
                mode: "solar_arc", birth: birth, reference: makeMoment(from: classicalReferenceDate),
                nodeMode: modernNodeMode, aspects: selectedAspectRequests(orb: globalOrb),
                patternsEnabled: false,
                ephemerisPath: normalizedEphemerisPath, noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.solarArc(request: request, pythonPath: appState.pythonPath)
            calcVM.modernResultData = .solarArc(result)
        } catch { calcVM.errorMessage = error.localizedDescription }
    }

    @MainActor
    func runHarmonic() async {
        guard let lat = parseDouble(birthLatitude), let lon = parseDouble(birthLongitude) else {
            calcVM.errorMessage = "经纬度需要是数字。"; return
        }
        calcVM.isRunning = true; calcVM.errorMessage = nil; defer { calcVM.isRunning = false }
        do {
            let birth = BirthSettings(
                moment: makeMoment(from: natalDate), latitude: lat, longitude: lon,
                houseSystem: selectedHouseSystem, zodiac: selectedZodiac,
                boundsSystem: selectedBoundsSystem, triplicitySystem: selectedTriplicitySystem
            )
            let request = HarmonicRequest(
                mode: "harmonic", birth: birth,
                harmonicOrder: modernHarmonicOrder, nodeMode: modernNodeMode,
                aspects: selectedAspectRequests(orb: globalOrb),
                ephemerisPath: normalizedEphemerisPath, noAsteroids: appState.noAsteroids, requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.harmonic(request: request, pythonPath: appState.pythonPath)
            calcVM.modernResultData = .harmonic(result)
        } catch { calcVM.errorMessage = error.localizedDescription }
    }

    @MainActor
    func runCalculation() async {
        calcVM.isRunning = true
        calcVM.errorMessage = nil
        calcVM.asteroidPreparationMessage = ""
        defer { calcVM.isRunning = false }

        do {
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
        } catch {
            calcVM.errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func runScan() async {
        guard scanEndDate > scanStartDate else {
            calcVM.errorMessage = "结束时间必须晚于开始时间。"
            return
        }

        calcVM.isRunning = true
        calcVM.errorMessage = nil
        calcVM.asteroidPreparationMessage = ""
        startEstimatedProgress(totalWork: estimatedScanWork(), label: "扫描窗口")
        defer {
            calcVM.isRunning = false
            finishProgress()
        }

        do {
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
        } catch {
            calcVM.errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func runClassical() async {
        guard let latitude = parseDouble(birthLatitude), let longitude = parseDouble(birthLongitude) else {
            calcVM.errorMessage = "经纬度需要是数字。"
            return
        }

        calcVM.isRunning = true
        calcVM.errorMessage = nil
        calcVM.asteroidPreparationMessage = ""
        startEstimatedProgress(totalWork: 10, label: "古典计算")
        defer {
            calcVM.isRunning = false
            finishProgress()
        }

        do {
            let birth = BirthSettings(
                moment: makeMoment(from: natalDate),
                latitude: latitude,
                longitude: longitude,
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                boundsSystem: selectedBoundsSystem,
                triplicitySystem: selectedTriplicitySystem
            )
            let request = ClassicalRequest(
                mode: "classical",
                birth: birth,
                reference: makeMoment(from: classicalReferenceDate),
                aspectOrb: classicalAspectOrb,
                returnMode: nil,
                ephemerisPath: normalizedEphemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.classical(request: request, pythonPath: appState.pythonPath)
            calcVM.classicalResult = result
            syncScanTargetsFromNatalChart()
        } catch {
            calcVM.errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func runClassicalTiming() async {
        guard let latitude = parseDouble(birthLatitude), let longitude = parseDouble(birthLongitude) else {
            calcVM.errorMessage = "经纬度需要是数字。"
            return
        }

        calcVM.isRunning = true
        calcVM.errorMessage = nil
        calcVM.asteroidPreparationMessage = ""
        startEstimatedProgress(totalWork: 4, label: "更新技法")
        defer {
            calcVM.isRunning = false
            finishProgress()
        }

        do {
            let birth = BirthSettings(
                moment: makeMoment(from: natalDate),
                latitude: latitude,
                longitude: longitude,
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                boundsSystem: selectedBoundsSystem,
                triplicitySystem: selectedTriplicitySystem
            )
            let request = ClassicalRequest(
                mode: "classical",
                birth: birth,
                reference: makeMoment(from: classicalReferenceDate),
                aspectOrb: classicalAspectOrb,
                returnMode: nil,
                ephemerisPath: normalizedEphemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.classical(request: request, pythonPath: appState.pythonPath)
            calcVM.classicalResult = result
        } catch {
            calcVM.errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func runHorary() async {
        guard let latitude = parseDouble(horaryLatitude), let longitude = parseDouble(horaryLongitude) else {
            calcVM.errorMessage = "Horary 经纬度需要是数字。"
            return
        }
        let question = horaryQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else {
            calcVM.errorMessage = "请输入 Horary 问题文本。"
            return
        }

        calcVM.isRunning = true
        calcVM.errorMessage = nil
        calcVM.asteroidPreparationMessage = ""
        defer { calcVM.isRunning = false }

        do {
            let request = HoraryRequest(
                mode: "horary",
                chart: HoraryChartSettings(
                    moment: makeMoment(from: horaryDate),
                    latitude: latitude,
                    longitude: longitude,
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
        } catch {
            calcVM.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Rectify

    @MainActor
    func runRectify() async {
        guard let lat = parseDouble(birthLatitude), let lng = parseDouble(birthLongitude) else {
            calcVM.errorMessage = "经纬度需要是数字。"
            return
        }

        calcVM.isRunning = true
        calcVM.errorMessage = nil
        startEstimatedProgress(totalWork: 61, label: "生时矫正")
        defer {
            calcVM.isRunning = false
            finishProgress()
        }

        do {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = selectedTimeZone
            let dateStr = f.string(from: natalDate)

            let t = DateFormatter()
            t.dateFormat = "HH:mm"
            t.timeZone = selectedTimeZone
            let timeStr = t.string(from: natalDate)

            let request = RectifyRequest(
                birthDate: dateStr,
                centerTime: timeStr,
                timezone: timezoneLabel,
                latitude: lat,
                longitude: lng,
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
        } catch {
            calcVM.errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func runRectifyLevel2(offsetSeconds: Int) async {
        guard let lat = parseDouble(birthLatitude), let lng = parseDouble(birthLongitude) else { return }

        let gen = calcVM.rectifyLevel2Gen  // already incremented by the closure

        do {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = selectedTimeZone
            let dateStr = f.string(from: natalDate)

            let t = DateFormatter()
            t.dateFormat = "HH:mm"
            t.timeZone = selectedTimeZone
            let timeStr = t.string(from: natalDate)

            let request = RectifyLevel2Request(
                birthDate: dateStr,
                centerTime: timeStr,
                timezone: timezoneLabel,
                latitude: lat,
                longitude: lng,
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                boundsSystem: selectedBoundsSystem,
                triplicitySystem: selectedTriplicitySystem,
                maxAge: 90,
                centerOffsetSeconds: offsetSeconds,
                windowSeconds: 30,
                stepSeconds: 5
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
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = selectedTimeZone
            let dateStr = f.string(from: natalDate)

            let t = DateFormatter()
            t.dateFormat = "HH:mm"
            t.timeZone = selectedTimeZone
            let timeStr = t.string(from: natalDate)

            let request = RectifyLevel2Request(
                birthDate: dateStr,
                centerTime: timeStr,
                timezone: timezoneLabel,
                latitude: lat,
                longitude: lng,
                houseSystem: selectedHouseSystem,
                zodiac: selectedZodiac,
                boundsSystem: selectedBoundsSystem,
                triplicitySystem: selectedTriplicitySystem,
                maxAge: 90,
                centerOffsetSeconds: offsetSeconds,
                windowSeconds: 5,
                stepSeconds: 1
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
        guard let latitude = parseDouble(birthLatitude), let longitude = parseDouble(birthLongitude) else {
            calcVM.errorMessage = "经纬度需要是数字。"
            return
        }

        calcVM.isRunning = true
        calcVM.errorMessage = nil
        defer { calcVM.isRunning = false }

        do {
            let birth = BirthSettings(
                moment: makeMoment(from: natalDate),
                latitude: latitude,
                longitude: longitude,
                houseSystem: selectedHouseSystem,
                zodiac: "sidereal_\(vedicAyanamsha)",
                boundsSystem: selectedBoundsSystem,
                triplicitySystem: selectedTriplicitySystem
            )
            let request = VedicRequest(
                mode: "vedic",
                birth: birth,
                reference: makeMoment(from: classicalReferenceDate),
                full: vedicFullMode,
                ephemerisPath: normalizedEphemerisPath,
                noAsteroids: appState.noAsteroids,
                requireEphemeris: appState.requireEphemeris
            )
            let result = try await BackendClient.vedic(request: request, pythonPath: appState.pythonPath)
            calcVM.vedicResult = result
        } catch {
            calcVM.errorMessage = error.localizedDescription
        }
    }
}
