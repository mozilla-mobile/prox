/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest
@testable import Prox

class EventTests: XCTestCase {

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

    func getEvent(withStartDate startDate: Date, andEndDate endDate: Date?) -> Event {
        return Event(id: "1", placeId: "2", coordinates: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), description: "Event", url: nil, startTime: startDate, endTime: endDate)
    }

    func testCurrentTimeTooEarlyBeforeEvent() {
        let startTime = currentTime + (2 * oneHour)
        let endTime = currentTime + endTimeInterval + oneHour
        let event = getEvent(withStartDate: startTime, andEndDate: endTime)
        XCTAssertFalse(event.shouldShowEvent(withStartTime: startTime, endTime: endTime, timeIntervalBeforeStartOfEvent: startTimeInterval, timeIntervalBeforeEndOfEvent: endTimeInterval, atCurrentTime: currentTime))
    }


    func testCurrentTimeTooEarlyBeforeEventNoEndTime() {
        let startTime = currentTime + (2 * oneHour)
        let event = getEvent(withStartDate: startTime, andEndDate: nil)
        XCTAssertFalse(event.shouldShowEvent(withStartTime: startTime, endTime: nil, timeIntervalBeforeStartOfEvent: startTimeInterval, timeIntervalBeforeEndOfEvent: endTimeInterval, atCurrentTime: currentTime))
    }

    func testCurrentTimeWithinTimeIntervalBeforeEvent() {
        let startTime = currentTime + (startTimeInterval / 2)
        let event = getEvent(withStartDate: startTime, andEndDate: nil)
        XCTAssertTrue(event.shouldShowEvent(withStartTime: startTime, endTime: nil, timeIntervalBeforeStartOfEvent: startTimeInterval, timeIntervalBeforeEndOfEvent: endTimeInterval, atCurrentTime: currentTime))
    }

    func testCurrentTimeWithinTimeIntervalDuringEvent() {
        let startTime = currentTime - (4 * oneHour)
        let endTime = currentTime + endTimeInterval + oneHour
        let event = getEvent(withStartDate: startTime, andEndDate: endTime)
        XCTAssertTrue(event.shouldShowEvent(withStartTime: startTime, endTime: endTime, timeIntervalBeforeStartOfEvent: startTimeInterval, timeIntervalBeforeEndOfEvent: endTimeInterval, atCurrentTime: currentTime))
    }

    func testCurrentTimeAfterTimeIntervalDuringEvent() {
        let startTime = currentTime - (6 * oneHour)
        let endTime = currentTime + (endTimeInterval / 2)
        let event = getEvent(withStartDate: startTime, andEndDate: endTime)
        XCTAssertFalse(event.shouldShowEvent(withStartTime: startTime, endTime: endTime, timeIntervalBeforeStartOfEvent: startTimeInterval, timeIntervalBeforeEndOfEvent: endTimeInterval, atCurrentTime: currentTime))
    }

    func testCurrentTimeAfterEventEnds() {
        let startTime = currentTime - (6 * oneHour)
        let endTime = currentTime - oneHour
        let event = getEvent(withStartDate: startTime, andEndDate: endTime)
        XCTAssertFalse(event.shouldShowEvent(withStartTime: startTime, endTime: endTime, timeIntervalBeforeStartOfEvent: startTimeInterval, timeIntervalBeforeEndOfEvent: endTimeInterval, atCurrentTime: currentTime))
    }

    func testCurrentTimeAfterEventStartsNoEndTime() {
        let startTime = currentTime - oneHour
        let event = getEvent(withStartDate: startTime, andEndDate: nil)
        XCTAssertFalse(event.shouldShowEvent(withStartTime: startTime, endTime: nil, timeIntervalBeforeStartOfEvent: startTimeInterval, timeIntervalBeforeEndOfEvent: endTimeInterval, atCurrentTime: currentTime))
    }
}
