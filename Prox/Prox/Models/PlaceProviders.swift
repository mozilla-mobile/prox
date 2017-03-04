/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

protocol PlaceProvider {
    var id: String? { get }
    var name: String? { get}
    var description: String? { get }
    var categories: (names: [String], ids: [String]) { get }
    var latLong: CLLocationCoordinate2D? { get }
    var photoURLs: [URL] { get }
    var url: URL? { get }
    var website: URL? { get }
    var address: String? { get }
    var hours: OpenHours? { get }
    var rating: Float? { get }
    var totalReviewCount: Int { get }
}

class SinglePlaceProvider: PlaceProvider {
    let id: String?
    let name: String?
    let description: String?
    let categories: (names: [String], ids: [String])
    let latLong: CLLocationCoordinate2D?
    let photoURLs: [URL]
    let url: URL?
    let website: URL?
    let address: String?
    let hours: OpenHours?
    let rating: Float?
    let totalReviewCount: Int

    init(fromDictionary dict: [String: Any]) {
        id = dict["id"] as? String

        name = dict["name"] as? String

        if let description = dict["description"] as? String, !description.isEmpty {
            self.description = description
        } else {
            self.description = nil
        }

        let categoryIds = dict["categories"] as? [String] ?? []
        var categories = (names: [String], ids: [String])([], [])
        for id in categoryIds {
            if let name = CategoriesUtil.categoryToName[id] {
                categories.ids.append(id)
                categories.names.append(name)
            } else if let placeid = self.id, placeid.hasPrefix("proxdiscover-") {
                // HACK: proxdiscover categories are stored by name without id
                categories.ids.append(id)
                categories.names.append(id)
            }
        }
        self.categories = categories

        if let coords = dict["coordinates"] as? [String: Double],
            let lat = coords["lat"],
            let lng = coords["lng"] {
            latLong = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else {
            latLong = nil
        }

        let photoURLStrings = (dict["images"] as? [[String:String]])?.flatMap { $0["src"] } ?? []
        photoURLs = photoURLStrings.flatMap { URL(string: $0) }

        if let urlString = dict["url"] as? String,
           let url = URL(string: urlString) {
            self.url = url
        } else {
            self.url = nil
        }

        if let websiteString = dict["website"] as? String,
            let website = URL(string: websiteString) {
            self.website = website
        } else {
            self.website = nil
        }

        address = (dict["address"] as? [String])?.joined(separator: " ")

        if let hoursDictFromServer = dict["hours"] as? [String : [[String]]],
            let hoursFromServer = OpenHours.fromFirebaseValue(hoursDictFromServer) {
            hours = hoursFromServer
        } else {
            hours = nil
        }

        rating = dict["rating"] as? Float

        totalReviewCount = dict["totalReviewCount"] as? Int ?? 0
    }
}

/// Pulls data from multiple providers, prioritizing data in the order of the providers given.
class CompositePlaceProvider: PlaceProvider {
    private(set) var id: String?
    private(set) var name: String?
    private(set) var description: String?
    private(set) var categories = (names: [String], ids: [String])([], [])
    private(set) var latLong: CLLocationCoordinate2D?
    private(set) var photoURLs = [URL]()
    private(set) var url: URL?
    private(set) var website: URL?
    private(set) var address: String?
    private(set) var hours: OpenHours?
    private(set) var rating: Float? = nil
    private(set) var totalReviewCount: Int = 0

    init(fromProviders providers: [PlaceProvider]) {
        for provider in providers {
            if id == nil {
                id = provider.id
            }

            if name == nil {
                name = provider.name
            }

            if description == nil {
                description = provider.description
            }

            // TODO: merge multiple categories (issue #513).
            if self.categories.ids.isEmpty {
                self.categories = provider.categories
            }

            if latLong == nil {
                latLong = provider.latLong
            }

            // TODO: merge multiple photos (issue #513).
            if photoURLs.isEmpty {
                photoURLs = provider.photoURLs
            }

            if url == nil {
                url = provider.url
            }

            if website == nil {
                website = provider.website
            }

            if address == nil {
                address = provider.address
            }

            if hours == nil {
                hours = provider.hours
            }

            if rating == nil {
                rating = provider.rating
            }

            totalReviewCount += provider.totalReviewCount
        }
    }
}
