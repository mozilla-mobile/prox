/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class PlaceDetailsTravelTimesView: PlaceDetailsIconInfoView, TravelTimesView {
    fileprivate var idForTravelTimesView: String?

    convenience init() {
        self.init(enableForwardArrow: true)
    }

    func getIDForTravelTimesView() -> String? { return idForTravelTimesView }
    func setIDForTravelTimesView(_ id: String) { idForTravelTimesView = id }

    func prepareTravelTimesUIForReuse() {
        self.isLoading  = false
        forwardArrowView.isHidden = true
        primaryTextLabel.text = nil
        secondaryTextLabel.text = nil
        iconView.image = nil
    }

    func setTravelTimesUIIsLoading(_ isLoading: Bool) {
        // Problem: we get rate-limited for travel times requests. When rate limited, one of the
        // requests never returns, leaving the user with a loading spinner. The loading spinner
        // hides the "View on Map" text, which allows the user to click through for directions.
        //
        // HACK: We request travel times on startup in order to sort the list of places. In practice,
        // this means we never see a spinner when the content is loading but only in the problem
        // situtation above. So instead of adding complexity by managing the state of our active
        // directions requests, we just show "View on Map" instead.
        updateTravelTimesUIForResult(.noData, durationInMinutes: nil)
    }

    func updateTravelTimesUIForResult(_ result: TravelTimesViewResult, durationInMinutes: Int?) {
        iconView.tintColor = nil

        switch result {
        case .userHere:
            isPrimaryTextLabelHidden = true
            forwardArrowView.isHidden = true
            secondaryTextLabel.text = "You're here!"
            iconView.image = UIImage(named: "icon_here")

        case .walkingDist:
            isPrimaryTextLabelHidden = false
            forwardArrowView.isHidden = false
            primaryTextLabel.text = "\(durationInMinutes!) min"
            secondaryTextLabel.text = "Walking"
            iconView.image = UIImage(named: "icon_walkingdist")

        case .drivingDist:
            isPrimaryTextLabelHidden = false
            forwardArrowView.isHidden = false
            primaryTextLabel.text = "\(durationInMinutes!) min"
            secondaryTextLabel.text = "Driving"
            iconView.image = UIImage(named: "icon_drivingdist")

        case .noData:
            isPrimaryTextLabelHidden = true
            forwardArrowView.isHidden = false
            secondaryTextLabel.text = "View on Map"

            iconView.tintColor = Colors.detailsViewTravelTimeErrorPinTint
            iconView.image = UIImage(named: "icon_here")?.withRenderingMode(.alwaysTemplate)
        }
    }
}
