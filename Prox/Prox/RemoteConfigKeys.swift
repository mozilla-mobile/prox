/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

/**
 * This file holds the keys to values held in Firebase's RemoteConfig file.
 * RemoteConfig allows us to change values remotely without going through 
 * an AppStore release cycle.
 * 
 * Values can be changed in the Firebase RemoteConfig console.
 * 
 * The pattern to add a new value:
 *
 * 1. add a key to `RemoteConfigKeys`. You should document the value here.
 * 2. add a default value to `RemoteConfigValues.plist`.
 * 3. add a value to Firebase using the firebase/remote config console.
 * 4. use the value in a lazy property, using the following as an example.
 *
 * return FIRRemoteConfig.remoteConfig()[key].numberValue!.doubleValue
 *
 */
class RemoteConfigKeys {
    // Expiration time of the current remote config.
    // Any previously fetched and cached config would be considered expired because it would have been fetched
    // more than remoteConfigCacheExpiration seconds ago. Thus the next fetch would go to the server unless
    // throttling is in progress. The default expiration duration is 43200 (12 hours).
    public static let remoteConfigCacheExpiration = "remote_config_cache_expiration"

    // The search radius the app will use to query the Firebase database.
    // This is measured in kilometers. The default value is 4 km.
    public static let searchRadiusInKm = "search_radius_in_km"

    // The minimum number of minutes walking to the venue to be considered at the venue.at
    // This is measured in minutes. The default value is 1 minute.
    public static let youAreHereWalkingTimeMins = "you_are_here_walking_time_mins"

    // This is the maximum time interval that we display walking directions before switching to driving directions.
    // This is measure in minutes. The default value is 30 minutes.
    public static let maxWalkingTimeInMins = "max_walking_time_in_mins"
}
