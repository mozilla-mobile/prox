/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Firebase
import FirebaseRemoteConfig
import GoogleMaps

struct SDKs {

    private static var isSetup = false

    // Not currently used but potentially useful.
    private(set) static var firebaseAuthorizedUser: FIRUser?

    private static let remoteConfigCacheExpiration: TimeInterval = {
        if AppConstants.isDebug {
            // Refresh the config if it hasn't been refreshed in 60 seconds.
            return 0.0
        }
        return RemoteConfigKeys.remoteConfigCacheExpiration.value
    }()

    static func setUp() {
        guard !isSetup else { fatalError("SDKs.setup already called") } // sanity check.

        setUpFirebase()
        setUpRemoteConfig()
        setUpGoogleMaps()
        BuddyBuildSDK.setup()

        isSetup = true
    }

    private static func setUpFirebase() {
        FIRApp.configure()

        if let user = FIRAuth.auth()?.currentUser {
            self.firebaseAuthorizedUser = user
        } else {
            FIRAuth.auth()?.signInAnonymously { (user, error) in
                guard let user = user else {
                    return log.error("sign in failed \(error)")
                }
                self.firebaseAuthorizedUser = user
                dump(user)
            }
        }
        FIRDatabase.database().persistenceEnabled = false
    }

    private static func setUpRemoteConfig() {
        let remoteConfig = FIRRemoteConfig.remoteConfig()
        let isDeveloperMode = AppConstants.isDebug || AppConstants.MOZ_LOCATION_FAKING
        remoteConfig.configSettings = FIRRemoteConfigSettings(developerModeEnabled: isDeveloperMode)!
        remoteConfig.setDefaultsFromPlistFileName("RemoteConfigDefaults")

        let defaults = UserDefaults.standard
        // Declare this here, because it's not needed anywhere else.
        let pendingUpdateKey = "pendingUpdate"

        remoteConfig.fetch(withExpirationDuration: remoteConfigCacheExpiration) { status, err in
            if status == FIRRemoteConfigFetchStatus.success {
                log.info("RemoteConfig fetched")
                // The config will be applied next time we load.
                // We don't do it now, because we want the update to be atomic,
                // at the beginning of a session with the app.
                defaults.set(true, forKey: pendingUpdateKey)
                defaults.synchronize()
            } else {
                // We'll revert back to the latest update, or the RemoteConfigDefaults plist.
                log.warn("RemoteConfig fetch failed")
            }
        }

        if defaults.bool(forKey: pendingUpdateKey) {
            remoteConfig.activateFetched()
            log.info("RemoteConfig updated")
            defaults.set(false, forKey: pendingUpdateKey)
            defaults.synchronize()
        }
    }

    private static func setUpGoogleMaps() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let googleServiceInfo = NSDictionary(contentsOfFile: path),
            let apiKey = googleServiceInfo["API_KEY"] as? String else {
                fatalError("Unable to initialize gmaps - did you include GoogleService-Info?")
        }

        GMSServices.provideAPIKey(apiKey)
    }
}
