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
        return places.filter() { place in
            do {
                let shouldShow = try CategoriesUtil.shouldShowPlace(byCategories: place.categories.ids)
                if !shouldShow {
                    print("lol filtering out place, \(place.id), by category")
                    return shouldShow
                }

            } catch CategoryError.Unknown(let name) {
                print("lol unknown category name, \(name), for place, \(place.id)")
                return false
            } catch { // I don't know why this is necessary - afaik, no other errors are thrown.
                print("lol Unknown error occurred while filtering place, \(place.id)")
                return false
            }

            return true
        }
    }

    static func getString(forCategories categories: [String]?) -> String? {
        return categories?.prefix(MaxDisplayedCategories).joined(separator: " • ")
    }

    static func updateReviewUI(fromProvider provider: ReviewProvider?, onView view: ReviewContainerView, isTextShortened: Bool = false) {
        guard let provider = provider else {
            setSubviewAlpha(0.4, forParent: view)
            view.score = nil
            view.numberOfReviewersLabel.text = "No data" + (isTextShortened ? "" : " available")
            return
        }

        setSubviewAlpha(1.0, forParent: view)
        view.score = provider.rating
        view.numberOfReviewersLabel.text = provider.totalReviewCount != nil ? "\(provider.totalReviewCount!) Reviews" : nil
    }

    private static func setSubviewAlpha(_ alpha: CGFloat, forParent parentView: ReviewContainerView) {
        for view in parentView.subviews {
            view.alpha = alpha
        }
    }
}
