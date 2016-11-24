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
        return RemoteConfigKeys.numberOfEventNotificationStrings.value
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
        return RemoteConfigKeys.numberOfPlaceDetailsEventStrings.value
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
        guard data.exists(), data.hasChildren(),
            let value = data.value as? NSDictionary,
            let id = value["id"] as? String,
            let placeId = (value["placeId"] as? String) ?? value["id"] as? String,
            let description = value["description"] as? String,
            let localStartTimeString = value["localStartTime"] as? String else {
                print("lol dropping event: missing data, id, placeId, description, start time \(data.value)")
                return nil
        }

        let eventfulDateFormatter = DateFormatter()
        eventfulDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        let gCalDateFormatter = DateFormatter()
        gCalDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssz"

        var localStartTime: Date

        if let startTime = eventfulDateFormatter.date(from: localStartTimeString) {
            localStartTime = startTime
        } else if let startTime = gCalDateFormatter.date(from: localStartTimeString) {
            localStartTime = startTime
        } else {
            NSLog("Dropping event due to incorrectly formatted start timestamp %@", localStartTimeString)
            return nil
        }

        let localEndTime: Date?

        if let localEndTimeString = value["localEndTime"] as? String {
            if let endTime = eventfulDateFormatter.date(from: localEndTimeString) {
                localEndTime = endTime
            } else if let endTime = gCalDateFormatter.date(from: localEndTimeString) {
                localEndTime = endTime
            } else {localEndTime = nil }
        } else { localEndTime = nil }


        self.init(id: id,
                  placeId: placeId,
                  description: description,
                  url:value["url"] as? String,
                  startTime: localStartTime,
                  endTime: localEndTime)
    }
}
