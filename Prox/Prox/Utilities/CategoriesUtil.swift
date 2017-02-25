/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

struct CategoriesUtil {

    private static let AllCategoriesPath = "Data.bundle/yelp_categories_v3"
    private static let AllCategoriesExt = "json"

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

    static let categoryToDescendantsMap: [String: Set<String>] = {
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
    }()

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

    private static let categoryToParentsMap: [String: [String]] = {
        let json = loadAllCategoriesFile()
        var categoryToParents = [String: [String]]()
        for categoryObject in json {
            let obj = categoryObject as! NSDictionary
            let title = obj["alias"] as! String
            let parents = obj["parents"] as! [String]
            categoryToParents[title] = parents
        }
        return categoryToParents
    }()

    static let categoryToRoots: [String: [String]] = {
        var categoryToRoots = [String: [String]]()
        for category in categoryToParentsMap.keys {
            categoryToRoots[category] = Array(getRootCategories(forCategory: category))
        }
        return categoryToRoots
    }()

    private static func getRootCategories(forCategory category: String) -> Set<String> {
        let parents = categoryToParentsMap[category]!

        if parents.isEmpty {
            return Set([category])
        }

        return parents.reduce(Set()) { res, parent in
            res.union(getRootCategories(forCategory: parent))
        }
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

    /// A category may not map to a filter if we recrawl after Yelp changes its categories
    /// (thus making yelp_categories_v3.json out of sync).
    static let categoryToFilter: [String: PlaceFilter] = {
        var categoryToFilter = [String: PlaceFilter]()

        // Build the initial map of categories -> filters that we set explicitly.
        for (filter, categories) in PlaceFilter.categories {
            for category in categories {
                categoryToFilter[category] = filter
            }
        }

        // Set the remaining categories based on the first ancestor with an explicitly-set filter.
        for category in categoryToParentsMap.keys {
            guard let firstCategorizedParent = getAncestors(forCategory: category).flatMap({ categoryToFilter[$0] }).first else { continue }
            categoryToFilter[category] = firstCategorizedParent
        }

        return categoryToFilter
    }()

    /// Returns this category, its root categories, and all parents in between.
    /// The result is DFS-ordered from this category to its roots.
    private static func getAncestors(forCategory category: String) -> [String] {
        let ancestors = categoryToParentsMap[category] ?? []
        let hierarchy = ancestors.reduce([category]) { $0 + getAncestors(forCategory: $1) }
        return Array(NSOrderedSet(array: hierarchy)) as! [String]
    }
}

enum CategoryError: Error {
    case UnknownCategory(name: String)
}
