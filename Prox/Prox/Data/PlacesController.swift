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
protocol PlacesProviderDelegate: class {
    func placesProviderWillStartFetchingPlaces(_ controller: PlacesProvider)
    func placesProvider(_ controller: PlacesProvider, didReceivePlaces places: [Place])
    func placesProviderDidFinishFetchingPlaces(_ controller: PlacesProvider)
    func placesProvider(_ controller: PlacesProvider, didError error: Error)
}

private let apiSuffix = "/api/v1.0/at/%f/%f"
private let numberOfRetries = 60
private let timeBetweenRetries = 1

class PlacesProvider {
    weak var delegate: PlacesProviderDelegate?

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

    private var nearbyPlaces = [CLLocation: [Place]]()
    private var eventsPlaces = [CLLocation: [Place]]()

    func updatePlaces(forLocation location: CLLocation) {
        assert(Thread.isMainThread)
        // We would like to prevent running more than one update at the same time.
        if isUpdating {
            return
        }
        isUpdating = true

        self.delegate?.placesProviderWillStartFetchingPlaces(self)

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
                    self.delegate?.placesProvider(self, didError: err)
                }
            }
        )

        // Immediately after we've told the server, we should start querying the firebase datastore,
        // because we may have already got something cached.
        nearbyPlaces.removeValue(forKey: location)
        retryQueryPlaces(location: location, withRadius: radius, retriesLeft: numberOfRetries, lastCount: 0)
        fetchPlacesWithEvents(location: location)
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
                self.nearbyPlaces[location] = places
                self.displayPlaces(forLocation: location)
                DispatchQueue.main.async {
                    // TODO refactor for a more incremental load, and therefore
                    // insertion sort approach to ranking. We shouldn't do too much of this until
                    // we have the waiting states implemented.
                    self.isUpdating = false
                    self.delegate?.placesProviderDidFinishFetchingPlaces(self)
                }
            } else {
                // We either have zero places, or the server is adding stuff to firebase,
                // and we should wait. 
                if placeCount > 0 && lastCount != placeCount {
                    self.nearbyPlaces[location] = places
                    self.displayPlaces(forLocation: location)
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

    private func fetchPlacesWithEvents(location: CLLocation) {
        let eventProvider = EventsProvider()
        eventsPlaces.removeValue(forKey: location)
        eventProvider.getEventsWithPlaces(forLocation: location, usingPlacesDatabase: database) { places in
            self.eventsPlaces[location] = places
            self.displayPlaces(forLocation: location)
        }
    }

    /**
    * Display places merges found places with events with places we have found nearby, giving us a combined list of
    * all the places that we need to show to the user.
    **/
    private func displayPlaces(forLocation location: CLLocation) {
        let placesNearby = self.nearbyPlaces[location]
        let placesWithEvents = self.eventsPlaces[location]
        let placesToDisplay = union(ofNearbyPlaces: placesNearby, andEventPlaces: placesWithEvents)

        let preparedPlaces = self.preparePlaces(places: placesToDisplay, forLocation: location)
        DispatchQueue.main.async {
            self.delegate?.placesProvider(self, didReceivePlaces: preparedPlaces)
        }

        if placesWithEvents != nil && !isUpdating {
            self.eventsPlaces.removeValue(forKey: location)
            self.nearbyPlaces.removeValue(forKey: location)
        }
    }

    // replaces any Place in nearbyPlaces with the equivalent Place from eventPlaces if it exists
    // otherwise just adds the eventPlace to the result
    // leaving a combination of places with events and places nearby
    private func union(ofNearbyPlaces nearbyPlaces: [Place]?, andEventPlaces eventPlaces: [Place]?) -> [Place] {
        var unionOfPlaces = nearbyPlaces ?? []
        for eventPlace in (eventPlaces ?? []){
            if let placeIndex = unionOfPlaces.index(of: eventPlace) {
                unionOfPlaces[placeIndex] = eventPlace
            } else {
                unionOfPlaces.append(eventPlace)
            }
        }
        return unionOfPlaces
    }

    private func preparePlaces(places: [Place], forLocation location: CLLocation) -> [Place] {
        let filteredPlaces = PlaceUtilities.filterPlacesForCarousel(places)
        return PlaceUtilities.sort(places: filteredPlaces, byDistanceFromLocation: location)
    }
}
