/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import AFNetworking
import Deferred

class GoogleDirectionsMatrixTravelTimesProvider: TravelTimesProvider {

    fileprivate static var directionsURL: String? = {
        guard let apiPlistPath = Bundle.main.path(forResource: AppConstants.APIKEYS_PATH, ofType: "plist"),
        let keysDict = NSDictionary(contentsOfFile: apiPlistPath) as? [String: String]else {
            fatalError("Unable to load API keys plist. Did you include the API keys plist file?")
        }

        guard let apiKey = keysDict["GoogleDistanceMatrix"]?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) else {
            NSLog("No Google Direction API key! Unable to fetch direction.")
            return nil
        }
        return "https://maps.googleapis.com/maps/api/distancematrix/json?origins=%@&destinations=%@&mode=%@&key=" + apiKey
    }()

    fileprivate static func distanceMatrixURL(fromLocation: CLLocationCoordinate2D, toLocations: [CLLocationCoordinate2D], byTransportType transportType: String) -> URL? {
        guard let urlString = directionsURL else { return nil }

        let toLocationString = toLocations.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "%7C")

        let distanceMatrixURL = NSString(format: urlString as NSString, "\(fromLocation.latitude),\(fromLocation.longitude)", toLocationString, transportType) as String
        return URL(string: distanceMatrixURL)
    }

    fileprivate static func mapTransportTypeToMode(transportType: MKDirectionsTransportType) -> String {
        switch transportType {
        case MKDirectionsTransportType.automobile:
            return "driving"
        case MKDirectionsTransportType.transit:
            return "transit"
        default:
            return "walking"
        }
    }

    fileprivate static var sessionManager: AFURLSessionManager = {
        let configuration = URLSessionConfiguration.default
        return AFURLSessionManager(sessionConfiguration: configuration)
    }()

    static func travelTimes(fromLocation: CLLocationCoordinate2D, toLocations: [PlaceKey : CLLocationCoordinate2D], byTransitType transitType: MKDirectionsTransportType) -> Deferred<DatabaseResult<[TravelTimes]>> {
        NSLog("Calculating travel times for \(toLocations)")
        let locations = Array(toLocations.values)
        var index = 0
        var fetchSize = min(locations.endIndex, 25) - 1
        var expectedResponseCount = 0
        var allTravelTimes = [TravelTimes]()
        let deferred = Deferred<DatabaseResult<[TravelTimes]>>()
        while index < locations.endIndex {
            let subarray = Array(locations[index...fetchSize])

            if let url = distanceMatrixURL(fromLocation: fromLocation, toLocations: subarray, byTransportType: mapTransportTypeToMode(transportType: transitType)) {
                let request = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.returnCacheDataElseLoad, timeoutInterval: 2 * AppConstants.ONE_MINUTE)
                let dataTask = sessionManager.dataTask(with: request) { response, object, error in
                    expectedResponseCount -= 1
                    if error != nil {
                        NSLog("Error fetching Google Distance Matrix request \(error)")
                        return
                    }

                    guard let responseObject = object as? [String: Any],
                        let row = (responseObject["rows"] as? [[String: Any]])?.first,
                        let elements = row["elements"] as? [[String: Any]]
                        else {
                            NSLog("Error parsing Google Distance Matrix Response \(object)")
                            return
                    }
                    for (index, result) in elements.enumerated() {
                        guard index < subarray.count,
                        let duration = result["duration"] as? [String: Any],
                        let value = duration["value"] as? Double else {
                            continue
                        }

                        let latLon = subarray[index]
                        let key = (toLocations as NSDictionary).allKeys(for: latLon).first as? PlaceKey

                        let travelTime: TravelTimes
                        switch transitType {
                        case MKDirectionsTransportType.automobile:
                            travelTime = TravelTimes(origin: fromLocation, destination: latLon, destinationPlaceKey: key, walkingTime: nil, drivingTime: value, publicTransportTime: nil)
                        case MKDirectionsTransportType.transit:
                            travelTime = TravelTimes(origin: fromLocation, destination: latLon, destinationPlaceKey: key, walkingTime: nil, drivingTime: nil, publicTransportTime: value)
                        default:
                            travelTime = TravelTimes(origin: fromLocation, destination: latLon, destinationPlaceKey: key, walkingTime: value, drivingTime: nil, publicTransportTime: nil)
                        }
                        allTravelTimes.append(travelTime)
                    }
                    if expectedResponseCount == 0 {
                        deferred.fill(with: DatabaseResult.succeed(value: allTravelTimes))
                    }
                }
                
                dataTask.resume()
            }
            index += fetchSize + 1
            fetchSize = min(locations.endIndex, index + 25) - 1
            expectedResponseCount += 1
        }

        return deferred
    }

    static func travelTime(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, byTransitType transitType: MKDirectionsTransportType = .any, withCompletion completion: @escaping ((TravelTimes?) -> ())) {
        guard let url = distanceMatrixURL(fromLocation: fromLocation, toLocations: [toLocation], byTransportType: mapTransportTypeToMode(transportType: transitType)) else { return completion(nil) }
        let request = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.returnCacheDataElseLoad, timeoutInterval: 2 * AppConstants.ONE_MINUTE)
        let dataTask = sessionManager.dataTask(with: request) { response, object, error in
            if error != nil {
                NSLog("Error fetching Google Distance Matrix request \(error)")
                completion(nil)
            }

            guard let responseObject = object as? [String: Any],
                let row = (responseObject["rows"] as? [[String: Any]])?.first,
                let elements = (row["elements"] as? [[String: Any]])?.first,
                let duration = elements["duration"] as? [String: Any],
                let value = duration["value"] as? Double
            else {
                NSLog("Error parsing Google Distance Matrix Response \(object)")
                return completion(nil)
            }

            let travelTime: TravelTimes?
            switch transitType {
            case MKDirectionsTransportType.automobile:
                travelTime = TravelTimes(origin: fromLocation, destination: toLocation, destinationPlaceKey: nil, walkingTime: nil, drivingTime: value, publicTransportTime: nil)
            case MKDirectionsTransportType.transit:
                travelTime = TravelTimes(origin: fromLocation, destination: toLocation, destinationPlaceKey: nil, walkingTime: nil, drivingTime: nil, publicTransportTime: value)
            default:
                travelTime = TravelTimes(origin: fromLocation, destination: toLocation, destinationPlaceKey: nil, walkingTime: value, drivingTime: nil, publicTransportTime: nil)
            }
            completion(travelTime)
        }

        dataTask.resume()
    }

    static func travelTime(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, byTransitTypes transitTypes: [MKDirectionsTransportType], withCompletion completion: @escaping ((TravelTimes?) -> ())) {
        var allTimes = [TravelTimes?]()
        for transportType in transitTypes {
            travelTime(fromLocation: fromLocation, toLocation: toLocation, byTransitType: transportType) { travelTime in
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
        completion(true)
    }
}
