import Combine
import CoreLocation
import Foundation

/// Active only while the user runs device playback. iOS may still suspend or
/// terminate the process; this is not a guarantee of unattended playback.
@MainActor
final class BackgroundLocationSession: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var status = "Background playback requests location access when started."
    @Published private(set) var isRunning = false
    @Published private(set) var isAuthorized = false
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.distanceFilter = 200
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func begin() {
        isRunning = true
        if manager.authorizationStatus == .notDetermined {
            status = "Allow location access to continue device playback while using other apps."
            manager.requestWhenInUseAuthorization()
        } else { updateAuthorization() }
    }

    func end() {
        isRunning = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        status = "Background playback stopped."
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in self?.updateAuthorization() }
    }

    private func updateAuthorization() {
        let authorization = manager.authorizationStatus
        isAuthorized = authorization == .authorizedAlways || authorization == .authorizedWhenInUse
        guard isRunning else { return }
        if isAuthorized {
            manager.allowsBackgroundLocationUpdates = true
            manager.startUpdatingLocation()
            status = "Background playback enabled while this location session remains active."
        } else {
            manager.stopUpdatingLocation()
            manager.allowsBackgroundLocationUpdates = false
            status = "Location access is off. Keep RoutePilot visible during device playback."
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.status = "Location session reported an error. Keep RoutePilot visible to ensure playback continues."
        }
    }
}
