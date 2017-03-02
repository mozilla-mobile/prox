/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import FirebaseRemoteConfig

public enum AppBuildChannel {
    case CurrentLocation
    case MockLocation
}

public struct AppConstants {

    public static let isRunningTest = NSClassFromString("XCTestCase") != nil
    
    #if DEBUG
    public static let backgroundFetchInterval: TimeInterval = 1 * 60
    public static let minimumIntervalAtLocationBeforeFetchingEvents: TimeInterval = 1 * 60
    #else
    public static var backgroundFetchInterval: TimeInterval {
        return RemoteConfigKeys.backgroundFetchIntervalMins.value * 60.0
    }
    #endif

    public static let timeOfLastLocationUpdateKey = "timeOfLastLocationUpdate"
    public static let ONE_DAY: TimeInterval = (60 * 60) * 24

    /// Build Channel.
    public static let BuildChannel: AppBuildChannel = {
        #if MOZ_CHANNEL_CURRENT_LOCATION
            return AppBuildChannel.CurrentLocation
        #else
            #if !MOZ_CHANNEL_MOCK_LOCATION
                assertionFailure("Unknown channel")
            #endif
            return AppBuildChannel.MockLocation
        #endif
    }()

    /// Flag indiciating if we are running in Debug mode or not.
    public static let isDebug: Bool = {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }()

    /// Flag indiciating if we are running in Enterprise mode or not.
    public static let isEnterprise: Bool = {
        return BuildChannel == .CurrentLocation
    }()

    public static let isSimulator: Bool = {
        #if (arch(i386) || arch(x86_64))
            return true
        #else
            return false
        #endif
    }()

    // Enables/disables location faking for Hawaii
    public static let MOZ_LOCATION_FAKING: Bool = {
        return BuildChannel == .MockLocation
    }()

    public static let APIKEYS_PATH = "APIKeys"

    // The root child in the Realtime Firebase database.
    public static let firebaseRoot: String = {
        let root = FirebaseBranches.N02_CHICAGO
        //let root = FirebaseBranches.getBranch(forUser: "jane") // for debugging.
        assert(root.hasSuffix("/"))
        return root
    }()
}
