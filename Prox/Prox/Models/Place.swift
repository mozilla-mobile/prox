/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Firebase
import CoreLocation

private let PROVIDERS_PATH = "providers/"
private let YELP_PATH = PROVIDERS_PATH + "yelp"

class Place: Hashable {

    var hashValue : Int {
        get {
            return id.hashValue
        }
    }

    private let transitTypes: [MKDirectionsTransportType] = [.automobile, .walking]

    let id: String

    let name: String
    let summary: String
    let latLong: CLLocationCoordinate2D

    // Optional values.
    let categories: [String]?
    let url: String?

    let address: String?

    let yelpProvider: ReviewProvider?
    let tripAdvisorProvider: ReviewProvider?

    let photoURLs: [String]?

    /*
     * Notes:
     *   - Times are 24hr, e.g. 1400 for 2pm
     *   - Times are in the timezone of the place
     *   - "end" < "start" if a location is open overnight
     *   - An entry for DayOfWeek will be missing if a location is not open that day
     */
    let hours: [DayOfWeek:OpenHours]?

    var travelTimes: TravelTimes?


    init(id: String, name: String, summary: String, latLong: CLLocationCoordinate2D, categories: [String]? = nil, url: String? = nil, address: String? = nil, yelpProvider: ReviewProvider?  = nil, tripAdvisorProvider: ReviewProvider? = nil, photoURLs: [String]? = nil, hours: [DayOfWeek: OpenHours]? = nil) {
        self.id = id
        self.name = name
        self.summary = summary
        self.latLong = latLong
        self.categories = categories
        self.url = url
        self.address = address
        self.yelpProvider = yelpProvider
        self.tripAdvisorProvider = tripAdvisorProvider
        self.photoURLs = photoURLs
        self.hours = hours
    }

    convenience init?(fromFirebaseSnapshot data: FIRDataSnapshot) {
        guard data.exists(), data.hasChildren(),
                let value = data.value as? NSDictionary,
                let summary = value["description"] as? String ?? value["pullQuote"] as? String,
                let id = value["id"] as? String,
                let name = value["id"] as? String, // TODO: change to name from id
                let coords = value["coordinates"] as? [String:Double],
                let lat = coords["lat"], let lon = coords["lon"] else {
            return nil
        }

        self.init(id: id,
                  name: name,
                  summary: summary,
                  latLong: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                  categories: [String](),
                  url: "",
                  address: (value["address"] as? [String])?.joined(separator: " "),
                  yelpProvider: ReviewProvider(fromFirebaseSnapshot: data.childSnapshot(forPath: YELP_PATH)),
                  tripAdvisorProvider: nil,
                  photoURLs: value["images"] as? [String],
                  hours: nil)
    }


    static func ==(lhs: Place, rhs: Place) -> Bool {
        return lhs.id == rhs.id
    }
}

enum DayOfWeek: Int {
    case monday = 0 // matches server representation
    case tuesday, wednesday, thursday, friday
    case saturday, sunday
}

struct OpenHours {
    let startTime: Int
    let endTime: Int
}
