/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

struct CategoriesUtil {

    private static let AllCategoriesPath = "Data.bundle/yelp_categories_v3"
    private static let AllCategoriesExt = "json"

    static func shouldShowPlace<S : Sequence>(byCategories categories: S) -> Bool where S.Iterator.Element == String {
        return true // we'll update this in the next commits.
    }

    private static func loadAllCategoriesFile() -> NSArray {
        // We choose not to handle errors: with an unchanging file, we should never hit an error case.
        guard let filePath = Bundle.main.path(forResource: AllCategoriesPath, ofType: AllCategoriesExt) else {
            fatalError("All categories file unexpectedly missing from app bundle")
        }

        guard let inputStream = InputStream(fileAtPath: filePath) else {
            fatalError("Unable to open input stream on bundle file")
        }

        inputStream.open()
        defer { inputStream.close() }

        return try! JSONSerialization.jsonObject(with: inputStream) as! NSArray
    }

}
