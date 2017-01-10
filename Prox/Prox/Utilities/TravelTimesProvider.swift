/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import CoreLocation
import Deferred

protocol TravelTimesProvider {
    static func travelTimes(fromLocation: CLLocationCoordinate2D, toLocations: [PlaceKey: CLLocationCoordinate2D], byTransitType transitType: MKDirectionsTransportType) -> Deferred<DatabaseResult<[TravelTimes]>>
    static func travelTime(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, byTransitType transitType: MKDirectionsTransportType, withCompletion completion: @escaping ((TravelTimes?) -> ()))
    static func travelTime(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, byTransitTypes transitTypes: [MKDirectionsTransportType], withCompletion completion: @escaping ((TravelTimes?) -> ()))
    static func canTravelFrom(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, before: Date, withCompletion completion: @escaping (Bool) -> ())
}

var travelTimesProvider = GoogleDirectionsMatrixTravelTimesProvider.self //MKDirectionsTravelTimesProvider.self  //

struct TravelTimes {
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D?
    let destinationPlaceKey: PlaceKey?
    let walkingTime: TimeInterval?
    let drivingTime: TimeInterval?
    let publicTransportTime: TimeInterval?

    func getShortestTravelTime() -> TimeInterval {
        let timeToDriveToLocation = (drivingTime ?? (Double.greatestFiniteMagnitude - AppConstants.travelTimePadding)) + AppConstants.travelTimePadding
        let timeToWalkToLocation = walkingTime ?? Double.greatestFiniteMagnitude
        return min(timeToWalkToLocation, timeToDriveToLocation)
    }
}
