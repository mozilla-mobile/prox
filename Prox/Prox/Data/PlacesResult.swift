/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

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

    func successResult() -> T {
        return value!
    }

}
