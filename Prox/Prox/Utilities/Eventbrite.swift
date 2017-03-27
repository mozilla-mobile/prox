/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Alamofire
import Deferred

private let defaultRadiusKm = 2

private let baseURL = "https://www.eventbriteapi.com/v3/"
private let eventSearchURL = baseURL + "events/search/"

struct Eventbrite {

    private static let oAuthToken: String = {
        return APIKey.EVENTBRITE_ANONYMOUS_OAUTH.get()
    }()

    private static let defaultHeaders = [
            "Authorization": "Bearer \(oAuthToken)",
            "Accept": "application/json",
    ]

    static func searchEvents(near location: CLLocationCoordinate2D, withRadiusKm radiusKm: Int = defaultRadiusKm, keyword: String? = nil, sortType: EventbriteSortType = .Distance) -> Future<DatabaseResult<[Event]>> {
        let params = [
            "q": keyword,
            "sort_by": sortType.name,
            "location.latitude": String(location.latitude),
            "location.longitude": String(location.longitude),
            "location.within": "\(radiusKm)km",
            "start_date.keyword": "this_week", // TODO: choose date range. as arg?
            "expand": "logo,venue,format,category", // todo: choose. can slows down requests.
        ].filterToDict { (_, v) in v != nil } as! [String: String] // non-optional Value needed for request.

        let deferred = Deferred<DatabaseResult<[Event]>>()
        Alamofire.request(eventSearchURL, parameters: params, headers: defaultHeaders).validate().responseJSON { res in
            switch res.result {
            case .failure(let err):
                print("err! \(err)")
                deferred.fill(with: DatabaseResult.fail(withMessage: "Eventbrite.searchEvents failed with: \(err)"))

            case .success(let response):
                if let response = response as? [String: Any],
                        let rawEvents = response["events"] as? [[String: Any]] {
                    let events = rawEvents.flatMap { Event(fromEventbriteJSON: $0) }
                    deferred.fill(with: DatabaseResult.succeed(value: events))
                } else {
                    deferred.fill(with: DatabaseResult.fail(withMessage: "Eventbrite.searchEvents failed: response has unexpected format")) // don't log response to avoid leaking PII.
                }
            }
        }

        return Future(deferred)
    }
}

enum EventbriteSortType: String {
    case Date, DateReverse
    case Distance, DistanceReverse
    case Best, BestReverse

    var name: String {
        let modifiedStr: String
        switch self { // TODO: for reverse, can more generically get from self.rawValue
        case .DateReverse: modifiedStr = "-date"
        case .DistanceReverse: modifiedStr = "-distance"
        case .BestReverse: modifiedStr = "-best"
        default: modifiedStr = rawValue
        }

        return modifiedStr.lowercased(with: Locale(identifier: "en_US"))
    }
}

extension Event {

    init?(fromEventbriteJSON json: [String: Any]) {
        guard let name = text(fromMultipartText: json["name"]) else { return nil }
        self.init(
            name: name,
            description: text(fromMultipartText: json["description"]),
            url: URL(string: json["url"] as? String ?? "")
        )
    }
}

/// Extracts the text field from Eventbrite's multipart-text data type:
///   https://www.eventbrite.com/developer/v3/response_formats/basic/#ebapi-std:format-multipart-text
private func text(fromMultipartText input: Any?) -> String? {
    let multipartText = input as? [String: String]
    return multipartText?["text"]
}
