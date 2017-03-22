/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

class PlaceDetailsCardViewController: UIViewController {

    private(set) var place: Place!

    lazy var cardView: PlaceDetailsCardView = {
        let view = PlaceDetailsCardView()
        return view
    }()

    let imageCarousel: PlaceDetailsImageCarousel

    init(place: Place, userLocation: CLLocation?) {
        imageCarousel = PlaceDetailsImageCarousel(place: place)
        super.init(nibName: nil, bundle: nil)
        set(place: place, withUserLocation: userLocation)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(place: Place, withUserLocation userLocation: CLLocation?) {
        self.place = place
        imageCarousel.place = place
        cardView.updateUI(forPlace: place, withUserLocation: userLocation)
    }
}

