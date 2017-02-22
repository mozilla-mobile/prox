/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import GoogleMaps

private let footerBottomOffset = Style.cardViewCornerRadius
private let footerCardMargin = 10

class MapViewController: UIViewController {

    fileprivate let searchRadiusInMeters: Double = RemoteConfigKeys.searchRadiusInKm.value * 1000

    weak var placesProvider: PlacesProvider?
    weak var locationProvider: LocationProvider?

    private lazy var rootContainer: UIStackView = {
        let container = UIStackView(arrangedSubviews: [
            self.titleHeader,
            self.mapView,
            self.placeFooter
        ])
        container.axis = .vertical
        container.distribution = .fill
        container.alignment = .fill
        return container
    }()

    private lazy var titleHeader: UILabel = {
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

    private lazy var mapView: GMSMapView = {
        let camera = GMSCameraPosition.camera(withTarget: CLLocationCoordinate2D(latitude: 0, longitude: 0), zoom: 1.0) // initial position unused.
        let mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        mapView.isMyLocationEnabled = true
        return mapView
    }()

    private lazy var placeFooter: MapViewCardFooter = MapViewCardFooter(bottomInset: footerBottomOffset)

    init() { super.init(nibName: nil, bundle: nil) }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func viewDidLoad() {
        view.addSubview(rootContainer)
        rootContainer.snp.makeConstraints { make in
            make.top.equalTo(topLayoutGuide.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomLayoutGuide.snp.top)
        }

        placeFooter.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(footerCardMargin)
            make.bottom.equalTo(bottomLayoutGuide.snp.top).offset(footerBottomOffset)
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        resetMapToUserLocation()

        // Keep the old places on the map if we don't have them (should never happen).
        guard let places = placesProvider?.getDisplayedPlacesCopy() else { return }
        mapView.clear()
        addToMap(places: places)
    }

    private func resetMapToUserLocation() {
        guard let userCoordinate = locationProvider?.getCurrentLocation()?.coordinate else {
            // TODO: do something clever
            log.warn("Map view controller does not have current location")
            return
        }

        // We want to display the full search circle in the map so we ensure the full search diameter
        // can be seen in the the smallest dimension of the map view. One hack is we use view.frame,
        // rather than mapView.frame, because mapView may not have been laid out in `viewWillAppear`.
        // We could use another callback but they add complexity (e.g. didLayoutSubviews is called
        // multiple times). Also, view.frame.width is the only dimension that is the same as the mapView
        // so we assume it's the smallest dimension.
        //
        // One alternative is to use GMSMapView.cameraForBounds with something like: http://stackoverflow.com/a/6635926/2219998
        // I could do that, but this already works. :)
        let mapWidthPoints = view.frame.width
        let mapWidthMeters = searchRadiusInMeters * 2 // convert radius to diameter.
        let desiredZoom = GMSCameraPosition.zoom(at: userCoordinate, forMeters: mapWidthMeters, perPoints: mapWidthPoints)
        let cameraUpdate = GMSCameraUpdate.setTarget(userCoordinate, zoom: desiredZoom)
        mapView.moveCamera(cameraUpdate)
    }

    private func addToMap(places: [Place]) {
        // Consider limiting the place count if we hit performance issues.
        for place in places {
            let marker = GMSMarker(for: place)
            marker.map = mapView
        }
    }
}
