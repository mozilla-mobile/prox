/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import FirebaseRemoteConfig

public enum AppBuildChannel {
    case Developer
    case Enterprise
    case EnterpriseKona
    case Release
}

public struct AppConstants {

    private static let hereBeDragonsKey = "here-be-dragons"

    public static let isRunningTest = NSClassFromString("XCTestCase") != nil
    
    #if MOZ_CHANNEL_DEBUG
    public static let backgroundFetchInterval: TimeInterval = 1 * 60
    public static let minimumIntervalAtLocationBeforeFetchingEvents: TimeInterval = 1 * 60
    #else
    public static var backgroundFetchInterval: TimeInterval {
        return RemoteConfigKeys.backgroundFetchIntervalMins.value * 60.0
    }
    public static var minimumIntervalAtLocationBeforeFetchingEvents: TimeInterval {
        return RemoteConfigKeys.notificationVisitIntervalMins.value * 60.0
    }
    #endif
    public static var userSeenHereBeDragons: Bool {
        get {
            return UserDefaults.standard.bool(forKey: AppConstants.hereBeDragonsKey)
        }

        set {
            UserDefaults.standard.set(newValue, forKey: AppConstants.hereBeDragonsKey)
        }
    }
    public static let timeOfLastLocationUpdateKey = "timeOfLastLocationUpdate"
    public static let ONE_DAY: TimeInterval = (60 * 60) * 24

    /// Build Channel.
    public static let BuildChannel: AppBuildChannel = {
        #if MOZ_CHANNEL_ENTERPRISE
            return AppBuildChannel.Enterprise
        #elseif MOZ_CHANNEL_ENTERPRISE_KONA
            return AppBuildChannel.EnterpriseKona
        #elseif MOZ_CHANNEL_RELEASE
            return AppBuildChannel.Release
        #else
            return AppBuildChannel.Developer
        #endif
    }()

    /// Flag indiciating if we are running in Debug mode or not.
    public static let isDebug: Bool = {
        #if MOZ_CHANNEL_DEBUG
            return true
        #else
            return false
        #endif
    }()

    /// Flag indiciating if we are running in Enterprise mode or not.
    public static let isEnterprise: Bool = {
        #if MOZ_CHANNEL_ENTERPRISE
            return true
        #else
            return false
        #endif
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
        #if MOZ_CHANNEL_ENTERPRISE_KONA
            return true
        #else
            return false
        #endif
    }()

    // URL of the server that updates our Firebase instance
    public static let serverURL: URL = {
        #if MOZ_CHANNEL_DEBUG
            return URL(string: "https://prox-dev.moo.mx")!
        #elseif MOZ_CHANNEL_ENTERPRISE
            return URL(string: "https://prox.moo.mx")!
        #elseif MOZ_CHANNEL_RELEASE
            return URL(string: "https://prox.moo.mx")!
        #else
            return URL(string: "https://prox-dev.moo.mx")!
        #endif
    }()

    public static let APIKEYS_PATH = "APIKeys"

    // The root child in the Realtime Firebase database.
    public static let firebaseRoot: String = {
        #if MOZ_CHANNEL_DEBUG
            return ""
        #elseif MOZ_CHANNEL_ENTERPRISE
            return "production/"
        #elseif MOZ_CHANNEL_RELEASE
            return "production/"
        #else
            return ""
        #endif
    }()
}
