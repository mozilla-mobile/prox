/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Firebase
import CoreLocation
import Deferred

private let PROVIDERS_PATH = "providers/"
private let YELP_PATH = PROVIDERS_PATH + "yelp"
private let TRIP_ADVISOR_PATH = PROVIDERS_PATH + "tripAdvisor"
private let WIKIPEDIA_PATH = PROVIDERS_PATH + "wikipedia"

class Place: Hashable {

    fileprivate static var travelTimeExpirationDistance: CLLocationDistance = {
        return RemoteConfigKeys.travelTimeExpirationDistance.value
    }()

    var hashValue : Int {
        get {
            return id.hashValue
        }
    }

    private let transitTypes: [MKDirectionsTransportType] = [.automobile, .walking]

    let id: String

    let name: String
    let categories: (names: [String], ids: [String]) // Indices correlate.
    let latLong: CLLocationCoordinate2D

    let photoURLs: [String]

    // Optional values.
    let url: String?

    let address: String?

    let yelpProvider: ReviewProvider
    let tripAdvisorProvider: ReviewProvider?
    let wikipediaProvider: ReviewProvider?

    let hours: OpenHours? // if nil, there are no listed hours for this place

    fileprivate(set) var lastTravelTime: (deferred: Deferred<DatabaseResult<TravelTimes>>, forLocation: CLLocation)?

    let wikiDescription: String?
    let yelpDescription: String?
    let tripAdvisorDescription: String?

    var events = [Event]()

    init(id: String, name: String, descriptions: (wiki: String?, yelp: String?, ta: String?)? = nil,
         latLong: CLLocationCoordinate2D, categories: (names: [String], ids: [String]), url: String? = nil,
         address: String? = nil, yelpProvider: ReviewProvider,
         tripAdvisorProvider: ReviewProvider? = nil, wikipediaProvider: ReviewProvider? = nil, photoURLs: [String] = [], hours: OpenHours? = nil) {
        self.id = id
        self.name = name
        self.wikiDescription = descriptions?.wiki
        self.yelpDescription = descriptions?.yelp
        self.tripAdvisorDescription = descriptions?.ta
        self.latLong = latLong
        self.categories = categories
        self.url = url
        self.address = address
        self.yelpProvider = yelpProvider
        self.tripAdvisorProvider = tripAdvisorProvider
        self.wikipediaProvider = wikipediaProvider
        self.photoURLs = photoURLs
        self.hours = hours
    }

    convenience init?(fromFirebaseSnapshot data: FIRDataSnapshot) {
        guard data.exists(), data.hasChildren(),
                let value = data.value as? NSDictionary,
                let id = value["id"] as? String,
                let name = value["name"] as? String,
                let categoriesFromFirebase = value["categories"] as? [[String:String]],
                let categories = Place.getCategories(fromFirebaseValue: categoriesFromFirebase),
                let coords = value["coordinates"] as? [String:Double],
                let lat = coords["lat"], let lng = coords["lng"] else {
            print("lol dropping place: missing data, id, name, or coords")
            return nil
        }

        // TODO: #38: we need to decide whether to handle having a rating OR a review. If so, don't
        // forget to update the UI.
        guard let yelpProvider = ReviewProvider(fromFirebaseSnapshot: data.childSnapshot(forPath: YELP_PATH)),
                (yelpProvider.rating != nil && yelpProvider.totalReviewCount != nil) else {
            print("lol unable to init yelp provider for place: \(id)")
            return nil
        }

        // TODO:
        // * validate incoming data
        // * b/c ^, tests
        let descriptions = Place.getDescriptions(fromFirebaseValue: value)
        let photoURLs = (value["images"] as? [[String:String]])?.flatMap { $0["src"] } ?? []

        guard photoURLs.count > 0 else {
            // Photo json format may also be incorrect (we default to []) but only log this to keep it simple.
            print("lol dropped place \"\(id)\": no photos")
            return nil
        }

        let hours: OpenHours?
        if value["hours"] == nil {
            hours = nil // no listed hours
        } else {
            if let hoursDictFromServer = value["hours"] as? [String : [[String]]],
                    let hoursFromServer = OpenHours.fromFirebaseValue(hoursDictFromServer) {
                hours = hoursFromServer
            } else {
                return nil // malformed hours object: fail to make the Place
            }
        }

        self.init(id: id,
                  name: name,
                  descriptions: descriptions,
                  latLong: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                  categories: categories,
                  url: value["url"] as? String,
                  address: (value["address"] as? [String])?.joined(separator: " "),
                  yelpProvider: yelpProvider,
                  tripAdvisorProvider: ReviewProvider(fromFirebaseSnapshot: data.childSnapshot(forPath: TRIP_ADVISOR_PATH)),
                  wikipediaProvider: ReviewProvider(fromFirebaseSnapshot: data.childSnapshot(forPath: WIKIPEDIA_PATH)),
                  photoURLs: photoURLs,
                  hours: hours)
    }

    static func ==(lhs: Place, rhs: Place) -> Bool {
        return lhs.id == rhs.id
    }

    private static func getCategories(fromFirebaseValue value: [[String:String]]) -> (names: [String], ids: [String])? {
        var names = [String]()
        var ids = [String]()
        for category in value {
            guard let name = category["text"],
                    let id = category["id"] else {
                print("lol unable to retrieve category from firebase data for place")
                return nil
            }

            names.append(name)
            ids.append(id)
        }

        return (names, ids)
    }

    private static func getDescriptions(fromFirebaseValue value: NSDictionary) -> (wiki: String?, yelp: String?, ta: String?) {
        var wikiDescription: String?
        var yelpDescription: String?
        var taDescription: String?
        if let descArr = value["description"] as? [[String:String]] {
            for providerDict in descArr {
                if let provider = providerDict["provider"],
                        let text = providerDict["text"] {
                    switch provider {
                    case "yelp":
                        yelpDescription = Place.description(fromText: text)
                    case "wikipedia":
                        wikiDescription = Place.description(fromText: text)
                    case "tripadvisor":
                        taDescription = Place.description(fromText: text)
                    default:
                        break
                    }
                }
            }
        }

        return (wiki: wikiDescription, yelp: yelpDescription, ta: taDescription)
    }

    private static func description(fromText text: String?) -> String? {
        guard let descriptionText = text,
            !descriptionText.isEmpty else { return nil }
        return descriptionText
    }

    // assumes will always be called from UI thread.
    func travelTimes(fromLocation location: CLLocation) -> Deferred<DatabaseResult<TravelTimes>> {
        if let lastTravelTime = lastTravelTime,
                shouldReturnCachedTravelTimes(forLocation: location) {
            return lastTravelTime.deferred
        }

        // TODO: In a better world, with an IDE that could refactor, I'd rename DatabaseResult.
        let deferred = Deferred<DatabaseResult<TravelTimes>>()
        lastTravelTime = (deferred, location)

        TravelTimesProvider.travelTime(fromLocation: location.coordinate, toLocation: latLong,
                                       byTransitTypes: [.automobile, .walking]) { travelTimes in
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

    private func shouldReturnCachedTravelTimes(forLocation newLocation: CLLocation) -> Bool {
        // Return a cached success value or in-flight request.
        // If the initial request failed or we've moved too far, let's get a new value.
        if let (lastDeferred, lastLocation) = lastTravelTime,
            lastLocation.distance(from: newLocation) < Place.travelTimeExpirationDistance {

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

    private func replaceEventName( string: String, withName name: String) -> String {
        return string.replacingOccurrences(of: "{event_name}", with: name)
    }

    private func replacePlaceName(string: String) -> String {
        return string.replacingOccurrences(of: "{venue_name}", with: self.name)
    }

    private func replaceTimeToEvent(string: String, withStartTime startTime: Date) -> String {
        let now = Date()
        let timeToEvent = startTime.timeIntervalSince(now)
        let timeString = timeToEvent.asHoursAndMinutesString()
        return string.replacingOccurrences(of: "{time_to_event}", with: "\(timeString)")
    }

    private func replaceStartTime(string: String, withStartTime startTime: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return string.replacingOccurrences(of: "{start_time}", with: formatter.string(from: startTime))
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
    let hours: [DayOfWeek : [(openTime: DateComponents, closeTime: DateComponents)]]

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
        var out = [DayOfWeek : [(openTime: DateComponents, closeTime: DateComponents)]]()

        // Note: we don't check if a day is missing because if it is,
        // it's closed for the day and we're supposed to omit it anyway.
        for dayFromServer in hoursDict.keys {
            var hoursForDay = [(openTime: DateComponents, closeTime: DateComponents)]()
            guard let day = DayOfWeek(rawValue: dayFromServer) else {
                print("lol unknown day of week from server: \(dayFromServer)")
                return nil
            }

            let hoursArr = hoursDict[dayFromServer]! // force unwrap: we're iterating over the keys.
            guard let lastInterval = hoursArr.last else {
                print("lol hours array for \(dayFromServer) unexpectedly empty")
                return nil
            }

            guard lastInterval.count == 2 else {
                print("lol last opening interval unexpectedly has \(lastInterval.count) entries")
                return nil
            }

            guard let openTime = getTimeComponents(fromServerStr: lastInterval[0]),
                    let closeTime = getTimeComponents(fromServerStr: lastInterval[1]) else {
                print("lol unable to convert date str, \(lastInterval[0]) & \(lastInterval[1]), to Date")
                return nil
            }
            hoursForDay.append((openTime: openTime, closeTime: closeTime))
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

    private func getOpeningTime(forDate date: Date) -> Date? {
        guard let openDatesComponents = hours[DayOfWeek.forDate(date)],
            let openDateComponents = openDatesComponents.last?.openTime,
            let openingTime = getDate(forTime: openDateComponents, onDate: date) else {
            return nil
        }

        return openingTime
    }

    private func getClosingTime(forDate date: Date) -> Date? {
        guard let openingTime = getOpeningTime(forDate: date),
            let closeDatesComponents = hours[DayOfWeek.forDate(date)],
            let closeDateComponents = closeDatesComponents.last?.closeTime,
            var closingTime = getDate(forTime: closeDateComponents, onDate: date) else {
                return nil
        }

        // Add 24 hours to the closing time if the closing time if before the opening time
        if closingTime <= openingTime {
            closingTime += AppConstants.ONE_DAY
        }
        return  closingTime
    }

    /** 
    * The logic for isOpen is as follows:
    * Apply opening time and closing time to the current date (provided as an argument)
    * If the closing time is < the opening time, then the venue is open over midnight and we have to add 24hrs to the closing time
    * If the current time is before the opening time, but the venue closed before midnight the previous day, the venue is closed
    * If the current time if before the opening time, but the venue closed after midnight the previous day, the venue is closed if the 
      current time is after yesterdays closing time, otherwise the venue is open
    * If the current time is before the closing time and after the opening time, the venue is open
    * If the current time is after the closing time and before the opening time, the venue is closed
    **/
    func isOpen(atTime time: Date) -> Bool {
        guard let openingTime = getOpeningTime(forDate: time),
            let closingTime = getClosingTime(forDate: time) else {
            return false
        }

        // Is the current time before the opening time and the venue closed after midnight the previous day?
        if time < openingTime,
            let yesterdaysClosingTime = getClosingTime(forDate: time.addingTimeInterval(-AppConstants.ONE_DAY)),
            yesterdaysClosingTime < openingTime {

                // the venue is open if our current time is before yesterdays close time
                return time < yesterdaysClosingTime
        }

        // the venue is open if our current time is after or at the opening time and before the closing time
        return time >= openingTime && time < closingTime
    }

    private func getDate(forTime time: DateComponents, onDate date: Date) -> Date? {
        var timeDateComponents = dateComponents(fromDate: date)
        timeDateComponents.hour = time.hour
        timeDateComponents.minute = time.minute

        return OpenHours.calendar.date(from: timeDateComponents)
    }

    func nextOpeningTime(forTime time: Date) -> String? {
        guard let openingTime = getOpeningTime(forDate: time) else {
                return nil
        }

        if time < openingTime {
            return timeString(forDate: openingTime)
        }

        if let tomorrowOpeningTime = getOpeningTime(forDate: time.addingTimeInterval(AppConstants.ONE_DAY)) {
            return timeString(forDate: tomorrowOpeningTime)
        }
        return nil
    }

    func closingTime(forTime time: Date) -> String? {
        guard let closingTime = getClosingTime(forDate: time) else {
                return nil
        }
        return timeString(forDate: closingTime)
    }

    func timeString(forDate date: Date) -> String {
        return OpenHours.outputTimeFormatter.string(from: date)
    }

    private func dateComponents(fromDate date: Date) -> DateComponents {
        return OpenHours.calendar.dateComponents(OpenHours.dateComponentsSet, from: date)
    }
}
