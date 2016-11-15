/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import CoreLocation

class EventNotificationsManager {

    fileprivate var shouldFetchEvents: Bool {
        guard let eventFetchStartTime = eventFetchStartTime else {
            return false
        }
        let now = Date()
        return eventFetchStartTime < now
    }

    fileprivate var eventFetchStartTime: Date? {
        guard let lastLocationFetchTime = timeOfLastLocationUpdate else {
            return nil
        }
        return lastLocationFetchTime.addingTimeInterval(AppConstants.minimumIntervalAtLocationBeforeFetchingEvents)
    }

    fileprivate var timeOfLastLocationUpdate: Date? {
        return UserDefaults.standard.value(forKey: AppConstants.timeOfLastLocationUpdateKey) as? Date
    }

    fileprivate lazy var eventsProvider = EventsProvider()

    func sendEventNotifications(forLocation location: CLLocation, completion: @escaping (([Event]?, Error?) -> Void)) {
        if shouldFetchEvents {
            print("Should fetch events")
            eventsProvider.getEventsForNotifications(forLocation: location, completion: completion)
            return
        }
        print("Should not fetch events")
        completion(nil, nil)
    }
}
