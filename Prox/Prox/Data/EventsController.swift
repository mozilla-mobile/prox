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
        return RemoteConfigKeys.getDouble(forKey: RemoteConfigKeys.eventSearchRadiusInKm)
    }()

    private lazy var eventStartNotificationInterval: Double = {
        return RemoteConfigKeys.getDouble(forKey: RemoteConfigKeys.eventStartNotificationInterval) * 60
    }()

    private lazy var eventStartPlaceInterval: Double = {
        return RemoteConfigKeys.getDouble(forKey: RemoteConfigKeys.eventStartPlaceInterval) * 60
    }()

    func getEventsForNotifications(forLocation location: CLLocation, completion: @escaping (([Event]?, Error?) -> Void)) {
        return eventsDatabase.getEvents(forLocation: location, withRadius: radius).upon { results in
            let events = results.flatMap { $0.successResult() }.filter { self.shouldShowEventForNotifications(event: $0, forLocation: location) }
            DispatchQueue.main.async {
                completion(events, nil)
            }
        }
    }

    func getEventsWithPlaces(forLocation location: CLLocation, usingPlacesDatabase placesDatabase: PlacesDatabase, completion: @escaping ([Place]) -> ()) {
        eventsDatabase.getPlacesWithEvents(forLocation: location, withRadius: radius, withPlacesDatabase: placesDatabase, filterEventsUsing: self.shouldShowEventForPlaces).upon { results in
            let places = results.flatMap { $0.successResult() }
            completion(places)
        }
    }

    private func shouldShowEventForNotifications(event: Event, forLocation location: CLLocation) -> Bool {
        return doesEvent(event: event, startAtCorrectTimeIntervalFromNow: eventStartNotificationInterval)
    }

    private func shouldShowEventForPlaces(event: Event, forLocation location: CLLocation) -> Bool {
        return isEventToday(event: event) && isEventYetToHappen(event: event)
    }

    private func doesEvent(event: Event, startAtCorrectTimeIntervalFromNow timeInterval: TimeInterval) -> Bool {
        // event must start in 1 hour
        let now = Date()
        let maxStartTime = now.addingTimeInterval(timeInterval)
        return event.startTime > now && event.startTime <= maxStartTime
    }

    private func isEventToday(event: Event) -> Bool {
        return Calendar.current.isDateInToday(event.startTime)
    }

    private func isEventYetToHappen(event: Event) -> Bool {
        return Date() < event.startTime
    }
}
