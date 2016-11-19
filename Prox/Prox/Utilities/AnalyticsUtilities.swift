/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Flurry_iOS_SDK

class Analytics {
    static func startAppSession() {
        Flurry.logEvent(AnalyticsEvent.APP_INIT)
    }

    static func logEvent(event: String, params: [String: String]) {
        Flurry.logEvent(event, withParameters: params)
    }
}

public struct AnalyticsEvent {
    static let APP_INIT = "app_init";

    // Durations
    static let LOADING_SCREEN_DURATION         = "loading_screen_duration"
    static let PLACE_DETAILS_SESSION_DURATION  = "details_session_duration"
    static let DETAILS_CARD_SESSION_DURATION   =
        "details_card_session_duration"
    static let PLACE_CAROUSEL_SESSION_DURATION = "carousel_session_duration"

    // Place Details
    static let YELP               = "yelp_link"
    static let YELP_TOGGLE        = "yelp_review_toggle"
    static let TRIPADVISOR        = "tripadvisor_link"
    static let WIKIPEDIA          = "wikipedia_link"
    static let WIKIPEDIA_TOGGLE   = "wikipedia_toggle"
    static let DIRECTIONS         = "directions_link"
    static let WEBSITE            = "website_link"
    static let MAP_BUTTON         = "map_button" // For returning to the Carousel
    static let NUM_DETAILS_CARDS  = "num_details"
    static let NUM_CAROUSEL_CARDS = "num_carousel"

    // Event Actions
    static let EVENT_BANNER_LINK  = "event_banner_link"
    static let EVENT_NOTIFICATION = "event_notification"

    static let PARAM_ACTION = "action"
}
