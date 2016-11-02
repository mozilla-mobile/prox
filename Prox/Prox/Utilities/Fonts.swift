/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
import Foundation
import UIKit

public struct Fonts {}

extension Fonts {
    public static let carouselViewNumberOfPlaces = UIFont.systemFont(ofSize: 48.0, weight: UIFontWeightLight)
    public static let carouselViewSunriseSetTimes = UIFont.systemFont(ofSize: 14.0)
    public static let carouselViewPlaceCardCategory = UIFont.boldSystemFont(ofSize: 12.0)
    public static let carouselViewPlaceCardName = UIFont.systemFont(ofSize: 18.0, weight: UIFontWeightSemibold)
    public static let carouselViewPlaceCardLocation = UIFont.systemFont(ofSize: 14.0)
}

extension Fonts {
    public static let reviewsNumberOfReviewers = UIFont.systemFont(ofSize: 12.0)
}

// Place Details View
extension Fonts {
    public static let detailsViewTitleText = UIFont.systemFont(ofSize: 24, weight: UIFontWeightSemibold)
    public static let detailsViewCategoryText = UIFont.systemFont(ofSize: 14)
    public static let detailsViewReviewerText = UIFont.systemFont(ofSize: 14)
    public static let detailsViewDescriptionTitle = UIFont.systemFont(ofSize: 16)
    public static let detailsViewDescriptionText = UIFont.systemFont(ofSize: 14)

    public static let detailsViewIconInfoPrimaryText = UIFont.systemFont(ofSize: 24, weight: UIFontWeightLight)
    public static let detailsViewIconInfoSecondaryText = UIFont.systemFont(ofSize: 14)

    public static let detailsViewMapButtonBadgeText = UIFont.systemFont(ofSize: 14)
}
