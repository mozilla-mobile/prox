/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import CoreLocation
import UserNotifications

private let sentNotificationDictKey = "sent_notifications_dict"

let notificationEventPlaceIDKey = "eventPlaceID"
let notificationEventIDKey = "eventID"

fileprivate typealias EventID = String

class EventNotificationsManager {
    // caches events by their start time by place
    fileprivate lazy var sentNotifications: Set<EventID> = {
        var cache = Set<EventID>()
        guard let savedNotifications = UserDefaults.standard.dictionary(forKey: sentNotificationDictKey) as? [String: [EventID]] else {
            return cache
        }
        for (dateString, eventIDs) in savedNotifications {
            if let timestamp = TimeInterval(dateString) {
                let date = Date(timeIntervalSinceReferenceDate: timestamp)
                if Calendar.current.isDateInToday(date) {
                    let newIdsSet = Set<EventID>(eventIDs)
                    cache.formUnion(newIdsSet)
                }
            }
        }
        return cache
    }()

    fileprivate var shouldFetchEvents: Bool {
        guard let eventFetchStartTime = eventFetchStartTime else {
            return false
        }
        let now = Date()
        return eventFetchStartTime < now
    }

    fileprivate var eventFetchStartTime: Date? {
        guard let lastLocationFetchTime = timeOfLastLocationUpdate else {
            return nil
        }
        return lastLocationFetchTime.addingTimeInterval(AppConstants.minimumIntervalAtLocationBeforeFetchingEvents)
    }

    fileprivate var timeOfLastLocationUpdate: Date? {
        return UserDefaults.standard.value(forKey: AppConstants.timeOfLastLocationUpdateKey) as? Date
    }

    fileprivate lazy var maxTravelTimeToEvent: TimeInterval = {
        return RemoteConfigKeys.maxTravelTimesToEventMins.value * 60.0
    }()

    fileprivate var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid

    fileprivate lazy var eventsProvider = EventsProvider()
    fileprivate lazy var placeProvider = PlacesProvider()

    fileprivate weak var locationProvider: LocationProvider?

    @available(iOS 10.0, *)
    fileprivate lazy var eventNotificationsCategory: UNNotificationCategory = {
        let openAction = UNNotificationAction(identifier: "OPEN_ACTION",
                                                title: "Open",
                                                options: .foreground)
        return UNNotificationCategory(identifier: "EVENTS",
                                      actions: [openAction],
                                      intentIdentifiers: [],
                                      options: .customDismissAction)
    }()

    init(withLocationProvider locationProvider: LocationProvider) {
        requestNotifications()
        self.locationProvider = locationProvider
    }

    func persistNotificationCache() {
        UserDefaults.standard.set([String(Date().timeIntervalSinceReferenceDate): Array(sentNotifications)], forKey: sentNotificationDictKey)
        UserDefaults.standard.synchronize()
    }

    private func requestNotifications() {
        if #available(iOS 10.0, *) {
            let center = UNUserNotificationCenter.current()
            center.setNotificationCategories([eventNotificationsCategory])
            center.getNotificationSettings { (settings) in
                if settings.authorizationStatus != .authorized {
                    center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
                        // Enable or disable features based on authorization.
                    }
                }
            }

        } else {
            // Fallback on earlier versions
            let application = UIApplication.shared
            application.registerUserNotificationSettings(UIUserNotificationSettings(types: [.alert, .sound], categories: nil))
        }
    }

    private func sendNotifications(forEvents events: [Event]) {
        for (index, event) in events.enumerated() {
            if isUnsent(event: event) {
                guard let currentLocation = self.locationProvider?.getCurrentLocation()?.coordinate else { return }
                // check that travel times are within current location limits before deciding whether to send notification
                TravelTimesProvider.canTravelFrom(fromLocation: currentLocation, toLocation: event.coordinates, before: event.arrivalByTime()) { canTravel in
//                    guard canTravel else { return }
                    DispatchQueue.main.async {
                        var timeInterval = 1
                        if index > 0 {
                            timeInterval = index * 30
                        }
                        self.sendNotification(forEvent: event, inSeconds: TimeInterval(timeInterval))
                    }
                }
                self.markAsSent(event: event)
            }
        }

        let applicationState = UIApplication.shared.applicationState
        if applicationState == .background
            || applicationState == .inactive {
            backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.persistNotificationCache()
                self?.backgroundTask = UIBackgroundTaskInvalid
            }
        } else {
            self.persistNotificationCache()
        }
    }

    private func sendNotification(forEvent event: Event, inSeconds timeInterval: TimeInterval) {
        guard let notificationString = event.notificationString else { return }
        let alertTitle = "It’s Happening!"
        let alertBody = notificationString
        if #available(iOS 10.0, *) {
            let center = UNUserNotificationCenter.current()
            center.getNotificationSettings { (settings) in
                if settings.authorizationStatus == .authorized {
                    let content = UNMutableNotificationContent()
                    content.title = NSString.localizedUserNotificationString(forKey: alertTitle, arguments: nil)
                    content.body =  NSString.localizedUserNotificationString(forKey: alertBody, arguments: nil)
                    content.categoryIdentifier = "EVENTS"
                    content.userInfo = [notificationEventIDKey: event.id, notificationEventPlaceIDKey: event.placeId]
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
                    let request = UNNotificationRequest(identifier: event.id, content: content, trigger: trigger)
                    center.add(request) { error in
                        if let theError = error {
                            print(theError.localizedDescription)
                        } else {
                            print("Notification scheduled for \(event.description)")
                        }
                    }
                } else {
                    print("Settings not authorized for notifications \(settings.authorizationStatus)")
                }
            }
        } else {
            if let userNotificationSettingsAuthorization = UIApplication.shared.currentUserNotificationSettings?.types,
                userNotificationSettingsAuthorization.contains(.alert) || userNotificationSettingsAuthorization.contains(.badge) {
                let alertActionTitle = "Open"
                let notification = UILocalNotification()
                notification.alertTitle = alertTitle
                notification.alertBody = alertBody
                notification.alertAction = alertActionTitle
                notification.fireDate = Date().addingTimeInterval(timeInterval)
                notification.userInfo = [notificationEventIDKey: event.id, notificationEventPlaceIDKey: event.placeId]
                UIApplication.shared.scheduleLocalNotification(notification)
            }
        }
    }

    func sendEventNotifications(forLocation location: CLLocation, completion: (([Event]?, Error?) -> Void)? = nil) {
        guard shouldFetchEvents else {
            completion?(nil, nil)
            return
        }
        eventsProvider.getEventsForNotifications(forLocation: location, completion: { events, error in
            defer {
                completion?(events, error)
            }
            guard let foundEvents = events,
                !foundEvents.isEmpty else {
                return
            }
            self.sendNotifications(forEvents: foundEvents)
        })
    }

    fileprivate func isUnsent(event: Event) -> Bool {
//        return !sentNotifications.contains(event.id)
        return true
    }

    fileprivate func markAsSent(event: Event) {
        sentNotifications.insert(event.id)
    }

//    func fakeEvents() -> [Event] {
//        return [Event(id: "Beginners-Jive-Classes2016-11-28 19:30:00", placeId: "gaucho-tower-bridge-london", coordinates: CLLocationCoordinate2D(latitude: 51.5045923, longitude: -0.0992805), description: "Free Jazz Concert", url: nil, startTime: Date() + (30 * 60), endTime: nil)]
//    }
}
