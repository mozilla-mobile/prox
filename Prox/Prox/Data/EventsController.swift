/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

import FirebaseRemoteConfig

protocol EventsProviderDelegate: class {
    func eventsProvider(_ eventsProvider: EventsProvider, didUpdateEvents: [Event])
    func eventsProvider(_ eventsProvider: EventsProvider, didError error: Error)
}

class EventsProvider {
    lazy var eventsDatabase: EventsDatabase = FirebaseEventsDatabase()

    private lazy var radius: Double = {
        let key = RemoteConfigKeys.eventSearchRadiusInKm
        return FIRRemoteConfig.remoteConfig()[key].numberValue!.doubleValue
    }()

    func getEvents(forLocation location: CLLocation, completion: @escaping (([Event]?, Error?) -> Void)) {
        return eventsDatabase.getEvents(forLocation: location, withRadius: radius).upon { results in
            let events = results.flatMap { $0.successResult() }.filter { self.shouldShowEvent(event: $0, forLocation: location) }
            DispatchQueue.main.async {
                completion(events, nil)
            }
        }
    }

    func getPlacesWithEvents(forLocation location: CLLocation, usingPlacesDatabase placesDatabase: PlacesDatabase, completion: @escaping ([Place]) -> ()) {
        return eventsDatabase.getPlacesWithEvents(forLocation: location, withRadius: radius, withPlacesDatabase: placesDatabase, filterEventsUsing: self.shouldShowEvent).upon { results in
            let places = results.flatMap { $0.successResult() }
            completion(places)
        }
    }

    private func shouldShowEvent(event: Event, forLocation location: CLLocation) -> Bool {
        return true
    }
}
