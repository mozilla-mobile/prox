/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Firebase
import CoreLocation
import Deferred

private let PROVIDERS_PATH = "providers/"
private let YELP2_PATH = PROVIDERS_PATH + "yelp"
private let YELP3_PATH = PROVIDERS_PATH + "yelp3"
private let TRIP_ADVISOR_PATH = PROVIDERS_PATH + "tripAdvisor"
private let WIKIPEDIA_PATH = PROVIDERS_PATH + "wikipedia"
private let GOOGLE_PATH = PROVIDERS_PATH + "google"
private let CUSTOM_PATH = PROVIDERS_PATH + "custom"

typealias CachedTravelTime = (deferred: Deferred<DatabaseResult<TravelTimes>>, forLocation: CLLocation)

class Place: Hashable {

    fileprivate static let travelTimeExpirationDistance: CLLocationDistance = {
        return RemoteConfigKeys.travelTimeExpirationDistance.value
    }()

    // HACK: probably shouldn't be a static member.
    static let travelTimesCache = TravelTimesCache()

    var hashValue: Int {
        return id.hashValue
    }

    private let transitTypes: [MKDirectionsTransportType] = [.automobile, .walking]

    let id: String
    let name: String
    let categories: (names: [String], ids: [String]) // Indices correlate.
    let latLong: CLLocationCoordinate2D
    let photoURLs: [URL]
    let url: URL?
    let website: URL?
    let address: String?
    let hours: OpenHours?
    let totalReviewCount: Int
    let yelpProvider: PlaceProvider
    let tripAdvisorProvider: PlaceProvider?
    let wikipediaProvider: PlaceProvider?
    let googleProvider: PlaceProvider?
    let customProvider: PlaceProvider?

    init(id: String,
         name: String,
         latLong: CLLocationCoordinate2D,
         categories: (names: [String], ids: [String]),
         photoURLs: [URL] = [],
         url: URL? = nil,
         website: URL? = nil,
         address: String? = nil,
         hours: OpenHours? = nil,
         totalReviewCount: Int = 0,
         yelpProvider: PlaceProvider,
         tripAdvisorProvider: PlaceProvider? = nil,
         wikipediaProvider: PlaceProvider? = nil,
         googleProvider: PlaceProvider? = nil,
         customProvider: PlaceProvider? = nil) {
            self.id = id
            self.name = name
            self.categories = categories
            self.latLong = latLong
            self.url = url
            self.website = website
            self.address = address
            self.photoURLs = photoURLs
            self.hours = hours
            self.totalReviewCount = totalReviewCount
            self.yelpProvider = yelpProvider
            self.tripAdvisorProvider = tripAdvisorProvider
            self.wikipediaProvider = wikipediaProvider
            self.googleProvider = googleProvider
            self.customProvider = customProvider
    }

    convenience init?(fromFirebaseSnapshot details: FIRDataSnapshot) {
        guard let yelp2Dict = details.childSnapshot(forPath: YELP2_PATH).value as? [String: Any] else {
            log.warn("place has no Yelp content: \(details.key)")
            return nil
        }

        let yelp3Dict = details.childSnapshot(forPath: YELP3_PATH).value as? [String: Any] ?? [:]
        let yelp2Provider = SinglePlaceProvider(fromDictionary: yelp2Dict)
        let yelp3Provider = SinglePlaceProvider(fromDictionary: yelp3Dict)
        let yelpProvider = CompositePlaceProvider(fromProviders: [yelp2Provider, yelp3Provider])

        var tripAdvisorProvider: SinglePlaceProvider?
        if let tripAdvisorDict = details.childSnapshot(forPath: TRIP_ADVISOR_PATH).value as? [String: Any] {
            tripAdvisorProvider = SinglePlaceProvider(fromDictionary: tripAdvisorDict)
        }

        var wikipediaProvider: SinglePlaceProvider?
        if let wikipediaDict = details.childSnapshot(forPath: WIKIPEDIA_PATH).value as? [String: Any] {
            wikipediaProvider = SinglePlaceProvider(fromDictionary: wikipediaDict)
        }

        var googleProvider: SinglePlaceProvider?
        if let googleDict = details.childSnapshot(forPath: GOOGLE_PATH).value as? [String: Any] {
            googleProvider = SinglePlaceProvider(fromDictionary: googleDict)
        }

        var customProvider: SinglePlaceProvider?
        if let customDict = details.childSnapshot(forPath: CUSTOM_PATH).value as? [String: Any] {
            customProvider = SinglePlaceProvider(fromDictionary: customDict)
        }

        let providers: [PlaceProvider?] = [customProvider, googleProvider, yelpProvider, tripAdvisorProvider, wikipediaProvider]

        let compositeProvider = CompositePlaceProvider(fromProviders: providers.flatMap { $0 })

        guard let id = compositeProvider.id else {
            log.error("fetched place with no id!")
            return nil
        }

        guard let name = compositeProvider.name,
              let latLong = compositeProvider.latLong,
              !compositeProvider.photoURLs.isEmpty else {
            log.warn("dropping place \(id): missing name, photos, or coords")
            return nil
        }

        log.debug("found place: \(id)")

        self.init(id: id,
                  name: name,
                  latLong: latLong,
                  categories: compositeProvider.categories,
                  photoURLs: compositeProvider.photoURLs,
                  url: compositeProvider.url,
                  website: compositeProvider.website,
                  address: compositeProvider.address,
                  hours: compositeProvider.hours,
                  totalReviewCount: compositeProvider.totalReviewCount,
                  yelpProvider: yelpProvider,
                  tripAdvisorProvider: tripAdvisorProvider,
                  wikipediaProvider: wikipediaProvider)
    }

    static func ==(lhs: Place, rhs: Place) -> Bool {
        return lhs.id == rhs.id
    }

    func travelTimes(fromLocation location: CLLocation, withTransitTypes transitTypes: [MKDirectionsTransportType] = [.automobile, .walking]) -> Deferred<DatabaseResult<TravelTimes>> {
        // TODO: we get a value from the travel times cache and maybe set one later. If this truly
        // happens concurrently, the value can change between accesses. We can solve by:
        //   - locking thewhole time (which breaks the encapsulation I wrote)
        //   - ensuring this is always run on the same thread.
        // For now, I think this is good enough because I doubt we get called from different threads.
        // I noticed this might be a problem because I tried to add `assert(Thread.isMainThread)`,
        // which failed.
        if let lastTravelTime = Place.travelTimesCache[id],
                shouldReturnCachedTravelTimes(forCachedValue: lastTravelTime, forLocation: location) {
            return lastTravelTime.deferred
        }

        // TODO: In a better world, with an IDE that could refactor, I'd rename DatabaseResult.
        let deferred = Deferred<DatabaseResult<TravelTimes>>()
        Place.travelTimesCache[id] = (deferred, location)

        TravelTimesProvider.travelTime(fromLocation: location.coordinate, toLocation: latLong,
                                       byTransitTypes: transitTypes) { travelTimes in
            let res: DatabaseResult<TravelTimes>
            if let travelTimes = travelTimes {
                res = DatabaseResult.succeed(value: travelTimes)
            } else {
                res = DatabaseResult.fail(withMessage: "Unable to retrieve travelTimes for place \(self.id)")
            }
            deferred.fill(with: res)
        }

        return deferred
    }

    private func shouldReturnCachedTravelTimes(forCachedValue cachedValue: CachedTravelTime,
                                               forLocation newLocation: CLLocation) -> Bool {
        // Return a cached success value or in-flight request.
        // If the initial request failed or we've moved too far, let's get a new value.
        let (lastDeferred, lastLocation) = cachedValue
        if lastLocation.distance(from: newLocation) < Place.travelTimeExpirationDistance {
            // TODO: It'd be great to combine these if statements but `if let` & `||` makes it not
            // worth my time.
            if !lastDeferred.isFilled { // request in-flight.
                return true
            }

            if let lastResult = lastDeferred.peek(),
                lastResult.isSuccess() { // cached success!
                return true
            }
        }

        return false
    }
}

// Help with debugging/printing place in lldb
extension Place: CustomDebugStringConvertible {
    var debugDescription: String {
        return "Place { name: \(self.name), id: \(self.id), photoURLs: \(self.photoURLs) }"
    }
}

enum DayOfWeek: String {
    case monday
    case tuesday, wednesday, thursday, friday
    case saturday, sunday

    private static let Cal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US")  // necessary for Calendar.weekdaySymbols to return long symbols.
        return cal
    }()

    static func forDate(_ date: Date) -> DayOfWeek {
        let weekdayInt = Cal.component(.weekday, from: date)
        let weekdayStr = Cal.weekdaySymbols[weekdayInt - 1]
        return DayOfWeek(rawValue: weekdayStr.lowercased())!
    }

    func nextWeekday() -> DayOfWeek {
        switch(self) {
        case .monday: return .tuesday
        case .tuesday: return .wednesday
        case .wednesday: return .thursday
        case .thursday: return .friday
        case .friday: return .saturday
        case .saturday: return .sunday
        case .sunday: return .monday
        }
    }

    func previousWeekday() -> DayOfWeek {
        switch(self) {
        case .monday: return .sunday
        case .tuesday: return .monday
        case .wednesday: return .tuesday
        case .thursday: return .wednesday
        case .friday: return .thursday
        case .saturday: return .friday
        case .sunday: return .saturday
        }
    }
}

typealias OpenPeriodDateComponents = (openTime: DateComponents, closeTime: DateComponents)
typealias OpenPeriodDates = (openTime: Date, closeTime: Date)

struct OpenHours {

    private static let calendar = Calendar(identifier: .gregorian)
    private static let dateComponentsSet: Set<Calendar.Component> = [Calendar.Component.day, Calendar.Component.month, Calendar.Component.year]
    private static let timeComponentsSet: Set<Calendar.Component> = [Calendar.Component.hour, Calendar.Component.minute]

    /* Notes:
     *   - An entry for DayOfWeek is missing if a location is not open that day.
     *   - For simplicity, we just use the last open interval for a day.
     *   - For simplicity, dates are normalized by a single day, allowing comparison but preventing
     *     the stored dates from being correct (e.g. if today is Mon Nov 7, the stored date for Tues
     *     isn't Nov 8).
     *
     * TODO:
     *   - Use all open intervals
     *   - Use accurate days of week in Date (maybe? It adds complexity for little gain).
     */
    let hours: [DayOfWeek : [OpenPeriodDateComponents]]

    private static let inputTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let outputTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    /*
     * Expected format: {"monday": [ ["7:00", "14:00"], ... ] }
     * Notes:
     *   - Times are 24hr, e.g. "14:00" for 2pm
     *   - Times are in the timezone of the place
     *   - "end" < "start" if a location is open overnight
     *   - An entry for DayOfWeek will be missing if a location is not open that day
     *
     * Returns nil if data format is unexpected in any way.
     * TODO: return nil ^ or just remove the days that are malformed?
     */
    static func fromFirebaseValue(_ hoursDict: [String : [[String]]]) -> OpenHours? {
        var out = [DayOfWeek : [OpenPeriodDateComponents]]()

        // Note: we don't check if a day is missing because if it is,
        // it's closed for the day and we're supposed to omit it anyway.
        for dayFromServer in hoursDict.keys {
            guard let day = DayOfWeek(rawValue: dayFromServer) else {
                log.error("unknown day of week from server: \(dayFromServer)")
                return nil
            }

            let hoursArr = hoursDict[dayFromServer]! // force unwrap: we're iterating over the keys.
            let hoursForDay: [OpenPeriodDateComponents] = hoursArr.flatMap { interval in
                guard interval.count == 2 else {
                    log.error("last opening interval unexpectedly has \(interval.count) entries")
                    return nil
                }

                guard let openTime = getTimeComponents(fromServerStr: interval[0]),
                        let closeTime = getTimeComponents(fromServerStr: interval[1]) else {
                    log.error("unable to convert date str, \(interval[0]) & \(interval[1]), to Date")
                    return nil
                }
                return(openTime: openTime, closeTime: closeTime)
            }
            out[day] = hoursForDay
        }

        return OpenHours(hours: out)
    }

    private static func getTimeComponents(fromServerStr serverStr: String) -> DateComponents? {
        guard let dateFromTime = inputTimeFormatter.date(from: serverStr) else {
            return nil
        }

        return OpenHours.calendar.dateComponents(timeComponentsSet, from: dateFromTime)
    }

    private func getOpeningTimes(forDate date: Date) -> [OpenPeriodDates]? {
        guard let openTimesForDay = hours[DayOfWeek.forDate(date)] else {
            log.debug("There are no open time for \(DayOfWeek.forDate(date)) in \(hours)")
            return nil
        }

        let allOpeningTimes: [OpenPeriodDates] = openTimesForDay.flatMap { times in
            guard let openingTime = getDate(forTime: times.openTime, onDate: date),
                var closingTime = getDate(forTime: times.closeTime, onDate: date) else {
                    log.debug("No opening times opening: \(getDate(forTime: times.openTime, onDate: date)), closing: \(getDate(forTime: times.closeTime, onDate: date))")
                    return nil
            }

            if closingTime < openingTime {
                closingTime += AppConstants.ONE_DAY
            }
            return (openTime: openingTime, closeTime: closingTime)
        }
        return allOpeningTimes.sorted { (periodA, periodB) in
            return  periodA.openTime < periodB.openTime
        }
    }

    private func getCurrentOpeningPeriod(fromOpeningPeriods openingPeriods: [OpenPeriodDates], forDate date: Date) -> OpenPeriodDates? {
        let currentPeriods = openingPeriods.filter { isTime(date, duringOpeningPeriod: $0) }
        return currentPeriods.first
    }

    private func getNextOpeningPeriod(fromOpeningPeriods openingPeriods: [OpenPeriodDates], forDate date: Date) -> OpenPeriodDates? {
        var nextOpenPeriod: OpenPeriodDates? = nil
        for openPeriod in openingPeriods {
            if openPeriod.openTime > date {
                guard let currentNextOpenPeriod = nextOpenPeriod else {
                    nextOpenPeriod = openPeriod
                    break
                }

                if openPeriod.openTime < currentNextOpenPeriod.openTime {
                    nextOpenPeriod = openPeriod
                }
            }
        }

        return nextOpenPeriod
    }

    private func getEarliestOpeningPeriod(fromOpeningPeriods periods: [OpenPeriodDates]) -> OpenPeriodDates? {
        return periods.first
    }


    func isOpen(atTime time: Date) -> Bool {
        guard let allOpeningTimes = getOpeningTimes(forDate: time) else {
            return false
        }

        if let _ = getCurrentOpeningPeriod(fromOpeningPeriods: allOpeningTimes, forDate: time) {
            return true
        }

        // check to see if the current time is before the earliest open time. If it is, it may be before yesterdays closing time too
        // otherwise we're just not open
        guard let earliestOpeningPeriod = getEarliestOpeningPeriod(fromOpeningPeriods: allOpeningTimes),
            time < earliestOpeningPeriod.openTime,
            let yesterdaysOpeningTimes = getOpeningTimes(forDate: time - AppConstants.ONE_DAY),
            let _ = getCurrentOpeningPeriod(fromOpeningPeriods: yesterdaysOpeningTimes, forDate: time) else {
            return false
        }

        return true
    }

    fileprivate func isTime(_ time: Date, duringOpeningPeriod openingPeriod: OpenPeriodDates) -> Bool {
        return time >= openingPeriod.openTime && time < openingPeriod.closeTime
    }

    private func getDate(forTime time: DateComponents, onDate date: Date) -> Date? {
        var timeDateComponents = dateComponents(fromDate: date)
        timeDateComponents.hour = time.hour
        timeDateComponents.minute = time.minute

        return OpenHours.calendar.date(from: timeDateComponents)
    }

    func getEarliestOpeningPeriod(forDate date: Date) -> OpenPeriodDates? {
        guard let allOpeningPeriods = getOpeningTimes(forDate: date) else {
            return nil
        }
        return getEarliestOpeningPeriod(fromOpeningPeriods: allOpeningPeriods)
    }

    func nextOpeningTime(forTime time: Date) -> String? {
        guard let allOpeningTimes = getOpeningTimes(forDate: time),
            let openingPeriod = getNextOpeningPeriod(fromOpeningPeriods: allOpeningTimes, forDate: time) else {
            // get tomorrows earliest opening time if possible
            if let openingPeriod = getEarliestOpeningPeriod(forDate: time + AppConstants.ONE_DAY) {
                return timeString(forDate: openingPeriod.openTime)
            }
            return nil
        }

        return timeString(forDate: openingPeriod.openTime)
    }

    func closingTime(forTime time: Date) -> String? {
        guard let allOpeningTimes = getOpeningTimes(forDate: time) else {
            return nil
        }
        if let openingTime = getCurrentOpeningPeriod(fromOpeningPeriods: allOpeningTimes, forDate: time) {
            return timeString(forDate: openingTime.closeTime)
        } else if let nextOpeningTime = getNextOpeningPeriod(fromOpeningPeriods: allOpeningTimes, forDate: time) {
            return timeString(forDate: nextOpeningTime.closeTime)
        }

        return nil
    }

    func timeString(forDate date: Date) -> String {
        return OpenHours.outputTimeFormatter.string(from: date)
    }

    private func dateComponents(fromDate date: Date) -> DateComponents {
        return OpenHours.calendar.dateComponents(OpenHours.dateComponentsSet, from: date)
    }
}

// This could be replaced with a thread-safe dictionary, but I didn't see one in the libs. :(
class TravelTimesCache {
    private var travelTimesCache = [String : CachedTravelTime]() // place-id : cached-value

    subscript(id: String) -> CachedTravelTime? {
        get {
            var out: CachedTravelTime?
            withLock { out = travelTimesCache[id] }
            return out
        }

        set(newValue) {
            withLock { travelTimesCache[id] = newValue }
        }
    }

    private func withLock(_ callback: () -> ()) {
        objc_sync_enter(self)
        callback()
        objc_sync_exit(self)
    }
}
