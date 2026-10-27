import CoreLocation
import Foundation
import Testing
@testable import TransitStudio

private final class LocationProviderStub: CurrentLocationProviding {
    weak var delegate: CLLocationManagerDelegate?
    var desiredAccuracy: CLLocationAccuracy = 0
    var authorizationStatus: CLAuthorizationStatus = .authorizedAlways
    var starts = 0
    var stops = 0
    var authorizationRequests = 0
    func requestWhenInUseAuthorization() { authorizationRequests += 1 }
    func startUpdatingLocation() { starts += 1 }
    func stopUpdatingLocation() { stops += 1 }
}

@MainActor
struct CurrentLocationManagerTests {
    private func location(age: TimeInterval = 0, accuracy: Double = 100, now: Date = Date()) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
                   altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: -1,
                   timestamp: now.addingTimeInterval(-age))
    }

    @Test func cachedAndInaccurateUpdatesWaitForFreshCoordinates() async throws {
        let provider = LocationProviderStub()
        let service = CurrentLocationManager(manager: provider, servicesEnabled: { true }, geocode: { _, callback in
            callback(nil, NSError(domain: kCLErrorDomain, code: CLError.network.rawValue))
        })
        var results: [Result<CurrentLocationResult, Error>] = []
        service.requestCurrentLocation { results.append($0) }
        let now = Date()
        service.receiveLocations([location(age: 120, now: now)], now: now)
        #expect(service.isLocating)
        #expect(results.isEmpty)
        #expect(service.statusText.contains("最近 60 秒"))
        service.receiveLocations([location(accuracy: 3000, now: now)], now: now)
        #expect(service.isLocating)
        #expect(results.isEmpty)
        #expect(service.statusText.contains("3000 米"))
        service.receiveError(NSError(domain: kCLErrorDomain, code: CLError.locationUnknown.rawValue))
        #expect(service.isLocating)
        service.receiveLocations([location(now: now)], now: now)
        try await Task.sleep(nanoseconds: 20_000_000)
        #expect(!service.isLocating)
        #expect(provider.starts == 1)
        #expect(provider.stops >= 1)
        #expect(results.count == 1)
        let payload = try #require(results.first).get()
        #expect(payload.latitude == 31.2304)
        #expect(payload.longitude == 121.4737)
        #expect(payload.placeName == "当前位置")
        #expect(service.statusText.contains("请核对起盘时区"))
        service.receiveLocations([location()])
        service.receiveError(NSError(domain: kCLErrorDomain, code: CLError.denied.rawValue))
        #expect(results.count == 1)
    }

    @Test func timeoutStopsServiceAndAllowsRetry() async throws {
        let provider = LocationProviderStub()
        let service = CurrentLocationManager(manager: provider, servicesEnabled: { true }, locationTimeout: 0.01)
        var callbacks = 0
        service.requestCurrentLocation { result in
            callbacks += 1
            if case .success = result { Issue.record("Stale coordinates must not succeed") }
        }
        service.receiveLocations([location(age: 100)])
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(callbacks == 1)
        #expect(!service.isLocating)
        #expect(provider.stops == 1)
        #expect(service.statusText == "定位超时")
        service.requestCurrentLocation { _ in callbacks += 1 }
        #expect(provider.starts == 2)
        service.receiveError(NSError(domain: kCLErrorDomain, code: CLError.network.rawValue))
        #expect(callbacks == 2)
        #expect(!service.isLocating)
    }

    @Test func geocodingTimeoutReturnsCoordinatesAndLateReplyCannotFinishNewRequest() async throws {
        let provider = LocationProviderStub()
        var geocodeReply: (@Sendable ([CLPlacemark]?, Error?) -> Void)?
        let service = CurrentLocationManager(manager: provider, servicesEnabled: { true }, geocodingTimeout: 0.01,
                                             geocode: { _, callback in geocodeReply = callback })
        var first: CurrentLocationResult?
        service.requestCurrentLocation { first = try? $0.get() }
        service.receiveLocations([location()])
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(first?.latitude == 31.2304)
        #expect(!service.isLocating)
        #expect(service.statusText.contains("地名解析超时"))
        var secondCallbacks = 0
        service.requestCurrentLocation { _ in secondCallbacks += 1 }
        geocodeReply?(nil, nil)
        try await Task.sleep(nanoseconds: 20_000_000)
        #expect(secondCallbacks == 0)
        #expect(service.isLocating)
        service.receiveError(NSError(domain: kCLErrorDomain, code: CLError.denied.rawValue))
        #expect(secondCallbacks == 1)
        #expect(!service.isLocating)
    }

    @Test func permissionAndDisabledServicesFailWithoutStartingLocation() {
        for enabled in [false, true] {
            let provider = LocationProviderStub()
            provider.authorizationStatus = .denied
            let service = CurrentLocationManager(manager: provider, servicesEnabled: { enabled })
            var message = ""
            service.requestCurrentLocation { result in
                if case .failure(let error) = result { message = error.localizedDescription }
            }
            #expect(provider.starts == 0)
            #expect(!service.isLocating)
            #expect(message.contains(enabled ? "定位权限被拒绝" : "系统定位服务未开启"))
        }
    }

    @Test func invalidOrFutureCoordinatesNeverReachGeocoder() {
        let provider = LocationProviderStub()
        var geocodeCalls = 0
        let service = CurrentLocationManager(manager: provider, servicesEnabled: { true }, geocode: { _, _ in geocodeCalls += 1 })
        service.requestCurrentLocation { _ in }
        service.receiveLocations([location(age: -10), location(accuracy: -1), location(accuracy: .nan)])
        #expect(geocodeCalls == 0)
        #expect(service.isLocating)
        service.receiveError(NSError(domain: kCLErrorDomain, code: CLError.denied.rawValue))
    }
}
