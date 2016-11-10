/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Deferred
import CoreLocation

/*
 * A listing of all the places we'd want to show a user.
 */
protocol PlacesDatabase {
    func getPlaces(forLocation location: CLLocation, withRadius: Double) -> Future<[DatabaseResult<Place>]>
}
