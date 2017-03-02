/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class MapViewTripAdvisorReviewProviderView: UIView, MapViewReviewProviderView {

    let scoreView = UIImageView()
    let reviewCountView = UILabel()

    let providerStarImageAccessor: ProviderStarImageAccessor = TripAdvisorStarImageAccessor()

    init() {
        super.init(frame: .zero)
        initViews(withParent: self)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func provider(from place: Place) -> PlaceProvider? { return place.tripAdvisorProvider }
}
