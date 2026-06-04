import Foundation

// MARK: - Vedic Result Models

struct VedicResult: Codable {
    let meta: VedicMeta
    let rasiChart: VedicRasiChart?
    let planets: [String: VedicPlanetPosition]?
    let navamsa: [String: VedicNavamsaPosition]?
    let vimshottari: VimsottariResult?
    let yoginiDasa: YoginiDasaResult?
    let ashtottariDasa: AshtottariDasaResult?
    let shadbala: [String: ShadbalaRow]?
    let yogas: [VedicYoga]?
    let warnings: [String]?

    // NEW sections
    let panchanga: VedicPanchanga?
    let solarDay: VedicSolarDay?
    let divisionalCharts: [String: VedicDivisionalChart]?
    let moonChart: VedicDerivedChart?
    let bhavaChart: VedicDerivedChart?
    let planetRelationships: VedicRelationships?
    let arudha: [String: VedicArudhaPada]?
    let jaiminiKarakas: VedicJaiminiKarakas?
    let ashtakavarga: VedicAshtakavarga?
    let upagrahas: [VedicUpagraha]?
    let specialLagnas: [VedicSpecialLagna]?

    enum CodingKeys: String, CodingKey {
        case meta
        case rasiChart = "rasi_chart"
        case planets
        case navamsa
        case vimshottari
        case yoginiDasa = "yogini_dasa"
        case ashtottariDasa = "ashtottari_dasa"
        case shadbala
        case yogas
        case warnings
        case panchanga
        case solarDay = "solar_day"
        case divisionalCharts = "divisional_charts"
        case moonChart = "moon_chart"
        case bhavaChart = "bhava_chart"
        case planetRelationships = "planet_relationships"
        case arudha
        case jaiminiKarakas = "jaimini_karakas"
        case ashtakavarga
        case upagrahas
        case specialLagnas = "special_lagnas"
    }
}

// MARK: - Meta

struct VedicMeta: Codable {
    let birthUtc: String
    let birthLocal: String
    let referenceUtc: String?
    let referenceLocal: String?
    let latitude: Double
    let longitude: Double
    let houseSystem: String
    let ayanamsha: String
    let zodiac: String
    let ephemeris: String

    // NEW
    let timezoneLabel: String?
    let utcOffsetText: String?
    let siderealModeLabel: String?
    let ayanamshaValue: Double?
    let nodeMode: String?
    let planetPositionMode: String?
    let signIndexTable: [VedicSignIndexEntry]?

    enum CodingKeys: String, CodingKey {
        case birthUtc = "birth_utc"
        case birthLocal = "birth_local"
        case referenceUtc = "reference_utc"
        case referenceLocal = "reference_local"
        case latitude, longitude
        case houseSystem = "house_system"
        case ayanamsha, zodiac, ephemeris
        case timezoneLabel = "timezone_label"
        case utcOffsetText = "utc_offset_text"
        case siderealModeLabel = "sidereal_mode_label"
        case ayanamshaValue = "ayanamsha_value"
        case nodeMode = "node_mode"
        case planetPositionMode = "planet_position_mode"
        case signIndexTable = "sign_index_table"
    }
}

struct VedicSignIndexEntry: Codable, Identifiable {
    let index: Int
    let nameEn: String
    let nameZh: String

    var id: Int { index }

    enum CodingKeys: String, CodingKey {
        case index
        case nameEn = "name_en"
        case nameZh = "name_zh"
    }
}

// MARK: - Rasi Chart

struct VedicRasiChart: Codable {
    let houseLabel: String
    let angles: [VedicAngle]
    let houses: [VedicHouse]
    let planets: [String: VedicPlanetPosition]

    enum CodingKeys: String, CodingKey {
        case houseLabel = "house_label"
        case angles, houses, planets
    }
}

struct VedicAngle: Codable, Identifiable {
    let id: String
    let name: String
    let longitude: Double
    let sign: String
    let degreeText: String
    let house: Int

    enum CodingKeys: String, CodingKey {
        case id, name, longitude, sign, house
        case degreeText = "degree_text"
    }
}

struct VedicHouse: Codable, Identifiable {
    let house: Int
    let sign: String
    let cuspLongitude: Double
    let cuspText: String
    let ruler: String

    var id: Int { house }

    enum CodingKeys: String, CodingKey {
        case house, sign, ruler
        case cuspLongitude = "cusp_longitude"
        case cuspText = "cusp_text"
    }
}

// MARK: - Planets

struct VedicPlanetPosition: Codable, Identifiable {
    let bodyId: String
    let name: String
    let longitude: Double
    let sign: String
    let degreeText: String
    let speed: Double?
    let house: Int?
    let nakshatra: VedicNakshatraDetails?

    var id: String { bodyId }

    enum CodingKeys: String, CodingKey {
        case bodyId = "body_id"
        case name, longitude, sign, speed, house
        case degreeText = "degree_text"
        case nakshatra
    }
}

// MARK: - Nakshatra

struct VedicNakshatraDetails: Codable {
    let nakshatra: VedicNakshatra
    let yoni: VedicYoni?
    let gana: VedicGana?
    let nadi: VedicNadi?
    let rajju: VedicRajju?
    let tara: VedicTara?
}

struct VedicNakshatra: Codable {
    let index: Int
    let nameZh: String
    let nameSa: String
    let lord: String
    let pada: Int
    let startLongitude: Double
    let endLongitude: Double

    enum CodingKeys: String, CodingKey {
        case index
        case nameZh = "name_zh"
        case nameSa = "name_sa"
        case lord, pada
        case startLongitude = "start_longitude"
        case endLongitude = "end_longitude"
    }
}

struct VedicYoni: Codable {
    let id: Int
    let nameSa: String
    let nameZh: String
    let isMale: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case nameSa = "name_sa"
        case nameZh = "name_zh"
        case isMale = "is_male"
    }
}

struct VedicGana: Codable {
    let id: Int
    let nameSa: String
    let nameZh: String

    enum CodingKeys: String, CodingKey {
        case id
        case nameSa = "name_sa"
        case nameZh = "name_zh"
    }
}

struct VedicNadi: Codable {
    let id: Int
    let nameSa: String
    let nameZh: String

    enum CodingKeys: String, CodingKey {
        case id
        case nameSa = "name_sa"
        case nameZh = "name_zh"
    }
}

struct VedicRajju: Codable {
    let type: String
    let subType: Int
    let nameSa: String
    let nameZh: String

    enum CodingKeys: String, CodingKey {
        case type
        case subType = "sub_type"
        case nameSa = "name_sa"
        case nameZh = "name_zh"
    }
}

struct VedicTara: Codable {
    let tara: Int
    let name: String
    let effect: String
    let isBenefic: Bool

    enum CodingKeys: String, CodingKey {
        case tara, name, effect
        case isBenefic = "is_benefic"
    }
}

// MARK: - Panchanga

struct VedicPanchanga: Codable {
    let tithi: VedicPanchangaItem
    let vara: VedicPanchangaItem
    let nakshatra: VedicPanchangaItem
    let yoga: VedicPanchangaItem
    let karana: VedicPanchangaItem
}

struct VedicPanchangaItem: Codable {
    let index: Int
    let nameSa: String
    let nameZh: String
    let startLongitude: Double
    let endLongitude: Double
    let lord: String?
    let paksha: String?

    enum CodingKeys: String, CodingKey {
        case index
        case nameSa = "name_sa"
        case nameZh = "name_zh"
        case startLongitude = "start_longitude"
        case endLongitude = "end_longitude"
        case lord, paksha
    }
}

// MARK: - Solar Day

struct VedicSolarDay: Codable {
    let sunriseLocal: String?
    let sunsetLocal: String?

    enum CodingKeys: String, CodingKey {
        case sunriseLocal = "sunrise_local"
        case sunsetLocal = "sunset_local"
    }
}

// MARK: - Divisional Charts

struct VedicDivisionalChart: Codable {
    let chartId: String
    let chartName: String
    let vargaNum: Int?
    let planets: [String: VedicDivisionalPlanet]
    let upagrahas: [VedicUpagraha]?
    let specialLagnas: [VedicSpecialLagna]?

    enum CodingKeys: String, CodingKey {
        case chartId = "chart_id"
        case chartName = "chart_name"
        case vargaNum = "varga_num"
        case planets
        case upagrahas
        case specialLagnas = "special_lagnas"
    }
}

struct VedicDivisionalPlanet: Codable, Identifiable {
    let bodyId: String
    let name: String
    let longitude: Double
    let vargaRasi: Int
    let vargaRasiSign: String
    let vargaDegree: Double
    let degreeText: String
    let nakshatra: VedicNakshatraSummary?

    var id: String { bodyId }

    enum CodingKeys: String, CodingKey {
        case bodyId = "body_id"
        case name, longitude
        case vargaRasi = "varga_rasi"
        case vargaRasiSign = "varga_rasi_sign"
        case vargaDegree = "varga_degree"
        case degreeText = "degree_text"
        case nakshatra
    }
}

struct VedicNakshatraSummary: Codable {
    let nameSa: String
    let pada: Int
    let lord: String

    enum CodingKeys: String, CodingKey {
        case nameSa = "name_sa"
        case pada, lord
    }
}

// MARK: - Moon / Bhava Chart

struct VedicDerivedChart: Codable {
    let chartId: String
    let chartName: String
    let planets: [String: VedicDerivedPlanet]
    let angles: [VedicAngle]?
    let moonRasi: Int?

    enum CodingKeys: String, CodingKey {
        case chartId = "chart_id"
        case chartName = "chart_name"
        case planets
        case angles
        case moonRasi = "moon_rasi"
    }
}

struct VedicDerivedPlanet: Codable, Identifiable {
    let bodyId: String
    let name: String
    let longitude: Double
    let rasi: Int
    let rasiName: String
    let degreeText: String
    let house: Int?
    let nakshatra: VedicNakshatraSummary?

    var id: String { bodyId }

    enum CodingKeys: String, CodingKey {
        case bodyId = "body_id"
        case name, longitude, rasi, house
        case rasiName = "rasi_name"
        case degreeText = "degree_text"
        case nakshatra
    }
}

// MARK: - Upagrahas & Special Lagnas

struct VedicUpagraha: Codable, Identifiable {
    let id: String
    let nameSa: String
    let nameZh: String
    let longitude: Double
    let rasi: Int
    let rasiName: String
    let degreeText: String
    let nakshatra: VedicNakshatraSummary?

    enum CodingKeys: String, CodingKey {
        case id
        case nameSa = "name_sa"
        case nameZh = "name_zh"
        case longitude, rasi
        case rasiName = "rasi_name"
        case degreeText = "degree_text"
        case nakshatra
    }
}

struct VedicSpecialLagna: Codable, Identifiable {
    let id: String
    let nameSa: String
    let nameZh: String
    let longitude: Double
    let rasi: Int
    let degreeText: String?
    let nakshatra: VedicNakshatraSummary?

    enum CodingKeys: String, CodingKey {
        case id
        case nameSa = "name_sa"
        case nameZh = "name_zh"
        case longitude, rasi
        case degreeText = "degree_text"
        case nakshatra
    }
}

// MARK: - Navamsa

struct VedicNavamsaPosition: Codable, Identifiable {
    let bodyId: String
    let name: String
    let navamsaRasi: Int
    let navamsaRasiName: String

    var id: String { bodyId }

    enum CodingKeys: String, CodingKey {
        case bodyId = "body_id"
        case name
        case navamsaRasi = "navamsa_rasi"
        case navamsaRasiName = "navamsa_rasi_name"
    }
}

// MARK: - Planet Relationships

struct VedicRelationships: Codable {
    let naisargika: VedicFriendshipSection
    let temporary: VedicFriendshipSection
    let compound: VedicCompoundSection
}

struct VedicFriendshipSection: Codable {
    let data: [String: [String: Int]]
    let labels: [String: String]?
}

struct VedicCompoundSection: Codable {
    let data: [String: [String: Int]]
    let labels: [String: String]?
    let labelsSa: [String: String]?

    enum CodingKeys: String, CodingKey {
        case data, labels
        case labelsSa = "labels_sa"
    }
}

// MARK: - Arudha

struct VedicArudhaPada: Codable, Identifiable {
    let padaName: String
    let rasi: Int
    let rasiName: String
    let house: Int

    var id: String { padaName }

    enum CodingKeys: String, CodingKey {
        case padaName = "pada_name"
        case rasi
        case rasiName = "rasi_name"
        case house
    }
}

// MARK: - Jaimini

struct VedicJaiminiKarakas: Codable {
    let charaKarakas: [VedicCharaKaraka]
    let system: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case charaKarakas = "chara_karakas"
        case system, note
    }
}

struct VedicCharaKaraka: Codable, Identifiable {
    let karakaType: Int
    let planet: String
    let planetName: String
    let longitudeInRasi: Double
    let effectiveLongitude: Double
    let nameSa: String
    let nameZh: String

    var id: String { "\(karakaType)-\(planet)" }

    enum CodingKeys: String, CodingKey {
        case karakaType = "karaka_type"
        case planet
        case planetName = "planet_name"
        case longitudeInRasi = "longitude_in_rasi"
        case effectiveLongitude = "effective_longitude"
        case nameSa = "name_sa"
        case nameZh = "name_zh"
    }
}

// MARK: - Ashtakavarga

struct VedicAshtakavarga: Codable {
    let bav: VedicBAV
    let sav: VedicSAV
}

struct VedicBAV: Codable {
    let planets: [String: [Int]]
}

struct VedicSAV: Codable {
    let rekha: [Int]
    let trikona: [Int]?
    let ekadhi: [Int]?
}

// MARK: - Dasa

struct VimsottariResult: Codable {
    let birthNakshatra: String
    let birthNakshatraIndex: Int
    let mahaDasas: [DasaPeriod]
    let currentMahadasa: DasaPeriod?

    enum CodingKeys: String, CodingKey {
        case birthNakshatra = "birth_nakshatra"
        case birthNakshatraIndex = "birth_nakshatra_index"
        case mahaDasas = "maha_dasas"
        case currentMahadasa = "current_mahadasa"
    }
}

struct DasaPeriod: Codable, Identifiable {
    let lord: String
    let durationYears: Int
    let start: String
    let end: String
    let antardashas: [AntardashaPeriod]?

    var id: String { "\(lord)-\(start)" }

    enum CodingKeys: String, CodingKey {
        case lord
        case durationYears = "duration_years"
        case start, end
        case antardashas
    }
}

struct AntardashaPeriod: Codable, Identifiable {
    let lord: String
    let start: String
    let end: String
    let durationYears: Double

    var id: String { "\(lord)-\(start)-\(end)" }

    enum CodingKeys: String, CodingKey {
        case lord
        case start, end
        case durationYears = "duration_years"
    }
}

struct YoginiDasaResult: Codable {
    let yoginiDasas: [YoginiPeriod]
    let currentYogini: YoginiPeriod?

    enum CodingKeys: String, CodingKey {
        case yoginiDasas = "yogini_dasas"
        case currentYogini = "current_yogini"
    }
}

struct YoginiPeriod: Codable, Identifiable {
    let yogini: String
    let durationYears: Int
    let start: String
    let end: String

    var id: String { "\(yogini)-\(start)" }

    enum CodingKeys: String, CodingKey {
        case yogini
        case durationYears = "duration_years"
        case start, end
    }
}

struct AshtottariDasaResult: Codable {
    let ashtottariDasas: [AshtottariPeriod]
    let currentAshtottari: AshtottariPeriod?

    enum CodingKeys: String, CodingKey {
        case ashtottariDasas = "ashtottari_dasas"
        case currentAshtottari = "current_ashtottari"
    }
}

struct AshtottariPeriod: Codable, Identifiable {
    let lord: String
    let durationYears: Int
    let start: String
    let end: String

    var id: String { "\(lord)-\(start)" }

    enum CodingKeys: String, CodingKey {
        case lord
        case durationYears = "duration_years"
        case start, end
    }
}

// MARK: - Shadbala

struct ShadbalaRow: Codable, Identifiable {
    let sthanaBala: Double
    let digBala: Double
    let kalaBala: Double
    let cheshtaBala: Double
    let naisargikaBala: Double
    let drigBala: Double
    let shadbalaTotal: Double
    let shadbalaRupas: Double
    let required: Int
    let percent: Double

    // NEW
    let requiredRupas: Double?
    let meetsRequired: Bool?
    let displaySummary: ShadbalaSummary?

    var id: String { "shadbala-\(shadbalaTotal)" }

    enum CodingKeys: String, CodingKey {
        case sthanaBala = "sthāna_bala"
        case digBala = "dig_bala"
        case kalaBala = "kāla_bala"
        case cheshtaBala = "ceṣṭa_bala"
        case naisargikaBala = "naiṣargika_bala"
        case drigBala = "dṛg_bala"
        case shadbalaTotal = "shadbala_total"
        case shadbalaRupas = "shadbala_rupas"
        case required, percent
        case requiredRupas = "required_rupas"
        case meetsRequired = "meets_required"
        case displaySummary = "display_summary"
    }
}

struct ShadbalaSummary: Codable {
    let total: Double
    let rupas: Double
    let required: Int
    let requiredRupas: Double
    let meetsRequired: Bool
    let percent: Double

    enum CodingKeys: String, CodingKey {
        case total, rupas, required, percent
        case requiredRupas = "required_rupas"
        case meetsRequired = "meets_required"
    }
}

// MARK: - Yoga

struct VedicYoga: Codable, Identifiable {
    let name: String
    let group: String
    let description: String?
    let effect: String
    let planets: [String]

    var id: String { "\(group)-\(name)-\(planets.joined())" }
}
