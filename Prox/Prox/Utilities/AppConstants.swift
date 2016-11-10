/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

public enum AppBuildChannel {
    case Developer
    case Enterprise
    case Release
}

public struct AppConstants {

    public static let isRunningTest = NSClassFromString("XCTestCase") != nil
    public static let backgroundFetchInterval: TimeInterval = 1 * 60

    /// Build Channel.
    public static let BuildChannel: AppBuildChannel = {
        #if MOZ_CHANNEL_ENTERPRISE
            return AppBuildChannel.Enterprise
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
        #if MOZ_CHANNEL_DEBUG
            return false
        #elseif MOZ_CHANNEL_ENTERPRISE
            return true
        #elseif MOZ_CHANNEL_RELEASE
            return false
        #else
            return false
        #endif
    }()
}
