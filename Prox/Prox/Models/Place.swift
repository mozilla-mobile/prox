/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

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
}
