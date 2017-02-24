/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

enum Filter: Int {
    case discover
    case eatAndDrink
    case shop
    case services

    static let categories: [Filter: [String]] = [
        Filter.discover: [
            "arts",
            "localflavor",

            // Active Life
            "amusementparks",
            "aquariums",
            "battingcages",
            "beaches",
            "boating",
            "escapegames",
            "experiences",
            "flyboarding",
            "gliding",
            "golf",
            "hanggliding",
            "hiking",
            "horsebackriding",
            "hot_air_balloons",
            "jetskis",
            "lakes",
            "lasertag",
            "mini_golf",
            "mountainbiking",
            "paddleboarding",
            "paintball",
            "parasailing",
            "parks",
            "publicplazas",
            "rafting",
            "rock_climbing",
            "sailing",
            "scavengerhunts",
            "skatingrinks",
            "skiing",
            "skydiving",
            "sledding",
            "snorkeling",
            "surfing",
            "trampoline",
            "tubing",
            "waterparks",
            "wildlifehunting",
            "zipline",
            "zoos",
            "zorbing",

            // Hotels & Travel
            "tours",

            // Public Services & Gov't
            "landmarks",
            "courthouses",
            "libraries",
            "townhall",

            // Nightlife
            "musicvenues",

            // Events & Services
            "boatcharters",
            "silentdisco",
        ],

        Filter.eatAndDrink: [
            "food",
            "nightlife",
            "restaurants"
        ],

        Filter.shop: [
            "shopping",
        ],

        Filter.services: [
            "active",
            "auto",
            "beautysvc",
            "bicycles",
            "education",
            "eventservices",
            "financialservices",
            "health",
            "homeservices",
            "hotelstravel",
            "localservices",
            "professional",
            "massmedia",
            "pets",
            "publicservicesgovt",
            "realestate",
            "religiousorgs",

            // Food
            "convenience",
        ],
    ]
}
