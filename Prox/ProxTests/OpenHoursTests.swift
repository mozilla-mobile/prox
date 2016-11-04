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
            XCTAssertEqual(actualOpen, expectedOpen)
            XCTAssertEqual(actualClose, expectedClose)
        }
    }

    func testFromFirebaseValue() {
        let firebase = ["monday" : [["7:00", "14:30"]],
                        "tuesday" : [["6:00", "7:00"],
                                     ["21:00", "22:00"]],
                        "wednesday" : [["21:00", "2:00"]]]
        let actual = OpenHours.fromFirebaseValue(firebase)

        let monExpected = (open: getNormalizedDate(forHour: 7, forMin: 0)!,
                           close: getNormalizedDate(forHour: 14, forMin: 30)!)
        let tuesExpected = (open: getNormalizedDate(forHour: 21, forMin: 0)!,
                            close: getNormalizedDate(forHour: 22, forMin: 0)!)
        let wedExpected = (open: getNormalizedDate(forHour: 21, forMin: 0)!,
                           close: getNormalizedDate(forHour: 2, forMin: 0, isTomorrow: true)!)
        let expected = OpenHours(hours: [DayOfWeek.monday : monExpected,
                                         DayOfWeek.tuesday : tuesExpected,
                                         DayOfWeek.wednesday : wedExpected])

        XCTAssertNotNil(actual)
        assertEquals(actual!, expected)

        // Time comparisons
        for day in actual!.hours.keys {
            let (open, close) = actual!.hours[day]!
            XCTAssertLessThan(open, close)
        }
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
        let mondayDate = DateComponents.init(calendar: GregorianCalendar,
                                             year: 2016, month: 11, day: 7).date! // Mon Nov. 7th 2016
        let tuesdayDate = DateComponents.init(calendar: GregorianCalendar,
                                              year: 2016, month: 11, day: 8).date!

        let hours = OpenHours(hours: [.monday : (open: mondayDate, close: mondayDate)])

        XCTAssertTrue(hours.isOpen(onDate: mondayDate), "Expected open for \(mondayDate)")
        XCTAssertFalse(hours.isOpen(onDate: tuesdayDate), "Expected closed for \(tuesdayDate)")
    }

    func testGetTimeString() {
        let openDate = getNormalizedDate(forHour: 7, forMin: 0)!
        let closeDate = getNormalizedDate(forHour: 14, forMin: 30)!
        let hours = OpenHours(hours: [.monday : (open: openDate, close: closeDate)])

        let testDate = DateComponents.init(calendar: GregorianCalendar,
                                           year: 2016, month: 11, day: 7).date! // Mon Nov. 7th 2016

        XCTAssertEqual(hours.getOpenTimeString(forDate: testDate), "7:00 AM")
        XCTAssertEqual(hours.getCloseTimeString(forDate: testDate), "2:30 PM")
    }
}
