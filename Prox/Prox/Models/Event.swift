/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Firebase
import FirebaseRemoteConfig

class Event {
    var id: String
    var placeId: String
    var description: String
    var startTime: Date
    var endTime: Date?
    var url: String?

    private static var numberOfEventNotificationStrings: Int = {
        let key = RemoteConfigKeys.numberOfEventNotificationStrings
        return FIRRemoteConfig.remoteConfig()[key].numberValue!.intValue
    }()

    private static var eventNotificationStrings: [String] = {
        var eventNotificationStrings = [String]()
        for i in 1...Event.numberOfEventNotificationStrings {
            let key = RemoteConfigKeys.eventNotificationStringRoot + "\(i)"
            if let string = FIRRemoteConfig.remoteConfig()[key].stringValue {
                eventNotificationStrings.append(string)
            }
        }
        return eventNotificationStrings
    }()

    var notificationString: String {
        let randomIndex = Int(arc4random_uniform(UInt32(Event.numberOfEventNotificationStrings)))
        return Event.eventNotificationStrings[randomIndex]
    }

    private static var numberOfPlaceDisplayStrings: Int = {
        let key = RemoteConfigKeys.numberOfPlaceDetailsEventStrings
        return FIRRemoteConfig.remoteConfig()[key].numberValue!.intValue
    }()

    private static var placeDisplayStrings: [String] = {
        var placeDisplayStrings = [String]()
        for i in 1...Event.numberOfPlaceDisplayStrings {
            let key = RemoteConfigKeys.placeDetailsEventStringRoot + "\(i)"
            if let string = FIRRemoteConfig.remoteConfig()[key].stringValue {
                placeDisplayStrings.append(string)
            }
        }
        return placeDisplayStrings
    }()

    var placeDisplayString: String {
        let randomIndex = Int(arc4random_uniform(UInt32(Event.numberOfPlaceDisplayStrings)))
        return Event.placeDisplayStrings[randomIndex]
    }

    init(id: String, placeId: String, description: String, url: String?, startTime: Date, endTime: Date?) {
        self.id = id
        self.placeId = placeId
        self.description = description
        self.url = url
        self.startTime = startTime
        self.endTime = endTime
    }

    convenience init?(fromFirebaseSnapshot data: FIRDataSnapshot) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard data.exists(), data.hasChildren(),
            let value = data.value as? NSDictionary,
            let id = value["id"] as? String,
            let description = value["description"] as? String,
            let localStartTimeString = value["localStartTime"] as? String,
            let localStartTime = formatter.date(from: localStartTimeString) else {
                print("lol dropping event: missing data, id, description, start time \(data.value)")
                return nil
        }

        let localEndTime: Date?

        if let localEndTimeString = value["localEndTime"] as? String {
            localEndTime = formatter.date(from: localEndTimeString)
        } else { localEndTime = nil }


        self.init(id: id,
                  placeId: id,
                  description: description,
                  url:value["url"] as? String,
                  startTime: localStartTime,
                  endTime: localEndTime)
    }
}
