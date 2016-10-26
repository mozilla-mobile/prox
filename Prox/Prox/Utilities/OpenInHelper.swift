/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


import Foundation

enum OpenInType {
    case browser
    case maps
    case yelp
    case tripAdvisor
}


struct OpenInHelper {
    static func open(url: URL, inType openInType: OpenInType) {
        switch openInType {
        case .browser:
            openURLInBrowser(url: url)
        default:
            print("Unable to open URL: \(url) in requested type \(openInType)")
        }
    }

    private static func openURLInBrowser(url: URL) {
        // check to see if Firefox is available
        // Open in Firefox or Safari
        let controller = OpenInFirefoxControllerSwift()
        if !(controller.isFirefoxInstalled() && controller.openInFirefox(url)) {
            UIApplication.shared.openURL(url)
        }
    }
}
