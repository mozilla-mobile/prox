/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import SnapKit

extension Constraint {

    /// Sets the constraint as active if the given value is active.
    /// Convenience method for `activate` and `deactivate`.
    func setActive(_ isActive: Bool) {
        if isActive {
            activate()
        } else {
            deactivate()
        }
    }
}

extension Array where Element: Constraint {

    func setAllActive(_ areAllActive: Bool) {
        for element in self {
            element.setActive(areAllActive)
        }
    }
}
