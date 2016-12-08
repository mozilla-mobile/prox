/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class GoogleDirectionsMatrixTravelTimesProvider: TravelTimesProvider {

    fileprivate static var directionsURL: String? = {
        guard let apiPlistPath = Bundle.main.path(forResource: AppConstants.APIKEYS_PATH, ofType: "plist"),
        let keysDict = NSDictionary(contentsOfFile: apiPlistPath) as? [String: String]else {
            fatalError("Unable to load API keys plist. Did you include the API keys plist file?")
        }

        guard let apiKey = keysDict["GoogleDistanceMatrix"] else {
            NSLog("No Google Direction API key! Unable to fetch direction.")
            return nil
        }
        return "https://maps.googleapis.com/maps/api/distancematrix/json?origins=%@&destinations=%@&key=" + apiKey
    }()

    static func travelTime(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, byTransitType transitType: MKDirectionsTransportType = .any, withCompletion completion: @escaping ((TravelTimes?) -> ())) {
    }

    static func travelTime(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, byTransitTypes transitTypes: [MKDirectionsTransportType], withCompletion completion: @escaping ((TravelTimes?) -> ())) {

    }

    static func canTravelFrom(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, before: Date, withCompletion completion: @escaping (Bool) -> ()) {
    }
}
