/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest

@testable import Prox

// Preferably with other constant declarations but its most convenient to put here so we don't need
// to reference with "CategoriesUtilTests.varName"
fileprivate let LeafParentCategory = "insurance"
fileprivate let LeafCategory = "autoinsurance" // 🚗

class CategoriesUtilTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // Root and its children
    private let RootCategory = "financialservices"
    // explicit types or SourceKitService eats your CPU: http://stackoverflow.com/a/28183589
    private let CategoryHierarchy: [String : Set<String>] =
        ["banks" : Set<String>(),
         "businessfinancing" : Set<String>(),
         "paydayloans" : Set<String>(),
         "currencyexchange" : Set<String>(),
         "debtrelief" : Set<String>(),
         "financialadvising" : Set<String>(),
         "installmentloans" : Set<String>(),
         LeafParentCategory : Set<String>([LeafCategory,
                                           "homeinsurance",
                                           "lifeinsurance"]),
         "investing" : Set<String>(),
         "taxservices" : Set<String>(),
         "titleloans" : Set<String>()]

    private let NotACategory = "not-a-category"

    func testCategoriesToDescendantsForLeaf() {
        XCTAssertEqual(CategoriesUtil.categoryToDescendantsMap[LeafCategory], Set<String>())
    }

    func testCategoriesToDescendantsForLeafParent() {
        let expected = CategoryHierarchy[LeafParentCategory]!
        XCTAssertEqual(CategoriesUtil.categoryToDescendantsMap[LeafParentCategory], expected)
    }

    func testCategoriesToDescendantsForRoot() {
        var expected = Set<String>()
        for (cat, children) in CategoryHierarchy {
            expected = expected.union(children)
            expected = expected.union([cat])
        }

        XCTAssertEqual(CategoriesUtil.categoryToDescendantsMap[RootCategory], expected)
    }
}
