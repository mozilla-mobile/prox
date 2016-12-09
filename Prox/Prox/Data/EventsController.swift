/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

import FirebaseRemoteConfig

class EventsProvider {
    lazy var eventsDatabase: EventsDatabase = FirebaseEventsDatabase()

    private lazy var radius: Double = {
        return RemoteConfigKeys.eventSearchRadiusInKm.value
    }()
    func event(forKey key: String, completion: @escaping (Event?) -> ()) {
        eventsDatabase.getEvent(withKey: key).upon { completion($0.successResult() )}
    }

    func getEventsForNotifications(forLocation location: CLLocation, isBackground: Bool, completion: @escaping (([Event]?, Error?) -> Void)) {
        return eventsDatabase.getEvents(forLocation: location, withRadius: radius, isBackground: isBackground).upon { results in
            let events = results.flatMap { $0.successResult() }.filter { self.isValidEvent(event: $0) }
            NSLog("found \(events.count) events")
            DispatchQueue.main.async {
                completion(events, nil)
            }
        }
    }

    func getEventsWithPlaces(forLocation location: CLLocation, usingPlacesDatabase placesDatabase: PlacesDatabase, completion: @escaping ([Place]) -> ()) {
        eventsDatabase.getPlacesWithEvents(forLocation: location, withRadius: radius, withPlacesDatabase: placesDatabase, filterEventsUsing: self.isValidEvent).upon { results in
            let places = results.flatMap { $0.successResult() }
            completion(places)
        }
    }

    internal func isValidEvent(event: Event) -> Bool {
        let valid = event.isValidEvent()
        NSLog("event \(event.description) is a \(valid ? "valid" : "invalid") event")
        return valid
    }
}
