/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Firebase
import FirebaseRemoteConfig
import GoogleMaps

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var placeCarouselViewController: PlaceCarouselViewController?

    let locationMonitor = LocationMonitor()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        SDKs.setUp()

        // create Window
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = UIColor.white;

        // create root view
        placeCarouselViewController = PlaceCarouselViewController()
        locationMonitor.delegate = placeCarouselViewController

        if AppConstants.BuildChannel != .MockLocation {
            window?.rootViewController = placeCarouselViewController
        } else {
            let mockLocationSelectionController = MockLocationSelectionTableViewController()
            mockLocationSelectionController.nextViewController = placeCarouselViewController
            mockLocationSelectionController.locationMonitor = locationMonitor
            window?.rootViewController = mockLocationSelectionController
        }

        // display
        window?.makeKeyAndVisible()

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        AppState.enterBackground()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        AppState.enterForeground()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        Analytics.startAppSession()
        if (AppState.getState() == AppState.State.initial || AppState.getState() == AppState.State.permissions) {
            AppState.enterLoading()
        }

        // Since we don't gracefully handle location updates, we defer a location
        // refresh until a mock location has been selected.
        if AppConstants.BuildChannel != .MockLocation {
            locationMonitor.refreshLocation()
        }
    }
}
