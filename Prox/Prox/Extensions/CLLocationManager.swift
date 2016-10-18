/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import MapKit

extension CLLocationManager {

    class func hasLocationPermissionAndEnabled() -> Bool {
        return CLLocationManager.locationServicesEnabled() &&
            CLLocationManager.authorizationStatus() == .authorizedAlways
    }

    /*
     * Requests permission to use device location services.
     *
     * May use the passed UIViewController to display a dialog:
     * be sure to call this method at the appropriate time.
     */
    func maybeRequestLocationPermission(viewController: UIViewController) {
        guard CLLocationManager.locationServicesEnabled() else {
            // This dialog, nor the app settings page it opens, are not a good descriptor that location
            // services are disabled but I don't think putting in the work right now is worth it.
            presentSettingsOrQuitPrompt(viewController)
            return
        }

        switch (CLLocationManager.authorizationStatus()) {
        case .notDetermined:
            self.requestAlwaysAuthorization()

        case .restricted, .denied:
            presentSettingsOrQuitPrompt(viewController)

        case .authorizedAlways:
            break

        case .authorizedWhenInUse:
            assertionFailure("Location permission, authorized when in use, not expected.")
        }
    }

    private func presentSettingsOrQuitPrompt(_ viewController: UIViewController) {
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

        viewController.present(alertController, animated: true)
    }
}
