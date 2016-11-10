/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class Event {
    var id: String
    var placeId: String
    var name: String
    var startTime: Date
    var endTime: Date?
    var url: String

    init(id: String, placeId: String, name: String, url: String, startTime: Date, endTime: Date?) {
        self.id = id
        self.placeId = placeId
        self.name = name
        self.url = url
        self.startTime = startTime
        self.endTime = endTime
    }
}
