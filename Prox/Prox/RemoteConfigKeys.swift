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
 * 2. add a value to Firebase using the firebase/remote config console.
 * 3. use the value in a lazy property, using the following as an example.
 *
 * ```
 * return RemoteConfigKeys.searchRadius.value
 * ```
 *
 * You can specify defaults in the RemoteConfigDefaults.plist, but this is 
 * advised only for values that are accessed through constructed keys. This 
 * itself is not recommeded, but is only for expediency– for example if 
 * a long string needs to be specified and it would impractical to have it in this file.
 */
class RemoteConfigKeys {
    // Expiration time of the current remote config.
    // Any previously fetched and cached config would be considered expired because it would have been fetched
    // more than remoteConfigCacheExpiration seconds ago. Thus the next fetch would go to the server unless
    // throttling is in progress. The default expiration duration is 43200 (12 hours).
    public static let remoteConfigCacheExpiration = RemoteConfigDouble(key: "remote_config_cache_expiration", defaultValue: 0.0)

    // The search radius the app will use to query the Firebase database.
    // This is measured in kilometers. The default value is 4 km.
    public static let searchRadiusInKm = RemoteConfigDouble(key: "search_radius_in_km", defaultValue: 4.0)

    // The minimum number of minutes walking to the venue to be considered at the venue.at
    // This is measured in minutes. The default value is 1 minute.
    public static let youAreHereWalkingTimeMins = RemoteConfigInt(key: "you_are_here_walking_time_mins", defaultValue: 1)

    // The distance the user must travel before the travel times on a location are reloaded.
    public static let travelTimeExpirationDistance = RemoteConfigDouble(key: "travel_time_expiration_distance", defaultValue: 0.2) // default: ~2.5min walk.

    // This is the maximum time interval that we display walking directions before switching to driving directions.
    // This is measure in minutes. The default value is 30 minutes.
    public static let maxWalkingTimeInMins = RemoteConfigInt(key: "max_walking_time_in_mins", defaultValue: 30)

    // The event search radius the app will use to query the Firebase datbase
    // This is measures in kilometers. The default value is 20 km.
    public static let eventSearchRadiusInKm = RemoteConfigDouble(key: "event_search_radius_in_km", defaultValue: 20.0)

    // The amount of time before the event starts we should show a notification
    // This is measures in minutes
    public static let eventStartNotificationInterval = RemoteConfigDouble(key: "event_start_notification_interval_mins", defaultValue: 60.0)
    public static let eventStartPlaceInterval = RemoteConfigDouble(key: "event_start_place_interval_mins", defaultValue: 300.0)

    // the number of strings that are in the config for event notifications
    public static let numberOfEventNotificationStrings = RemoteConfigInt(key: "number_of_event_notification_strings", defaultValue: 2)

    // the root string that all keys for event notification strings will start with
    public static let eventNotificationStringRoot = "event_notification_string_"

    // the number of strings that are in the config for events displayed on the place details
    public static let numberOfPlaceDetailsEventStrings = RemoteConfigInt(key: "number_of_place_details_event_strings", defaultValue: 2)

    // the root string that all keys for place details event strings will start with
    public static let placeDetailsEventStringRoot = "place_details_event_string_"

    public static let backgroundFetchIntervalMins = RemoteConfigDouble(key: "background_fetch_interval_mins", defaultValue: 5.0)
    public static let notificationVisitIntervalMins = RemoteConfigDouble(key: "notification_visit_interval_mins", defaultValue: 15.0)
    public static let maxEventDurationForNotificationsMins = RemoteConfigDouble(key: "max_duration_of_event_for_notification_mins", defaultValue: 240.0)
    public static let maxTravelTimesToEventMins = RemoteConfigDouble(key: "max_travel_time_to_event_mins", defaultValue: 60.0)
    public static let minTimeFromEndOfEventForNotificationMins = RemoteConfigDouble(key: "min_time_from_end_of_event_for_notifications_mins", defaultValue: 120.0)
    public static let placeCategoriesToHideCSV = RemoteConfigStringArray(key: "place_categories_to_hide_csv", defaultValue: [])
    public static let significantLocationChangeDistanceMeters = RemoteConfigDouble(key: "significant_location_change_distance_meters", defaultValue: 100)

    // this is the distance a user has to move from their current location to trigger a "visit" to kick off notifications
    public static let radiusForCurrentLocationMonitoringMeters = RemoteConfigDouble(key: "radius_for_current_location_meters", defaultValue: 50.0)
    
    // the number of times the PlaceProvider should try to fetch places before timing out
    public static let numberOfPlaceFetchRetries = RemoteConfigInt(key: "number_of_place_fetch_retries", defaultValue: 60)
}

/*
 * The base class that gives type safe access to Remote configs and defaults.
 */
class RemoteConfigProperty<T> {
    let key: String
    let defaultValue: T

    var value: T {
        let remoteConfig = FIRRemoteConfig.remoteConfig()

        // rcv is never nil even if there is no key.
        // rcv.numberValue? never fails either (in light of an invalid number, it defaults to zero).
        // So, we get the string value, and try parsing it ourselves.
        let rcv = remoteConfig[key]
        if let string = rcv.stringValue {
            if let value = convert(string) {
                return value
            } else if string != "" {
                // i.e. the fetched value, or the plist default value is not valid.
                NSLog("RemoteConfigKeys: Existing value for \(key) is not a valid \(type(of: defaultValue))")
            }
        }

        // TODO: Consider saving the last successful value in UserDefaults.standard, then fall back to it here,
        // instead of falling back to what's in the plist. This could lead to all sorts of caching related bugs,
        // but would ameliorate the jarring application of a way out of date default.

        // Check to see if RemoteConfigDefaults.plist has a parseable default.
        // We only get here if the a) the fetched value is invalid, OR b) there is no fetched value AND no valid plist value
        // If a), then we default to the plist value. If b) we fall through.
        if let rcv = remoteConfig.defaultValue(forKey: key, namespace: FIRNamespaceGoogleMobilePlatform),
            let string = rcv.stringValue,
            let value = convert(string) {
            NSLog("RemoteConfigKeys: Default value for \(key) from embedded plist")
            return value
        }

        // If the plist doesn't have a default (most shouldn't, as per comments above)
        // we fall back to the typesafe default we were given in the constructor.
        NSLog("RemoteConfigKeys: Default value for \(key) from compiled code")
        return defaultValue
    }

    init(key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    fileprivate func convert(_ remoteConfigValue: String) -> T? {
        return nil
    }
}

class RemoteConfigDouble: RemoteConfigProperty<Double> {
    fileprivate override func convert(_ string: String) -> Double? {
        return Double(string)
    }
}

class RemoteConfigInt: RemoteConfigProperty<Int> {
    fileprivate override func convert(_ string: String) -> Int? {
        return Int(string)
    }
}

class RemoteConfigString: RemoteConfigProperty<String> {
    fileprivate override func convert(_ string: String) -> String? {
        return string != "" ? string : nil
    }
}

class RemoteConfigStringArray: RemoteConfigProperty<[String]> {
    fileprivate override func convert(_ string: String) -> [String]? {
        return string.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { $0 != "" }
    }
}
