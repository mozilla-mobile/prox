/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import FirebaseRemoteConfig
import Foundation
import MapKit
import Deferred

struct MKDirectionsTravelTimesProvider: TravelTimesProvider {

    private static func directions(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, byTransitType transitType: MKDirectionsTransportType) -> MKDirections {

        let directionsRequest = MKDirectionsRequest()
        directionsRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: fromLocation, addressDictionary: nil))
        directionsRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: toLocation, addressDictionary: nil))
        directionsRequest.departureDate = Date()
        directionsRequest.transportType = transitType

        return MKDirections(request: directionsRequest)
    }


    static func travelTimes(fromLocation: CLLocationCoordinate2D, toLocations: [PlaceKey : CLLocationCoordinate2D], byTransitType transitType: MKDirectionsTransportType)  -> Deferred<DatabaseResult<[TravelTimes]>> {
        let deferred = Deferred<DatabaseResult<[TravelTimes]>>()
        var allTimes = [TravelTimes]()
        for (index, location) in Array(toLocations.values).enumerated() {
            self.travelTime(fromLocation: fromLocation, toLocation: location, byTransitType: transitType) { (travelTime) in
                defer {
                    if index == toLocations.count-1 {
                        deferred.fill(with: DatabaseResult.succeed(value: allTimes))
                    }
                }
                guard let time = travelTime else { return }
                allTimes.append(time)
            }
        }
        return deferred
    }

    static func travelTime(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, byTransitType transitType: MKDirectionsTransportType = .any, withCompletion completion: @escaping ((TravelTimes?) -> ())) {
        let directions = self.directions(fromLocation: fromLocation, toLocation: toLocation, byTransitType: transitType)
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
                travelTime = TravelTimes(origin: fromLocation, destination: toLocation, destinationPlaceKey: nil, walkingTime: nil, drivingTime: response.expectedTravelTime, publicTransportTime: nil)
            case MKDirectionsTransportType.transit:
                travelTime = TravelTimes(origin: fromLocation, destination: toLocation, destinationPlaceKey: nil, walkingTime: nil, drivingTime: nil, publicTransportTime: response.expectedTravelTime)
            case MKDirectionsTransportType.walking:
                travelTime = TravelTimes(origin: fromLocation, destination: toLocation, destinationPlaceKey: nil, walkingTime: response.expectedTravelTime, drivingTime: nil, publicTransportTime: nil)
            default:
                travelTime = nil
            }
            completion(travelTime)
        }
    }

    static func travelTime(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, byTransitTypes transitTypes: [MKDirectionsTransportType], withCompletion completion: @escaping ((TravelTimes?) -> ())) {
        var allTimes = [TravelTimes?]()
        for transitType in transitTypes {
            self.travelTime(fromLocation: fromLocation, toLocation: toLocation, byTransitType: transitType) { (travelTime) in
                allTimes.append(travelTime)
                if allTimes.count == transitTypes.count {
                    var walking: TimeInterval?
                    var driving: TimeInterval?
                    var transit: TimeInterval?
                    for time in allTimes {
                        if let walkingTime = time?.walkingTime { walking = walkingTime }
                        else if let drivingTime = time?.drivingTime { driving = drivingTime }
                        else if let transitTime = time?.publicTransportTime { transit = transitTime }
                    }
                    if walking == nil && driving == nil && transit == nil {
                        return completion(nil)
                    }
                    return completion(TravelTimes(origin: fromLocation, destination: toLocation, destinationPlaceKey: nil, walkingTime: walking, drivingTime: driving, publicTransportTime: transit))
                }
            }
        }
    }

    static func canTravelFrom(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, before: Date, withCompletion completion: @escaping (Bool) -> ()) {
        let timeInterval = before.timeIntervalSince(Date())
        travelTimesProvider.travelTime(fromLocation: fromLocation, toLocation: toLocation, byTransitType: [.automobile], withCompletion: { (times) in
            guard let travelTimes = times,
                let drivingTime = travelTimes.drivingTime else {
                    return completion(false)
            }
            completion((drivingTime + travelTimePadding)  <= timeInterval)
        })
    }
}
