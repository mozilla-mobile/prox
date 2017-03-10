/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import GoogleMaps
import SnapKit

private let fadeDuration: TimeInterval = 0.1

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
    func mapViewController(_ mapViewController: MapViewController, didDismissWithSelectedPlace place: Place?)
}

enum MapState {
    case initializing
    case normal
    case movingByCode
}

class MapViewController: UIViewController {

    fileprivate let searchRadiusInMeters: Double = RemoteConfigKeys.searchRadiusInKm.value * 1000

    weak var delegate: MapViewControllerDelegate?
    weak var placesProvider: PlacesProvider?
    weak var locationProvider: LocationProvider?
    private let database = FirebasePlacesDatabase()

    fileprivate var displayedPlaces: [Place]!
    fileprivate var selectedPlace: Place?
    fileprivate var selectedMarker: GMSMarker?

    /// The filters the displayed list of places is filtered with.
    fileprivate let enabledFilters: Set<PlaceFilter>

    fileprivate var mapState = MapState.initializing

    fileprivate var showMapConstraints = [Constraint]()
    fileprivate var hideMapConstraints = [Constraint]()
    fileprivate var showFooterConstraints = [Constraint]()
    fileprivate var hideFooterConstraints = [Constraint]()

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
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(closeWithSelected))
        footer.addGestureRecognizer(tapRecognizer)
        return footer
    }()

    init(selectedPlace: Place, enabledFilters: Set<PlaceFilter>) {
        self.enabledFilters = enabledFilters
        super.init(nibName: nil, bundle: nil)

        self.modalPresentationStyle = .overCurrentContext
        self.transitioningDelegate = self
        self.selectedPlace = selectedPlace
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func viewDidLoad() {
        let closeButton = UIButton()
        closeButton.setImage(#imageLiteral(resourceName: "button_dismiss"), for: .normal)
        closeButton.addTarget(self, action: #selector(closeWithButton), for: .touchUpInside)

        let container = UIView()
        container.backgroundColor = Colors.mapViewBackgroundColor

        for subview in [container, mapView, searchButton, placeFooter, closeButton] as [UIView] {
            view.addSubview(subview)
        }

        container.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()

            showMapConstraints = [ make.top.bottom.equalToSuperview().constraint ]
            hideMapConstraints = [ make.bottom.equalTo(view.snp.top).constraint ]
        }

        closeButton.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(45)
            make.trailing.equalToSuperview().inset(27)
        }

        mapView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalTo(container)
            make.top.equalTo(container).inset(mapViewAnchorFromTop)
        }

        searchButtonTopConstraint = searchButton.centerYAnchor.constraint(equalTo: mapView.topAnchor)
        searchButtonTopConstraint.isActive = true
        searchButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
        }

        placeFooter.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(footerCardMargin)

            showFooterConstraints = [ make.bottom.equalToSuperview().offset(footerBottomOffset).constraint ]
            hideFooterConstraints = [ make.top.equalTo(view.snp.bottom).constraint ]
        }

        showMapConstraints.forEach { $0.deactivate() }
        showFooterConstraints.forEach { $0.deactivate() }
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

    @objc private func closeWithButton() {
        dismiss(withSelectedPlace: nil)
    }

    @objc private func closeWithSelected() {
        dismiss(withSelectedPlace: selectedPlace)
    }

    private func dismiss(withSelectedPlace place: Place?) {
        self.dismiss(animated: true)
        delegate?.mapViewController(self, didDismissWithSelectedPlace: place)

        view.layoutIfNeeded()
        slideCard(toBeShown: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        resetMapToUserLocation(shouldAnimate: false)

        // Keep the old places on the map if we don't have them (should never happen).
        guard let places = placesProvider?.getDisplayedPlacesCopy() else { return }
        displayedPlaces = places
        mapView.clear()
        addToMap(places: displayedPlaces)
    }

    private func resetMapToUserLocation(shouldAnimate: Bool) {
        guard let userCoordinate = locationProvider?.getCurrentLocation()?.coordinate else {
            // TODO: do something clever
            log.warn("Map view controller does not have current location")
            return
        }

        searchButton.setIsHiddenWithAnimations(true)

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

        if mapState == .normal { mapState = .movingByCode } // todo: checking against mapState everywhere is fragile.
        if (!shouldAnimate) {
            mapView.moveCamera(cameraUpdate)
        } else {
            mapView.animate(with: cameraUpdate)
        }
    }

    private func addToMap(places: [Place]) {
        // Consider limiting the place count if we hit performance issues.
        for place in places {
            let marker = GMSMarker(for: place)
            marker.map = mapView

            if place == selectedPlace {
                updateSelected(marker: marker, andPlace: place)
            }
        }
    }

    @objc private func searchInVisibleArea() {
        searchButton.isEnabled = false
        mapView.clear()
        slideCard(toBeShown: false)

        // todo: calculate radius for zoom level.
        let tmpRadius = searchRadiusInMeters / 1000
        database.getPlaces(forLocation: CLLocation(coordinate: mapView.camera.target), withRadius: tmpRadius).upon(.main) { results in
            let rawPlaces = results.flatMap { $0.successResult() }
            self.displayedPlaces = PlaceUtilities.filter(places: rawPlaces, withFilters: self.enabledFilters)

            guard self.displayedPlaces.count != 0 else {
                self.present(self.getNoResultsController(), animated: true) {
                    self.searchButton.setIsHiddenWithAnimations(true)
                }
                return
            }

            self.addToMap(places: self.displayedPlaces)
            self.searchButton.setIsHiddenWithAnimations(true)
        }
    }

    private func getNoResultsController() -> UIAlertController {
        let controller = UIAlertController(title: Strings.mapView.noResultsYet, message: nil, preferredStyle: .alert)
        let dismissAction = UIAlertAction(title: Strings.mapView.dismissNoResults, style: .default) { action in
            controller.dismiss(animated: true)
        }
        controller.addAction(dismissAction)
        return controller
    }

    fileprivate func updateSelected(marker newMarker: GMSMarker, andPlace newPlace: Place) {
        selectedMarker?.updateMarker(forSelected: false)
        selectedMarker = newMarker
        selectedMarker?.updateMarker(forSelected: true)
        selectedPlace = newPlace

        slideCard(toBeShown: false) { _ in
            self.placeFooter.update(for: newPlace)
            self.slideCard(toBeShown: true)
        }
    }

    private func slideCard(toBeShown shown: Bool, completion: ((Bool) -> ())? = nil) {
        view.layoutIfNeeded()
        UIView.animate(withDuration: fadeDuration, animations: {
            if shown {
                self.hideFooterConstraints.forEach { $0.deactivate() }
                self.showFooterConstraints.forEach { $0.activate() }
            } else {
                self.showFooterConstraints.forEach { $0.deactivate() }
                self.hideFooterConstraints.forEach { $0.activate() }
            }
            self.view.layoutIfNeeded()
        }, completion: completion)
    }
}

extension MapViewController: GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        guard let placeID = marker.userData as? String,
                let place = displayedPlaces.first(where: { $0.id == placeID }) else {
            log.error("Unable to get place for marker data: \(marker.userData)")
            return true // if we return false, the map will do move & display an overlay, which we don't want.
        }

        updateSelected(marker: marker, andPlace: place)

        return true
    }

    func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
        switch mapState {
        case .initializing:
            // We init the map view with a position and then update the position so idleAt gets called.
            // Since it happens before the view is seen, we ignore this first call.
            mapState = .normal

        case .movingByCode:
            mapState = .normal // done moving.

        case .normal:
            if searchButton.isHidden {
                searchButton.setIsHiddenWithAnimations(false) // e.g. finger dragged.
            }
        }
    }
}

extension MapViewController: UIViewControllerAnimatedTransitioning, UIViewControllerTransitioningDelegate {
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        transitionContext.containerView.addSubview(view)
        view.layoutIfNeeded()

        UIView.animate(withDuration: 0.2, animations: {
            if transitionContext.viewController(forKey: .to) == self {
                self.hideMapConstraints.forEach { $0.deactivate() }
                self.showMapConstraints.forEach { $0.activate() }
            } else {
                self.showMapConstraints.forEach { $0.deactivate() }
                self.hideMapConstraints.forEach { $0.activate() }
            }

            self.view.layoutIfNeeded()
        }, completion: { _ in
            transitionContext.completeTransition(true)
        })
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.2
    }

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
}
