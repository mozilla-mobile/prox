/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

enum APIKey: String {

    case FLURRY, FLURRY_CHICAGO
    case EVENTBRITE_ANONYMOUS_OAUTH

    func get() -> String {
        guard let val = APIKey.plistDict[rawValue] else {
            fatalError("API key, \(rawValue), not present in APIKey plist file.")
        }
        return val
    }

    private static let plistDict: [String: String] = {
        guard let apiPlistPath = Bundle.main.path(forResource: AppConstants.APIKEYS_PATH, ofType: "plist") else {
            fatalError("Unable to load API keys plist. Did you include the API keys plist file?")
        }

        return NSDictionary(contentsOfFile: apiPlistPath) as! [String: String]
    }()
}
