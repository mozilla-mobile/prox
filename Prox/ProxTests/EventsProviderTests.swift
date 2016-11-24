/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest
@testable import Prox

class EventsProviderTests: XCTestCase {

    let eventProvider = EventsProvider()

    let oneHour: Double = 60 * 60

    lazy var startTimeInterval: Double = { return self.oneHour } ()
    lazy var endTimeInterval: Double = { return 2 * self.oneHour } ()

    let currentTime = Date()
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testCurrentTimeTooEarlyBeforeEvent() {
        XCTAssertFalse(eventProvider.shouldShowEvent(withStartTime: currentTime + (2 * oneHour), endTime: nil, timeIntervalBeforeStartOfEvent: startTimeInterval, timeIntervalBeforeEndOfEvent: endTimeInterval, atCurrentTime: currentTime))
    }

    func testCurrentTimeWithinTimeIntervalBeforeEvent() {
        let startTime = currentTime + (startTimeInterval / 2)
        XCTAssertTrue(eventProvider.shouldShowEvent(withStartTime: startTime, endTime: nil, timeIntervalBeforeStartOfEvent: startTimeInterval, timeIntervalBeforeEndOfEvent: endTimeInterval, atCurrentTime: currentTime))
    }

    func testCurrentTimeWithinTimeIntervalDuringEvent() {
        let startTime = currentTime - (4 * oneHour)
        let endTime = currentTime + endTimeInterval + oneHour
        XCTAssertTrue(eventProvider.shouldShowEvent(withStartTime: startTime, endTime: endTime, timeIntervalBeforeStartOfEvent: startTimeInterval, timeIntervalBeforeEndOfEvent: endTimeInterval, atCurrentTime: currentTime))
    }

    func testCurrenTimeAfterTimeIntervalDuringEvent() {
        let startTime = currentTime - (6 * oneHour)
        let endTime = currentTime + (endTimeInterval / 2)
        XCTAssertFalse(eventProvider.shouldShowEvent(withStartTime: startTime, endTime: endTime, timeIntervalBeforeStartOfEvent: startTimeInterval, timeIntervalBeforeEndOfEvent: endTimeInterval, atCurrentTime: currentTime))
    }

    func testCurrentTimeAfterEventEnds() {
        let startTime = currentTime - (6 * oneHour)
        let endTime = currentTime - oneHour
        XCTAssertFalse(eventProvider.shouldShowEvent(withStartTime: startTime, endTime: endTime, timeIntervalBeforeStartOfEvent: startTimeInterval, timeIntervalBeforeEndOfEvent: endTimeInterval, atCurrentTime: currentTime))
    }

    func testCurrentTimeAfterEventStartsNoEndTime() {
        let startTime = currentTime - oneHour
        XCTAssertFalse(eventProvider.shouldShowEvent(withStartTime: startTime, endTime: nil, timeIntervalBeforeStartOfEvent: startTimeInterval, timeIntervalBeforeEndOfEvent: endTimeInterval, atCurrentTime: currentTime))
    }
}
