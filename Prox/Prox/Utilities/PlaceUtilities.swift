/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

struct PlaceUtilities {
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

    static func updateReviewUI(fromProvider provider: ReviewProvider?, onView view: ReviewContainerView) {
        guard let provider = provider else {
            setSubviewAlpha(0.4, forParent: view)
            view.score = 0
            view.numberOfReviewersLabel.text = "No data available"
            return
        }

        setSubviewAlpha(1.0, forParent: view)
        view.score = provider.rating ?? 0 // TODO: error state (& next line)
        view.numberOfReviewersLabel.text = "\(provider.totalReviewCount ?? 0) Reviews"
    }

    private static func setSubviewAlpha(_ alpha: CGFloat, forParent parentView: ReviewContainerView) {
        for view in parentView.subviews {
            view.alpha = alpha
        }
    }
}
