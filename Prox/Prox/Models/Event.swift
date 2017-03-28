/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

private let idPrefix = "proxevent-"

/// An event. Properties are modelled after an Eventbrite Event:
///   https://www.eventbrite.com/developer/v3/response_formats/event/#ebapi-std:format-event
/// This is likely to change when we add events from other providers.
struct Event {

    let name: String
    let description: String?
    let url: URL?

    let category: String?
    let subcategory: String?
    let format: String? // called "Event Type" on Eventbrite's website.

//    let start: Date?
//    let end: Date?

    let location: CLLocationCoordinate2D

    let photoURLs: [URL]

    // Unused things we might care about.
    let venueName: String?
    let isOnline: Bool? // maybe not relevant since we require a location.
    let isFree: Bool? // TODO: would it be useful to get the ticket price too? Can we?
    let capacity: Int?

    /// True if this a repeating event.
    let isSeries: Bool?
    let isSeriesParent: Bool?

    // let bookmarkInfo => we could get this property, which gives the count of ppl who bookmarked this event.

    func toPlace() -> Place {
        let categoryNames = [category, subcategory, format].flatMap { $0 }

        return Place(id: Event.getID(),
                     name: name,
                     latLong: location,
                     categories: (categoryNames, categoryNames), // dupe names & ids because we don't actually have IDs.
                     photoURLs: photoURLs,
                     url: url,
                     yelpProvider: SinglePlaceProvider(fromDictionary: [:]),
                     // TODO: if description is empty, the event won't have an event banner.
                     customProvider: SinglePlaceProvider(fromDictionary: ["description": description as Any])
        )
    }

    // TODO: use name & date.
    private static var idCount = 0
    private static func getID() -> String {
        idCount += 1
        return idPrefix + String(idCount)
    }
}
