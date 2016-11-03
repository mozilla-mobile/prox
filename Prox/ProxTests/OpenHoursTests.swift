/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest
@testable import Prox

class OpenHoursTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    // TODO: if we had more time, maybe we want to write some tests for 24hr clock config.
    func testGetStringForStartTime() {
        let actualToExpected = [700 : "7:00 AM",
                                1900 : "7:00 PM"]
        for (startTime, expected) in actualToExpected {
            let hours = OpenHours(startTime: startTime, endTime: 2000)
            XCTAssertEqual(hours.getStringForStartTime(), expected)
        }
    }

    func testGetStringForEndTime() {
        let actualToExpected = [700 : "7:00 AM",
                                1900 : "7:00 PM"]
        for (endTime, expected) in actualToExpected {
            let hours = OpenHours(startTime: 200, endTime: endTime)
            XCTAssertEqual(hours.getStringForEndTime(), expected)
        }
    }

}
