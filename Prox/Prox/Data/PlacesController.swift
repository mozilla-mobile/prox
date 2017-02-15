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
    func placesProvider(_ controller: PlacesProvider, didUpdatePlaces places: [Place])
}

class PlacesProvider {
    weak var delegate: PlacesProviderDelegate?

    private let database = FirebasePlacesDatabase()

    private lazy var sessionManager: AFHTTPSessionManager = {
        let manager = AFHTTPSessionManager(sessionConfiguration: .default)
        manager.responseSerializer = AFHTTPResponseSerializer()
        return manager
    }()

    private lazy var radius: Double = {
        return RemoteConfigKeys.searchRadiusInKm.value
    }()

    private var allPlaces = [Place]()

    fileprivate var displayedPlaces = [Place]()
    fileprivate var placeKeyMap = [String: Int]()
    fileprivate let placesLock = NSLock()

    let filters = [
        PlaceFilter(label: Strings.filterView.discover, enabled: true,
                    categories: ["active", "arts", "localflavor", "hotelstravel"]),
        PlaceFilter(label: Strings.filterView.eatAndDrink, enabled: true,
                    categories: ["food", "nightlife", "restaurants"]),
        PlaceFilter(label: Strings.filterView.shop, enabled: true,
                    categories: ["shopping"]),
        PlaceFilter(label: Strings.filterView.services, enabled: true,
                    categories: ["auto", "beautysvc", "bicycles", "education", "eventplanning", "financialservices", "health", "homeservices", "localservices", "professional", "massmedia", "pets", "publicservicesgovt", "realestate", "religiousorgs"]),
    ]

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
                        let place = self.allPlaces[index]
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

    func updatePlaces(forLocation location: CLLocation) {
        // Fetch a stable list of places from firebase.
        getPlaces(forLocation: location, withRadius: radius).upon { results in
            let places = results.flatMap { $0.successResult() }
            self.didFinishFetchingPlaces(places: places, forLocation: location)
        }
    }

    func filterPlaces(filters: [PlaceFilter]) -> [Place] {
        let enabledCategories = Set(filters.filter { $0.enabled }.map { $0.categories }.reduce([], +))
        let toRoots = CategoriesUtil.categoryToRootsMap

        return allPlaces.filter { place in
            let categories = Set(place.categories.ids.flatMap { toRoots[$0] }.reduce([], +))
            return !enabledCategories.isDisjoint(with: categories)
        }
    }

    /// Applies the current set of filters to all places, setting `displayedPlaces` to the result.
    /// Callers must acquire a write lock before calling this method!
    fileprivate func updateDisplayedPlaces() {
        displayedPlaces = filterPlaces(filters: filters)

        var placesMap = [String: Int]()
        for (index, place) in displayedPlaces.enumerated() {
            placesMap[place.id] = index
        }
        placeKeyMap = placesMap
    }

    /**
     * displayPlaces merges found places with events with places we have found nearby, giving us a combined list of
     * all the places that we need to show to the user.
     **/
    private func displayPlaces(places: [Place], forLocation location: CLLocation) {
        let filteredPlaces = PlaceUtilities.filterPlacesForCarousel(places)
        return PlaceUtilities.sort(places: filteredPlaces, byTravelTimeFromLocation: location, ascending: true, completion: { sortedPlaces in
            self.placesLock.withWriteLock {
                self.allPlaces = sortedPlaces
                self.updateDisplayedPlaces()
            }
            DispatchQueue.main.async {
                self.placesLock.withReadLock {
                    self.delegate?.placesProvider(self, didUpdatePlaces: self.displayedPlaces)
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

            // TODO refactor for a more incremental load, and therefore
            // insertion sort approach to ranking. We shouldn't do too much of this until
            // we have the waiting states implemented.
            self.displayPlaces(places: Array(union), forLocation: location)
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

    func sortPlaces(byLocation location: CLLocation) {
        self.placesLock.withWriteLock {
            let sortedPlaces = PlaceUtilities.sort(places: displayedPlaces, byDistanceFromLocation: location)
            self.displayedPlaces = sortedPlaces
        }
    }

    func refresh() {
        assert(Thread.isMainThread)

        placesLock.withWriteLock {
            updateDisplayedPlaces()
        }

        delegate?.placesProvider(self, didUpdatePlaces: displayedPlaces)
    }
}
