/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Deferred
import Firebase

// Adding "$name/" allows you to develop against a locally run database.
// TODO prox-server – allow this string to be passed in as a URL parameter when in debug mode.
private let ROOT_PATH = ""
private let EVENTS_PATH = ROOT_PATH + "events/"
private let GEOFIRE_PATH = EVENTS_PATH + "locations/"
private let DETAILS_PATH = EVENTS_PATH + "details/"

class FirebaseEventsDatabase: EventsDatabase {

    private let eventDetailsRef: FIRDatabaseReference
    private let geofire: GeoFire

    init() {
        let rootRef = FIRDatabase.database().reference()
        eventDetailsRef = rootRef.child(DETAILS_PATH)
        geofire = GeoFire(firebaseRef: rootRef.child(GEOFIRE_PATH))
    }

    internal func getEvents(forLocation location: CLLocation, withRadius radius: Double) -> Future<[DatabaseResult<Event>]> {
        let queue = DispatchQueue.global(qos: .userInitiated)
        let events = getEventKeys(aroundPoint: location, withRadius: radius).andThen(upon: queue) { (eventKeyToLoc) -> Future<[DatabaseResult<Event>]> in
            let eventKeys = Array(eventKeyToLoc.keys)
            let fetchedEvents = eventKeys.map { self.getEvent(withKey: $0) }
            return fetchedEvents.allFilled()
        }
        return events
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
            print("lol geofire query has completed")
            circleQuery.removeAllObservers()
            deferred.fill(with: eventKeyToLoc)
        }

        return deferred
    }

    private func getEvent(withKey key: String) -> Deferred<DatabaseResult<Event>> {
        let deferred = Deferred<DatabaseResult<Event>>()

        let detailRef = eventDetailsRef.child(key)
        detailRef.queryOrderedByKey().observeSingleEvent(of: .value) { (data: FIRDataSnapshot) in
            guard data.exists() else {
                deferred.fill(with: DatabaseResult.fail(withMessage: "Event with key \(key) does not exist"))
                return
            }

            if let event = Event(fromFirebaseSnapshot: data) {
                deferred.fill(with: DatabaseResult.succeed(value: event))
            } else {
                deferred.fill(with: DatabaseResult.fail(withMessage: "Snapshot missing required Event data: \(data)"))
            }
        }

        return deferred
    }

    func getPlacesWithEvents(forLocation location: CLLocation, withRadius radius: Double, withPlacesDatabase placesDatabase: PlacesDatabase, filterEventsUsing eventFilter: @escaping (Event, CLLocation) -> Bool) -> Future<[DatabaseResult<Place>]> {
        let dispatchQueue = DispatchQueue.global(qos: .userInitiated)
        let places = getEvents(forLocation: location, withRadius: radius).andThen(upon: dispatchQueue) { events -> Future<[DatabaseResult<Place>]> in
            let eventsMap = events.map { eventResult -> Deferred<DatabaseResult<Place>> in
                let deferred = Deferred<DatabaseResult<Place>>()
                guard let event = eventResult.successResult(),
                    eventFilter(event, location) else {
                    deferred.fill(with: DatabaseResult.fail(withMessage: "No event found"))
                    return deferred
                }
                // TODO: Figure out what we do if we've already fetched this place for another event - maybe we need to remember the places we've already seen?
                placesDatabase.getPlace(forKey: event.placeId).upon { result in
                    if let place = result.successResult()   {
                        place.events.append(event)
                        deferred.fill(with: DatabaseResult.succeed(value: place))
                    } else {
                        deferred.fill(with: DatabaseResult.fail(withMessage: "No Place for event \(event.id)"))
                    }
                }
                return deferred
            }
            return eventsMap.allFilled()
        }

        return places
    }
}
