/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Firebase

private let PROVIDERS_PATH = "providers/"
private let YELP_PATH = PROVIDERS_PATH + "yelp"

class Place {

    let name: String
    let categories: [String]
    let url: String
    let summary: String

    let address: String
    let latLong: CLLocationCoordinate2D
    var travelTimeMins: Int {
        // TODO: get travel time – need to be async?
        return -1
    }

    let yelpProvider: ReviewProvider
    let tripAdvisorProvider: ReviewProvider

    let photoURLs: [String]

    // todo: hours

    // TODO: temporary? for testing purposes.
    init(name: String,
         categories: [String],
         url: String,
         summary: String,
         address: String,
         longitude: Double,
         latitude: Double,
         yelpProvider: ReviewProvider,
         tripAdvisorProvider: ReviewProvider,
         photoURLs: [String]) {

        self.name = name
        self.categories = categories
        self.url = url
        self.summary = summary

        self.address = address
        self.latLong = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        self.yelpProvider = yelpProvider
        self.tripAdvisorProvider = tripAdvisorProvider

        self.photoURLs = photoURLs
    }

    init?(fromFirebaseSnapshot data: FIRDataSnapshot) {
        guard data.exists(), data.hasChildren(), let value = data.value as? NSDictionary else {
            return nil
        }

        // TODO: handle missing values more robustly
        self.name = value["id"] as? String ?? "Name unknown"
        self.summary = value["pullQuote"] as? String ?? "Summary unknown"

        self.address = (value["address"] as? [String])?.joined(separator: " ") ?? "Address unknown"
        if let coords = value["coordinates"] as? [String:Double],
            let lat = coords["lat"], let lon = coords["lon"] {
            self.latLong = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            // TODO: if we already have the address, maybe we reverse-geocode & do better. In any
            // case, handle this.
            print("lol unable to find coordinates")
            return nil
        }

        self.yelpProvider = ReviewProvider(fromFirebaseSnapshot: data.childSnapshot(forPath: YELP_PATH)) ??
            ReviewProvider(url: "", rating: -1, reviews: [], totalReviewCount: -1)

        // TODO: get data from DB. Below are currently using default values.
        self.categories = [String]()
        self.url = ""

        self.tripAdvisorProvider = ReviewProvider(url: "", rating: -1, reviews: [], totalReviewCount: -1)

        self.photoURLs = []
    }
}
