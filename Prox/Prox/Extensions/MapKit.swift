/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

extension MKDirectionsTransportType {
    var name: String {
        let returnVal: String
        switch self {
        case MKDirectionsTransportType.walking: returnVal = "walking"
        case MKDirectionsTransportType.automobile: returnVal = "automobile"
        case MKDirectionsTransportType.transit: returnVal = "transit"
        case MKDirectionsTransportType.any: returnVal = "any"
        default: returnVal = "unknown"
        }

        return returnVal
    }
}
