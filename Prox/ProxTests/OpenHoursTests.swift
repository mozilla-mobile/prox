/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest
@testable import Prox

class OpenHoursTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    private func assertEquals(_ actual: OpenHours, _ expected: OpenHours) {
        XCTAssertEqual(Set(actual.hours.keys), Set(expected.hours.keys))

        for dayOfWeek in expected.hours.keys {
            let (actualOpen, actualClose) = actual.hours[dayOfWeek]!.last!
            let (expectedOpen, expectedClose) = expected.hours[dayOfWeek]!.last!
            XCTAssertEqual(actualOpen.hour, expectedOpen.hour)
            XCTAssertEqual(actualOpen.minute, expectedOpen.minute)
            XCTAssertEqual(actualClose.hour, expectedClose.hour)
            XCTAssertEqual(actualClose.minute, expectedClose.minute)
        }
    }

    private func dateComponents(withHour hour: Int, minute: Int) -> DateComponents {
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        return dateComponents
    }

    private func dateComponents(withYear year: Int, month: Int, day: Int, hour: Int, minute: Int) -> DateComponents {
        var dateComponents = DateComponents(calendar: calendar, year: year, month: month, day: day)
        dateComponents.hour = hour
        dateComponents.minute = minute
        return dateComponents
    }

    func testFromFirebaseValue() {
        let firebase = ["monday" : [["7:00", "14:30"]],
                        "tuesday" : [["6:00", "7:00"],
                                     ["21:00", "22:00"]],
                        "wednesday" : [["21:00", "2:00"]]]
        let actual = OpenHours.fromFirebaseValue(firebase)

        // mondays opening time = 7:00
        // mondays closing time = 14: 30
        let monExpected = [(openTime: dateComponents(withHour: 7, minute: 0),
                           closeTime: dateComponents(withHour: 14, minute: 30))]

        // Tuesdays opening time = 21:00
        // tuesdays closing time = 22:00
        let tuesExpected = [(openTime: dateComponents(withHour: 21, minute: 0),
                            closeTime: dateComponents(withHour: 22, minute: 0))]

        // wednesdays opening time = 21:00
        // wednesdays closing time = 2:00
        let wedExpected = [(openTime: dateComponents(withHour: 21, minute: 0),
                            closeTime: dateComponents(withHour: 2, minute: 0))]
        let expected = OpenHours(hours: [DayOfWeek.monday : monExpected,
                                         DayOfWeek.tuesday : tuesExpected,
                                         DayOfWeek.wednesday : wedExpected])

        XCTAssertNotNil(actual)
        assertEquals(actual!, expected)

    }

    private func monday(atHour hour: Int, minute: Int) -> Date {
        return dateComponents(withYear: 2016, month: 11, day: 7, hour: hour, minute: minute).date!
    }

    private func tuesday(atHour hour: Int, minute: Int) -> Date {
        return dateComponents(withYear: 2016, month: 11, day: 8, hour: hour, minute: minute).date!
    }

    private func wednesday(atHour hour: Int, minute: Int) -> Date {
        return dateComponents(withYear: 2016, month: 11, day: 9, hour: hour, minute: minute).date!
    }

    func testIsClosedWhenCurrentTimeAfterYesterdaysClosingTimeButBeforeTodaysOpeningTime() {
        let hours = OpenHours(hours: [.sunday : [(openTime: dateComponents(withHour: 7, minute: 0), closeTime: dateComponents(withHour: 21, minute: 0))],
                                      .monday : [(openTime: dateComponents(withHour: 7, minute: 0), closeTime: dateComponents(withHour: 21, minute: 0))]])
        let date = monday(atHour: 6, minute: 59)

        assertIsClosed(openHours: hours, time: date)
    }

    func testIfOpenWhenCurrentTimeIsTodaysOpeningTime() {
        let hours = OpenHours(hours: [.sunday : [(openTime: dateComponents(withHour: 7, minute: 0), closeTime: dateComponents(withHour: 21, minute: 0))],
                                      .monday : [(openTime: dateComponents(withHour: 7, minute: 0), closeTime: dateComponents(withHour: 21, minute: 0))]])
        let date = monday(atHour: 7, minute: 00)
        assertIsOpen(openHours: hours, time: date)
    }

    func testIfOpenWhenCurrentTimeBetweenOpeningTimeAndClosingTime() {
        let hours = OpenHours(hours: [.sunday : [(openTime: dateComponents(withHour: 7, minute: 0), closeTime: dateComponents(withHour: 21, minute: 0))],
                                      .monday : [(openTime: dateComponents(withHour: 7, minute: 0), closeTime: dateComponents(withHour: 21, minute: 0))]])
        let date = monday(atHour: 12, minute: 00)
        assertIsOpen(openHours: hours, time: date)
    }

    func testIsClosedWhenCurrentTimeIsTodaysClosingTime() {
        let hours = OpenHours(hours: [.sunday : [(openTime: dateComponents(withHour: 7, minute: 0), closeTime: dateComponents(withHour: 21, minute: 0))],
                                      .monday : [(openTime: dateComponents(withHour: 7, minute: 0), closeTime: dateComponents(withHour: 21, minute: 0))],
                                      .tuesday : [(openTime: dateComponents(withHour: 7, minute: 0), closeTime: dateComponents(withHour: 21, minute: 0))]])
        let date = monday(atHour: 21, minute: 00)
        assertIsClosed(openHours: hours, time: date)
    }

    func testIsOpenWhenCurrentTimeIsBeforeMidnightAndClosingTimeIsAfterMidnight() {
        let opening = dateComponents(withHour: 7, minute: 0)
        let hours = OpenHours(hours: [.monday : [(openTime: opening, closeTime: dateComponents(withHour: 0, minute: 0))],
                                  .tuesday : [(openTime: opening, closeTime: dateComponents(withHour: 2, minute: 0))],
                                  .wednesday : [(openTime: opening, closeTime: dateComponents(withHour: 2, minute: 0))]])
        let date = monday(atHour: 23, minute: 59)
        assertIsOpen(openHours: hours, time: date)
    }

    func testIsClosedWhenCurrentTimeIsAfterMidnightAndClosingTimeIsBeforeMidnight() {
        let opening = dateComponents(withHour: 7, minute: 0)
        let hours = OpenHours(hours: [.monday : [(openTime: opening, closeTime: dateComponents(withHour: 23, minute: 30))],
                                      .tuesday : [(openTime: opening, closeTime: dateComponents(withHour: 2, minute: 0))],
                                      .wednesday : [(openTime: opening, closeTime: dateComponents(withHour: 2, minute: 0))]])
        let date = tuesday(atHour: 0, minute: 0)
        assertIsClosed(openHours: hours, time: date)
    }

    func testIsOpenWhenCurrentTimeIsAfterMidnightAndBeforeClosingTimeAfterMidnight() {
        let opening = dateComponents(withHour: 7, minute: 0)
        let hours = OpenHours(hours: [.monday : [(openTime: opening, closeTime: dateComponents(withHour: 0, minute: 0))],
                                      .tuesday : [(openTime: opening, closeTime: dateComponents(withHour: 2, minute: 0))],
                                      .wednesday : [(openTime: opening, closeTime: dateComponents(withHour: 2, minute: 0))]])
        let date = wednesday(atHour: 0, minute: 0)
        assertIsOpen(openHours: hours, time: date)
    }

    func testIsClosedWhenCurrentTimeIsAfterMidnightAndAfterClosingTimeAfterMidnight() {
        let opening = dateComponents(withHour: 7, minute: 0)
        let hours = OpenHours(hours: [.monday : [(openTime: opening, closeTime: dateComponents(withHour: 0, minute: 0))],
                                      .tuesday : [(openTime: opening, closeTime: dateComponents(withHour: 2, minute: 0))],
                                      .wednesday : [(openTime: opening, closeTime: dateComponents(withHour: 2, minute: 0))]])
        let date = wednesday(atHour: 3, minute: 0)
        assertIsClosed(openHours: hours, time: date)
    }

    func testIsClosedWhenCurrentTimeMatchesClosingTimeAfterMidnight() {
        let opening = dateComponents(withHour: 7, minute: 0)
        let hours = OpenHours(hours: [.monday : [(openTime: opening, closeTime: dateComponents(withHour: 0, minute: 0))],
                                      .tuesday : [(openTime: opening, closeTime: dateComponents(withHour: 2, minute: 0))],
                                      .wednesday : [(openTime: opening, closeTime: dateComponents(withHour: 2, minute: 0))]])
        let date = wednesday(atHour: 2, minute: 0)
        assertIsClosed(openHours: hours, time: date)
    }

    func testIsClosedWhenBeforeFirstOpeningPeriod() {
        let firstOpenPeriod = (openTime: dateComponents(withHour: 12, minute: 0), closeTime: dateComponents(withHour: 15, minute: 0))
        let secondOpenPeriod = (openTime: dateComponents(withHour: 18, minute: 0), closeTime: dateComponents(withHour: 1, minute: 30))
        let hours = OpenHours(hours: [.monday : [firstOpenPeriod, secondOpenPeriod],
                                      .tuesday : [firstOpenPeriod, secondOpenPeriod],
                                      .wednesday : [firstOpenPeriod, secondOpenPeriod]])
        let date = tuesday(atHour: 11, minute: 54)
        assertIsClosed(openHours: hours, time: date)
    }

    func testIsOpenWhenDuringFirstOpeningPeriod() {
        let firstOpenPeriod = (openTime: dateComponents(withHour: 12, minute: 0), closeTime: dateComponents(withHour: 15, minute: 0))
        let secondOpenPeriod = (openTime: dateComponents(withHour: 18, minute: 0), closeTime: dateComponents(withHour: 1, minute: 30))
        let hours = OpenHours(hours: [.monday : [firstOpenPeriod, secondOpenPeriod],
                                      .tuesday : [firstOpenPeriod, secondOpenPeriod],
                                      .wednesday : [firstOpenPeriod, secondOpenPeriod]])
        let date = tuesday(atHour: 13, minute: 18)
        assertIsOpen(openHours: hours, time: date)
    }

    func testIsClosedWhenBetweenOpeningPeriods() {
        let firstOpenPeriod = (openTime: dateComponents(withHour: 12, minute: 0), closeTime: dateComponents(withHour: 15, minute: 0))
        let secondOpenPeriod = (openTime: dateComponents(withHour: 18, minute: 0), closeTime: dateComponents(withHour: 1, minute: 30))
        let hours = OpenHours(hours: [.monday : [firstOpenPeriod, secondOpenPeriod],
                                      .tuesday : [firstOpenPeriod, secondOpenPeriod],
                                      .wednesday : [firstOpenPeriod, secondOpenPeriod]])
        let date = tuesday(atHour: 16, minute: 26)
        assertIsClosed(openHours: hours, time: date)
    }

    func testIsOpenWhenDuringSecondOpeningPeriod() {
        let firstOpenPeriod = (openTime: dateComponents(withHour: 12, minute: 0), closeTime: dateComponents(withHour: 15, minute: 0))
        let secondOpenPeriod = (openTime: dateComponents(withHour: 18, minute: 0), closeTime: dateComponents(withHour: 1, minute: 30))
        let hours = OpenHours(hours: [.monday : [firstOpenPeriod, secondOpenPeriod],
                                      .tuesday : [firstOpenPeriod, secondOpenPeriod],
                                      .wednesday : [firstOpenPeriod, secondOpenPeriod]])
        let date = tuesday(atHour: 20, minute: 12)
        assertIsOpen(openHours: hours, time: date)
    }

    func testIsOpenDuringSecondOpeningPeriodAfterMidnight() {
        let firstOpenPeriod = (openTime: dateComponents(withHour: 12, minute: 0), closeTime: dateComponents(withHour: 15, minute: 0))
        let secondOpenPeriod = (openTime: dateComponents(withHour: 18, minute: 0), closeTime: dateComponents(withHour: 1, minute: 30))
        let hours = OpenHours(hours: [.monday : [firstOpenPeriod, secondOpenPeriod],
                                      .tuesday : [firstOpenPeriod, secondOpenPeriod],
                                      .wednesday : [firstOpenPeriod, secondOpenPeriod]])
        let date = wednesday(atHour: 0, minute: 47)
        assertIsOpen(openHours: hours, time: date)
    }

    func testIsClosedAfterSecondOpeningPeriodAfterMidnight() {
        let firstOpenPeriod = (openTime: dateComponents(withHour: 12, minute: 0), closeTime: dateComponents(withHour: 15, minute: 0))
        let secondOpenPeriod = (openTime: dateComponents(withHour: 18, minute: 0), closeTime: dateComponents(withHour: 1, minute: 30))
        let hours = OpenHours(hours: [.monday : [firstOpenPeriod, secondOpenPeriod],
                                      .tuesday : [firstOpenPeriod, secondOpenPeriod],
                                      .wednesday : [firstOpenPeriod, secondOpenPeriod]])
        let date = wednesday(atHour: 1, minute: 38)
        assertIsClosed(openHours: hours, time: date)
    }

    private func assertIsOpen(openHours: OpenHours, time: Date) {
        XCTAssertTrue(openHours.isOpen(atTime: time), "Expected open for \(time)")
    }

    private func assertIsClosed(openHours: OpenHours, time: Date) {
        XCTAssertFalse(openHours.isOpen(atTime: time), "Expected closed for \(time)")
    }

    func testGetTimeString() {
        let opening = dateComponents(withHour: 7, minute: 0)
        let closing = dateComponents(withHour: 14, minute: 30)
        let tuesdayOpening = dateComponents(withHour: 10, minute: 0)
        let wednesdayOpening = dateComponents(withHour: 0, minute: 0)
        let hours = OpenHours(hours: [.monday : [(openTime: opening, closeTime: closing)],
                                      .tuesday : [(openTime: tuesdayOpening, closeTime: closing)],
                                      .wednesday : [(openTime: wednesdayOpening, closeTime: closing)]])

        var testDate = monday(atHour: 6, minute: 59)

        // we are before the opening time for today, so we are expecting todays opening time to be returned from nextOpeningTime
        XCTAssertEqual(hours.nextOpeningTime(forTime: testDate), "7:00 AM")
        XCTAssertEqual(hours.closingTime(forTime: testDate), "2:30 PM")

        // If today's hours are done, show "tomorrow".
        testDate = monday(atHour: 14, minute: 01)
        XCTAssertEqual(hours.nextOpeningTime(forTime: testDate), "tomorrow")

        // If the hours start at midnight, also show that as "tomorrow".
        testDate = tuesday(atHour: 10, minute: 1)
        XCTAssertEqual(hours.nextOpeningTime(forTime: testDate), "tomorrow")

        // Both days have passed, so look ahead to next week.
        testDate = wednesday(atHour: 0, minute: 1)
        XCTAssertEqual(hours.nextOpeningTime(forTime: testDate), "Monday")
    }
}
