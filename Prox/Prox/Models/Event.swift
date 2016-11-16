/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Firebase

class Event {
    var id: String
    var placeId: String
    var description: String
    var startTime: Date
    var endTime: Date?
    var url: String

    init(id: String, placeId: String, description: String, url: String, startTime: Date, endTime: Date?) {
        self.id = id
        self.placeId = placeId
        self.description = description
        self.url = url
        self.startTime = startTime
        self.endTime = endTime
    }

    convenience init?(fromFirebaseSnapshot data: FIRDataSnapshot) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard data.exists(), data.hasChildren(),
            let value = data.value as? NSDictionary,
            let id = value["id"] as? String,
            let description = value["description"] as? String,
            let localStartTimeString = value["localStartTime"] as? String,
            let localStartTime = formatter.date(from: localStartTimeString),
            let url = value["url"] as? String else {
                print("lol dropping event: missing data, id, description, start time, or url \(data.value)")
                return nil
        }

        let localEndTime: Date?

        if let localEndTimeString = value["localEndTime"] as? String {
            localEndTime = formatter.date(from: localEndTimeString)
        } else { localEndTime = nil }


        self.init(id: id,
                  placeId: id,
                  description: description,
                  url:url,
                  startTime: localStartTime,
                  endTime: localEndTime)
    }
}
