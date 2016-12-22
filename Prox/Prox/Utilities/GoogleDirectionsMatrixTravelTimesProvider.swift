/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import AFNetworking

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

    fileprivate static func distanceMatrixURL(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, byTransportType transportType: String) -> URL? {
        guard let urlString = directionsURL else { return nil }

        let distanceMatrixURL = NSString(format: urlString as NSString, "\(fromLocation.latitude),\(fromLocation.longitude)", "\(toLocation.latitude),\(toLocation.longitude)", transportType) as String
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

    static func travelTime(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, byTransitType transitType: MKDirectionsTransportType = .any, withCompletion completion: @escaping ((TravelTimes?) -> ())) {
        guard let url = distanceMatrixURL(fromLocation: fromLocation, toLocation: toLocation, byTransportType: mapTransportTypeToMode(transportType: transitType)) else { return completion(nil) }
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
                travelTime = TravelTimes(walkingTime: nil, drivingTime: value, publicTransportTime: nil)
            case MKDirectionsTransportType.transit:
                travelTime = TravelTimes(walkingTime: nil, drivingTime: nil, publicTransportTime: value)
            default:
                travelTime = TravelTimes(walkingTime: value, drivingTime: nil, publicTransportTime: nil)
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
                    return completion(TravelTimes(walkingTime: walking, drivingTime: driving, publicTransportTime: transit))
                }
            }
        }
    }

    static func canTravelFrom(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, before: Date, withCompletion completion: @escaping (Bool) -> ()) {
        completion(true)
    }
}
