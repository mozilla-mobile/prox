/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

private let idPrefix = "proxevent-"

struct Event {

    let name: String
    //    let logo: UIImage?
    let description: String?
    let url: URL?
    //    let start: Date?
    //    let end: Date?

    // TODO: other things we might care about.
    // category_id, format_id, subcategory_id
    // venue
    // location
    // is_series/is_series_parent
    // is_free (can we get
    // is_online
    // capacity.

     // TODO: get real data.
    func toPlace() -> Place {
        return Place(id: Event.getID(),
                     name: name,
                     latLong: CLLocationCoordinate2D(latitude: 41.877312, longitude: -87.625575),
                     categories: ([], []),
                     photoURLs: [URL(string: "http://www.m-magazine.co.uk/wp-content/uploads/2016/08/Eventbrite-logo-2016.jpg")!],
                     url: url,
                     yelpProvider: SinglePlaceProvider(fromDictionary: [:]))
    }

    // TODO: use name & date.
    private static var idCount = 0
    private static func getID() -> String {
        idCount += 1
        return idPrefix + String(idCount)
    }
}
