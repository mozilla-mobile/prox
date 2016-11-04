/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest
@testable import Prox

class DayOfWeekTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testForDate() {
        let cal = Calendar(identifier: .gregorian)

        // We iterate from Monday Nov. 7th, 2016 to Sunday Nov. 13, 2016. A better implementation
        // might iterate over a date range or something but this is easier!
        for (expectedDayOfWeekStr, dayOfMonth) in ["monday":7,
                                                   "tuesday":8,
                                                   "wednesday":9,
                                                   "thursday":10,
                                                   "friday":11,
                                                   "saturday":12,
                                                   "sunday":13] {

            // TODO: rawValue would be better suited to its own test but lets save time and do it here.
            let expectedDayOfWeek = DayOfWeek(rawValue: expectedDayOfWeekStr)
            let dateForDayOfMonth = DateComponents(calendar: cal,
                                                   year: 2016,
                                                   month: 11,
                                                   day: dayOfMonth).date!
            XCTAssertEqual(DayOfWeek.forDate(dateForDayOfMonth), expectedDayOfWeek)
        }
    }
}
