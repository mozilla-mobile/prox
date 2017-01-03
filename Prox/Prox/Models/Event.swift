/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Firebase
import FirebaseRemoteConfig
import CoreLocation

class Event {
    var id: String
    var placeId: PlaceKey
    var description: String
    var startTime: Date
    var endTime: Date?
    var url: String?
    var coordinates: CLLocationCoordinate2D

    private static var eventStartNotificationInterval: TimeInterval = {
        return RemoteConfigKeys.eventStartNotificationInterval.value * 60
    }()

    private static var minTimeFromEndOfEventForNotificationMins: TimeInterval = {
        return RemoteConfigKeys.minTimeFromEndOfEventForNotificationMins.value * 60
    }()

    private static var eventAboutToStartInterval: TimeInterval = {
        return RemoteConfigKeys.eventAboutToStartIntervalMins.value * 60
    }()
    private static var eventAboutToEndInterval: TimeInterval = {
        return RemoteConfigKeys.eventAboutToEndIntervalMins.value * 60
    }()

    private lazy var eventAboutToStartCardString: String = {
        return self.formatEventString(string: RemoteConfigKeys.eventAboutToStartCardString.value)
    }()

    private lazy var eventAboutToEndCardString: String = {
        return self.formatEventString(string: RemoteConfigKeys.eventAboutToEndCardString.value)
    }()

    private lazy var upcomingEventCardString: String =  {
        return self.formatEventString(string: RemoteConfigKeys.upcomingEventCardString.value)
    }()

    private lazy var ongoingEventCardString: String = {
        return self.formatEventString(string: RemoteConfigKeys.ongoingEventCardString.value)
    }()

    private lazy var endingEventCardString: String = {
        return self.formatEventString(string: RemoteConfigKeys.endingEventCardString.value)
    }()

    var notificationString: String? {
        let now = Date()
        if isUpcomingEvent(currentTime: now) {
            return formatEventString(string: RemoteConfigKeys.upcomingEventNotificationString.value)
        }

        if isOngoingEvent(currentTime: now) {
            return formatEventString(string: RemoteConfigKeys.ongoingEventNotificationString.value)
        }

        if isEndingEvent(currentTime: now) {
            return formatEventString(string: RemoteConfigKeys.endingEventNotificationString.value)
        }

        return nil
    }

    var placeDisplayString: String? {
        let now = Date()
        if isAboutToStart(currentTime: now) {
            return eventAboutToStartCardString
        }

        if isAboutToEnd(currentTime: now) {
            return eventAboutToEndCardString
        }

        if isUpcomingEvent(currentTime: now) {
            return upcomingEventCardString
        }

        if isOngoingEvent(currentTime: now) {
            return ongoingEventCardString
        }

        if isEndingEvent(currentTime: now) {
            return formatEventString(string: RemoteConfigKeys.endingEventCardString.value)
        }

        return nil
    }

    init(id: String, placeId: String, coordinates: CLLocationCoordinate2D, description: String, url: String?, startTime: Date, endTime: Date?) {
        self.id = id
        self.placeId = placeId
        self.coordinates = coordinates
        self.description = description
        self.url = url
        self.startTime = startTime
        self.endTime = endTime
    }

    convenience init?(fromDictionary value: NSDictionary) {
        guard let id = value["id"] as? String,
            let placeId = (value["placeId"] as? String),
            let coords = value["coordinates"] as? [String:String],
            let latStr = coords["lat"], let lat = Double(latStr),
            let lngStr = coords["lng"], let lng = Double(lngStr),
            let description = value["description"] as? String,
            let localStartTimeString = value["localStartTime"] as? String else {
                print("lol dropping event: missing data, id, placeId, description, start time \(value)")
                return nil
        }

        // TODO: remove the double date formatting when the server has sorted out the mismatched dates
        let eventfulDateFormatter = DateFormatter()
        eventfulDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        let gCalDateFormatter = DateFormatter()
        gCalDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssz"

        var localStartTime: Date

        if let startTime = eventfulDateFormatter.date(from: localStartTimeString) {
            localStartTime = startTime
        } else if let startTime = gCalDateFormatter.date(from: localStartTimeString) {
            localStartTime = startTime
        } else {
            NSLog("Dropping event due to incorrectly formatted start timestamp %@", localStartTimeString)
            return nil
        }

        let localEndTime: Date?

        if let localEndTimeString = value["localEndTime"] as? String {
            if let endTime = eventfulDateFormatter.date(from: localEndTimeString) {
                localEndTime = endTime
            } else if let endTime = gCalDateFormatter.date(from: localEndTimeString) {
                localEndTime = endTime
            } else {localEndTime = nil }
        } else { localEndTime = nil }


        self.init(id: id,
                  placeId: placeId,
                  coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                  description: description,
                  url:value["url"] as? String,
                  startTime: localStartTime,
                  endTime: localEndTime)
    }

    convenience init?(fromFirebaseSnapshot data: FIRDataSnapshot) {
        guard data.exists(), data.hasChildren(),
            let value = data.value as? NSDictionary else {
                return nil
        }

        self.init(fromDictionary: value)
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
    internal func isValidEvent() -> Bool {
        return shouldShowEvent(withStartTime: startTime, endTime: endTime, timeIntervalBeforeStartOfEvent: Event.eventStartNotificationInterval, timeIntervalBeforeEndOfEvent: Event.minTimeFromEndOfEventForNotificationMins, atCurrentTime: Date())
    }

    internal func shouldShowEvent(withStartTime startTime: Date, endTime: Date?, timeIntervalBeforeStartOfEvent startTimeInterval: TimeInterval, timeIntervalBeforeEndOfEvent endTimeInterval: TimeInterval, atCurrentTime currentTime: Date) -> Bool {
        if isFutureEvent(currentTime: currentTime) {
            let validFutureEvent = (startTime - startTimeInterval) <= currentTime
            if !validFutureEvent {
                NSLog("\(description) is a future event but (\(startTime) - \(startTimeInterval)) <= \(currentTime)")
            }
            return validFutureEvent
        }
        guard let endTime = endTime else {
            NSLog("\(description) is not a future event and has no end time")
            return false
        }

        let isOngoing = currentTime < endTime - endTimeInterval
        if !isOngoing {
            NSLog("\(description) is not an ongoing event because (\(currentTime) >= \(endTime)) - \(endTimeInterval)")
        }
        return isOngoing
    }

    func arrivalByTime() -> Date {
        let eventEndTimeArrivalInterval = Event.minTimeFromEndOfEventForNotificationMins
        let arrivalByTime: Date
        if let endTime = self.endTime {
            arrivalByTime = endTime - eventEndTimeArrivalInterval
        } else {
            arrivalByTime = startTime
        }

        return arrivalByTime
    }

    private func isAboutToStart(currentTime: Date) -> Bool {
        return isUpcomingEvent(currentTime: currentTime) && (startTime - Event.eventAboutToStartInterval) <= currentTime
    }

    private func isUpcomingEvent(currentTime: Date) -> Bool {
        return isFutureEvent(currentTime: currentTime) && (startTime - Event.eventStartNotificationInterval) <= currentTime
    }

    private func isOngoingEvent(currentTime: Date) -> Bool {
        guard let endTime = endTime else {
            return false
        }
        return currentTime < (endTime - (Event.minTimeFromEndOfEventForNotificationMins + Event.eventStartNotificationInterval))
    }

    private func isAboutToEnd(currentTime: Date) -> Bool {
        guard let endTime = endTime else {
            return false
        }
        return isEndingEvent(currentTime: currentTime) && (endTime - Event.eventAboutToEndInterval) <= currentTime
    }

    private func isEndingEvent(currentTime: Date) -> Bool {
        guard let endTime = endTime else {
            return false
        }
        let lastNotificationTime = endTime - Event.minTimeFromEndOfEventForNotificationMins
        return currentTime > lastNotificationTime - Event.eventStartNotificationInterval && currentTime < lastNotificationTime
    }

    private func isFutureEvent(currentTime: Date) -> Bool {
        return currentTime < startTime
    }

    private func formatEventString(string: String) -> String {
        var eventString = replaceEventName(string: string)
        eventString = replaceStartTime(string: eventString)
        eventString = replaceEndTime(string: eventString)
        eventString = replaceTimeToStart(string: eventString)
        eventString = replaceTimeToEnd(string: eventString)

        return eventString
    }

    private func replaceEventName( string: String) -> String {
        return string.replacingOccurrences(of: "{event_name}", with: description)
    }

    private func replaceTimeToStart(string: String) -> String {
        let now = Date()
        let timeToEvent = startTime.timeIntervalSince(now)
        let timeString = timeToEvent.asHoursAndMinutesString()
        return string.replacingOccurrences(of: "{time_to_start}", with: "\(timeString)")
    }

    private func replaceTimeToEnd(string: String) -> String {
        guard let endTime = endTime else { return string.replacingOccurrences(of: "{time_to_end}", with: "unknown") }
        let now = Date()
        let timeToEvent = endTime.timeIntervalSince(now)
        let timeString = timeToEvent.asHoursAndMinutesString()
        return string.replacingOccurrences(of: "{time_to_end}", with: "\(timeString)")
    }

    private func replaceStartTime(string: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return string.replacingOccurrences(of: "{start_time}", with: formatter.string(from: startTime))
    }

    private func replaceEndTime(string: String) -> String {
        guard let endTime = endTime else { return string.replacingOccurrences(of: "{end_time}", with: "unknown") }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return string.replacingOccurrences(of: "{end_time}", with: formatter.string(from: endTime))
    }
}
