/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

struct CategoriesUtil {

    private static let HiddenRootCategories = Set(arrayLiteral: "auto", // 🚗
                                                  "bicycles",
                                                  "education",
                                                  "financialservices",
                                                  "health",
                                                  "homeservices",
                                                  "localservices",
                                                  "professional",
                                                  "realestate",
                                                  "religiousorgs")

    private static let AllCategoriesPath = "Data.bundle/yelp_categories_v3"
    private static let AllCategoriesExt = "json"

    // This accesses the app bundle, which could be slow. If it's an issue, consider using a background thread.
    static let categoryToParents = getCategoryToParents()

    private static func getCategoryToParents() -> [String:Set<String>] {
        let json = loadAllCategoriesFile()

        var categoryToParents = [String:Set<String>]()
        for categoryObject in json {
            let obj = categoryObject as! NSDictionary
            let title = obj["alias"] as! String
            let parents = obj["parents"] as! [String]

            categoryToParents[title] = Set(parents)
        }
        return categoryToParents
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

    static func getRootCategories<S : Sequence>(forCategories categories: S) throws -> Set<String> where S.Iterator.Element == String {
        return try categories.reduce(Set()) { res, category in
            res.union(try getRootCategories(forCategory: category))
        }
    }

    private static func getRootCategories(forCategory category: String) throws -> Set<String> {
        guard let parents = categoryToParents[category] else {
            throw UnknownCategoryError(name: category)
        }

        if parents.isEmpty {
            return Set([category])
        }

        return try parents.reduce(Set()) { res, parent in
            res.union(try getRootCategories(forCategory: parent))
        }
    }

    struct UnknownCategoryError: Error {
        let name: String
    }
}
