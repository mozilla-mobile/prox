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
            "active",
            "arts",
            "localflavor",
            "hotelstravel",
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
            "auto",
            "beautysvc",
            "bicycles",
            "education",
            "eventservices",
            "financialservices",
            "health",
            "homeservices",
            "localservices",
            "professional",
            "massmedia",
            "pets",
            "publicservicesgovt",
            "realestate",
            "religiousorgs",
        ],
    ]
}
