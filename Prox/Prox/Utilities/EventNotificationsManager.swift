/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import CoreLocation
import UserNotifications

private let sentNotificationDictKey = "sent_notifications_dict"

let notificationEventIDKey = "eventPlaceID"

class EventNotificationsManager {

    fileprivate var sentNotifications: [String: [String]] {
        get {
            return UserDefaults.standard.dictionary(forKey: sentNotificationDictKey) as? [String : [String]] ?? [String : [String]]()
        }

        set {
            UserDefaults.standard.set(newValue, forKey: sentNotificationDictKey)
        }
    }

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

    fileprivate lazy var eventsProvider = EventsProvider()
    fileprivate lazy var placeProvider = PlacesProvider()

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

    init() {
        requestNotifications()
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
            application.registerUserNotificationSettings(UIUserNotificationSettings(types: [.alert, .badge], categories: nil))
        }
    }

    private func sendNotifications(forEvents events: [Event]) {
        for event in events {
            if isUnsent(event: event) {
                placeProvider.place(forKey: event.placeId) { place in
                    guard let place = place else { return }
                    DispatchQueue.main.async {
                        self.sendNotification(forEvent: event, atPlace: place)
                        self.markAsSent(event: event)
                    }
                }
            }
        }
    }

    private func sendNotification(forEvent event: Event, atPlace place: Place) {
        print("Sending notification for event \(event.description)")
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
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
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
                notification.fireDate = Date().addingTimeInterval(1)
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
        return !placeEvents.contains(event.description)
    }

    fileprivate func markAsSent(event: Event) {
        var sent = sentNotifications
        if sent.keys.contains(event.placeId) {
            sent[event.placeId]?.append(event.description)
        } else {
            sent[event.placeId] = [event.description]
        }
        sentNotifications = sent
    }
}
