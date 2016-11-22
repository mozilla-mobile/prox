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
        return RemoteConfigKeys.eventSearchRadiusInKm.value
    }()

    private lazy var eventStartNotificationInterval: TimeInterval = {
        return RemoteConfigKeys.eventStartNotificationInterval.value * 60
    }()

    private lazy var eventStartPlaceInterval: TimeInterval = {
        return RemoteConfigKeys.eventStartPlaceInterval.value * 60
    }()

    private lazy var maxEventDuration: TimeInterval = {
        return RemoteConfigKeys.maxEventDurationForNotificationsMins.value * 60.0
    }()

    private lazy var minTimeFromEndOfEventForNotificationMins: TimeInterval = {
        return RemoteConfigKeys.minTimeFromEndOfEventForNotificationMins.value * 60.0
    }()

    func event(forKey key: String, completion: @escaping (Event?) -> ()) {
        eventsDatabase.getEvent(withKey: key).upon { completion($0.successResult() )}
    }

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

    internal func shouldShowEventForNotifications(event: Event, forLocation location: CLLocation) -> Bool {
        let now = Date()
        return isValidFutureEvent(event: event, currentTime: now, forNotifications: true) || isValidCurrentEvent(event: event, currentTime: now, forNotifications: true)
    }

    internal func shouldShowEventForPlaces(event: Event, forLocation location: CLLocation) -> Bool {
        let now = Date()
        return isValidFutureEvent(event: event, currentTime: now) || isValidCurrentEvent(event: event, currentTime: now)
    }

    internal func isValidFutureEvent(event: Event, currentTime: Date, forNotifications: Bool = false) -> Bool {
        let startTimeInterval = forNotifications ? eventStartNotificationInterval : eventStartPlaceInterval
        return isEventToday(event: event) && isFutureEvent(event: event, currentTime: currentTime) && isTime(time: event.startTime, withinTimeInterval: startTimeInterval, fromTime: currentTime)
    }

    internal func isValidCurrentEvent(event: Event, currentTime: Date, forNotifications: Bool = false) -> Bool {
        guard isCurrentEvent(event: event, currentTime: currentTime), let endTime = event.endTime else { return false }

        return doesEvent(event: event, lastLessThan: maxEventDuration) || isTime(time: currentTime, withinTimeInterval: -minTimeFromEndOfEventForNotificationMins, fromTime: endTime)
    }

    internal func isTime(time: Date, withinTimeInterval timeInterval: TimeInterval, fromTime startTime: Date) -> Bool {
        // event must start in specified time interval
        let maxStartTime = startTime + timeInterval
        return time <= maxStartTime
    }

    private func isEventToday(event: Event) -> Bool {
        return Calendar.current.isDateInToday(event.startTime)
    }

    internal func isFutureEvent(event: Event, currentTime: Date) -> Bool {
        return currentTime < event.startTime
    }

    internal func isCurrentEvent(event: Event, currentTime: Date) -> Bool {
        // if we have no end time then we don't want to treat this as a current event
        // because we have no idea if the event is still running
        guard currentTime >= event.startTime,
            let endTime = event.endTime else {
            return false
        }

        return currentTime <= endTime
    }

    internal func doesEvent(event: Event, lastLessThan maxDuration: TimeInterval) -> Bool {
        guard let endTime = event.endTime else { return false }
        let eventDuration = endTime.timeIntervalSince(event.startTime)
        return eventDuration <= maxDuration
    }
}
