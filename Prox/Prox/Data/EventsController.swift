/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

protocol EventsControllerDelegate: class {
    func eventController(_ eventController: EventsController, didUpdateEvents: [Event])
    func eventController(_ eventController: EventsController, didError error: Error)
}

class EventsController {
    lazy var eventsDatabase: EventsDatabase = FakeEventsDatabase()

    weak var delegate: EventsControllerDelegate?

    func getEvents(forLocation location: CLLocation) {
        return eventsDatabase.getEvents(forLocation: location).upon { results in
            let events = results.flatMap { $0.successResult() }
            DispatchQueue.main.async {
                self.delegate?.eventController(self, didUpdateEvents: events)
            }
        }
    }
}
