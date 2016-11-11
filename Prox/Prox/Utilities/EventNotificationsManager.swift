/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import CoreLocation

class EventNotificationsManager {

    fileprivate var eventFetchCompletionHandler: (([Event]?, Error?) -> Void)?
    fileprivate var shouldFetchEvents: Bool {
        guard var lastLocationFetchTime = timeOfLastLocationUpdate else {
            return false
        }
        let now = Date()
        lastLocationFetchTime += AppConstants.minimumTimeAtLocationBeforeFetchingEvents
        return lastLocationFetchTime < now
    }

    fileprivate var timeOfLastLocationUpdate: Date? {
        return UserDefaults.standard.value(forKey: AppConstants.timeOfLastLocationUpdateKey) as? Date
    }

    fileprivate lazy var eventsController: EventsController = {
        let controller = EventsController()
        controller.delegate = self
        return controller
    }()

    func fetchEvents(forLocation location: CLLocation, completion: (([Event]?, Error?) -> Void)? = nil) {
        if shouldFetchEvents {
            eventFetchCompletionHandler = completion
            print("Should fetch events")
            eventsController.getEvents(forLocation: location)
            return
        }
        print("Should not fetch events")
        completion?(nil, nil)
    }
}

extension EventNotificationsManager: EventsControllerDelegate {
    func eventController(_ eventController: EventsController, didUpdateEvents events: [Event]) {
        eventFetchCompletionHandler?(events, nil)
    }

    func eventController(_ eventController: EventsController, didError error: Error) {
        eventFetchCompletionHandler?(nil, error)
    }
}
