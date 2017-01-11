/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest

@testable import Prox

class TimeIntervalTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func hoursAsSeconds(hours: Int) -> TimeInterval {
        return minutesAsSeconds(minutes: hours * 60)
    }

    func minutesAsSeconds(minutes: Int) -> TimeInterval {
        return TimeInterval(minutes * 60)
    }
    
    func testAsHoursAndMinutes() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(hoursAsSeconds(hours: 2) + minutesAsSeconds(minutes: 22))

        let timeDifference = endTime.timeIntervalSince(startTime)
        let (hours, mins) = timeDifference.asHoursAndMinutes()

        XCTAssertEqual(hours, 2)
        XCTAssertEqual(mins, 22)

    }

    func testAsHoursAndMinutesString() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(hoursAsSeconds(hours: 2) + minutesAsSeconds(minutes: 22))
        let timeDifference = endTime.timeIntervalSince(startTime)
        let timeDifferenceString = timeDifference.asHoursAndMinutesString()

        XCTAssertEqual(timeDifferenceString, "2 hours, 22 minutes")
    }


    func testAsHoursAndMinutesStringZeroHours() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(minutesAsSeconds(minutes: 22))
        let timeDifference = endTime.timeIntervalSince(startTime)
        let timeDifferenceString = timeDifference.asHoursAndMinutesString()

        XCTAssertEqual(timeDifferenceString, "22 minutes")
    }


    func testAsHoursAndMinutesStringZeroMinutes() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(hoursAsSeconds(hours: 2))
        let timeDifference = endTime.timeIntervalSince(startTime)
        let timeDifferenceString = timeDifference.asHoursAndMinutesString()

        XCTAssertEqual(timeDifferenceString, "2 hours")
    }


    func testAsHoursAndMinutesStringOneHour() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(hoursAsSeconds(hours: 1))
        let timeDifference = endTime.timeIntervalSince(startTime)
        let timeDifferenceString = timeDifference.asHoursAndMinutesString()

        XCTAssertEqual(timeDifferenceString, "1 hour")
    }


    func testAsHoursAndMinutesStringOneMinute() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(minutesAsSeconds(minutes: 1))
        let timeDifference = endTime.timeIntervalSince(startTime)
        let timeDifferenceString = timeDifference.asHoursAndMinutesString()

        XCTAssertEqual(timeDifferenceString, "1 minute")
    }
}
