/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class PlaceFilter {
    let label: String
    let categories: [String]
    var enabled: Bool

    init(label: String, enabled: Bool, categories: [String]) {
        self.label = label
        self.enabled = enabled
        self.categories = categories
    }

    convenience init(placeFilter: PlaceFilter) {
        self.init(label: placeFilter.label, enabled: placeFilter.enabled, categories: placeFilter.categories)
    }
}
