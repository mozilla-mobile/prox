/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

/// A protocol for to adhere to for anything that we want to animate
protocol Animatable {
    associatedtype T
    func animatableProperties() -> T
}
