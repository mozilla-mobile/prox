/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import CoreLocation

var travelTimePadding: Double = {
    return RemoteConfigKeys.travelTimePaddingMins.value * 60
}()

var MIN_WALKING_TIME: Int = {
    // Note that this is semantically maximum walking time,
    // rather than minimum walking time (as used throughout the codebase).
    return RemoteConfigKeys.maxWalkingTimeInMins.value
}()

var YOU_ARE_HERE_WALKING_TIME: Int = {
    return RemoteConfigKeys.youAreHereWalkingTimeMins.value
}()

protocol TravelTimesProvider {
    static func travelTime(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, byTransitType transitType: MKDirectionsTransportType, withCompletion completion: @escaping ((TravelTimes?) -> ()))
    static func travelTime(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, byTransitTypes transitTypes: [MKDirectionsTransportType], withCompletion completion: @escaping ((TravelTimes?) -> ()))
    static func canTravelFrom(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, before: Date, withCompletion completion: @escaping (Bool) -> ())
}

var travelTimesProvider = GoogleDirectionsMatrixTravelTimesProvider.self //MKDirectionsTravelTimesProvider.self  //

struct TravelTimes {
    let walkingTime: TimeInterval?
    let drivingTime: TimeInterval?
    let publicTransportTime: TimeInterval?

    func getShortestTravelTime() -> TimeInterval {
        let driveTimePadding: Double = travelTimePadding
        let driveTime = drivingTime ?? (Double.greatestFiniteMagnitude - driveTimePadding)
        return min(walkingTime ?? Double.greatestFiniteMagnitude, driveTime + driveTimePadding )
    }
}
