/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var placeCarouselViewController: PlaceCarouselViewController?

    private var authorizedUser: FIRUser?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        setupFirebase()
        BuddyBuildSDK.setup()
        application.setMinimumBackgroundFetchInterval(AppConstants.backgroundFetchInterval)

        // create Window
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = UIColor.white;

        // create root view
        placeCarouselViewController = PlaceCarouselViewController()
        window?.rootViewController = placeCarouselViewController

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
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // if there is a timer running, cancel it. We'll wait until background app refresh fires instead
        placeCarouselViewController?.cancelTimeAtLocationTimer()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        placeCarouselViewController?.refreshLocation()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        placeCarouselViewController?.fetchEvents(completion: completionHandler)

    }


}

