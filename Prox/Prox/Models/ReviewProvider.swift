/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class ReviewProvider {

    let url: String

    let rating: Double
    let reviews: [String]
    let totalReviewCount: Int

    init(url: String,
         rating: Double,
         reviews: [String],
         totalReviewCount: Int) {

        self.url = url

        self.rating = rating
        self.reviews = reviews
        self.totalReviewCount = totalReviewCount
    }
}
