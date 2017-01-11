/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

public extension TimeInterval {
     public func asHoursAndMinutesString() -> String {
        let (hours, mins) = asHoursAndMinutes()
        var timeString: String = ""
        if hours > 0 {
            timeString += "\(hours) hour"
            if hours > 1 {
                timeString += "s"
            }
            if mins > 0 {
                timeString += ", "
            }
        }
        if mins > 0 {
            timeString += "\(mins) minute"
            if mins != 1 {
                timeString += "s"
            }
        }
        return timeString
    }


    public func asHoursAndMinutes () -> (Int, Int) {
        let selfAsInt = Int(self)
        return (selfAsInt / 3600, (selfAsInt % 3600) / 60)
    }
}
