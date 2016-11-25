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

    var places: [Place] = [Place]() {
        didSet {
            if oldValue == places {
                return
            }
            // TODO: how do we make sure the user wasn't interacting?
            headerView.numberOfPlacesLabel.text = "\(places.count) place" + (places.count != 1 ? "s" : "")
            placeCarousel.refresh()
        }
    }

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

    lazy var placeCarousel: PlaceCarousel = {
        let carousel = PlaceCarousel()
        carousel.delegate = self
        carousel.dataSource = self
        carousel.locationProvider = self.locationMonitor
        return carousel
    }()

    fileprivate var shouldFetchPlaces: Bool = true

    var sunriseSet: EDSunriseSet? {
        didSet {
            setSunriseSetTimes()
        }
    }

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

        // add the views to the stack view
        view.addSubview(headerView)

        // setting up the layout constraints
        constraints.append(contentsOf: [headerView.topAnchor.constraint(equalTo: view.topAnchor),
                                        headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        headerView.heightAnchor.constraint(equalToConstant: 150)])

        view.addSubview(sunView)
        constraints.append(contentsOf: [sunView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
                                        sunView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        sunView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        sunView.heightAnchor.constraint(equalToConstant: 90)])


        // set up the subviews for the sunrise/set view
        sunView.addSubview(sunriseSetTimesLabel)
        constraints.append(sunriseSetTimesLabel.leadingAnchor.constraint(equalTo: sunView.leadingAnchor, constant: 20))
        constraints.append(sunriseSetTimesLabel.topAnchor.constraint(equalTo: sunView.topAnchor, constant: 14))

        headerView.numberOfPlacesLabel.text = "" // placeholder

        view.addSubview(placeCarousel.carousel)
        constraints.append(contentsOf: [placeCarousel.carousel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        placeCarousel.carousel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        placeCarousel.carousel.topAnchor.constraint(equalTo: sunView.bottomAnchor, constant: -35),
                                        placeCarousel.carousel.heightAnchor.constraint(equalToConstant: 275)])

        loadingOverlay.delegate = self
        view.addSubview(loadingOverlay)
        constraints.append(contentsOf: [loadingOverlay.topAnchor.constraint(equalTo: self.topLayoutGuide.bottomAnchor),
                                        loadingOverlay.bottomAnchor.constraint(equalTo: self.bottomLayoutGuide.topAnchor),
                                        loadingOverlay.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                                        loadingOverlay.rightAnchor.constraint(equalTo: self.view.rightAnchor)])

        // apply the constraints
        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)

        toggleLoadingUI(loading: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func openFirstPlace() {
        guard let place = places.first else {
            return
        }
        openDetail(forPlace: place)
    }

    func openDetail(forPlace place: Place) {
        // if we are already displaying a place detail, don't try and display another one
        // places should be able to update beneath without affecting what the user currently sees
        if let _ = self.presentedViewController {
            return
        }
        let placeDetailViewController = PlaceDetailViewController(place: place)
        placeDetailViewController.dataSource = self
        placeDetailViewController.locationProvider = self.locationMonitor
        placeDetailViewController.transitioningDelegate = self

        self.present(placeDetailViewController, animated: true, completion: nil)
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

    fileprivate func toggleLoadingUI(loading: Bool) {
        headerView.alpha = loading ? 0 : 1
        sunView.alpha = loading ? 0 : 1
        loadingOverlay.alpha = loading ? 1 : 0
    }

    fileprivate func updatePlaces(forLocation location: CLLocation) {
        // don't bother fetching new places when in the background.
        if UIApplication.shared.applicationState != .background {
            if shouldFetchPlaces {
                fetchPlaces(forLocation: location)
            } else {
                // re-sort places based on new location
                let sortedPlaces = PlaceUtilities.sort(places: self.places, byDistanceFromLocation: location)
                self.places = sortedPlaces
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

        self.present(alertController, animated: true)
    }

    func openPlaceForEvent(withKey key: String) {
        placesProvider.placeWithEvent(forKey: key) { place in
            DispatchQueue.main.async {
                guard let place = place else { return }
                guard let presentedVC = self.presentedViewController else {
                    // open the details screen for the place
                    return self.openDetail(forPlace: place)
                }

                // handle when the user is already looking at the app
                (presentedVC as? PlaceDetailViewController)?.openCard(forPlaceWithEvent: place)
            }
        }
    }
}

extension PlaceCarouselViewController: PlaceDataSource {

    func nextPlace(forPlace place: Place) -> Place? {
        // if the place isn't in the list, make the first item in the list the next item
        guard let currentPlaceIndex = places.index(where: {$0 == place}) else {
            return places[places.startIndex]
        }

        guard currentPlaceIndex + 1 < places.endIndex else { return nil }

        return places[places.index(after: currentPlaceIndex)]
    }

    func previousPlace(forPlace place: Place) -> Place? {
        guard let currentPlaceIndex = places.index(where: {$0 == place}),
            currentPlaceIndex > places.startIndex else { return nil }

        return places[places.index(before: currentPlaceIndex)]
    }

    func numberOfPlaces() -> Int {
        return places.count
    }

    func place(forIndex index: Int) throws -> Place {
        guard index < places.endIndex,
            index >= places.startIndex else {
            throw PlaceDataSourceError(message: "There is no place at index: \(index)")
        }

        return places[index]
    }

    func index(forPlace place: Place) -> Int? {
        return places.index(of: place)
    }
}

extension PlaceCarouselViewController: PlaceCarouselDelegate {
    func placeCarousel(placeCarousel: PlaceCarousel, didSelectPlaceAtIndex index: Int) {
        openDetail(forPlace: places[index])
    }
}

extension PlaceCarouselViewController: LocationMonitorDelegate {
    func locationMonitor(_ locationMonitor: LocationMonitor, didUpdateLocation location: CLLocation) {
        updateLocation(location: location)
    }

    func locationMonitor(_ locationMonitor: LocationMonitor, userDidVisitLocation location: CLLocation) {
        let eventNotificationsManager = EventNotificationsManager(withLocationProvider: locationMonitor)
        eventNotificationsManager.sendEventNotifications(forLocation: location)
    }
    func locationMonitorNeedsUserPermissionsPrompt(_ locationMonitor: LocationMonitor) {
        presentSettingsOrQuitPrompt()
    }

    func locationMonitor(_ locationMonitor: LocationMonitor, userDidExitCurrentLocation location: CLLocation) {
        locationMonitor.refreshLocation()
    }
}

extension PlaceCarouselViewController: PlacesProviderDelegate {
    fileprivate func showErrorMessageIfNoPlaces() {
        if self.places.isEmpty {
            loadingOverlay.fadeInMessaging()
            headerView.numberOfPlacesLabel.text = "No Places Found"
        }
    }

    func placesProviderWillStartFetchingPlaces(_ controller: PlacesProvider) {
    }

    func placesProviderDidFinishFetchingPlaces(_ controller: PlacesProvider) {
        showErrorMessageIfNoPlaces()
    }

    func placesProvider(_ controller: PlacesProvider, didReceivePlaces places: [Place]) {
        let wasEmpty = self.places.isEmpty
        self.places = places

        (self.presentedViewController as? PlaceDetailViewController)?.placesUpdated()

        if wasEmpty && !places.isEmpty {
            toggleLoadingUI(loading: false)

            // Wrap the openClosedPlace in an async block to make sure its queued after the
            // carousel's refresh so the cells load before we invoke the transition
            DispatchQueue.main.async {
                self.openFirstPlace()
            }
        }
    }

    func placesProvider(_ controller: PlacesProvider, didError error: Error) {
        showErrorMessageIfNoPlaces()
    }

    func placesProviderDidTimeout(_ controller: PlacesProvider) {
        showErrorMessageIfNoPlaces()
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
        if let _ = presented as? PlaceDetailViewController {
            let transition = MapPlacesTransition()
            transition.presenting = true
            return transition
        }
        return nil
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if let _ = dismissed as? PlaceDetailViewController {
            let transition = MapPlacesTransition()
            transition.presenting = false
            return transition
        }
        return nil
    }
}

