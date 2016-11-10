/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import AFNetworking
import Deferred
import FirebaseRemoteConfig
import Foundation

/*
 * Delegate methods for updating places asynchronously.
 * All methods on the delegate will be called on the main thread.
 */
protocol PlacesControllerDelegate: class {
    func placeControllerWillStartFetchingPlaces(_ controller: PlacesController)
    func placesController(_ controller: PlacesController, didReceivePlaces places: [Place])
    func placeControllerDidFinishFetchingPlaces(_ controller: PlacesController)
    func placesController(_ controller: PlacesController, didError error: Error)
}

private let apiSuffix = "/api/v1.0/at/%f/%f"
private let numberOfRetries = 60
private let timeBetweenRetries = 1

class PlacesController {
    weak var delegate: PlacesControllerDelegate?

    private let database = FirebasePlacesDatabase()

    private var isUpdating = false

    private lazy var sessionManager: AFHTTPSessionManager = {
        let manager = AFHTTPSessionManager(sessionConfiguration: .default)
        manager.responseSerializer = AFHTTPResponseSerializer()
        return manager
    }()

    private lazy var radius: Double = {
        let key = RemoteConfigKeys.searchRadiusInKm
        return FIRRemoteConfig.remoteConfig()[key].numberValue!.doubleValue
    }()

    func updatePlaces(forLocation location: CLLocation) {
        assert(Thread.isMainThread)
        // We would like to prevent running more than one update at the same time.
        if isUpdating {
            return
        }
        isUpdating = true

        self.delegate?.placeControllerWillStartFetchingPlaces(self)

        // Tell the server that we're here. We don't need to do anything with the return
        // value: we're just instructing the server to go crawl the venues/events the area 
        // we're in now.
        let coord = location.coordinate
        let path  = String(format:apiSuffix, coord.latitude, coord.longitude)
        let url   = AppConstants.serverURL.appendingPathComponent(path)

        sessionManager.put(url.absoluteString, parameters: nil,
            success: { (task, data) in
                // TODO is there anything useful we can get from the server to help the UI here?
                // e.g. some JSON to give queue size (how busy is it).
                print("Server responded ok.")
            },
            failure: { (task, err) in
                print("Error from server: \(err)")
                DispatchQueue.main.async {
                    self.delegate?.placesController(self, didError: err)
                }
            }
        )

        // Immediately after we've told the server, we should start querying the firebase datastore,
        // because we may have already got something cached.
        retryQueryPlaces(location: location, withRadius: radius, retriesLeft: numberOfRetries)
    }

    private func retryQueryPlaces(location: CLLocation, withRadius radius: Double, retriesLeft: Int, lastCount: Int = -1) {
        // Fetch a stable list of places from firebase.
        // In the event of the server crawling (from a cold start, for example)
        // the server will be adding places to firebase.
        // We want to wait for the number of firebase results to stop changing.
        database.getPlaces(forLocation: location, withRadius: radius).upon { results in
            let places = results.flatMap { $0.successResult() }
            let placeCount = places.count
            // Check if we have a stable number of places.
            if (placeCount > 0 && lastCount == placeCount) || retriesLeft == 0 {
                self.displayPlaces(places: places, forLocation: location)
                DispatchQueue.main.async {
                    // TODO refactor for a more incremental load, and therefore
                    // insertion sort approach to ranking. We shouldn't do too much of this until
                    // we have the waiting states implemented.
                    self.delegate?.placeControllerDidFinishFetchingPlaces(self)
                    self.isUpdating = false
                }
            } else {
                // We either have zero places, or the server is adding stuff to firebase,
                // and we should wait.
                if placeCount > 0 && lastCount != placeCount {
                    self.displayPlaces(places: places, forLocation: location)
                }
                DispatchQueue.main.asyncAfter(wallDeadline: .now() + .seconds(timeBetweenRetries)) {
                    self.retryQueryPlaces(location: location,
                                          withRadius: radius,
                                          retriesLeft: retriesLeft - 1,
                                          lastCount: placeCount)
                }
            }
        }
    }

    private func displayPlaces(places: [Place], forLocation location: CLLocation) {
        let sortedPlaces = self.preparePlaces(places: places, forLocation: location)
        DispatchQueue.main.async {
            self.delegate?.placesController(self, didReceivePlaces: sortedPlaces)
        }
    }

    private func preparePlaces(places: [Place], forLocation location: CLLocation) -> [Place] {
        // TODO filter places, based on… distance, categories, availability, rating etc
        return PlaceUtilities.sort(places: places, byDistanceFromLocation: location)
    }
}
