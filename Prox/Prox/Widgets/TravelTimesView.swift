/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

protocol TravelTimesView {
    // Used to prevent view updates on re-use.
    // Note: I'd use a property but then we have to deal with mutating type BS and its not worth it.
    func getIDForTravelTimesView() -> String?
    func setIDForTravelTimesView(_ id: String)

    func prepareTravelTimesUIForReuse()
    func setTravelTimesUIIsLoading(_ isLoading: Bool)
    func updateTravelTimesUIForResult(_ result: TravelTimesViewResult, durationInMinutes: Int?)
}

enum TravelTimesViewResult {
    case userHere
    case walkingDist, drivingDist
    case noData
}
