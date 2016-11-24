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
            // always show places if they have events
            guard place.events.isEmpty else { return true }
            
            let shouldShowByCategory = CategoriesUtil.shouldShowPlace(byCategories: place.categories.ids)
            guard shouldShowByCategory else {
                print("lol filtering out place, \(place.id), by category")
                return shouldShowByCategory
            }

            let shouldShowByRating = shouldShowPlaceByRatingAndReviewCount(place)
            guard shouldShowByRating  else {
                print("lol filtering out place, \(place.id), by rating")
                return shouldShowByRating
            }

            return true
        }
    }

    static func shouldShowPlaceByRatingAndReviewCount(_ place: Place) -> Bool {
        guard let rating = place.yelpProvider.rating,
                let reviewCount = place.yelpProvider.totalReviewCount else {
            print("lol missing rating or review count for place \(place.id)")
            return false
        }


        if (rating < 2.5) || // poorly-reviewed
                reviewCount < 4 { // unpopular
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

    // assumes called from UI thread.
    static func updateTravelTimeUI(fromPlace place: Place, toLocation location: CLLocation?, forView view: TravelTimesView) {
        view.prepareTravelTimesUIForReuse()

        guard let location = location else {
            // TODO: how to handle? Previously, this was unhandled.
            return
        }

        // TODO: need to cancel long running requests or users may be stuck with a loading spinner
        // rather than a "View on Map" button. I think this only happens when you swipe real fast.
        let travelTimesResult = place.travelTimes(fromLocation: location)
        if !travelTimesResult.isFilled {
            view.setTravelTimesUIIsLoading(true)
        }

        let idAtCallTime = place.id
        view.setIDForTravelTimesView(idAtCallTime)
        travelTimesResult.upon(DispatchQueue.main) { res in
            guard let idAtResultTime = view.getIDForTravelTimesView(), // should never be nil
                    idAtCallTime == idAtResultTime else {
                // Someone has requested new travel times for this view (re-used?) before we could
                // display the result: cancel view update.
                return
            }

            view.setTravelTimesUIIsLoading(false)

            guard let travelTimes = res.successResult() else {
                view.updateTravelTimesUIForResult(.noData, durationInMinutes: nil)
                return
            }

            if let walkingTimeSeconds = travelTimes.walkingTime {
                let walkingTimeMinutes = Int(round(walkingTimeSeconds / 60.0))
                if walkingTimeMinutes <= TravelTimesProvider.MIN_WALKING_TIME {
                    if walkingTimeMinutes < TravelTimesProvider.YOU_ARE_HERE_WALKING_TIME {
                        view.updateTravelTimesUIForResult(.userHere, durationInMinutes: nil)
                    } else {
                        view.updateTravelTimesUIForResult(.walkingDist, durationInMinutes: walkingTimeMinutes)
                    }
                    return
                }
            }

            if let drivingTimeSeconds = travelTimes.drivingTime {
                let drivingTimeMinutes = Int(round(drivingTimeSeconds / 60.0))
                view.updateTravelTimesUIForResult(.drivingDist, durationInMinutes: drivingTimeMinutes)
                return
            }

            view.updateTravelTimesUIForResult(.noData, durationInMinutes: nil)
        }
    }

    private static func setSubviewAlpha(_ alpha: CGFloat, forParent parentView: ReviewContainerView) {
        for view in parentView.subviews {
            view.alpha = alpha
        }
    }
}
