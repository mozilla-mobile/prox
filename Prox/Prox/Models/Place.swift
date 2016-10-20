/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Firebase
import CoreLocation

private let PROVIDERS_PATH = "providers/"
private let YELP_PATH = PROVIDERS_PATH + "yelp"

class Place {

    let name: String
    let summary: String
    let latLong: CLLocationCoordinate2D

    // Optional values.
    let categories: [String]?
    let url: String?

    let address: String?
    var travelTimeMins: Int {
        // TODO: get travel time – need to be async?
        return -1
    }

    let yelpProvider: ReviewProvider?
    let tripAdvisorProvider: ReviewProvider?

    let photoURLs: [String]?

    // todo: hours

    init?(fromFirebaseSnapshot data: FIRDataSnapshot) {
        guard data.exists(), data.hasChildren(),
                let value = data.value as? NSDictionary,
                let summary = value["description"] as? String ?? value["pullQuote"] as? String,
                let name = value["id"] as? String, // TODO: change to name from id
                let coords = value["coordinates"] as? [String:Double],
                let lat = coords["lat"], let lon = coords["lon"] else {
            return nil
        }

        self.name = name

        self.summary = summary

        self.latLong = CLLocationCoordinate2D(latitude: lat, longitude: lon)

        self.address = (value["address"] as? [String])?.joined(separator: " ")

        self.yelpProvider = ReviewProvider(fromFirebaseSnapshot: data.childSnapshot(forPath: YELP_PATH))

        // TODO: get data from DB. Below are currently using default values.
        self.categories = [String]()
        self.url = ""

        self.tripAdvisorProvider = nil

        self.photoURLs = []
    }
}
