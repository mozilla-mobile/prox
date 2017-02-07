/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Deferred
import Firebase

// Adding "$name/" allows you to develop against a locally run database.
// TODO prox-server – allow this string to be passed in as a URL parameter when in debug mode.
private let ROOT_PATH = AppConstants.firebaseRoot
private let EVENTS_PATH = ROOT_PATH + "events/"
private let GEOFIRE_PATH = EVENTS_PATH + "locations/"
private let DETAILS_PATH = EVENTS_PATH + "details/"

class FirebaseEventsDatabase: EventsDatabase {

    private let eventDetailsRef: FIRDatabaseReference
    private let geofire: GeoFire

    private lazy var cachedLastResponse: [String: NSDictionary]? = {
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            return nil
        }
        let appFile = URL(fileURLWithPath: documentsPath).appendingPathComponent("events.json")
        do {
            let jsonData = try Data(contentsOf: appFile, options: .mappedIfSafe)
            let json = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.mutableContainers ) as? [String: NSDictionary]
            if json != nil {
                return json
            }
        } catch {
            NSLog("Unable to fetch file from disk \(error)")
        }
        return nil
    }()

    private lazy var fetchedEvents = [String: NSDictionary]()

    init() {
        let rootRef = FIRDatabase.database().reference()
        eventDetailsRef = rootRef.child(DETAILS_PATH)
        geofire = GeoFire(firebaseRef: rootRef.child(GEOFIRE_PATH))
    }

    internal func getEvents(forLocation location: CLLocation, withRadius radius: Double, isBackground: Bool = false) -> Future<[DatabaseResult<Event>]> {
        if isBackground {
            return fetchEventsInBackground(forLocation: location, withRadius: radius)
        }
        return fetchEventsInForeground(forLocation: location, withRadius: radius)

    }

    fileprivate func fetchEventsInForeground(forLocation location: CLLocation, withRadius radius: Double)-> Future<[DatabaseResult<Event>]> {
        let queue = DispatchQueue.global(qos: .userInitiated)
        let events = getEventKeys(aroundPoint: location, withRadius: radius).andThen(upon: queue) { (eventKeyToLoc) -> Future<[DatabaseResult<Event>]> in
            let eventKeys = Array(eventKeyToLoc.keys)
            let fetchedEvents = eventKeys.map { self.getEvent(withKey: $0) }
            return fetchedEvents.allFilled().andThen(upon: queue) { result -> Future<[DatabaseResult<Event>]> in
                self.cacheEvents()
                return Future(value: result)
            }
        }
        return events
    }

    fileprivate func fetchEventsInBackground(forLocation location: CLLocation, withRadius radius: Double)-> Future<[DatabaseResult<Event>]> {
        guard let eventsResponse = cachedLastResponse else {
            return fetchEventsInForeground(forLocation: location, withRadius: radius)
        }
        let events:[DatabaseResult<Event>]  = eventsResponse.values.flatMap { Event(fromDictionary: $0) }.map { DatabaseResult<Event>.succeed(value: $0) }
        return Future(value: events)
    }

    fileprivate func cacheEvents() {
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            NSLog("Unable to find documentsPath at \(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true))")
            return
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: fetchedEvents)
            let appFile = (documentsPath as NSString).appendingPathComponent("events.json")
            guard let fileHandle = FileHandle(forWritingAtPath: appFile) else {
                if !FileManager.default.createFile(atPath: appFile, contents: data, attributes: nil) {
                    NSLog("Unable to create file at \(appFile)")
                }
                return
            }
            fileHandle.write(data)
        } catch {
            NSLog("Error converting fetched events to JSON object \(error)")
        }

    }

    /*
     * Queries GeoFire to find keys that represent locations around the given point.
     */
    private func getEventKeys(aroundPoint location: CLLocation, withRadius radius: Double) -> Deferred<[String:CLLocation]> {
        let deferred = Deferred<[String:CLLocation]>()
        var eventKeyToLoc = [String:CLLocation]()

        guard let circleQuery = geofire.query(at: location, withRadius: radius) else {
            deferred.fill(with: eventKeyToLoc)
            return deferred
        }

        // Append results to return object.
        circleQuery.observe(.keyEntered) { (key, location) in
            if let unwrappedKey = key, let unwrappedLocation = location {
                eventKeyToLoc[unwrappedKey] = unwrappedLocation
            }
        }

        // Handle query completion.
        circleQuery.observeReady {
            log.debug("geofire events query complete: found \(eventKeyToLoc.count) events")
            circleQuery.removeAllObservers()
            deferred.fill(with: eventKeyToLoc)
        }

        return deferred
    }

    func getEvent(withKey key: String) -> Deferred<DatabaseResult<Event>> {
        let deferred = Deferred<DatabaseResult<Event>>()

        let detailRef = eventDetailsRef.child(key)
        detailRef.queryOrderedByKey().observeSingleEvent(of: .value) { (data: FIRDataSnapshot) in
            guard data.exists() else {
                deferred.fill(with: DatabaseResult.fail(withMessage: "Event with key \(key) does not exist"))
                return
            }

            if let event = Event(fromFirebaseSnapshot: data) {
                if let eventDict = data.value as? NSDictionary {
                    self.fetchedEvents[key] = eventDict
                }
                deferred.fill(with: DatabaseResult.succeed(value: event))
            } else {
                deferred.fill(with: DatabaseResult.fail(withMessage: "Snapshot missing required Event data: \(data)"))
            }
        }

        return deferred
    }

    private func mapEventsToPlaceIds(events: [Event]) -> [String: [Event]] {
        var placeIdsToEventMap = [String: [Event]]()
        for event in events {
            if var mappedEvents = placeIdsToEventMap[event.placeId] {
                mappedEvents.append(event)
            } else {
                placeIdsToEventMap[event.placeId] = [event]
            }
        }
        return placeIdsToEventMap
    }

    func getPlacesWithEvents(forLocation location: CLLocation, withRadius radius: Double, withPlacesDatabase placesDatabase: PlacesDatabase, filterEventsUsing eventFilter: @escaping (Event) -> Bool) -> Future<[DatabaseResult<Place>]> {
        let dispatchQueue = DispatchQueue.global(qos: .userInitiated)
        // get the events within our event radius
        return getEvents(forLocation: location, withRadius: radius).andThen(upon: dispatchQueue) { events -> Future<[DatabaseResult<Place>]> in
            let filteredEvents = events.flatMap { $0.successResult() } .filter { return eventFilter($0) }
            let eventToPlaceMap = self.mapEventsToPlaceIds(events: filteredEvents)
            var fetchedPlaces = [String: Place]()
            // loop through each event and fetch the place
            return eventToPlaceMap.keys.map { placeKey -> Deferred<DatabaseResult<Place>> in
                let deferred = Deferred<DatabaseResult<Place>>()
                placesDatabase.getPlace(forKey: placeKey).upon { result in
                    if let place = result.successResult(),
                        let placeEvents = eventToPlaceMap[placeKey] {
                        place.events = placeEvents
                        deferred.fill(with: DatabaseResult.succeed(value: place))
                        fetchedPlaces[place.id] = place
                    } else {
                        deferred.fill(with: DatabaseResult.fail(withMessage: "No Place for event place with id \(placeKey)"))
                    }
                }
                return deferred
            }.allFilled()
        }
    }
}
