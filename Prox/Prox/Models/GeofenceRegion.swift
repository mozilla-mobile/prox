/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation


class GeofenceRegion {
    let location: CLLocationCoordinate2D
    let identifier: String
    let radius: CLLocationDistance
    var onEntry: ((GeofenceRegion) -> ())?
    var onExit: ((GeofenceRegion) -> ())?

    private(set) lazy var region: CLCircularRegion = {
        let region = CLCircularRegion(center: self.location, radius: self.radius, identifier: self.identifier)
        region.notifyOnExit = self.onExit != nil
        region.notifyOnEntry = self.onEntry != nil
        return region
    }()

    init(location: CLLocationCoordinate2D, identifier: String, radius: CLLocationDistance, onEntry: ((GeofenceRegion)->())? = nil, onExit: ((GeofenceRegion)->())? = nil) {
        self.location = location
        self.identifier = identifier
        self.radius = radius
        self.onEntry = onEntry
        self.onExit = onExit
    }
}
