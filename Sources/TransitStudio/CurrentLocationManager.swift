import CoreLocation
import Foundation

private let currentLocationMaximumAge: TimeInterval = 60
private let currentLocationMaximumHorizontalAccuracy: CLLocationAccuracy = 1000

struct CurrentLocationResult {
    let placeName: String
    let latitude: Double
    let longitude: Double
    let timeZone: TimeZone?
}

// Keep the system service replaceable so request lifecycle tests need no OS permission.
protocol CurrentLocationProviding: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: CurrentLocationProviding {}

@MainActor
final class CurrentLocationManager: NSObject, ObservableObject {
    @Published var statusText = "未定位"
    @Published var isLocating = false

    typealias Geocode = (CLLocation, @escaping @Sendable ([CLPlacemark]?, Error?) -> Void) -> Void
    private let manager: CurrentLocationProviding
    private let servicesEnabled: () -> Bool
    private let geocode: Geocode
    private let locationTimeout: TimeInterval
    private let geocodingTimeout: TimeInterval
    private var completion: ((Result<CurrentLocationResult, Error>) -> Void)?
    private var timeoutTask: Task<Void, Never>?
    private var requestID: UUID?
    private var isUpdating = false
    private var isGeocoding = false
    private var lastRejection: String?

    init(
        manager: CurrentLocationProviding = CLLocationManager(),
        servicesEnabled: @escaping () -> Bool = { CLLocationManager.locationServicesEnabled() },
        locationTimeout: TimeInterval = 30,
        geocodingTimeout: TimeInterval = 8,
        geocode: @escaping Geocode = { location, completion in
            CLGeocoder().reverseGeocodeLocation(location, completionHandler: completion)
        }
    ) {
        self.manager = manager
        self.servicesEnabled = servicesEnabled
        self.locationTimeout = locationTimeout
        self.geocodingTimeout = geocodingTimeout
        self.geocode = geocode
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation(completion: @escaping (Result<CurrentLocationResult, Error>) -> Void) {
        guard !isLocating else { return }
        self.completion = completion
        requestID = UUID()
        lastRejection = nil
        isLocating = true
        guard servicesEnabled() else {
            finish(.failure(LocationError.servicesDisabled), status: "系统定位服务未开启")
            return
        }
        handleAuthorization(manager.authorizationStatus)
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        guard completion != nil else { return }
        switch status {
        case .notDetermined:
            statusText = "请求定位权限..."
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            finish(.failure(LocationError.permissionDenied), status: "定位权限被拒绝")
        case .authorizedAlways, .authorizedWhenInUse:
            guard !isUpdating, !isGeocoding else { return }
            isUpdating = true
            statusText = "正在定位..."
            let id = requestID
            scheduleTimeout(after: locationTimeout) { [weak self] in
                guard let self, self.requestID == id else { return }
                self.finish(.failure(LocationError.timedOut(self.lastRejection)), status: "定位超时")
            }
            // A first update can be cached or inaccurate. Wait for a usable update
            // instead of rejecting the only result of requestLocation().
            manager.startUpdatingLocation()
        @unknown default:
            finish(.failure(LocationError.unknownStatus), status: "未知定位状态")
        }
    }

    private func scheduleTimeout(after interval: TimeInterval, action: @escaping @MainActor () -> Void) {
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            } catch { return }
            guard !Task.isCancelled else { return }
            action()
        }
    }

    private func finish(_ result: Result<CurrentLocationResult, Error>, status: String) {
        guard let callback = completion else { return }
        completion = nil
        requestID = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
        isUpdating = false
        isGeocoding = false
        isLocating = false
        statusText = status
        callback(result)
    }

    func receiveLocations(_ locations: [CLLocation], now: Date = Date()) {
        guard completion != nil, isUpdating, !isGeocoding else { return }
        let location = locations
            .filter { CLLocationCoordinate2DIsValid($0.coordinate) }
            .filter { $0.horizontalAccuracy.isFinite && $0.horizontalAccuracy >= 0 }
            .filter { (0...currentLocationMaximumAge).contains(now.timeIntervalSince($0.timestamp)) }
            .filter { $0.horizontalAccuracy <= currentLocationMaximumHorizontalAccuracy }
            .min { lhs, rhs in
                if lhs.horizontalAccuracy == rhs.horizontalAccuracy {
                    return lhs.timestamp > rhs.timestamp
                }
                return lhs.horizontalAccuracy < rhs.horizontalAccuracy
            }
        guard let location else {
            if let latest = locations.max(by: { $0.timestamp < $1.timestamp }) {
                let age = now.timeIntervalSince(latest.timestamp)
                if !(0...currentLocationMaximumAge).contains(age) {
                    lastRejection = "系统返回的位置不是最近 60 秒内的数据"
                } else if latest.horizontalAccuracy.isFinite && latest.horizontalAccuracy > currentLocationMaximumHorizontalAccuracy {
                    lastRejection = String(format: "系统位置精度约 %.0f 米，超过 1000 米要求", latest.horizontalAccuracy)
                } else {
                    lastRejection = "系统返回的位置数据无效"
                }
            }
            statusText = "等待位置刷新..." + (lastRejection.map { "（\($0)）" } ?? "")
            return
        }

        manager.stopUpdatingLocation()
        isUpdating = false
        isGeocoding = true
        statusText = "已获取坐标，正在解析地名..."
        let id = requestID
        let fallback = CurrentLocationResult(
            placeName: "当前位置", latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude, timeZone: nil
        )
        scheduleTimeout(after: geocodingTimeout) { [weak self] in
            guard let self, self.requestID == id else { return }
            self.finish(.success(fallback), status: "定位成功，地名解析超时；请核对起盘时区")
        }
        geocode(location) { [weak self] placemarks, error in
            Task { @MainActor in
                guard let self, self.requestID == id else { return }
                let placemark = placemarks?.first
                let name = [placemark?.locality, placemark?.administrativeArea, placemark?.country]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
                let payload = CurrentLocationResult(
                    placeName: name.isEmpty ? fallback.placeName : name,
                    latitude: fallback.latitude, longitude: fallback.longitude,
                    timeZone: placemark?.timeZone
                )
                let status = error != nil || placemark == nil
                    ? "定位成功，地名解析失败；请核对起盘时区"
                    : (placemark?.timeZone == nil ? "定位成功；请核对起盘时区" : "定位成功")
                self.finish(.success(payload), status: status)
            }
        }
    }

    func receiveError(_ error: Error) {
        guard completion != nil, isUpdating else { return }
        let nsError = error as NSError
        if nsError.domain == kCLErrorDomain {
            switch CLError.Code(rawValue: nsError.code) {
            case .locationUnknown:
                statusText = "暂时无法确定位置，继续定位..."
                return
            case .denied:
                let failure: LocationError = servicesEnabled() ? .permissionDenied : .servicesDisabled
                finish(.failure(failure), status: failure.localizedDescription)
                return
            case .network:
                finish(.failure(LocationError.network), status: "定位网络连接失败")
                return
            default:
                break
            }
        }
        finish(.failure(error), status: "定位失败：\(error.localizedDescription)")
    }
}

extension CurrentLocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.handleAuthorization(manager.authorizationStatus)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.receiveLocations(locations) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.receiveError(error) }
    }
}

enum LocationError: LocalizedError {
    case permissionDenied
    case servicesDisabled
    case timedOut(String?)
    case network
    case unknownStatus

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "定位权限被拒绝。请在系统设置 → 隐私与安全性 → 定位服务中允许 Transit Studio 获取位置。"
        case .servicesDisabled:
            return "系统定位服务未开启。请在系统设置 → 隐私与安全性 → 定位服务中开启定位服务。"
        case .timedOut(let detail):
            return "未能在 30 秒内获取最近 60 秒且精度在 1000 米以内的位置。"
                + (detail.map { "\($0)。" } ?? "")
                + "请确认 Wi-Fi 已开启并稍后重试，或手动填写提问地点。"
        case .network:
            return "定位服务网络连接失败。请检查网络连接后重试，或手动填写提问地点。"
        case .unknownStatus:
            return "未知定位状态。"
        }
    }
}
