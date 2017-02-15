/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import MapKit
import QuartzCore
import EDSunriseSet
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

    // the top part of the background. Contains Number of Places, horizontal line & (soon to be) Current Location button
    lazy var headerView: PlaceCarouselHeaderView = {
        let view = PlaceCarouselHeaderView()
        view.backgroundColor = Colors.carouselViewHeaderBackground
        return view
    }()

    // View that will display the sunset and sunrise times
    lazy var sunView: UIView = {
        let view = UIView()
        view.backgroundColor = Colors.carouselViewHeaderBackground

        view.layer.shadowColor = UIColor.darkGray.cgColor
        view.layer.shadowOpacity = 0.25
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 2

        return view
    }()

    lazy var loadingOverlay = LoadingOverlayView(frame: CGRect.zero)

    // label displaying sunrise and sunset times
    lazy var sunriseSetTimesLabel: UILabel = {
        let label = UILabel()
        label.textColor = Colors.carouselViewSunriseSetTimesLabelText
        label.font = Fonts.carouselViewSunriseSetTimes
        return label
    }()

    var locationMonitor: LocationMonitor { return (UIApplication.shared.delegate! as! AppDelegate).locationMonitor }
    fileprivate var isNoLocationAlertPresented = false

    lazy var placeCarousel: PlaceCarousel = {
        let carousel = PlaceCarousel()
        carousel.delegate = self
        carousel.dataSource = self.placesProvider
        carousel.locationProvider = self.locationMonitor
        return carousel
    }()

    fileprivate var shouldFetchPlaces: Bool = true

    fileprivate var isLoading: Bool = false {
        didSet {
            headerView.alpha = isLoading ? 0 : 1
            sunView.alpha = isLoading ? 0 : 1
            placeCarousel.carousel.alpha = isLoading ? 0 : 1
            loadingOverlay.alpha = isLoading ? 1 : 0
        }
    }

    var sunriseSet: EDSunriseSet? {
        didSet {
            setSunriseSetTimes()
        }
    }

    fileprivate var notificationToastProvider: InAppNotificationToastProvider?

    private func setSunriseSetTimes() {
        let today = Date()

        guard let sunriseSet = self.sunriseSet else {
            return self.sunriseSetTimesLabel.text = nil
        }

        sunriseSet.calculateSunriseSunset(today)

        guard let sunrise = sunriseSet.localSunrise(),
            let sunset = sunriseSet.localSunset(),
            let calendar = NSCalendar(identifier: NSCalendar.Identifier.gregorian) else {
                return self.sunriseSetTimesLabel.text = nil
        }

        let sunriseToday = updateDateComponents(dateComponents: sunrise, toDate: today, withCalendar: calendar)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"

        if let sunriseTime = calendar.date(from: sunriseToday),
            sunriseTime > today {
            let timeAsString = dateFormatter.string(from: sunriseTime)
            return self.sunriseSetTimesLabel.text = "Sunrise is at \(timeAsString) today"
        }

        let sunsetToday = updateDateComponents(dateComponents: sunset, toDate: today, withCalendar: calendar)

        if let sunsetTime = calendar.date(from: sunsetToday),
            sunsetTime > today {
            let timeAsString = dateFormatter.string(from: sunsetTime)
            return self.sunriseSetTimesLabel.text = "Sunset is at \(timeAsString) today"
        }

        let tomorrow = today.addingTimeInterval(AppConstants.ONE_DAY)
        sunriseSet.calculateSunriseSunset(tomorrow)
        if let tomorrowSunrise = sunriseSet.localSunrise(),
            let tomorrowSunriseTime = calendar.date(from: tomorrowSunrise) {
            let timeAsString = dateFormatter.string(from: tomorrowSunriseTime)
            self.sunriseSetTimesLabel.text = "Sunrise is at \(timeAsString) tomorrow"
        } else {
            self.sunriseSetTimesLabel.text = nil
        }
    }

    private func updateDateComponents(dateComponents: DateComponents, toDate date: Date, withCalendar calendar: NSCalendar) -> DateComponents {
        var newDateComponents = dateComponents
        newDateComponents.day = calendar.component(NSCalendar.Unit.day, from: date)
        newDateComponents.month = calendar.component(NSCalendar.Unit.month, from: date)
        newDateComponents.year = calendar.component(NSCalendar.Unit.year, from: date)

        return newDateComponents
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)

        if let backgroundImage = UIImage(named: "map_background") {
            self.view.layer.contents = backgroundImage.cgImage
        }

        var constraints = [NSLayoutConstraint]()

        view.addSubview(sunView)
        constraints.append(contentsOf: [sunView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
                                        sunView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        sunView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        sunView.heightAnchor.constraint(equalToConstant: 90)])

        // add the views to the stack view
        view.addSubview(headerView)

        // setting up the layout constraints
        constraints.append(contentsOf: [headerView.topAnchor.constraint(equalTo: topLayoutGuide.topAnchor),
                                        headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        headerView.heightAnchor.constraint(equalToConstant: 150)])

        // set up the subviews for the sunrise/set view
        sunView.addSubview(sunriseSetTimesLabel)
        constraints.append(sunriseSetTimesLabel.leadingAnchor.constraint(equalTo: sunView.leadingAnchor, constant: 20))
        constraints.append(sunriseSetTimesLabel.topAnchor.constraint(equalTo: sunView.topAnchor, constant: 14))

        headerView.numberOfPlacesLabel.text = "" // placeholder

        view.addSubview(placeCarousel.carousel)
        constraints.append(contentsOf: [placeCarousel.carousel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        placeCarousel.carousel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        placeCarousel.carousel.topAnchor.constraint(equalTo: sunView.bottomAnchor, constant: -35),
                                        placeCarousel.carousel.heightAnchor.constraint(equalToConstant: 300)])

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
            if self.presentedViewController == nil {
                openDetail(forPlace: place)
            }
        } catch {
            NSLog("Unable to open first place as there are no places")
        }
    }

    func openDetail(forPlace place: Place, withCompletion completion: (() -> ())? = nil) {
        // if we are already displaying a place detail, don't try and display another one
        // places should be able to update beneath without affecting what the user currently sees
        if let _ = self.presentedViewController {
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

        if sunriseSet == nil {
            updateSunRiseSetTimes(forLocation: location)
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
                placeCarousel.refresh()
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

    fileprivate func updateSunRiseSetTimes(forLocation location: CLLocation) {
        let coord = location.coordinate
        // if we're running in the simulator, find the timezone of the current coordinates and calculate the sunrise/set times for then
        // this is so that, if we're simulating our location, we still get sunset/sunrise times
        #if (arch(i386) || arch(x86_64))
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let placemark = placemarks?.first {
                    DispatchQueue.main.async() {
                        self.sunriseSet = EDSunriseSet(timezone: placemark.timeZone, latitude: coord.latitude, longitude: coord.longitude)
                    }
                }
            }
        #else
            sunriseSet = EDSunriseSet(timezone: NSTimeZone.local, latitude: coord.latitude, longitude: coord.longitude)
        #endif

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

extension PlaceCarouselViewController: PlaceCarouselDelegate {
    func placeCarousel(placeCarousel: PlaceCarousel, didSelectPlaceAtIndex index: Int) {
        openDetail(forPlace: try! placesProvider.place(forIndex: index))
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
            headerView.numberOfPlacesLabel.text = "No Places Found"
        } else {
            loadingOverlay.fadeOutMessaging()
            headerView.numberOfPlacesLabel.text = "\(places.count) place" + (places.count != 1 ? "s" : "")
        }

        // Wrap the openClosedPlace in an async block to make sure its queued after the
        // carousel's refresh so the cells load before we invoke the transition.
        // TODO: This is a mess: we deadlock without the async wrapper. Fix this.
        DispatchQueue.main.async {
            self.openFirstPlace()
        }
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
            } else {
                let transition = MapPlacesTransition()
                transition.presenting = true
                return transition
            }
        }
        return nil
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if let detailVC = dismissed as? PlaceDetailViewController,
            let _ = placesProvider.index(forPlace: detailVC.currentPlace) {
            let transition = MapPlacesTransition()
            transition.presenting = false
            return transition
        }
        return nil
    }
}

