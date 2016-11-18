/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

struct PlaceUtilities {

    private static let MaxDisplayedCategories = 3 // via #54

    static func sort(places: [Place], byDistanceFromLocation location: CLLocation, ascending: Bool = true) -> [Place] {
        return places.sorted { (placeA, placeB) -> Bool in
            let placeADistance = location.distance(from: CLLocation(latitude: placeA.latLong.latitude, longitude: placeA.latLong.longitude))
            let placeBDistance = location.distance(from: CLLocation(latitude: placeB.latLong.latitude, longitude: placeB.latLong.longitude))

            if ascending {
                return placeADistance < placeBDistance
            }

            return placeADistance > placeBDistance
        }
    }

    static func filterPlacesForCarousel(_ places: [Place]) -> [Place] {
        return places.filter { place in
            let shouldShowByCategory = CategoriesUtil.shouldShowPlace(byCategories: place.categories.ids)
            guard shouldShowByCategory else {
                print("lol filtering out place, \(place.id), by category")
                return shouldShowByCategory
            }

            let shouldShowByRating = shouldShowPlaceByRating(place)
            guard shouldShowByRating  else {
                print("lol filtering out place, \(place.id), by rating")
                return shouldShowByRating
            }

            return true
        }
    }

    static func shouldShowPlaceByRating(_ place: Place) -> Bool {
        guard let rating = place.yelpProvider.rating,
                let reviewCount = place.yelpProvider.totalReviewCount else {
            print("lol missing rating or review count for place \(place.id)")
            return false
        }

        if (rating < 2.5) || // poorly-reviewed
                (rating == 3 && reviewCount > 3) { // known to be mediocre
            return false
        } else {
            return true
        }
    }

    static func getString(forCategories categories: [String]?) -> String? {
        return categories?.prefix(MaxDisplayedCategories).joined(separator: " • ")
    }

    static func updateReviewUI(fromProvider provider: ReviewProvider?, onView view: ReviewContainerView, isTextShortened: Bool = false) {
        guard let provider = provider,
                !(provider.totalReviewCount == nil && provider.rating == nil) else { // intentional: if both null, short-circuit
            setSubviewAlpha(0.4, forParent: view)
            view.score = 0
            view.numberOfReviewersLabel.text = "No data" + (isTextShortened ? "" : " available")
            return
        }

        setSubviewAlpha(1.0, forParent: view)

        if let rating = provider.rating {
            view.score = rating
        } else {
            view.reviewScore.alpha = 0.15 // no UX spec so I eyeballed. Unlikely anyway.
            view.score = 0
        }

        let reviewPrefix: String
        if let reviewCount = provider.totalReviewCount { reviewPrefix = String(reviewCount) }
        else { reviewPrefix = "No" }
        view.numberOfReviewersLabel.text = reviewPrefix + " Reviews"
    }

    private static func setSubviewAlpha(_ alpha: CGFloat, forParent parentView: ReviewContainerView) {
        for view in parentView.subviews {
            view.alpha = alpha
        }
    }
}
