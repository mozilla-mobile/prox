/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import GoogleMaps

class MapViewController: UIViewController {

    lazy var rootContainer: UIStackView = {
        let container = UIStackView(arrangedSubviews: [self.titleHeader, self.mapView, self.placeFooter])
        container.axis = .vertical
        container.distribution = .fill
        container.alignment = .fill
        return container
    }()

    lazy var titleHeader: UILabel = {
        let titleView = UILabel()
        titleView.text = "Map view (tap me to dismiss)"
        titleView.textAlignment = .center
        titleView.font = Fonts.mapViewTitleText

        // TODO: temporary: need latest designs & focusing on hard stuff.
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.close))
        titleView.addGestureRecognizer(tapRecognizer)
        titleView.isUserInteractionEnabled = true
        return titleView
    }()

    lazy var mapView: GMSMapView = {
        let camera = GMSCameraPosition.camera(withLatitude: 41.88, longitude: -87.62, zoom: 14.0)
        let mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        mapView.isMyLocationEnabled = true
        return mapView
    }()

    lazy var placeFooter: UIView = {
        let placeholderView = UILabel()
        placeholderView.text = "Placeholder footer"
        placeholderView.textAlignment = .center
        return placeholderView
    }()

    init() { super.init(nibName: nil, bundle: nil) }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func viewDidLoad() {
        view.addSubview(rootContainer)
        let constraints = [
                rootContainer.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
                rootContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                rootContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                rootContainer.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor),
        ]

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    @objc private func close() {
        print("called")
        dismiss(animated: true)
    }
}
