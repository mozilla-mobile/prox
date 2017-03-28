/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Alamofire
import Deferred

private let defaultRadiusKm = 2
private let defaultLogo = URL(string: "http://www.m-magazine.co.uk/wp-content/uploads/2016/08/Eventbrite-logo-2016.jpg")!

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

            // The specified "Expansions" will let us download additional models;
            // by default, we just receive the ID. More info:
            //   https://www.eventbrite.com/developer/v3/api_overview/expansions/
            "expand": "logo,venue,format,category", // todo: choose which ones we want; each one can slow down the request.
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

    /// Create an event from text in the Eventbrite Event format:
    ///   https://www.eventbrite.com/developer/v3/response_formats/event/#ebapi-std:format-event
    fileprivate init?(fromEventbriteJSON json: [String: Any]) {
        guard let name = text(fromMultipartText: json["name"]),
            let venue = json["venue"] as? [String: Any],
            let address = venue["address"] as? [String: Any],
            let latitude = CLLocationDegrees(address["latitude"] as? String ?? ""),
            let longitude = CLLocationDegrees(address["longitude"] as? String ?? ""),

            let startDateObj = json["start"] as? [String: String],
            let startDate = localDate(fromDatetimeTZ: startDateObj),
            let endDateObj = json["end"] as? [String: String],
            let endDate = localDate(fromDatetimeTZ: endDateObj) else { return nil }

        let categoryObj = json["category"] as? [String: Any]
        let subcategoryObj = json["subcategory"] as? [String: Any]
        let formatObj = json["format"] as? [String: Any]

        let logo = json["logo"] as? [String: Any]
        let fullsizeLogo = logo?["original"] as? [String: Any]
        let fullsizeLogoURL = URL(string: fullsizeLogo?["url"] as? String ?? "") ?? defaultLogo

        self.init(
            name: name,
            description: text(fromMultipartText: json["description"]),
            url: URL(string: json["url"] as? String ?? ""),

            category: categoryObj?["short_name"] as? String,
            subcategory: subcategoryObj?["name"] as? String, // there is no short_name. TODO: haven't been not nil yet
            format: formatObj?["short_name"] as? String,

            start: startDate,
            end: endDate,

            location: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            photoURLs: [fullsizeLogoURL],

            venueName: venue["name"] as? String,
            isOnline: json["online_event"] as? Bool,
            isFree: json["is_free"] as? Bool,
            capacity: json["capacity"] as? Int,

            isSeries: json["is_series"] as? Bool,
            isSeriesParent: json["is_series_parent"] as? Bool
        )
    }
}

/// Extracts the text field from Eventbrite's multipart-text data type:
///   https://www.eventbrite.com/developer/v3/response_formats/basic/#ebapi-std:format-multipart-text
private func text(fromMultipartText input: Any?) -> String? {
    let multipartText = input as? [String: String]
    return multipartText?["text"]
}

// ISO8601 via http://stackoverflow.com/a/28016614
private let localDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)

    // ISO8601 has multiple formats for timezone - this happens to be the one that works for local eventbrite.
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return formatter
}()

/// Extracts a local Date obj from Eventbrite's datetime-tz data type:
///   https://www.eventbrite.com/developer/v3/response_formats/basic/#ebapi-std:format-datetime-tz
private func localDate(fromDatetimeTZ json: [String: String]) -> Date? {
    return localDateFormatter.date(from: json["local"] ?? "")
}
