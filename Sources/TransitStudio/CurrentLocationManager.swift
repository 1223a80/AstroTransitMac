import CoreLocation
import Foundation

@MainActor
final class CurrentLocationManager: NSObject, ObservableObject {
    @Published var statusText = "未定位"
    @Published var isLocating = false

    private let manager = CLLocationManager()
    private var completion: ((Result<(String, Double, Double), Error>) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation(completion: @escaping (Result<(String, Double, Double), Error>) -> Void) {
        self.completion = completion
        let status = manager.authorizationStatus

        switch status {
        case .notDetermined:
            Task { @MainActor in
                self.statusText = "请求定位权限..."
                self.isLocating = true
            }
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            Task { @MainActor in
                self.statusText = "定位权限被拒绝"
            }
            completion(.failure(LocationError.permissionDenied))
            self.completion = nil
        case .authorizedAlways, .authorizedWhenInUse:
            Task { @MainActor in
                self.statusText = "正在定位..."
                self.isLocating = true
            }
            manager.requestLocation()
        @unknown default:
            Task { @MainActor in
                self.statusText = "未知定位状态"
            }
            completion(.failure(LocationError.unknownStatus))
            self.completion = nil
        }
    }
}

extension CurrentLocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.completion != nil else {
                return
            }
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                self.statusText = "正在定位..."
                self.isLocating = true
                manager.requestLocation()
            case .restricted, .denied:
                self.statusText = "定位权限被拒绝"
                self.isLocating = false
                self.completion?(.failure(LocationError.permissionDenied))
                self.completion = nil
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            Task { @MainActor in
                let completion = self.completion
                self.completion = nil
                self.statusText = "未获取到位置"
                self.isLocating = false
                completion?(.failure(LocationError.noLocation))
            }
            return
        }

        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            Task { @MainActor in
                if let error {
                    self.statusText = "定位成功，地名解析失败"
                    self.completion?(.failure(error))
                    self.completion = nil
                    self.isLocating = false
                    return
                }

                let placeName = placemarks?.first.map { placemark in
                    [placemark.locality, placemark.administrativeArea, placemark.country]
                        .compactMap { $0 }
                        .joined(separator: ", ")
                } ?? "Current Location"

                self.statusText = "定位成功"
                self.completion?(.success((placeName, location.coordinate.latitude, location.coordinate.longitude)))
                self.completion = nil
                self.isLocating = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let completion = self.completion
            self.completion = nil
            self.statusText = "定位失败"
            self.isLocating = false
            completion?(.failure(error))
        }
    }
}

enum LocationError: LocalizedError {
    case permissionDenied
    case noLocation
    case unknownStatus

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "定位权限被拒绝。"
        case .noLocation:
            return "未获取到当前位置。"
        case .unknownStatus:
            return "未知定位状态。"
        }
    }
}
