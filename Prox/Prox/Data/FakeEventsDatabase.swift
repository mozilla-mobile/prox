/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Deferred

class FakeEventsDatabase: EventsDatabase {

    internal func getEvents(forLocation location: CLLocation, withRadius radius: Double) -> Future<[DatabaseResult<Event>]> {
        let deferred = Deferred<[DatabaseResult<Event>]>()
        var eventResults: [DatabaseResult<Event>] = [DatabaseResult<Event>]()
        eventResults.append(DatabaseResult.succeed(value: getFakeEvent()))
        deferred.fill(with: eventResults)
        return Future(deferred)
    }

    func getPlacesWithEvents(forLocation location: CLLocation, withRadius radius: Double, withPlacesDatabase placesDatabase: PlacesDatabase) -> Future<[DatabaseResult<Place>]> {
        return Future( Deferred<[DatabaseResult<Place>]>())
    }

    private func getFakeEvent() -> Event {
        return Event(id: "fake-event", placeId: "fake-place", description: "Fake Event at Fake Place!", url: "https://mozilla.org", startTime: Date(), endTime: nil)
    }
}
