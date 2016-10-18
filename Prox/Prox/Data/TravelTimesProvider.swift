/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import MapKit

struct TravelTimesProvider {

    static func travelTime(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, byTransitType transitType: MKDirectionsTransportType = .any, withCompletion completion: @escaping ((TravelTimes?) -> ())) {

        let directionsRequest = MKDirectionsRequest()
        if #available(iOS 10.0, *) {
            directionsRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: fromLocation))
            directionsRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: toLocation))
        } else {
            directionsRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: fromLocation, addressDictionary: nil))
            directionsRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: toLocation, addressDictionary: nil))
        }

        directionsRequest.departureDate = Date()
        directionsRequest.transportType = transitType

        let directions = MKDirections(request: directionsRequest)
        directions.calculateETA { (response, error) in
            if let error = error {
                dump(error)
                completion(nil)
                return
            }
            guard let response = response else {
                return completion(nil)
            }
            let travelTime: TravelTimes?
            switch response.transportType {
            case MKDirectionsTransportType.automobile:
                travelTime = TravelTimes(walkingTime: nil, drivingTime: response.expectedTravelTime, publicTransportTime: nil)
            case MKDirectionsTransportType.transit:
                travelTime = TravelTimes(walkingTime: nil, drivingTime: nil, publicTransportTime: response.expectedTravelTime)
            case MKDirectionsTransportType.walking:
                travelTime = TravelTimes(walkingTime: response.expectedTravelTime, drivingTime: nil, publicTransportTime: nil)
            default:
                travelTime = nil
            }
            completion(travelTime)
        }
    }
}

struct TravelTimes {
    let walkingTime: Double?
    let drivingTime: Double?
    let publicTransportTime: Double?
}
