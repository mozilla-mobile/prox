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
    func placesProviderDidTimeout(_ controller: PlacesProvider)
    func placesProviderDidFetchFirstPlace()
}

private let apiSuffix = "/api/v1.0/at/%f/%f"
private let numberOfRetries = RemoteConfigKeys.numberOfPlaceFetchRetries.value
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
        return RemoteConfigKeys.searchRadiusInKm.value
    }()

    fileprivate var displayedPlaces = [Place]() {
        didSet {
            var placesMap = [PlaceKey: Int]()
            for (index, place) in displayedPlaces.enumerated() {
                placesMap[place.id] = index
            }
            self.placeKeyMap = placesMap
        }
    }
    fileprivate var placeKeyMap = [PlaceKey: Int]()

    fileprivate var firstFetch = true

    fileprivate let placesLock = NSLock()

    init() {

    }

    convenience init(places: [Place]) {
        self.init()
        self.displayedPlaces = places
        var placesMap = [PlaceKey: Int]()
        for (index, place) in displayedPlaces.enumerated() {
            placesMap[place.id] = index
        }
        self.placeKeyMap = placesMap
    }

    func place(forKey key: String, callback: @escaping (Place?) -> ()) {
        database.getPlace(forKey: key).upon { callback($0.successResult() )}
    }

    func place(withKey placeKey: String, forEventWithKey eventKey: String, callback: @escaping (Place?) -> ()) {
        let eventProvider = EventsProvider()
        var placeWithEvent: Place?
        var eventForPlace: Event?
        let lock = NSLock()
        var placeReturned = false
        var eventReturned = false
        place(forKey: placeKey) { place in
            defer {
                lock.unlock()
            }
            lock.lock()
            placeReturned = true
            guard let foundPlace = place,
                let event = eventForPlace else {
                    placeWithEvent = place
                    if (eventReturned) {
                        callback(nil)
                    }
                    return
            }
            foundPlace.events.append(event)
            callback(foundPlace)
        }

        eventProvider.event(forKey: eventKey) { event in
            defer {
                lock.unlock()
            }
            lock.lock()
            eventReturned = true
            guard let foundEvent = event,
                let place = placeWithEvent else {
                    eventForPlace = event
                    if (placeReturned) {
                        callback(nil)
                    }
                    return
            }
            place.events.append(foundEvent)
            callback(place)
        }
    }

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
                NSLog("Server responded ok.")
            },
            failure: { (task, err) in
                NSLog("Error from server: \(err)")
            }
        )

        // Immediately after we've told the server, we should start querying the firebase datastore,
        // because we may have already got something cached.
        retryQueryPlaces(location: location, withRadius: radius, retriesLeft: numberOfRetries, lastCount: 0)
    }


    /*
     * Queries GeoFire to get the place keys around the given location and then queries Firebase to
     * get the place details for the place keys.
     */
    func getPlaces(forLocation location: CLLocation, withRadius radius: Double) -> Future<[DatabaseResult<Place>]> {
        let queue = DispatchQueue.global(qos: .userInitiated)


        let places = database.getPlaceKeys(aroundPoint: location, withRadius: radius).andThen(upon: queue) { (placeKeyToLoc) -> Future<[DatabaseResult<Place>]> in
            var unfetchedPlaces = [String]()
            var fetchedPlaces = [Deferred<DatabaseResult<Place>>]()
            self.placesLock.withReadLock {
                for placeKey in Array(placeKeyToLoc.keys) {
                    if let index = self.placeKeyMap[placeKey] {
                        let place = self.displayedPlaces[index]
                        fetchedPlaces.append(Deferred(filledWith: DatabaseResult.succeed(value: place)))
                    } else {
                        unfetchedPlaces.append(placeKey)
                    }
                }
            }
            return (self.database.getPlaceDetails(fromKeys: unfetchedPlaces) + fetchedPlaces).allFilled()
        }
        return places
    }

    private func retryQueryPlaces(location: CLLocation, withRadius radius: Double, retriesLeft: Int, lastCount: Int) {
        // Fetch a stable list of places from firebase.
        // In the event of the server crawling (from a cold start, for example)
        // the server will be adding places to firebase.
        // We want to wait for the number of firebase results to stop changing.
        getPlaces(forLocation: location, withRadius: radius).upon { results in
            let places = results.flatMap { $0.successResult() }
            let placeCount = places.count

            guard retriesLeft > 0 else {
                self.isUpdating = false
                DispatchQueue.main.async {
                    self.delegate?.placesProviderDidTimeout(self)
                }
                return
            }
            
            // Check if we have a stable number of places.
            if placeCount > 0 && lastCount == placeCount {
                self.didFinishFetchingPlaces(places: places, forLocation: location)
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

    /**
    * Display places merges found places with events with places we have found nearby, giving us a combined list of
    * all the places that we need to show to the user.
    **/
    private func displayPlaces(places: [Place], forLocation location: CLLocation) {
        let filteredPlaces = PlaceUtilities.filterPlacesForCarousel(places)
        return PlaceUtilities.sort(places: filteredPlaces, byTravelTimeFromLocation: location, ascending: true, completion: { sortedPlaces in
            self.placesLock.withWriteLock {
                self.displayedPlaces = sortedPlaces
            }
            DispatchQueue.main.async {
                self.placesLock.withReadLock {
                    self.delegate?.placesProvider(self, didReceivePlaces: self.displayedPlaces)
                }
                if self.firstFetch {
                    self.delegate?.placesProviderDidFetchFirstPlace()
                    self.firstFetch = false
                }
            }

        })
    }

    private func didFinishFetchingPlaces(places: [Place], forLocation location: CLLocation) {
        let eventsProvider = EventsProvider()
        eventsProvider.getEventsWithPlaces(forLocation: location, usingPlacesDatabase: self.database) { placesWithEvents in
            let placesSet = Set<Place>(places)
            let eventPlacesSet = Set<Place>(placesWithEvents)
            let union = eventPlacesSet.union(placesSet)

            self.displayPlaces(places: Array(union), forLocation: location)
            DispatchQueue.main.async {
                // TODO refactor for a more incremental load, and therefore
                // insertion sort approach to ranking. We shouldn't do too much of this until
                // we have the waiting states implemented.
                self.isUpdating = false
                self.delegate?.placesProviderDidFinishFetchingPlaces(self)
            }
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
}

extension PlacesProvider: PlaceDataSource {
    func nextPlace(forPlace place: Place) -> Place? {
        return self.placesLock.withReadLock {
            // if the place isn't in the list, make the first item in the list the next item
            guard let currentPlaceIndex = self.placeKeyMap[place.id] else {
                return displayedPlaces.count > 0 ? displayedPlaces[displayedPlaces.startIndex] : nil
            }

            guard currentPlaceIndex + 1 < displayedPlaces.endIndex else { return nil }

            return displayedPlaces[displayedPlaces.index(after: currentPlaceIndex)]
        }
    }

    func previousPlace(forPlace place: Place) -> Place? {
        return self.placesLock.withReadLock {
            guard let currentPlaceIndex = self.placeKeyMap[place.id],
                currentPlaceIndex > displayedPlaces.startIndex else { return nil }

            return displayedPlaces[displayedPlaces.index(before: currentPlaceIndex)]
        }
    }

    func numberOfPlaces() -> Int {
        return self.placesLock.withReadLock {
            return displayedPlaces.count
        }
    }

    func place(forIndex index: Int) throws -> Place {
        return try self.placesLock.withReadLock {
            guard index < displayedPlaces.endIndex,
                index >= displayedPlaces.startIndex else {
                    throw PlaceDataSourceError(message: "There is no place at index: \(index)")
            }

            return displayedPlaces[index]
        }
    }

    func index(forPlace place: Place) -> Int? {
        return self.placesLock.withReadLock {
            return placeKeyMap[place.id]
        }
    }

    func fetchPlace(placeKey: String, withEvent eventKey: String, callback: @escaping (Place?) -> ()) {
        self.placesLock.withReadLock {
            if let placeIndex = placeKeyMap[placeKey] {
                let place = displayedPlaces[placeIndex]
                if place.events.contains(where: { $0.id == eventKey }) {
                    callback(place)
                }
                let eventProvider = EventsProvider()
                eventProvider.event(forKey: eventKey) { event in
                    guard let event = event else { return callback(nil) }
                    self.placesLock.withWriteLock {
                        place.events.append(event)
                    }
                    callback(place)
                }
            } else {
                self.place(withKey: placeKey, forEventWithKey: eventKey) { place in
                    callback(place)
                }
            }
        }
    }

    func allPlaces() -> [Place] {
        return displayedPlaces
    }

    func sortPlaces(byLocation location: CLLocation) {
        self.placesLock.withWriteLock {
            let sortedPlaces = PlaceUtilities.sort(places: displayedPlaces, byDistanceFromLocation: location)
            self.displayedPlaces = sortedPlaces
        }
    }
}
