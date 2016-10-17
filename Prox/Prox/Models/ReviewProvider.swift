/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Firebase

class ReviewProvider {

    let url: String

    let rating: Double
    let reviews: [String]
    let totalReviewCount: Int

    // TODO: temporary? until we can init everything from Firebase
    init(url: String,
         rating: Double,
         reviews: [String],
         totalReviewCount: Int) {

        self.url = url

        self.rating = rating
        self.reviews = reviews
        self.totalReviewCount = totalReviewCount
    }

    init?(fromFirebaseSnapshot data: FIRDataSnapshot) {
        guard data.exists(), data.hasChildren(), let value = data.value as? NSDictionary else {
            print("lol unable to init ReviewProvider")
            return nil
        }

        // TODO: handle missing values robustly
        self.url = value["url"] as? String ?? "URL unknown"

        self.rating = value["rating"] as? Double ?? -1
        self.totalReviewCount = value["reviewCount"] as? Int ?? -1

        // TODO: get values from DB (these are default).
        self.reviews = []
    }
}
