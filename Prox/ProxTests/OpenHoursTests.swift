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
            let (actualOpen, actualClose) = actual.hours[dayOfWeek]!
            let (expectedOpen, expectedClose) = expected.hours[dayOfWeek]!
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
        let monExpected = (openTime: dateComponents(withHour: 7, minute: 0),
                           closeTime: dateComponents(withHour: 14, minute: 30))

        // Tuesdays opening time = 21:00
        // tuesdays closing time = 22:00
        let tuesExpected = (openTime: dateComponents(withHour: 21, minute: 0),
                            closeTime: dateComponents(withHour: 22, minute: 0))

        // wednesdays opening time = 21:00
        // wednesdays closing time = 2:00
        let wedExpected = (openTime: dateComponents(withHour: 21, minute: 0),
                            closeTime: dateComponents(withHour: 2, minute: 0))
        let expected = OpenHours(hours: [DayOfWeek.monday : monExpected,
                                         DayOfWeek.tuesday : tuesExpected,
                                         DayOfWeek.wednesday : wedExpected])

        XCTAssertNotNil(actual)
        assertEquals(actual!, expected)

    }

    func testIsOpen() {
        // current time 7th November 2016 06:59
        var date = dateComponents(withYear: 2016, month: 11, day: 7, hour: 6, minute: 59).date!

        // open time 07:00, closing time 21:00
        var hours = OpenHours(hours: [.monday : (openTime: dateComponents(withHour: 7, minute: 0), closeTime: dateComponents(withHour: 21, minute: 0))])

        XCTAssertFalse(hours.isOpen(atTime: date), "Expected closed for \(date)")

        // current time 7th November 2016 07:00
        date = dateComponents(withYear: 2016, month: 11, day: 7, hour: 7, minute: 0).date!
        XCTAssertTrue(hours.isOpen(atTime: date), "Expected open for \(date)")

        // current time 7th November 2016 21:00
        date = dateComponents(withYear: 2016, month: 11, day: 7, hour: 21, minute: 0).date!
        XCTAssertFalse(hours.isOpen(atTime: date), "Expected closed for \(date)")

        // Monday open time 07:00, closing time 00:00
        // Tuesday open time 07:00, closing time 02:00
        let opening = dateComponents(withHour: 7, minute: 0)
        hours = OpenHours(hours: [.monday : (openTime: opening, closeTime: dateComponents(withHour: 0, minute: 0)),
                                  .tuesday : (openTime: opening, closeTime: dateComponents(withHour: 2, minute: 0)),
                                  .wednesday : (openTime: opening, closeTime: dateComponents(withHour: 2, minute: 0))])

        // current time 7th November 2016 23:59
        // open time 7th November 2016 07:00
        // close time 8th November 2016 00:00
        date = dateComponents(withYear: 2016, month: 11, day: 7, hour: 23, minute: 59).date!
        XCTAssertTrue(hours.isOpen(atTime: date), "Expected open for \(date)")

        // current time 7th November 2016 00:00
        // open time 7th November 2016 07:00
        // close time 8th November 2016 00:00
        date = dateComponents(withYear: 2016, month: 11, day: 7, hour: 0, minute: 0).date!
        XCTAssertFalse(hours.isOpen(atTime: date), "Expected closed for \(date)")

        // current time 9th November 2016 00:00
        // open time 8th November 2016 07:00
        // close time 9th November 2016 02:00
        date = dateComponents(withYear: 2016, month: 11, day: 9, hour: 0, minute: 0).date!
        XCTAssertTrue(hours.isOpen(atTime: date), "Expected open for \(date)")

        // current time 9th November 2016 02:00
        // open time 8th November 2016 07:00
        // close time 9th November 2016 02:00
        date = dateComponents(withYear: 2016, month: 11, day: 9, hour: 2, minute: 0).date!
        XCTAssertFalse(hours.isOpen(atTime: date), "Expected closed for \(date)")
    }

    func testGetTimeString() {
        let opening = dateComponents(withHour: 7, minute: 0)
        let closing = dateComponents(withHour: 14, minute: 30)
        let tuesdayOpening = dateComponents(withHour: 10, minute: 0)
        let hours = OpenHours(hours: [.monday : (openTime: opening, closeTime: closing),
                                      .tuesday : (openTime: tuesdayOpening, closeTime: closing)])

        var testDateComponents = dateComponents(withYear: 2016, month: 11, day: 7, hour: 6, minute: 59) // Mon Nov. 7th 2016 06:59
        var testDate = testDateComponents.date!

        // we are before the opening time for today, so we are expecting todays opening time to be returned from nextOpeningTime
        XCTAssertEqual(hours.nextOpeningTime(forTime: testDate), "7:00 AM")
        XCTAssertEqual(hours.closingTime(forTime: testDate), "2:30 PM")

        // we are now past the opening time for today, so we are expecting tomorrows opening time to be returned from nextOpeningTime
        testDateComponents = dateComponents(withYear: 2016, month: 11, day: 7, hour: 14, minute: 01) // Mon Nov. 7th 2016 14:01
        testDate = testDateComponents.date!
        XCTAssertEqual(hours.nextOpeningTime(forTime: testDate), "10:00 AM")
    }
}
