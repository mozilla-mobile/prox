/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit

public struct Colors { }

fileprivate let dividerColor = UIColor(colorLiteralRed: 0.8, green: 0.8, blue: 0.8, alpha: 0.3)

// Place Carousel Colors
extension Colors {
    public static let carouselViewHeaderBackground = UIColor.white
    public static let carouselViewHeaderHorizontalLine = dividerColor
    public static let carouselViewPlaceCardBackground = UIColor.white
    public static let carouselViewSunriseSetTimesLabelText = UIColor.black.withAlphaComponent(0.5)
    public static let carouselViewImageOpacityLayer = UIColor.black.withAlphaComponent(0.2)
    public static let carouselViewPlaceCardImageText = UIColor.white
    public static let carouselLoadingViewColor = UIColor(red:0.00, green:0.59, blue:0.87, alpha:1.0)
    public static let restartButtonColor = UIColor(red:0.00, green:0.48, blue:1.00, alpha:1.0)
}

// review provider colours
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
    public static let detailsViewCardLinkText = UIColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1.0)
    public static let pageIndicatorTintColor = UIColor.black.withAlphaComponent(0.4)
    public static let detailsViewCardSeparator = dividerColor
    public static let currentPageIndicatorTintColor = UIColor.white
    public static let detailsViewMapButtonBadgeBackground = UIColor(colorLiteralRed: 0.07, green: 0.40, blue: 0.98, alpha: 1.0)
    public static let detailsViewMapButtonBadgeFont = UIColor.white
    public static let detailsViewMapButtonShadow = UIColor.black.withAlphaComponent(0.4)
    public static let detailsViewMapButtonBackground = UIColor.white

    public static let detailsViewTravelTimeErrorPinTint = UIColor(colorLiteralRed: 0.8, green: 0.8, blue: 0.8, alpha: 1)

    public static let detailsViewImageCarouselPageControlShadow = UIColor.black.withAlphaComponent(0.4)

    public static let detailsViewEventText = UIColor.white
    public static let detailsViewEventBackground = UIColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1.0)

    public static let detailsViewBackgroundGradientStart = UIColor(red: 0, green: 0.01, blue: 0.53, alpha: 0.5)
    public static let detailsViewBackgroundGradientEnd = UIColor(red: 0, green: 0.48, blue: 1.00, alpha: 0.1)

    public static let detailsViewDescriptionExpandArrow = UIColor(red: 0.78, green: 0.78, blue: 0.78, alpha: 1.0)
}

// notification colours
extension Colors {
    public static let notificationText = Colors.detailsViewEventText
    public static let notificationBackground = Colors.detailsViewEventBackground
}
