/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

struct Strings {
    struct detailsView {
        static let open = "Open"
        static let twentyFourHours = "24 hours"

        static let eventTitle = "Event"
    }

    struct filterView {
        static let discover = "Discover"
        static let events = "Local events"
        static let eatAndDrink = "Eat & Drink"
        static let shop = "Shop"
        static let services = "Services"
        static let placeCount = "%d places"
        static let popularityToast = "Select more filters to get better results"
        static let topRatedLabel = "Sort by popularity"
    }

    struct mapView {
        static let noInfo = "No info"
        static let numReviews = "%d Review%@"

        static let searchHere = "Search here"
        static let searching = "Searching..."

        static let noResultsYet = "No results for this area yet"
        static let dismissNoResults = "Dismiss"

        static let eventHeader = "Event %@ at %@"
    }

    struct place {
        static let today = "today"
        static let tomorrow = "tomorrow"
    }
}
