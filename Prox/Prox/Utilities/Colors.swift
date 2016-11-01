/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit

public struct Colors { }

// Place Carousel Colors
extension Colors {
    public static let carouselViewHeaderHorizontalLine = UIColor(colorLiteralRed: 0.78, green: 0.78, blue: 0.78, alpha: 1.0)
    public static let carouselViewPlaceCardBackground = UIColor.white
    public static let carouselViewSunriseSetTimesLabelText = UIColor.black.withAlphaComponent(0.5)
    public static let carouselViewImageOpacityLayer = UIColor.black.withAlphaComponent(0.2)
    public static let carouselViewPlaceCardImageText = UIColor.white
}

extension Colors {
    public static let yelp = UIColor(colorLiteralRed: 0.83, green: 0.14, blue: 0.14, alpha: 1.0)
    public static let tripAdvisor = UIColor(colorLiteralRed: 0.18, green: 0.62, blue: 0.27, alpha: 1.0)
    public static let reviewsNumberOfReviewers = UIColor.black.withAlphaComponent(0.4)
    public static let reviewScoreDefault = UIColor.lightGray
}

// Place Details Colors
extension Colors {
    public static let detailsViewCardBackground = UIColor.white
    public static let detailsViewCardPrimaryText = UIColor.black
    public static let detailsViewCardSecondaryText = UIColor.black.withAlphaComponent(0.5)
    public static let pageIndicatorTintColor = UIColor.black.withAlphaComponent(0.5)
    public static let detailsViewCardSeparator = UIColor(hue: 0, saturation: 0, brightness: 0.94, alpha: 1)
    public static let currentPageIndicatorTintColor = UIColor.white
    public static let detailsViewMapButtonBadgeBackground = UIColor(colorLiteralRed: 0.07, green: 0.40, blue: 0.98, alpha: 1.0)
    public static let detailsViewMapButtonBadgeFont = UIColor.white
    public static let detailsViewMapButtonShadow = UIColor.black.withAlphaComponent(0.4)
    public static let detailsViewMapButtonBackground = UIColor.white
}
