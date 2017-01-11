/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Deferred

protocol EventsDatabase {
    func getEvents(forLocation location: CLLocation, withRadius radius: Double, isBackground: Bool) -> Future<[DatabaseResult<Event>]>
    func getPlacesWithEvents(forLocation location: CLLocation, withRadius radius: Double, withPlacesDatabase placesDatabase: PlacesDatabase, filterEventsUsing eventFilter: @escaping (Event) -> Bool) -> Future<[DatabaseResult<Place>]>
    func getEvent(withKey key: String) -> Deferred<DatabaseResult<Event>>
}
