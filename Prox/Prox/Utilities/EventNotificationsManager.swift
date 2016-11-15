/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import CoreLocation

class EventNotificationsManager {

    fileprivate var shouldFetchEvents: Bool {
        guard var lastLocationFetchTime = timeOfLastLocationUpdate else {
            return false
        }
        let now = Date()
        lastLocationFetchTime += AppConstants.minimumIntervalAtLocationBeforeFetchingEvents
        return lastLocationFetchTime < now
    }

    fileprivate var timeOfLastLocationUpdate: Date? {
        return UserDefaults.standard.value(forKey: AppConstants.timeOfLastLocationUpdateKey) as? Date
    }

    fileprivate lazy var eventsController = EventsController()

    func fetchEvents(forLocation location: CLLocation, completion: @escaping (([Event]?, Error?) -> Void)) {
        if shouldFetchEvents {
            print("Should fetch events")
            eventsController.getEvents(forLocation: location, completion: completion)
            return
        }
        print("Should not fetch events")
        completion(nil, nil)
    }
}
