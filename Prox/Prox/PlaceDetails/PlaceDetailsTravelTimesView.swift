/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

protocol PlaceDetailsTravelTimesViewDelegate: class {
    func placeDetailsTravelTimesView(_ view: PlaceDetailsTravelTimesView, updateTravelTimesUIForResult result: TravelTimesViewResult)
}

class PlaceDetailsTravelTimesView: PlaceDetailsIconInfoView, TravelTimesView {
    fileprivate var idForTravelTimesView: String?

    weak var delegate: PlaceDetailsTravelTimesViewDelegate?

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
        self.isLoading = isLoading
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

        if let delegate = self.delegate {
            delegate.placeDetailsTravelTimesView(self, updateTravelTimesUIForResult: result)
        }
    }
}
