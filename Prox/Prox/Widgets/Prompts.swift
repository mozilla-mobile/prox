/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

/// A collection of random prompt functions.
/// Maybe these would be better as a UIAlertController subclass. If so, make sure you continue to
/// log the analytics in a way people won't forget to call it (e.g. in `viewWillAppear`).
struct Prompts {

    static func presentSettingsOrQuitPrompt(for controller: UIViewController) {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
        let alertController = UIAlertController(title: "\(appName) requires location access",
            message: "This prototype is not supported without location access.", preferredStyle: .alert)

        let settingsAction = UIAlertAction(title: "Settings", style: .default, handler: {(action: UIAlertAction) -> Void in
            UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
        })
        let quitAction = UIAlertAction(title: "Quit", style: .destructive, handler: {(action: UIAlertAction) -> Void in
            UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
        })
        alertController.addAction(settingsAction)
        alertController.addAction(quitAction)

        Analytics.logEvent(event: AnalyticsEvent.LOCATION_REPROMPT, params: [:])
        controller.present(alertController, animated: true)
    }

    // HACK: this variable. Maybe it can be replaced if we subclass UIAlertController and we compare
    // the presented controller type.
    static var isNoLocationAlertPresented = false
    static func presentNoLocationAlert(for controller: UIViewController) {
        // The message says to close and restart Prox, however, at time of writing, this is not
        // always necessary: if we receive a location event while or after the dialog is displayed,
        // we'll show the places. It's used as a catch all because we don't know for sure what
        // causes the loading screen stall (#392).
        let alert = UIAlertController(title: "Where did you go?",
                                      message: "We can't find your current location. Please close and restart Prox.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK, got it.", style: .default) { _ in
            controller.dismiss(animated: true) { isNoLocationAlertPresented = false }
        })

        controller.present(alert, animated: true) { isNoLocationAlertPresented = true }
    }
}
