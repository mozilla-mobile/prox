/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import FirebaseRemoteConfig

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

    // The event search radius the app will use to query the Firebase datbase
    // This is measures in kilometers. The default value is 20 km.
    public static let eventSearchRadiusInKm = "event_search_radius_in_km"

    // The amount of time before the event starts we should show a notification
    // This is measures in minutes
    public static let eventStartNotificationInterval = "event_start_notification_interval_mins"
    public static let eventStartPlaceInterval = "event_start_place_interval_mins"

    // the number of strings that are in the config for event notifications
    public static let numberOfEventNotificationStrings = "number_of_event_notification_strings"
    // the root string that all keys for event notification strings will start with
    public static let eventNotificationStringRoot = "event_notification_string_"

    // the number of strings that are in the config for events displayed on the place details
    public static let numberOfPlaceDetailsEventStrings = "number_of_place_details_event_strings"

    // the root string that all keys for place details event strings will start with
    public static let placeDetailsEventStringRoot = "place_details_event_string_"

    public static let backgroundFetchIntervalMins = "background_fetch_interval_mins"
    public static let notificationVisitIntervalMins = "notification_visit_interval_mins"
    public static let maxEventDurationForNotificationsMins = "max_duration_of_event_for_notification_mins"
    public static let maxTravelTimesToEventMins = "max_travel_time_to_event_mins"
    
}

extension RemoteConfigKeys {
    open static func getDouble(forKey key: String) -> Double {
        return FIRRemoteConfig.remoteConfig()[key].numberValue!.doubleValue
    }

    open static func getString(forKey key: String) -> String {
        return FIRRemoteConfig.remoteConfig()[key].stringValue!
    }

    open static func getInt(forKey key: String) -> Int {
        return FIRRemoteConfig.remoteConfig()[key].numberValue!.intValue
    }

    open static func getTimeInterval(forKey key: String) -> TimeInterval {
        return RemoteConfigKeys.getDouble(forKey: key) * 60
    }
}
