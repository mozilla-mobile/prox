/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

// This is a generic result class for describing the result of a database call
// It is done this way because:
// 1. Deferred cannot handle optionals
// 2. Deferred cannot handle Protocols, even if they are class protocols
// 3. Deferred can only handle actual classes. Therefore if a Venue fails to initalize
//    because it doesn't have all the info it needs to make itself
//    we cannot return a nil through the deferred, we have to return a result object
//    that can encapsulate the actual result of the call while still returning a 
//    guarenteed value for Deferred

private enum DeferredResult {
    case success
    case failure
}

class DatabaseResult<T> {

    private let value: T?
    private let deferredResult: DeferredResult

    let errorMessage: String?

    private init(value: T) {
        self.value = value
        deferredResult = .success
        errorMessage = nil
    }

    private init(errorMessage: String?) {
        self.errorMessage = errorMessage
        deferredResult = .failure
        value = nil
    }

    static func succeed(value: T) -> DatabaseResult {
        return DatabaseResult(value: value)
    }

    static func fail(withMessage message: String?) -> DatabaseResult {
        return DatabaseResult(errorMessage: message)
    }

    func isSuccess() -> Bool {
        return deferredResult == .success && value != nil
    }

    func isFailure() -> Bool {
        return deferredResult == .failure
    }

    func successResult() -> T? {
        return value
    }

}
