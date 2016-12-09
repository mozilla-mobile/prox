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

    fileprivate var sentNotifications: Set<String> {
        get {
            return Set<String>(UserDefaults.standard.array(forKey: sentNotificationDictKey) as? [String] ?? [])
        }

        set {
            UserDefaults.standard.set(Array(newValue), forKey: sentNotificationDictKey)
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
        guard let currentLocation = self.locationProvider?.getCurrentLocation()?.coordinate else { return NSLog("Not sending notifications for events because we have no location") }
        for (index, event) in events.enumerated() {
            if isUnsent(event: event) {
                // check to see if there is an associated place
                // don't send the notification if there isn't
                let placesDB = PlacesProvider()
                placesDB.place(forKey: event.placeId) { place in
                    guard let _ = place else { return  NSLog("Not sending notification for \(event.id) as it has no place") }
                    // check that travel times are within current location limits before deciding whether to send notification
                    TravelTimesProvider.canTravelFrom(fromLocation: currentLocation, toLocation: event.coordinates, before: event.arrivalByTime()) { canTravel in
                        guard canTravel else { return NSLog("Not sending notification for \(event.id) as used cannot travel to it in time") }
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
            } else {
                 NSLog("Not sending notification for \(event.id) as is has already been sent")
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
        guard let notificationString = event.notificationString else { return NSLog("Not sending notification for \(event.id) because we were unable to format a notifcation string") }
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
                            NSLog(theError.localizedDescription)
                        } else {
                            NSLog("Notification scheduled for \(event.id)")
                        }
                    }
                } else {
                    NSLog("Settings not authorized for notifications \(settings.authorizationStatus)")
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

    func checkForEventsToNotify(forLocation location: CLLocation, isBackground: Bool = false, completion: (([Event]?, Error?) -> Void)? = nil) {
        guard shouldFetchEvents else {
            completion?(nil, nil)
            return
        }
        eventsProvider.getEventsForNotifications(forLocation: location, isBackground: isBackground, completion: { events, error in
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
        return !sentNotifications.contains(event.id)
    }

    fileprivate func markAsSent(event: Event) {
        var sent = sentNotifications
        sent.insert(event.id)
        sentNotifications = sent
    }
}
