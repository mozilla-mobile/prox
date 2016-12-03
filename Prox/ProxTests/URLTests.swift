/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest
@testable import Prox

class URLTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    private func assertInitHTTPString(urlStr: String) {
        let httpURL = URL(httpStringMaybeWithScheme: urlStr)
        XCTAssertNotNil(httpURL)
        XCTAssertNotNil(httpURL?.host)
        XCTAssertNotNil(httpURL?.scheme)
    }

    func testInitHTTPStringWithScheme() {
        for urlStr in ["http://google.com", "https://google.com", "https://google.com/archive.php", "http://sub.goog.com"] {
            assertInitHTTPString(urlStr: urlStr)
        }
    }

    func testInitHTTPStringWithoutScheme() {
        for urlStr in ["google.com", "bing.com/search.html", "sub.bing.com"] {
            assertInitHTTPString(urlStr: urlStr)
        }
    }

}
