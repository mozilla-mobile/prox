/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

/// An event. Properties are modelled after an Eventbrite Event:
///   https://www.eventbrite.com/developer/v3/response_formats/event/#ebapi-std:format-event
/// This is likely to change when we add events from other providers.

struct Event {

    let name: String
    let description: String?
    let url: URL?

    let category: String?
    let subcategory: String?
    let format: String? // called "Event Type" on Eventbrite's website.

    /// The event start date in the event's local timezone.
    let start: Date
    /// The event end date in the event's local timezone.
    let end: Date

    let location: CLLocationCoordinate2D

    let photoURLs: [URL]

    // Unused things we might care about.
    let venueName: String?
    let isOnline: Bool? // maybe not relevant since we require a location.
    let isFree: Bool? // TODO: would it be useful to get the ticket price too? Can we?
    let capacity: Int?

    /// True if this a repeating event.
    let isSeries: Bool?
    let isSeriesParent: Bool?

    // let bookmarkInfo => we could get this property, which gives the count of ppl who bookmarked this event.

    func toPlace() -> Place {
        let categoryNames = [category, subcategory, format].flatMap { $0 }

        return Place(id: Event.getID(),
                     name: name,
                     latLong: location,
                     categories: (categoryNames, categoryNames), // dupe names & ids because we don't actually have IDs.
                     photoURLs: photoURLs,
                     url: url,
                     hours: OpenHours(start: start, end: end),
                     yelpProvider: SinglePlaceProvider(fromDictionary: [:]),
                     // TODO: if description is empty, the event won't have an event banner.
                     customProvider: SinglePlaceProvider(fromDictionary: ["description": description as Any])
        )
    }

    // TODO: use name & date.
    private static var idCount = 0
    private static func getID() -> String {
        idCount += 1
        return AppConstants.testPrefixEvent + String(idCount)
    }
}

// MARK: OpenHours conversion.
// TODO: encapsulate in other file? It's getting messy in here.
private let openHoursCalendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)

    // We assume the given Date objects are in the time zone of the event and the framework assumes
    // Date objects are in GMT so we set the calendar to GMT to ensure the calendar doesn't offset
    // the Date objects for time zone.
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    cal.locale = Locale(identifier: "en_US")  // necessary for Calendar.weekdaySymbols to return long symbols.
    return cal
}()

private let openHoursComponents = Set<Calendar.Component>(arrayLiteral: .day)
private let oneDay: TimeInterval = 60 * 60 * 24

private extension OpenHours {

    /// Returns the OpenHours for the given start & end times, assumed to be in the timezone of the
    /// event. Notes:
    /// - The event can only span one overnight period (an assumption in OpenHours).
    /// - The returned times are in the timezone of the event, rather than the users current time zone.
    init?(start: Date, end: Date) {
        guard start <= end else { return nil }

        let startComponents = openHoursCalendar.dateComponents(openHoursComponents, from: start)
        let dayAfterStartComponents = openHoursCalendar.dateComponents(openHoursComponents, from: start.addingTimeInterval(oneDay))
        let endComponents = openHoursCalendar.dateComponents(openHoursComponents, from: end)

        // OpenHours assumes things can only be open for one overnight cycle.
        guard startComponents.day == endComponents.day ||
            dayAfterStartComponents.day == endComponents.day else { return nil }

        // HACK: we're duplicating the functionality from `OpenHours.fromFirebaseValue`, which sets the OpenHours with
        // `timeComponentsSet`. This is fragile because the specific DateComponents required is not type-safe.
        let startTimeComp = openHoursCalendar.dateComponents(OpenHours.timeComponentsSet, from: start)
        let endTimeComp = openHoursCalendar.dateComponents(OpenHours.timeComponentsSet, from: end)

        let currentDay = OpenHours.dayOfWeekForDate(start)
        var hours = [DayOfWeek: [OpenPeriodDateComponents]]()
        hours[currentDay] = [(openTime: startTimeComp, closeTime: endTimeComp)]
        self.init(hours: hours)
    }

    // HACK: This duplicates DayOfWeek.forDate, but that assumes a time zone and it was easier to
    // copy-pasta than fix it.
    private static func dayOfWeekForDate(_ date: Date) -> DayOfWeek {
        let weekdayInt = openHoursCalendar.component(.weekday, from: date)
        let weekdayStr = openHoursCalendar.weekdaySymbols[weekdayInt - 1]
        return DayOfWeek(rawValue: weekdayStr.lowercased())!
    }
}
