/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

private enum DeferredResult {
    case success
    case failure
}

class PlacesResult {

    private let place: Place?
    private let deferredResult: DeferredResult

    let errorMessage: String?

    private init(place: Place) {
        self.place = place
        deferredResult = .success
        errorMessage = nil
    }

    private init(errorMessage: String?) {
        self.errorMessage = errorMessage
        deferredResult = .failure
        place = nil
    }

    static func succeed(place: Place) -> PlacesResult {
        return PlacesResult(place: place)
    }

    static func fail(withMessage message: String?) -> PlacesResult {
        return PlacesResult(errorMessage: message)
    }

    func isSuccess() -> Bool {
        return deferredResult == .success && place != nil
    }

    func isFailure() -> Bool {
        return deferredResult == .failure
    }

    func successResult() -> Place {
        return place!
    }

}
