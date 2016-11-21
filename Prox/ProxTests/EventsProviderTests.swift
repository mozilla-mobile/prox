/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest
@testable import Prox

class EventsProviderTests: XCTestCase {

    let eventProvider = EventsProvider()

    let oneHour: Double = 60 * 60
    let timeInterval: Double = 3 * 60 * 60
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func getEvent(withStartDate startDate: Date, andEndDate endDate: Date?) -> Event {
        return Event(id: "1", placeId: "2", description: "Event", url: nil, startTime: startDate, endTime: endDate)
    }

    func testIsInvalidCurrentEventIfEndTimeNil() {
        let now = Date()
        let event = getEvent(withStartDate: now + oneHour, andEndDate: nil)
        XCTAssertFalse(eventProvider.isValidCurrentEvent(event: event, currentTime: now))
    }

    func testIsTimeWithinTimeIntervalFromTime() {
        let now = Date()
        XCTAssertTrue(eventProvider.isTime(time: now + oneHour, withinTimeInterval: timeInterval, fromTime: now))
    }

    func testIsTimeWithinTimeIntervalFromTimeFalse() {
        let now = Date()
        XCTAssertFalse(eventProvider.isTime(time: now + timeInterval, withinTimeInterval: timeInterval - oneHour, fromTime: now ))
    }

    func testIsFutureEventTrueIfCurrentTimeBeforeStartTime() {
        let now = Date()
        let event = getEvent(withStartDate: now + oneHour, andEndDate: nil)
        XCTAssertTrue(eventProvider.isFutureEvent(event: event, currentTime: now))
    }

    func testIsFutureEventFalseIfCurrentTimeAtStartTime() {
        let now = Date()
        let event = getEvent(withStartDate: now, andEndDate: nil)
        XCTAssertFalse(eventProvider.isFutureEvent(event: event, currentTime: now))
    }

    func testIsFutureEventFalseIfCurrentTimeAfterStartTime() {
        let now = Date()
        let event = getEvent(withStartDate: now - oneHour, andEndDate: nil)
        XCTAssertFalse(eventProvider.isFutureEvent(event: event, currentTime: now))
    }

    func testIsCurrentEventTrueIfCurrentTimeBetweenStartAndEndTimes() {
        let now = Date()
        let event = getEvent(withStartDate: now - oneHour, andEndDate: now + timeInterval)
        XCTAssertTrue(eventProvider.isCurrentEvent(event: event, currentTime: now))
    }

    func testIsCurrentEventTrueIfCurrentTimeAtStartTime() {
        let now = Date()
        let event = getEvent(withStartDate: now, andEndDate: now + timeInterval)
        XCTAssertTrue(eventProvider.isCurrentEvent(event: event, currentTime: now))
    }

    func testIsCurrentEventTrueIfCurrentTimeAtEndTime() {
        let now = Date()
        let event = getEvent(withStartDate: now.addingTimeInterval(-timeInterval), andEndDate: now)
        XCTAssertTrue(eventProvider.isCurrentEvent(event: event, currentTime: now))
    }

    func testIsCurrentEventFalseIfCurrentTimeBeforeStartTime() {
        let now = Date()
        let event = getEvent(withStartDate: now + oneHour, andEndDate: now + timeInterval)
        XCTAssertFalse(eventProvider.isCurrentEvent(event: event, currentTime: now))
    }

    func testIsCurrentEventFalseIfCurrentTimeAfterEndTime() {
        let now = Date()
        let event = getEvent(withStartDate: now - timeInterval, andEndDate: now - oneHour)
        XCTAssertFalse(eventProvider.isCurrentEvent(event: event, currentTime: now))
    }

    func testIsCurrentEventFalseNoEndTime() {
        let now = Date()
        let event = getEvent(withStartDate: now, andEndDate: nil)
        XCTAssertFalse(eventProvider.isCurrentEvent(event: event, currentTime: now))
    }

    func testDoesEventLastLessThanTimeIntervalTrueIfLessThanDuration() {
        // returns true if startDate - endDate <= timeInterval
        let now = Date()
        let event = getEvent(withStartDate: now, andEndDate: now + timeInterval)
        XCTAssertTrue(eventProvider.doesEvent(event: event, lastLessThan: timeInterval + oneHour))
    }

    func testDoesEventLastLessThanTimeIntervalTrueIfEqualToDuration() {
        // returns true if startDate - endDate <= timeInterval
        let now = Date()
        let timeInterval: Double = 3 * oneHour
        let event = getEvent(withStartDate: now, andEndDate: now + timeInterval)
        XCTAssertTrue(eventProvider.doesEvent(event: event, lastLessThan: timeInterval))
    }

    func testDoesEventLastLessThanTimeIntervalFalseIfGreaterThanDuration() {
        // return false is startDate - endDate > timeInterval
        let now = Date()
        let event = getEvent(withStartDate: now, andEndDate: now + (timeInterval + oneHour))
        XCTAssertFalse(eventProvider.doesEvent(event: event, lastLessThan: timeInterval))

    }
    func testDoesEventLastLessThanTimeIntervalFalseIfEndTimeNil() {
        // returns false if endDate is nil
        let now = Date()
        let event = getEvent(withStartDate: now, andEndDate: nil)
        XCTAssertFalse(eventProvider.doesEvent(event: event, lastLessThan: timeInterval))
    }
}
