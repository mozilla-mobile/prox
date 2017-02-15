/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import MapKit
import QuartzCore
import Deferred

protocol PlaceDataSource: class {
    func nextPlace(forPlace place: Place) -> Place?
    func previousPlace(forPlace place: Place) -> Place?
    func numberOfPlaces() -> Int
    func place(forIndex: Int) throws -> Place
    func index(forPlace: Place) -> Int?
    func fetchPlace(placeKey: String, withEvent eventKey: String, callback: @escaping (Place?) -> ())
    func sortPlaces(byLocation location: CLLocation)

    /// Returns all nearby places filtered by the given set of filters.
    /// This function does not modify the data source.
    func filterPlaces(filters: [PlaceFilter]) -> [Place]

    /// Refreshes the data source by filtering with the enabled filters.
    func refresh()

    /// You must call refresh() after changing the enabled state of any filter!
    var filters: [PlaceFilter] { get }
}

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

    lazy var loadingOverlay = LoadingOverlayView(frame: CGRect.zero)

    var locationMonitor: LocationMonitor { return (UIApplication.shared.delegate! as! AppDelegate).locationMonitor }
    fileprivate var isNoLocationAlertPresented = false

    fileprivate var shouldFetchPlaces: Bool = true

    fileprivate var isLoading: Bool = false {
        didSet {
            loadingOverlay.alpha = isLoading ? 1 : 0
        }
    }

    fileprivate var notificationToastProvider: InAppNotificationToastProvider?

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)

        if let backgroundImage = UIImage(named: "map_background") {
            self.view.layer.contents = backgroundImage.cgImage
        }

        var constraints = [NSLayoutConstraint]()
        loadingOverlay.delegate = self
        view.addSubview(loadingOverlay)
        constraints.append(contentsOf: [loadingOverlay.topAnchor.constraint(equalTo: self.topLayoutGuide.bottomAnchor),
                                        loadingOverlay.bottomAnchor.constraint(equalTo: self.bottomLayoutGuide.topAnchor),
                                        loadingOverlay.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                                        loadingOverlay.rightAnchor.constraint(equalTo: self.view.rightAnchor)])

        // apply the constraints
        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)

        isLoading = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
            presented.openCard(forPlaceWithEvent: place)
            return
        }

        let placeDetailViewController = PlaceDetailViewController(place: place)
        placeDetailViewController.dataSource = placesProvider
        placeDetailViewController.locationProvider = self.locationMonitor
        placeDetailViewController.transitioningDelegate = self

        self.present(placeDetailViewController, animated: true, completion: completion)
    }

    @objc fileprivate func willEnterForeground() {
        self.shouldFetchPlaces = true
    }

    // MARK: Location Handling
    fileprivate func updateLocation(location: CLLocation) {
        if let timeOfLastLocationUpdate = locationMonitor.timeOfLastLocationUpdate,
            timeOfLastLocationUpdate < location.timestamp {
            locationMonitor.startMonitoringForVisitAtCurrentLocation()
        }

        updatePlaces(forLocation: location)
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

    fileprivate func presentSettingsOrQuitPrompt() {
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
        self.present(alertController, animated: true)
    }

    fileprivate func presentNoLocationAlert() {
        // The message says to close and restart Prox, however, at time of writing, this is not
        // always necessary: if we receive a location event while or after the dialog is displayed,
        // we'll show the places. It's used as a catch all because we don't know for sure what
        // causes the loading screen stall (#392).
        let alert = UIAlertController(title: "Where did you go?",
                                      message: "We can't find your current location. Please close and restart Prox.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK, got it.", style: .default) { _ in
            self.dismiss(animated: true) { self.isNoLocationAlertPresented = false }
        })

        self.present(alert, animated: true) { self.isNoLocationAlertPresented = true }
    }

    func openPlace(placeKey: String, forEventWithKey eventKey: String) {
        placesProvider.place(withKey: placeKey, forEventWithKey: eventKey) { place in
            guard let place = place else { return }
            DispatchQueue.main.async {
                guard let presentedVC = self.presentedViewController else {
                    // open the details screen for the place
                    return self.openDetail(forPlace: place)
                }

                // handle when the user is already looking at the app
                (presentedVC as? PlaceDetailViewController)?.openCard(forPlaceWithEvent: place)
            }
        }
    }

    fileprivate func openPlace(_ place: Place) {
        guard let presentedVC = self.presentedViewController as? PlaceDetailViewController else {
        // open the details screen for the place
            return self.openDetail(forPlace: place)
        }

        // handle when the user is already looking at the app
        presentedVC.openCard(forPlaceWithEvent: place)
    }

    func presentInAppEventNotification(forEventWithKey eventKey: String, atPlaceWithKey placeKey: String, withDescription description: String) {
        DispatchQueue.main.async {
            guard let presentedVC = self.presentedViewController as? PlaceDetailViewController else {
                // open the details screen for the place
                return self.presentToast(withText: description, forEventWithId: eventKey, atPlaceWithId: placeKey)
            }

            // handle when the user is already looking at the app
            presentedVC.presentToast(withText: description, forEvent: eventKey, atPlace: placeKey)
        }
    }

    private func presentToast(withText text: String, forEventWithId eventId: String, atPlaceWithId placeId: String) {
        if notificationToastProvider == nil {
            notificationToastProvider = InAppNotificationToastProvider(placeId: placeId, eventId: eventId, text: text)
            notificationToastProvider?.delegate = self
            notificationToastProvider?.presentOnView(self.view)
        }
    }
}

extension PlaceCarouselViewController: InAppNotificationToastDelegate {
    internal func inAppNotificationToastProvider(_ toast: InAppNotificationToastProvider, userDidRespondToNotificationForEventWithId eventId: String, atPlaceWithId placeId: String) {
        placesProvider.fetchPlace(placeKey: placeId, withEvent: eventId) { place in
            guard let place = place else {
                NSLog("Unable to find place with id \(placeId) and event with id \(eventId)")
                return
            }
            DispatchQueue.main.async {
                self.openDetail(forPlace: place)
            }
        }
    }

    func inAppNotificationToastProviderDidDismiss(_ toast: InAppNotificationToastProvider) {
        self.notificationToastProvider = nil
    }
}

extension PlaceCarouselViewController: LocationMonitorDelegate {
    func locationMonitor(_ locationMonitor: LocationMonitor, didUpdateLocation location: CLLocation) {
        if !isNoLocationAlertPresented {
            updateLocation(location: location)
            return
        }

        // If we don't dismiss the location alert, the detail view controller (called from
        // updateLocation) does not get presented.
        dismiss(animated: true) {
            self.isNoLocationAlertPresented = false
            self.updateLocation(location: location)
        }
    }

    func locationMonitor(_ locationMonitor: LocationMonitor, userDidVisitLocation location: CLLocation) {
        guard AppConstants.areNotificationsEnabled else { return }
        let eventNotificationsManager = EventNotificationsManager(withLocationProvider: locationMonitor)
        eventNotificationsManager.checkForEventsToNotify(forLocation: location)
    }
    
    func locationMonitorNeedsUserPermissionsPrompt(_ locationMonitor: LocationMonitor) {
        presentSettingsOrQuitPrompt()
    }

    func locationMonitor(_ locationMonitor: LocationMonitor, userDidExitCurrentLocation location: CLLocation) {
        locationMonitor.refreshLocation()
    }

    func locationMonitor(_ locationMonitor: LocationMonitor, didFailInitialUpdateWithError error: Error) {
        // Note: actually, at this point, if the location comes, `didUpdateLocation` will be called.
        presentNoLocationAlert()
    }
}

extension PlaceCarouselViewController: PlacesProviderDelegate {
    func placesProvider(_ controller: PlacesProvider, didUpdatePlaces places: [Place]) {
        if places.count == 0 {
            // We don't want to show two error pop-ups: checking for any VC is a superset, but simple.
            let isOtherViewControllerShown = presentedViewController != nil
            let hasLocation = locationMonitor.getCurrentLocation() != nil
            guard hasLocation, !isOtherViewControllerShown else {
                presentNoLocationAlert()
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
        guard let location = locationMonitor.getCurrentLocation() else {
            return
        }
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

