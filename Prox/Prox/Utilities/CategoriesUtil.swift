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

    static let categoryToDescendantsMap = getCategoryToDescendantsMap()

    private static func getCategoryToDescendantsMap() -> [String:Set<String>] {
        let allCats = loadAllCategoriesFile()

        var parentToDescendantsMap = [String:Set<String>]()
        for cat in allCats {
            let obj = cat as! NSDictionary
            let name = obj["alias"] as! String
            let parents = obj["parents"] as! [String]

            // Ensure leaf nodes have entries.
            if parentToDescendantsMap[name] == nil {
                parentToDescendantsMap[name] = Set()
            }

            for parent in parents {
                let value = parentToDescendantsMap[parent] ?? Set()
                parentToDescendantsMap[parent] = value.union([name])
            }
        }

        // Handle sub-categories. This code assumes yelp's hierarchy is three levels deep.
        for (cat, children) in parentToDescendantsMap {
            var grandChildren = Set<String>()
            for child in children {
                grandChildren = grandChildren.union(parentToDescendantsMap[child] ?? Set())
            }

            parentToDescendantsMap[cat] = children.union(grandChildren)
        }

        return parentToDescendantsMap
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

enum CategoryError: Error {
    case UnknownCategory(name: String)
}
