/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import GoogleMaps

private let mapViewAnchorFromTop = mapViewMaskTopOffset - mapViewMaskMargin

/// If we use the search radius as the map mask diameter, the places are within the circle but the
/// markers overflow: this is padding to prevent the overflow.
private let mapViewPaddingForPins: CGFloat = 50

// Note: the constants are for inner circle. I haven't implemented see-through outer circle for time (yet?).
// The outer numbers are expanded by 30 in every direction (i.e. outside the view). 80% white
private let mapViewMaskMargin: CGFloat = 20
private let mapViewMaskTopOffset: CGFloat = 74

private let footerBottomOffset = Style.cardViewCornerRadius
private let footerCardMargin = 16

protocol MapViewControllerDelegate: class {
    func mapViewController(didSelect: Place)
}

class MapViewController: UIViewController {

    fileprivate let searchRadiusInMeters: Double = RemoteConfigKeys.searchRadiusInKm.value * 1000

    weak var delegate: MapViewControllerDelegate?
    weak var placesProvider: PlacesProvider?
    weak var locationProvider: LocationProvider?
    private let database = FirebasePlacesDatabase()

    fileprivate var displayedPlaces: [Place]!
    var selectedPlace: Place?

    /// The filters the displayed list of places is filtered with.
    fileprivate let enabledFilters: Set<PlaceFilter>

    fileprivate var isAfterFirstIdleAtCall = false

    private let mapViewMask = CAShapeLayer()
    private lazy var mapView: GMSMapView = {
        let camera = GMSCameraPosition.camera(withTarget: CLLocationCoordinate2D(latitude: 0, longitude: 0), zoom: 1.0) // initial position unused.
        let mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        mapView.isMyLocationEnabled = true
        mapView.delegate = self

        mapView.layer.mask = self.mapViewMask
        return mapView
    }()

    fileprivate let searchButton: MapViewSearchButton = {
        let button = MapViewSearchButton()
        button.addTarget(self, action: #selector(searchInVisibleArea), for: .touchUpInside)
        return button
    }()
    fileprivate var searchButtonTopConstraint: NSLayoutConstraint!

    fileprivate lazy var placeFooter: MapViewCardFooter = {
        let footer = MapViewCardFooter(bottomInset: footerBottomOffset)
        footer.alpha = 0 // hide until the first place is selected.
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(closeWithSelected))
        footer.addGestureRecognizer(tapRecognizer)
        return footer
    }()

    init(enabledFilters: Set<PlaceFilter>) {
        self.enabledFilters = enabledFilters
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func viewDidLoad() {
        view.backgroundColor = Colors.mapViewBackgroundColor

        let closeButton = UIButton()
        closeButton.setImage(#imageLiteral(resourceName: "button_dismiss"), for: .normal)
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)

        for subview in [self.mapView, searchButton, self.placeFooter, closeButton] as [UIView] {
            view.addSubview(subview)
        }

        closeButton.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(45)
            make.trailing.equalToSuperview().inset(27)
        }

        mapView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(mapViewAnchorFromTop)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(placeFooter.snp.top)
        }

        searchButtonTopConstraint = searchButton.centerYAnchor.constraint(equalTo: mapView.topAnchor)
        searchButtonTopConstraint.isActive = true
        searchButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
        }

        placeFooter.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(footerCardMargin)
            make.bottom.equalTo(bottomLayoutGuide.snp.top).offset(footerBottomOffset)
        }
    }

    override func viewDidLayoutSubviews() {
        updateMapViewMask()
    }

    private func updateMapViewMask() {
        let diameter = mapView.bounds.width - mapViewMaskMargin * 2 // roughly duplicated in resetMapToUserLocation.
        let rect = CGRect(x: mapViewMaskMargin, y: mapViewMaskMargin, width: diameter, height: diameter)
        let ellipseInRect = CGPath(ellipseIn: rect, transform: nil)
        mapViewMask.path = ellipseInRect

        searchButtonTopConstraint.constant = rect.maxY
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    @objc private func closeWithSelected() {
        if let selectedPlace = selectedPlace {
            delegate?.mapViewController(didSelect: selectedPlace)
        }
        close()
    }

    override func viewWillAppear(_ animated: Bool) {
        resetMapToUserLocation()

        // Keep the old places on the map if we don't have them (should never happen).
        guard let places = placesProvider?.getDisplayedPlacesCopy() else { return }
        displayedPlaces = places
        mapView.clear()
        addToMap(places: displayedPlaces)
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
        let mapDiameterPoints = view.frame.width - mapViewMaskMargin * 2 - mapViewPaddingForPins // roughly duplicated in updateMapViewMask
        let mapDiameterMeters = searchRadiusInMeters * 2 // convert radius to diameter.
        let desiredZoom = GMSCameraPosition.zoom(at: userCoordinate, forMeters: mapDiameterMeters, perPoints: mapDiameterPoints)
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

    @objc private func searchInVisibleArea() {
        searchButton.isEnabled = false
        mapView.clear()

        // todo: calculate radius for zoom level.
        let tmpRadius = searchRadiusInMeters / 1000
        database.getPlaces(forLocation: CLLocation(coordinate: mapView.camera.target), withRadius: tmpRadius).upon(.main) { results in
            let rawPlaces = results.flatMap { $0.successResult() }
            self.displayedPlaces = PlaceUtilities.filter(places: rawPlaces, withFilters: self.enabledFilters)
            // todo: handle 0 places.
            self.addToMap(places: self.displayedPlaces)

            self.searchButton.setIsHiddenWithAnimations(true)
        }
    }
}

extension MapViewController: GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        guard let placeID = marker.userData as? String,
                let place = displayedPlaces.first(where: { $0.id == placeID }) else {
            log.error("Unable to get place for marker data: \(marker.userData)")
            return true // if we return false, the map will do move & display an overlay, which we don't want.
        }

        selectedPlace = place
        placeFooter.update(for: place)
        if placeFooter.alpha != 1 {
            UIView.animate(withDuration: 0.4) {
                self.placeFooter.alpha = 1
            }
        }
        return true
    }

    func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
        // We move the map after init so we ignore that first call here.
        guard isAfterFirstIdleAtCall else {
            isAfterFirstIdleAtCall = true
            return
        }

        searchButton.setIsHiddenWithAnimations(false)
    }
}
