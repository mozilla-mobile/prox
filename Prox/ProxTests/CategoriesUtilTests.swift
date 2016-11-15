/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest

@testable import Prox

class CategoriesUtilTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    // Descendants (e.g. direct, multi-level) are relative to the root.
    private let RootCategory = "restaurants"
    private let DirectDescendant = (name: "3dprinting", parents: ["localservices"])
    private let MultilevelDescendant = (name: "yakiniku", parents: ["japanese"], roots: ["restaurants"])
    private let MultipleParentsDirectDescendant = (name: "cosmetics", parents: ["shopping", "beautysvc"])
    private let MultipleParentsMultilevelDescendant = (name: "sportswear",
                                                       parents: ["sportgoods", "fashion"],
                                                       roots: ["shopping"])
    private let NotACategory = "not-a-category"

    private func assertCategoryToParents(input: String, expected: [String]) {
        let actual = CategoriesUtil.categoryToParents[input]
        XCTAssertEqual(actual, Set(expected))
    }

    private func assertGetRootCategories(input: [String], expected: [String]) {
        let actual = try! CategoriesUtil.getRootCategories(forCategories: expected)
        XCTAssertEqual(actual, Set(expected))
    }
    
    func testCategoryToParentsForRootCategory() {
        assertCategoryToParents(input: RootCategory, expected: [])
    }

    func testCategoryToParentsForDirectDescendant() {
        assertCategoryToParents(input: DirectDescendant.name, expected: DirectDescendant.parents)
    }

    func testCategoryToParentsForMultilevelDescendant() {
        assertCategoryToParents(input: MultilevelDescendant.name, expected: MultilevelDescendant.parents)
    }

    func testCategoryToParentsForMultipleParents() {
        assertCategoryToParents(input: MultipleParentsDirectDescendant.name,
                                expected: MultipleParentsDirectDescendant.parents)
    }

    func testCategoryToParentsForMissingCategory() {
        let actual = CategoriesUtil.categoryToParents[NotACategory]
        XCTAssertNil(actual)
    }

    func testGetRootCategoriesForRootCategory() {
        let rootCategoryArr = [RootCategory]
        assertGetRootCategories(input: rootCategoryArr, expected: rootCategoryArr)
    }

    func testGetRootCategoriesForDirectDescendant() {
        assertGetRootCategories(input: [DirectDescendant.name], expected: DirectDescendant.parents)
    }

    func testGetRootCategoriesForMultilevelDescendant() {
        assertGetRootCategories(input: [MultilevelDescendant.name], expected: MultilevelDescendant.roots)
    }

    func testGetRootCategoriesForMultipleParentsDirectDescendant() {
        assertGetRootCategories(input: [MultipleParentsDirectDescendant.name],
                                expected: MultipleParentsDirectDescendant.parents)
    }

    func testGetRootCategoriesForMultipleParentsMultilevelDescendant() {
        assertGetRootCategories(input: [MultipleParentsMultilevelDescendant.name],
                                expected: MultipleParentsMultilevelDescendant.roots)
    }

    func testGetRootCategoriesForMultipleCategoryInputs() {
        let input = [RootCategory, MultipleParentsMultilevelDescendant.name]
        let expected = [RootCategory] + MultipleParentsMultilevelDescendant.roots
        assertGetRootCategories(input: input, expected: expected)
    }

    func testGetRootForMissingCategory() {
        XCTAssertThrowsError(try CategoriesUtil.getRootCategories(forCategories: [NotACategory]))
    }

    func testShouldShowPlaceOnAllMatch() {
        let input = CategoriesUtil.HiddenRootCategories.prefix(3)
        XCTAssertFalse(try CategoriesUtil.shouldShowPlace(byCategories: input))
    }

    func testShouldShowPlaceOnPartialMatch() {
        let input = Set(CategoriesUtil.HiddenRootCategories.prefix(1)).union(getNonHiddenCategories())
        XCTAssertTrue(try CategoriesUtil.shouldShowPlace(byCategories: input))
    }

    func testShouldShowPlaceOnNoMatch() {
        let input = getNonHiddenCategories()
        XCTAssertTrue(try CategoriesUtil.shouldShowPlace(byCategories: input))
    }

    func testShouldShowPlaceThrowsOnInvalidCategory() {
        XCTAssertThrowsError(try CategoriesUtil.shouldShowPlace(byCategories: ["not-a-category"]))
    }

    private func getNonHiddenCategories() -> Set<String> {
        let nonHiddenCat = "shopping"
        XCTAssertFalse(CategoriesUtil.HiddenRootCategories.contains(nonHiddenCat),
                       "Failed sanity check: expected \(nonHiddenCat) to be a non-hidden category.")
        return Set(arrayLiteral: nonHiddenCat)
    }
}
