/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation


protocol LocationProvider: class {
    func getCurrentLocation() -> CLLocation?
}

protocol LocationMonitorDelegate: class {
    func locationMonitor(_ locationMonitor: LocationMonitor, didUpdateLocation location: CLLocation)
    func locationMonitor(_ locationMonitor: LocationMonitor, userDidExitCurrentLocation location: CLLocation)
    func locationMonitorNeedsUserPermissionsPrompt(_ locationMonitor: LocationMonitor)
    func locationMonitor(_ locationMonitor: LocationMonitor, userDidVisitLocation location: CLLocation)

    func locationMonitor(_ locationMonitor: LocationMonitor, didFailInitialUpdateWithError error: Error)
}

// an extension on the delegate allows us to give default implementations to some of the functions, making them optional
extension LocationMonitorDelegate {
    func locationMonitor(_ locationMonitor: LocationMonitor, userDidVisitLocation location: CLLocation) {}
    func locationMonitor(_ locationMonitor: LocationMonitor, userDidExitCurrentLocation location: CLLocation) {}
}

class LocationMonitor: NSObject {

    weak var delegate: LocationMonitorDelegate?

    fileprivate(set) var currentLocation: CLLocation?

    fileprivate let currentLocationIdentifier = "CURRENT_LOCATION"
    fileprivate let MIN_SECS_BETWEEN_LOCATION_UPDATES: TimeInterval = 1

    fileprivate(set) var timeOfLastLocationUpdate: Date? {
        get {
            return UserDefaults.standard.value(forKey: AppConstants.timeOfLastLocationUpdateKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: AppConstants.timeOfLastLocationUpdateKey)
        }
    }

    lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        // TODO: update to a more sane distance value when testing is over.
        // This is probably going to be around 100m
        manager.distanceFilter = RemoteConfigKeys.significantLocationChangeDistanceMeters.value
        manager.pausesLocationUpdatesAutomatically = true
        return manager
    }()

    // fake the location to Hilton Waikaloa Village, Kona, Hawaii
    var fakeLocation: CLLocation = CLLocation(latitude: 19.924043, longitude: -155.887652)

    fileprivate var monitoredRegions: [String: GeofenceRegion] = [String: GeofenceRegion]()
    fileprivate var timeAtLocationTimer: Timer?

    fileprivate var isAuthorized = false

    func refreshLocation() {
        if (CLLocationManager.hasLocationPermissionAndEnabled()) {
            isAuthorized = true
            locationManager.startUpdatingLocation()
        } else {
            isAuthorized = false
            // requestLocation expected to be called on authorization status change.
            maybeRequestLocationPermission()
        }
    }


    func cancelTimeAtLocationTimer() {
        timeAtLocationTimer?.invalidate()
        timeAtLocationTimer = nil
    }

    func startTimeAtLocationTimer() {
        if timeAtLocationTimer == nil {
            timeAtLocationTimer = Timer.scheduledTimer(timeInterval: AppConstants.minimumIntervalAtLocationBeforeFetchingEvents, target: self, selector: #selector(timerFired(timer:)), userInfo: nil, repeats: true)
        }
    }

    @objc fileprivate func timerFired(timer: Timer) {
        guard let currentLocation = getCurrentLocation() else { return }
        delegate?.locationMonitor(self, userDidVisitLocation: currentLocation)
    }

    func startMonitoringForVisitAtCurrentLocation() {
        guard let currentLocation = getCurrentLocation(),
            !monitoredRegions.keys.contains(currentLocationIdentifier) else { return }
        startTimeAtLocationTimer()
        startMonitoring(location: currentLocation, withIdentifier: currentLocationIdentifier, withRadius: RemoteConfigKeys.radiusForCurrentLocationMonitoringMeters.value, forEntry: nil, forExit: { region in
            self.cancelTimeAtLocationTimer()
            self.stopMonitoringRegion(withIdentifier: self.currentLocationIdentifier)
            self.delegate?.locationMonitor(self, userDidExitCurrentLocation: currentLocation)
        })
    }

    func startMonitoring(location: CLLocation, withIdentifier identifier: String, withRadius radius: CLLocationDistance, forEntry: ((GeofenceRegion)->())?, forExit: ((GeofenceRegion)->())?) {
        let region = GeofenceRegion(location: location.coordinate, identifier: identifier, radius: radius, onEntry: forEntry, onExit: forExit)
        monitoredRegions[identifier] = region

        self.locationManager.startMonitoring(for: region.region)
    }

    func stopMonitoringRegion(withIdentifier identifier: String) {
        guard let monitoredRegion = monitoredRegions[identifier]?.region else {
            return
        }
        self.locationManager.stopMonitoring(for: monitoredRegion)
        monitoredRegions.removeValue(forKey: identifier)
    }

    /*
     * Requests permission to use device location services.
     *
     * May use the passed UIViewController to display a dialog:
     * be sure to call this method at the appropriate time.
     */
    func maybeRequestLocationPermission() {
        guard CLLocationManager.locationServicesEnabled() else {
            // This dialog, nor the app settings page it opens, are not a good descriptor that location
            // services are disabled but I don't think putting in the work right now is worth it.
            delegate?.locationMonitorNeedsUserPermissionsPrompt(self)
            return
        }

        switch (CLLocationManager.authorizationStatus()) {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()

        case .restricted, .denied:
            delegate?.locationMonitorNeedsUserPermissionsPrompt(self)

        case .authorizedAlways:
            break

        case .authorizedWhenInUse:
            assertionFailure("Location permission, authorized when in use, not expected.")
        }
    }
}

extension LocationMonitor: LocationProvider {
    func getCurrentLocation() -> CLLocation? {
        if currentLocation == nil {
            if AppConstants.MOZ_LOCATION_FAKING {
                // fake the location to Hilton Waikaloa Village, Kona, Hawaii
                currentLocation = fakeLocation
            }else {
                currentLocation = self.locationManager.location
            }
        }
        return currentLocation
    }
}

extension LocationMonitor: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if !isAuthorized || !CLLocationManager.hasLocationPermissionAndEnabled(){
            refreshLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Use last coord: we want to display where the user is now.
        if var location = locations.last {
            // In iOS9, didUpdateLocations can be unexpectedly called multiple
            // times for a single `requestLocation`: we guard against that here.

            if AppConstants.MOZ_LOCATION_FAKING {
                // fake the location to Hilton Waikaloa Village, Kona, Hawaii
                location = fakeLocation
            }
            self.currentLocation = location

            self.delegate?.locationMonitor(self, didUpdateLocation: location)

            timeOfLastLocationUpdate = location.timestamp
            locationManager.stopUpdatingLocation()
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard currentLocation == nil else {
            // If we have a cached location, we can use that - no need to display another error.
            return
        }

        NSLog("lol-location \(error.localizedDescription)")
        self.delegate?.locationMonitor(self, didFailInitialUpdateWithError: error)
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let region = monitoredRegions[region.identifier] else { return }
        region.onEntry?(region)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let region = monitoredRegions[region.identifier] else { return }
        region.onExit?(region)
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("lol-location region monitoring failed \(error.localizedDescription)")
    }
}
