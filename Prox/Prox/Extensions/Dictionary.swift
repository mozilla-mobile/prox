/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

extension Dictionary {

    /// `filter` but returning a Dictionary.
    func filterToDict(_ isIncluded: (Element) throws -> Bool) rethrows -> Dictionary {
        var outDict = self
        for (k, v) in outDict {
            if try !isIncluded((k, v)) {
                outDict.removeValue(forKey: k)
            }
        }
        return outDict
    }
}
