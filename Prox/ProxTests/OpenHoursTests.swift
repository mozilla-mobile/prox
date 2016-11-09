/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest
@testable import Prox

class OpenHoursTests: XCTestCase {

    private var GregorianCalendar: Calendar!

    override func setUp() {
        super.setUp()
        GregorianCalendar = Calendar(identifier: .gregorian)
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

    func testFromFirebaseValue() {
        let firebase = ["monday" : [["7:00", "14:30"]],
                        "tuesday" : [["6:00", "7:00"],
                                     ["21:00", "22:00"]],
                        "wednesday" : [["21:00", "2:00"]]]
        let actual = OpenHours.fromFirebaseValue(firebase)

        var openingDateComponents = DateComponents()
        openingDateComponents.hour = 7
        openingDateComponents.minute = 0
        var closingDateComponents = DateComponents()
        closingDateComponents.hour = 14
        closingDateComponents.minute = 30
        let monExpected = (openTime: openingDateComponents,
                           closeTime: closingDateComponents)

        openingDateComponents.hour = 21
        closingDateComponents.hour = 22
        closingDateComponents.minute = 0
        let tuesExpected = (openTime: openingDateComponents,
                            closeTime: closingDateComponents)

        closingDateComponents.hour = 2
        let wedExpected = (openTime: openingDateComponents,
                            closeTime: closingDateComponents)
        let expected = OpenHours(hours: [DayOfWeek.monday : monExpected,
                                         DayOfWeek.tuesday : tuesExpected,
                                         DayOfWeek.wednesday : wedExpected])

        XCTAssertNotNil(actual)
        assertEquals(actual!, expected)

    }

    // Date is normalized to allow simple time comparisons, like OpenHours' stored dates.
    private func getNormalizedDate(forHour hour: Int, forMin minute: Int, isTomorrow: Bool = false) -> Date? {
        var date = DateComponents.init(calendar: GregorianCalendar,
                                       // fragile: OpenHours uses DateFormatter & these are its default d/m/y
                                       year: 2000, month: 1, day: 1,
                                       hour: hour, minute: minute).date
        if isTomorrow {
            date!.addTimeInterval(60 * 60 * 24)
        }
        return date
    }

    func testIsOpen() {
        var date = DateComponents.init(calendar: GregorianCalendar,
                                             year: 2016, month: 11, day: 7)
        date.hour = 6
        date.minute = 59

        var opening = DateComponents()
        opening.hour = 7
        opening.minute = 0
        var closing = DateComponents()
        closing.hour = 21
        closing.minute = 0

        var hours = OpenHours(hours: [.monday : (openTime: opening, closeTime: closing)])

        XCTAssertFalse(hours.isOpen(atTime: date.date!), "Expected closed for \(date)")

        date.hour = 7
        date.minute = 0
        XCTAssertTrue(hours.isOpen(atTime: date.date!), "Expected open for \(date)")

        date.hour = 21
        date.minute = 0
        XCTAssertFalse(hours.isOpen(atTime: date.date!), "Expected closed for \(date)")

        closing.hour = 2
        closing.minute = 0
        hours = OpenHours(hours: [.monday : (openTime: opening, closeTime: closing),
                                  .tuesday : (openTime: opening, closeTime: closing)])

        date.hour = 23
        date.minute = 59
        XCTAssertTrue(hours.isOpen(atTime: date.date!), "Expected open for \(date)")

        date.hour = 0
        date.minute = 0
        XCTAssertFalse(hours.isOpen(atTime: date.date!), "Expected closed for \(date)")

        date.day = 8
        XCTAssertTrue(hours.isOpen(atTime: date.date!), "Expected open for \(date)")

        date.hour = 2
        date.minute = 0
        XCTAssertFalse(hours.isOpen(atTime: date.date!), "Expected closed for \(date)")
    }

    func testGetTimeString() {
        var opening = DateComponents()
        opening.hour = 7
        opening.minute = 0
        var closing = DateComponents()
        closing.hour = 14
        closing.minute = 30
        var tuesdayOpening = DateComponents()
        tuesdayOpening.hour = 10
        tuesdayOpening.minute = 0
        let hours = OpenHours(hours: [.monday : (openTime: opening, closeTime: closing),
                                      .tuesday : (openTime: tuesdayOpening, closeTime: closing)])

        var testDateComponents = DateComponents.init(calendar: GregorianCalendar,
                                           year: 2016, month: 11, day: 7) // Mon Nov. 7th 2016

        testDateComponents.hour = 6
        testDateComponents.minute = 59

        var testDate = testDateComponents.date!

        XCTAssertEqual(hours.nextOpeningTime(forTime: testDate), "7:00 AM")
        XCTAssertEqual(hours.closingTime(forTime: testDate), "2:30 PM")


        testDateComponents.hour = 14
        testDateComponents.minute = 01
        testDate = testDateComponents.date!
        XCTAssertEqual(hours.nextOpeningTime(forTime: testDate), "10:00 AM")
    }
}
