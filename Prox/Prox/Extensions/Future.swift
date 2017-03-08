/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Deferred

extension FutureProtocol {
    /// Returns a Future resolved with the result of this Future, or nil
    /// if this Future isn't resolved by the deadline.
    func timeout(deadline: DispatchTime) -> Future<Value?> {
        let deferred = Deferred<Value?>()
        let queue = DefaultExecutor.any()
        upon(queue) { result in deferred.fill(with: result) }
        queue.asyncAfter(deadline: deadline) { deferred.fill(with: self.peek()) }
        return Future(deferred)
    }
}
