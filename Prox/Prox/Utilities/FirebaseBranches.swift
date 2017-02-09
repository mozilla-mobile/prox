/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

private let BRANCH_PREFIX = "branches"
private let USER_PREFIX = "users"

struct FirebaseBranches {

    static let N02_CHICAGO = getBranch(BRANCH_PREFIX, "02-chicago")

    // Old schemas - these are not expected to work with the current build.
    static let N01_HAWAII = getBranch("production")

    private static func getBranch(_ keys: String...) -> String {
        return keys.joined(separator: "/") + "/"
    }

    // For debugging.
    static func getBranch(forUser user: String) -> String {
        return getBranch(USER_PREFIX, user)
    }
}
