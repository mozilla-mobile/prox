/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

struct CategoriesUtil {

    private static let AllCategoriesPath = "Data.bundle/yelp_categories_v3"
    private static let AllCategoriesExt = "json"

    static func shouldShowPlace<S : Sequence>(byCategories categories: S) -> Bool where S.Iterator.Element == String {
        // TODO: UX still needs to tell us whether they want to hide a place if its categories contains
        // a single category they said to hide or only if *all* its categories are in the categories
        // they said to hide. For now, we hide if they all match.
        let categorySet = Set(categories)
        let allMatched = categorySet.subtracting(HiddenCategories).isEmpty
        return !allMatched
    }

    // UX gives us a CSV list of categories to hide and we hide them *and their children*.
    // This is an exhaustive collection of these categories and their children.
    // Caveat: we don't expect UX to include root categories, which are special-cased: we can reduce
    // yelp resource use by whitelisting the categories we ask for meaning the other root categories
    // are hidden implicitly.
    static let HiddenCategories: Set<String> = {
        let categories = RemoteConfigKeys.placeCategoriesToHideCSV.value
        return getHiddenCategories(forCategories: categories)
    }()

    // Separated for testing: I don't know how to do automated tests with the Firebase value.
    internal static func getHiddenCategories(forCSV csv: String) -> Set<String> {
        let categories = csv.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0 != "" }
        return getHiddenCategories(forCategories: categories)
    }

    internal static func getHiddenCategories(forCategories categories: [String]) -> Set<String> {
        var hiddenCategories = Set<String>()
        for category in categories {
            guard let descendants = categoryToDescendantsMap[category] else {
                log.warn("unknown category, \(category) (from Firebase?). Ignoring")
                continue
            }

            hiddenCategories.update(with: category)
            hiddenCategories = hiddenCategories.union(descendants)
        }

        return hiddenCategories
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

    static let categoryToName: [String: String] = {
        let json = loadAllCategoriesFile()
        var categoryToName = [String: String]()
        for obj in json as! [[String: Any]] {
            let id = obj["alias"] as! String
            let title = obj["title"] as! String
            assert(categoryToName[id] == nil)
            categoryToName[id] = title
        }
        return categoryToName
    }()
}

enum CategoryError: Error {
    case UnknownCategory(name: String)
}
