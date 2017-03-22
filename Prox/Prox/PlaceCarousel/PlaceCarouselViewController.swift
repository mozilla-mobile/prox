/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import MapKit
import QuartzCore
import Deferred

struct PlaceDataSourceError: Error {
    let message: String
}

fileprivate let placesFetchMonitorIdentifier = "PlaceFetchRadiusMonitor"

class PlaceCarouselViewController: UIViewController {

    lazy var placesProvider: PlacesProvider = {
        let controller = PlacesProvider()
        controller.delegate = self
        return controller
    }()

    fileprivate lazy var loadingOverlay: LoadingOverlayView = {
        let view = LoadingOverlayView(frame: .zero)
        view.delegate = self
        return view
    }()
    fileprivate var isLoading: Bool = false {
        didSet { loadingOverlay.alpha = isLoading ? 1 : 0 }
    }

    fileprivate var locationMonitor: LocationMonitor { return (UIApplication.shared.delegate! as! AppDelegate).locationMonitor }

    fileprivate var shouldFetchPlaces: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        initLoadingOverlay()
    }

    private func initLoadingOverlay() {
        loadingOverlay.addAsSubview(on: view)
        isLoading = true
    }

    func openFirstPlace() {
        do {
            let place = try placesProvider.place(forIndex: 0)
            openDetail(forPlace: place)
        } catch {
            NSLog("Unable to open first place as there are no places")
        }
    }

    func openDetail(forPlace place: Place, withCompletion completion: (() -> ())? = nil) {
        if let presented = self.presentedViewController as? PlaceDetailViewController {
            presented.openCard(forExistingPlace: place)
            return
        }

        let placeDetailViewController = PlaceDetailViewController(place: place, locationProvider: self.locationMonitor)
        placeDetailViewController.dataSource = placesProvider
        placeDetailViewController.transitioningDelegate = self

        self.present(placeDetailViewController, animated: true, completion: completion)
    }

    @objc fileprivate func willEnterForeground() {
        self.shouldFetchPlaces = true
    }

    fileprivate func updatePlaces(forLocation location: CLLocation) {
        // don't bother fetching new places when in the background.
        if UIApplication.shared.applicationState != .background {
            if shouldFetchPlaces {
                fetchPlaces(forLocation: location)
            } else {
                // re-sort places based on new location
                placesProvider.sortPlaces(byLocation: location)
            }
        }
    }

    fileprivate func fetchPlaces(forLocation location: CLLocation) {
        self.placesProvider.updatePlaces(forLocation: location)
        let placeMonitoringRadius = RemoteConfigKeys.searchRadiusInKm.value / 4
        locationMonitor.startMonitoring(location: location, withIdentifier: placesFetchMonitorIdentifier, withRadius: placeMonitoringRadius, forEntry: nil, forExit: { region in
            self.locationMonitor.stopMonitoringRegion(withIdentifier: placesFetchMonitorIdentifier)
            self.shouldFetchPlaces = true
        })
        self.shouldFetchPlaces = false
    }
}

extension PlaceCarouselViewController: LocationMonitorDelegate {
    func locationMonitor(_ locationMonitor: LocationMonitor, didUpdateLocation location: CLLocation) {
        if !Prompts.isNoLocationAlertPresented {
            updateLocation(location: location)
            return
        }

        // If we don't dismiss the location alert, the detail view controller (called from
        // updateLocation) does not get presented.
        dismiss(animated: true) {
            Prompts.isNoLocationAlertPresented = false
            self.updateLocation(location: location)
        }
    }

    private func updateLocation(location: CLLocation) {
        if let timeOfLastLocationUpdate = locationMonitor.timeOfLastLocationUpdate,
            timeOfLastLocationUpdate < location.timestamp {
            locationMonitor.startMonitoringForVisitAtCurrentLocation()
        }

        updatePlaces(forLocation: location)
    }
    
    func locationMonitorNeedsUserPermissionsPrompt(_ locationMonitor: LocationMonitor) {
        Prompts.presentSettingsOrQuitPrompt(for: self)
    }

    func locationMonitor(_ locationMonitor: LocationMonitor, userDidExitCurrentLocation location: CLLocation) {
        locationMonitor.refreshLocation()
    }

    func locationMonitor(_ locationMonitor: LocationMonitor, didFailInitialUpdateWithError error: Error) {
        // Note: actually, at this point, if the location comes, `didUpdateLocation` will be called.
        Prompts.presentNoLocationAlert(for: self)
    }
}

extension PlaceCarouselViewController: PlacesProviderDelegate {
    func placesProvider(_ controller: PlacesProvider, didUpdatePlaces places: [Place]) {
        if places.count == 0 {
            // We don't want to show two error pop-ups: checking for any VC is a superset, but simple.
            let isOtherViewControllerShown = presentedViewController != nil
            let hasLocation = locationMonitor.getCurrentLocation() != nil
            guard hasLocation, !isOtherViewControllerShown else {
                Prompts.presentNoLocationAlert(for: self)
                return // Don't show "Try again" button - it could be misleading.
            }

            loadingOverlay.fadeInMessaging()
        } else {
            loadingOverlay.fadeOutMessaging()
        }

        self.openFirstPlace()
    }
}

extension PlaceCarouselViewController: LoadingOverlayDelegate {
    func loadingOverlayDidTapSearchAgain() {
        guard let location = locationMonitor.getCurrentLocation() else { return }
        self.placesProvider.updatePlaces(forLocation: location)
    }
}

extension PlaceCarouselViewController: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if let detailVC = presented as? PlaceDetailViewController,
            let _ = placesProvider.index(forPlace: detailVC.currentPlace) {
            if isLoading {
                let fadeTransition = CrossFadeTransition()

                // Hide the loading state after we've transitioned away from this view controller
                fadeTransition.completionCallback = {
                    self.isLoading = false
                }
                return fadeTransition
            }
        }
        return nil
    }
}

