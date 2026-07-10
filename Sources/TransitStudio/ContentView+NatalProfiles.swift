import SwiftUI

extension ContentView {
var natalProfiles: [NatalProfile] {
        guard let data = appState.natalProfilesJSON.data(using: .utf8),
              let profiles = try? JSONDecoder().decode([NatalProfile].self, from: data)
        else {
            return []
        }
        return profiles
    }

    func saveNatalProfiles(_ profiles: [NatalProfile]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(profiles),
              let text = String(data: data, encoding: .utf8)
        else {
            return
        }
        appState.natalProfilesJSON = text
    }

    func saveNatalProfile() {
        let name = natalProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            calcVM.errorMessage = "资料名称不能为空。"
            return
        }

        let profile = NatalProfile(
            id: UUID(uuidString: selectedNatalProfileID) ?? UUID(),
            name: name,
            moment: makeMoment(from: natalDate),
            latitude: birthLatitude,
            longitude: birthLongitude,
            gmtOffset: gmtOffset,
            chartStyle: practiceMode.rawValue,
            houseSystem: selectedHouseSystem,
            zodiac: selectedZodiac,
            boundsSystem: selectedBoundsSystem,
            triplicitySystem: selectedTriplicitySystem
        )

        var profiles = natalProfiles
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        saveNatalProfiles(profiles.sorted { $0.name.localizedCompare($1.name) == .orderedAscending })
        selectedNatalProfileID = profile.id.uuidString
        calcVM.errorMessage = nil
    }

    func loadSelectedNatalProfile() {
        guard let profile = natalProfiles.first(where: { $0.id.uuidString == selectedNatalProfileID }) else {
            return
        }

        natalProfileName = profile.name
        gmtOffset = profile.gmtOffset
        birthLatitude = profile.latitude
        birthLongitude = profile.longitude
        // Loading a saved birth profile should not kick the user out of the
        // current classical/modern workspace.
        selectedHouseSystem = profile.houseSystem
        selectedZodiac = profile.zodiac
        selectedBoundsSystem = profile.boundsSystem
        selectedTriplicitySystem = profile.triplicitySystem
        natalDate = date(from: profile.moment, gmtOffset: profile.gmtOffset)
    }

    func deleteSelectedNatalProfile() {
        let profiles = natalProfiles.filter { $0.id.uuidString != selectedNatalProfileID }
        saveNatalProfiles(profiles)
        selectedNatalProfileID = profiles.first?.id.uuidString ?? ""
        if let first = profiles.first {
            natalProfileName = first.name
        }
    }

    func date(from moment: ChartMoment, gmtOffset: Double) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone(for: gmtOffset)
        return calendar.date(from: DateComponents(
            year: moment.year,
            month: moment.month,
            day: moment.day,
            hour: moment.hour,
            minute: moment.minute
    )) ?? Date()
}
}
