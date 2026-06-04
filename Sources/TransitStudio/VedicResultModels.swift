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

    enum CodingKeys: String, CodingKey {
        case birthUtc = "birth_utc"
        case birthLocal = "birth_local"
        case referenceUtc = "reference_utc"
        case referenceLocal = "reference_local"
        case latitude, longitude
        case houseSystem = "house_system"
        case ayanamsha, zodiac, ephemeris
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

    var id: String { "\(lord)-\(start)" }

    enum CodingKeys: String, CodingKey {
        case lord
        case durationYears = "duration_years"
        case start, end
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
    }
}

// MARK: - Yoga

struct VedicYoga: Codable, Identifiable {
    let name: String
    let group: String
    let description: String
    let effect: String
    let planets: [String]

    var id: String { "\(group)-\(name)-\(planets.joined())" }
}
