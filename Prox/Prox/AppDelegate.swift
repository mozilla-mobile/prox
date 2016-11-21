/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Firebase
import FirebaseRemoteConfig
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var placeCarouselViewController: PlaceCarouselViewController?

    private var authorizedUser: FIRUser?
    
    private lazy var remoteConfigCacheExpiration: TimeInterval = {
        if AppConstants.isDebug {
            // Refresh the config if it hasn't been refreshed in 60 seconds.
            return 60
        }
        let key = RemoteConfigKeys.remoteConfigCacheExpiration
        return FIRRemoteConfig.remoteConfig()[key].numberValue!.doubleValue
    }()

    private var eventsNotificationsManager = EventNotificationsManager()


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        setupFirebase()
        setupRemoteConfig()
        BuddyBuildSDK.setup()
        application.setMinimumBackgroundFetchInterval(AppConstants.backgroundFetchInterval)

        // create Window
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = UIColor.white;

        // create root view
        placeCarouselViewController = PlaceCarouselViewController()
        window?.rootViewController = placeCarouselViewController

        if #available(iOS 10.0, *) {
            self.setupUserNotificationCenter()
        }

        // display
        window?.makeKeyAndVisible()

        return true
    }

    private func setupFirebase() {
        FIRApp.configure()

        if let user = FIRAuth.auth()?.currentUser {
            authorizedUser = user
        } else {
            FIRAuth.auth()?.signInAnonymously { (user, error) in
                guard let user = user else {
                    return print("sign in failed \(error)")
                }
                self.authorizedUser = user
                dump(user)
            }
        }
        FIRDatabase.database().persistenceEnabled = true
    }

    private func setupRemoteConfig() {
        let remoteConfig = FIRRemoteConfig.remoteConfig()
        remoteConfig.configSettings = FIRRemoteConfigSettings(developerModeEnabled: AppConstants.isDebug)!
        remoteConfig.setDefaultsFromPlistFileName("RemoteConfigDefaults")

        let defaults = UserDefaults.standard
        // Declare this here, because it's not needed anywhere else.
        let pendingUpdateKey = "pendingUpdate"

        remoteConfig.fetch(withExpirationDuration: remoteConfigCacheExpiration) { status, err in
            if status == FIRRemoteConfigFetchStatus.success {
                print("RemoteConfig fetched")
                // The config will be applied next time we load.
                // We don't do it now, because we want the update to be atomic,
                // at the beginning of a session with the app.
                defaults.set(true, forKey: pendingUpdateKey)
                defaults.synchronize()
            } else {
                // We'll revert back to the latest update, or the RemoteConfigDefaults plist.
                print("RemoteConfig fetch failed")
            }
        }

        if defaults.bool(forKey: pendingUpdateKey) {
            remoteConfig.activateFetched()
            print("RemoteConfig updated")
            defaults.set(false, forKey: pendingUpdateKey)
            defaults.synchronize()
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // if there is a timer running, cancel it. We'll wait until background app refresh fires instead
        placeCarouselViewController?.locationMonitor.cancelTimeAtLocationTimer()
        eventsNotificationsManager.persistNotificationCache()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        placeCarouselViewController?.locationMonitor.startTimeAtLocationTimer()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        placeCarouselViewController?.locationMonitor.refreshLocation()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        placeCarouselViewController?.locationMonitor.cancelTimeAtLocationTimer()
        eventsNotificationsManager.persistNotificationCache()
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let currentLocation =  placeCarouselViewController?.locationMonitor.getCurrentLocation() else {
            return completionHandler(.noData)
        }
        eventsNotificationsManager.sendEventNotifications(forLocation: currentLocation) { (events, error) in
            if let _ = error {
                return completionHandler(.failed)
            }

            guard let events = events,
                !events.isEmpty else {
                return completionHandler(.noData)
            }

            completionHandler(.newData)
        }
    }

    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        if let eventKey = notification.userInfo?[notificationEventIDKey] as? String {
            placeCarouselViewController?.openPlaceForEvent(withKey: eventKey)
        }
    }
}


@available(iOS 10.0, *)

extension AppDelegate: UNUserNotificationCenterDelegate {

    func setupUserNotificationCenter() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // show a badge.
        completionHandler(UNNotificationPresentationOptions.alert)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.content.categoryIdentifier == "EVENTS" {
            if let eventKey = response.notification.request.content.userInfo[notificationEventIDKey] as? String {
                placeCarouselViewController?.openPlaceForEvent(withKey: eventKey)
            }
        }
    }
}

