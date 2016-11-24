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

    private lazy var eventStartNotificationInterval: TimeInterval = {
        return RemoteConfigKeys.eventStartNotificationInterval.value * 60
    }()

    private lazy var minTimeFromEndOfEventForNotificationMins: TimeInterval = {
        return RemoteConfigKeys.minTimeFromEndOfEventForNotificationMins.value * 60.0
    }()

    func event(forKey key: String, completion: @escaping (Event?) -> ()) {
        eventsDatabase.getEvent(withKey: key).upon { completion($0.successResult() )}
    }

    func getEventsForNotifications(forLocation location: CLLocation, completion: @escaping (([Event]?, Error?) -> Void)) {
        return eventsDatabase.getEvents(forLocation: location, withRadius: radius).upon { results in
            let events = results.flatMap { $0.successResult() }.filter { self.isValidEvent(event: $0) }
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

    /**
    * Event Notification criteria
    * paddedTravelTime = time to drive to event + 10 minutes
    * IF event HAS eventEndTime
    * IF currentTime <= (eventStartTime - 1 hour) AND currentTime < (eventEndTime - (1 hour + paddedTravelTime )) THEN notify
    * ELSE
    * IF currentTime <= (eventStartTime - paddedTravelTime) THEN notify
    * Travel time will be calculated later, just before when we display the event
    **/

    internal func isValidEvent(event: Event) -> Bool {
        return shouldShowEvent(withStartTime: event.startTime, endTime: event.endTime, timeIntervalBeforeStartOfEvent: eventStartNotificationInterval, timeIntervalBeforeEndOfEvent: minTimeFromEndOfEventForNotificationMins, atCurrentTime: Date())
    }

    internal func shouldShowEvent(withStartTime startTime: Date, endTime: Date?, timeIntervalBeforeStartOfEvent startTimeInterval: TimeInterval, timeIntervalBeforeEndOfEvent endTimeInterval: TimeInterval, atCurrentTime currentTime: Date) -> Bool {
        if isFutureEvent(eventStartTime: startTime, currentTime: currentTime)
            && (startTime - startTimeInterval) <= currentTime {
            return true
        }
        guard let endTime = endTime else {
            return false
        }
        return currentTime < endTime - endTimeInterval
    }

    internal func isFutureEvent(eventStartTime: Date, currentTime: Date) -> Bool {
        return currentTime < eventStartTime
    }
}
