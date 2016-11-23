/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import CoreLocation
import UserNotifications

private let sentNotificationDictKey = "sent_notifications_dict"

let notificationEventIDKey = "eventPlaceID"

fileprivate typealias PlaceID = String
fileprivate typealias EventStartTimestamp = Double

class EventNotificationsManager {

    // caches events by their start time by place
    fileprivate lazy var sentNotifications: [PlaceID: [EventStartTimestamp]] = {
        var cache = [PlaceID: [EventStartTimestamp]]()
        guard let savedNotifications = UserDefaults.standard.dictionary(forKey: sentNotificationDictKey) as? [PlaceID: [EventStartTimestamp]] else {
            return cache
        }
        for (place, eventsStartTimes) in savedNotifications {
            let todaysEvents = eventsStartTimes.filter { Calendar.current.isDateInToday(Date(timeIntervalSinceReferenceDate: $0)) }
            if !todaysEvents.isEmpty {
                cache[place] = todaysEvents
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
        UserDefaults.standard.set(sentNotifications, forKey: sentNotificationDictKey)
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
                placeProvider.place(forKey: event.placeId) { place in
                    guard let place = place,
                    let currentLocation = self.locationProvider?.getCurrentLocation()?.coordinate else { return }
                    // check that travel times are within current location limits before deciding whether to send notification
                    TravelTimesProvider.travelTime(fromLocation: currentLocation, toLocation: place.latLong, byTransitType: [.automobile], withCompletion: { (times) in
                        guard let travelTimes = times,
                        let drivingTime = travelTimes.drivingTime else { return }
                        if drivingTime <= self.maxTravelTimeToEvent {
                            DispatchQueue.main.async {
                                self.sendNotification(forEvent: event, atPlace: place, inSeconds: TimeInterval(index + 1))
                                self.markAsSent(event: event)
                            }
                        }
                    })
                }
            }
        }
    }

    private func sendNotification(forEvent event: Event, atPlace place: Place, inSeconds timeInterval: TimeInterval) {
        let alertTitle = "New event!"
        let alertActionTitle = "Open"
        let alertBody = place.getNotificationString(forEvent: event)
        if #available(iOS 10.0, *) {
            let center = UNUserNotificationCenter.current()
            center.getNotificationSettings { (settings) in
                if settings.authorizationStatus == .authorized {
                    let content = UNMutableNotificationContent()
                    content.title = NSString.localizedUserNotificationString(forKey: alertTitle, arguments: nil)
                    content.body =  NSString.localizedUserNotificationString(forKey: alertBody, arguments: nil)
                    content.categoryIdentifier = "EVENTS"
                    content.userInfo = [notificationEventIDKey: event.placeId]
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
                    let request = UNNotificationRequest(identifier: "EventNotification", content: content, trigger: trigger)
                    center.add(request) { error in
                        if let theError = error {
                            print(theError.localizedDescription)
                        } else {
                            print("Notification scheduled")
                        }
                    }
                } else {
                    print("Settings not authorized for notifications \(settings.authorizationStatus)")
                }
            }
        } else {
            if let userNotificationSettingsAuthorization = UIApplication.shared.currentUserNotificationSettings?.types,
                userNotificationSettingsAuthorization.contains(.alert) || userNotificationSettingsAuthorization.contains(.badge) {
                let notification = UILocalNotification()
                notification.alertTitle = alertTitle
                notification.alertBody = alertBody
                notification.alertAction = alertActionTitle
                notification.fireDate = Date().addingTimeInterval(timeInterval)
                notification.userInfo = ["eventPlaceID": event.placeId]
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
        guard let placeEvents = sentNotifications[event.placeId] else {
            return true
        }
        return !placeEvents.contains(event.startTime.timeIntervalSinceReferenceDate)
    }

    fileprivate func markAsSent(event: Event) {
        if var events = sentNotifications[event.placeId] {
            events.append(event.startTime.timeIntervalSinceReferenceDate)
        } else {
            sentNotifications[event.placeId] = [event.startTime.timeIntervalSinceReferenceDate]
        }

        let applicationState = UIApplication.shared.applicationState
        if applicationState == .background
            || applicationState == .inactive {
            persistNotificationCache()
        }
    }
}
