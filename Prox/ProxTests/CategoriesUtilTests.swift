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

}
