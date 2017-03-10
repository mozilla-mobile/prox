/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import GoogleMaps

/// The default icon for places - we keep a reference for re-use. Motivation:
///
/// via https://developers.google.com/maps/documentation/ios-sdk/marker#use_the_markers_icon_property :
/// If you are creating several markers with the same image, use the same instance of UIImage for
/// each of the markers. This helps improve the performance of your application when displaying many markers.
private let placeDefaultIcon = #imageLiteral(resourceName: "icon_map_inactive")

/// The selected icon for places - we keep a reference for re-use. For motivation, see `placeMarkerIcon`.
private let placeSelectedIcon = #imageLiteral(resourceName: "icon_map_active")

extension GMSMarker {

    convenience init(for place: Place) {
        self.init(position: place.latLong)
        userData = place.id
        title = place.name
        snippet = place.yelpProvider.description
        icon = placeDefaultIcon
    }

    func updateMarker(forSelected isSelected: Bool) {
        icon = isSelected ? placeSelectedIcon : placeDefaultIcon
    }
}
