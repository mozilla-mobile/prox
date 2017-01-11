/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

private let httpScheme = "http://"
private let httpSchemeCollection = [httpScheme, "https://"]

extension URL {

    /*
     * If the URL is a known HTTP String, make sure the prefix is present.
     * I don't know why this isn't built in. :|
     *
     * TODO: we don't handle this well if it already has a scheme.
     */
    init?(httpStringMaybeWithScheme urlStr: String) {
        for httpScheme in httpSchemeCollection {
            if urlStr.hasPrefix(httpScheme) {
                self.init(string: urlStr)
                return
            }
        }

        self.init(string: httpScheme + urlStr)
    }
}
